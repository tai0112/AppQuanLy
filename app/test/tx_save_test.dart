// Thêm giao dịch không làm giật các màn phía sau:
// - lưu xong ghi ngay xuống máy, nhưng các màn khác chỉ được báo SAU khi màn nhập đóng xong;
// - tổng theo khoảng thời gian (đã nhớ) cho kết quả giống cách tính cũ;
// - đồng bộ trả về đúng bản vừa đẩy lên thì không tăng phiên bản bảng (không tính lại).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lht_money/core/theme.dart';
import 'package:lht_money/data/local_store.dart';
import 'package:lht_money/data/logic.dart';
import 'package:lht_money/data/models.dart';
import 'package:lht_money/features/transactions.dart';
import 'package:lht_money/providers.dart';

void main() {
  late LocalStore store;
  late String acc;
  late List<String> cats;

  setUpAll(() async {
    await initializeDateFormatting('vi');
    final dir = await Directory.systemTemp.createTemp('lht_tx_save');
    Hive.init(dir.path);
    store = LocalStore();
    await store.initForTest(filesDir: '${dir.path}/files');
    services = Services.forTest(store);
    store.put(E.appSettings, {'baseCurrencyCode': 'VND', 'financeMonthStartDay': 1, 'firstDayOfWeek': 1});
    store.put(E.currencies, {'code': 'VND', 'name': 'VND', 'symbol': '₫', 'decimals': 0, 'symbolPosition': 1, 'isBase': true});
    acc = store.put(E.accounts, {'name': 'Tiền mặt', 'type': 1, 'currencyCode': 'VND', 'openingBalance': 0})['id'] as String;
    final parent = store.put(E.categories, {'name': 'Ăn uống', 'type': 1, 'icon': 'restaurant', 'sortOrder': 0})['id'] as String;
    cats = [
      parent,
      store.put(E.categories, {'name': 'Ăn sáng', 'type': 1, 'parentId': parent, 'sortOrder': 1})['id'] as String,
      store.put(E.categories, {'name': 'Lương', 'type': 2, 'sortOrder': 2})['id'] as String,
    ];
    final now = DateTime.now();
    for (var i = 0; i < 300; i++) {
      store.put(E.transactions, {
        'type': i % 5 == 0 ? 2 : 1,
        'amount': 1000 + i,
        'currencyCode': 'VND',
        'accountId': acc,
        'categoryId': i % 5 == 0 ? cats[2] : cats[i % 2],
        'occurredAt': now.subtract(Duration(hours: i * 7)).toUtc().toIso8601String(),
      }, notify: false);
    }
    store.commit();
  });

  test('totalsIn / byCategoryIn (đã nhớ) giống cách tính cũ, và cập nhật khi có giao dịch mới', () {
    var f = Finance(store);
    final (from, to) = f.monthRange(DateTime.now());
    expect(f.totalsIn(from, to), f.totals(f.inRange(from, to)));
    String flat(List<({Category? category, double amount})> l) => l.map((g) => '${g.category?.id}=${g.amount}').join(',');
    expect(flat(f.byCategoryIn(from, to, TxType.expense)), flat(f.byCategory(f.inRange(from, to), TxType.expense)));
    expect(flat(f.byCategoryIn(from, to, TxType.expense, parentId: cats[0])), flat(f.byCategory(f.inRange(from, to), TxType.expense, parentId: cats[0])));
    final before = f.totalsIn(from, to).expense;

    store.put(E.transactions, {
      'type': 1,
      'amount': 777,
      'currencyCode': 'VND',
      'accountId': acc,
      'categoryId': cats[1],
      'occurredAt': DateTime.now().toUtc().toIso8601String(),
    });
    f = Finance(store);
    expect(f.totalsIn(from, to).expense, before + 777, reason: 'giao dịch mới phải vào tổng (bộ nhớ theo phiên bản bảng)');
    expect(f.transactions.first.amount, 777, reason: 'danh sách vẫn sắp mới → cũ');
  });

  test('đồng bộ trả về đúng bản vừa đẩy lên: không tăng phiên bản bảng; khác nội dung thì có', () {
    final rec = store.put(E.categories, {'name': 'Thử', 'type': 1, 'sortOrder': 9});
    store.markSynced(E.categories, rec['id'] as String);
    final v0 = store.entityVersion(E.categories);
    // Server: thêm userId, mốc thời gian khác, số dạng 9.0 — cùng nội dung.
    store.applyRemote(E.categories, {
      ...rec,
      'sortOrder': 9.0,
      'userId': 'u1',
      'updatedAt': DateTime.now().add(const Duration(seconds: 3)).toUtc().toIso8601String(),
    });
    expect(store.entityVersion(E.categories), v0);

    store.applyRemote(E.categories, {...rec, 'name': 'Đã đổi trên máy khác'});
    expect(store.entityVersion(E.categories), greaterThan(v0));
    expect(store.get(E.categories, rec['id'] as String)!['name'], 'Đã đổi trên máy khác');

    expect(LocalStore.sameContent({'occurredAt': '2026-11-27T07:00:00.000Z'}, {'occurredAt': '2026-11-27T14:00:00+07:00'}), isTrue);
    expect(LocalStore.sameContent({'amount': 1}, {'amount': 2}), isFalse);
  });

  testWidgets('bấm Lưu: dữ liệu ghi ngay, nhưng màn phía sau chỉ cập nhật sau khi màn nhập đóng xong', (t) async {
    var homeBuilds = 0;
    await t.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildTheme(Brightness.light, AppColors.seeds.first),
          locale: const Locale('vi'),
          supportedLocales: const [Locale('vi')],
          localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
          home: Consumer(
            builder: (c, ref, _) {
              final n = ref.watch(financeProvider).transactions.length;
              homeBuilds++;
              return Scaffold(
                body: Text('n=$n'),
                floatingActionButton: FloatingActionButton(onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const TransactionEditPage()))),
              );
            },
          ),
        ),
      ),
    );
    final n0 = Finance(store).transactions.length;
    expect(find.text('n=$n0'), findsOneWidget);

    await t.tap(find.byType(FloatingActionButton));
    await t.pumpAndSettle(const Duration(milliseconds: 50));
    await t.enterText(find.byType(TextField).first, '45000');
    FocusManager.instance.primaryFocus?.unfocus();
    await t.pumpAndSettle(const Duration(milliseconds: 50));
    await t.tap(find.text('Ăn uống').first);
    await t.pump(const Duration(milliseconds: 300));

    final buildsBefore = homeBuilds;
    await t.tap(find.textContaining('Lưu khoản chi'));
    await t.pump(); // bấm Lưu
    expect(store.all(E.transactions).where((m) => m['amount'] == 45000), hasLength(1), reason: 'đã ghi xuống máy ngay');

    // Trong lúc màn nhập đang trượt ra: màn phía sau KHÔNG dựng lại.
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 16));
    }
    expect(homeBuilds, buildsBefore, reason: 'không dựng lại màn phía sau giữa hiệu ứng đóng');

    await t.pumpAndSettle();
    expect(find.text('n=${n0 + 1}'), findsOneWidget, reason: 'đóng xong thì màn phía sau cập nhật');
    expect(t.takeException(), isNull);
  });
}
