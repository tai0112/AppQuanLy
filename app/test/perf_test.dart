import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:lht_money/data/local_store.dart';
import 'package:lht_money/data/logic.dart';
import 'package:lht_money/data/models.dart';

/// Đo hiệu năng phần tính toán khi dữ liệu lớn (5.000 giao dịch, 12 tài khoản, 60 danh mục, 10 định mức).
/// Mỗi lần dữ liệu đổi, màn hình gọi lại các phép tính này — phải đủ nhanh để không giật (< 16ms/khung hình).
void main() {
  late LocalStore store;

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('lht_perf');
    Hive.init(dir.path);
    store = LocalStore();
    await store.initForTest();
    final accIds = <String>[];
    for (var i = 0; i < 12; i++) {
      accIds.add(
        store.put(E.accounts, {'name': 'TK $i', 'type': i == 0 ? 1 : 2, 'currencyCode': 'VND', 'openingBalance': 1000000}, notify: false)['id'] as String,
      );
    }
    final catIds = <String>[];
    for (var i = 0; i < 60; i++) {
      catIds.add(store.put(E.categories, {'name': 'DM $i', 'type': 1, 'parentId': i >= 10 ? catIds[i % 10] : null}, notify: false)['id'] as String);
    }
    final now = DateTime.now();
    for (var i = 0; i < 5000; i++) {
      store.put(E.transactions, {
        'type': i % 7 == 0 ? 2 : 1,
        'amount': 10000 + i,
        'currencyCode': 'VND',
        'accountId': accIds[i % 12],
        'categoryId': catIds[i % 60],
        'occurredAt': now.subtract(Duration(hours: i * 3)).toUtc().toIso8601String(),
      }, notify: false);
    }
    for (var i = 0; i < 10; i++) {
      store.put(E.budgets, {
        'name': 'B$i',
        'scope': 2,
        'refId': catIds[i],
        'period': 3,
        'limitAmount': 2000000,
        'currencyCode': 'VND',
        'warnPercent': 80,
        'isActive': true,
      }, notify: false);
    }
  });

  test('Thời gian tính một khung hình trang chủ + thống kê', () {
    final sw = Stopwatch()..start();
    const rounds = 20;
    for (var r = 0; r < rounds; r++) {
      final f = Finance(store); // mỗi lần dữ liệu đổi sẽ tạo Finance mới
      final (from, to) = f.monthRange(DateTime.now());
      final month = f.inRange(from, to);
      f.totals(month);
      f.totalBalance;
      for (final a in f.accounts) {
        f.balance(a);
      }
      f.byCategory(month, TxType.expense);
      for (final b in f.budgets) {
        f.budgetSpent(b);
      }
      // 30 dòng giao dịch: mỗi dòng tra danh mục + tài khoản
      for (final t in f.transactions.take(30)) {
        f.category(t.categoryId);
        f.account(t.accountId);
        f.rootCategory(t.categoryId);
      }
    }
    final ms = sw.elapsedMicroseconds / 1000 / rounds;
    // ignore: avoid_print
    print('⏱  Trung bình ${ms.toStringAsFixed(1)} ms / lần tính (5.000 giao dịch)');
    expect(ms, lessThan(50)); // một khung hình 60fps = 16ms; giữ dư địa cho máy yếu
  });

  test('Sau khi thêm 1 giao dịch (bảng giao dịch đổi thật)', () {
    void frame() {
      final f = Finance(store);
      final (from, to) = f.monthRange(DateTime.now());
      final month = f.inRange(from, to);
      f.totals(month);
      f.totalBalance;
      for (final a in f.accounts) {
        f.balance(a);
      }
      f.byCategory(month, TxType.expense);
      for (final b in f.budgets) {
        f.budgetSpent(b);
      }
    }

    frame();
    final acc = store.all(E.accounts).first['id'];
    const rounds = 20;
    final sw = Stopwatch()..start();
    for (var r = 0; r < rounds; r++) {
      store.put(E.transactions, {'type': 1, 'amount': 5000, 'currencyCode': 'VND', 'accountId': acc, 'occurredAt': DateTime.now().toUtc().toIso8601String()});
      frame();
    }
    final ms = sw.elapsedMicroseconds / 1000 / rounds;
    // ignore: avoid_print
    print('⏱  Thêm 1 giao dịch → tính lại: ${ms.toStringAsFixed(1)} ms');
    expect(ms, lessThan(30));
  });
}
