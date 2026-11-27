// Màn Giao dịch dạng lịch: vuốt sang tháng khác phải mượt (một hiệu ứng trượt trang, không chồng mờ chéo cả khối lịch),
// tháng mới hiện đủ số liệu, tiêu đề / tổng đổi sau khi trượt xong.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lht_money/core/format.dart';
import 'package:lht_money/core/theme.dart';
import 'package:lht_money/data/local_store.dart';
import 'package:lht_money/features/transactions.dart';
import 'package:lht_money/providers.dart';
import 'package:table_calendar/table_calendar.dart';

void main() {
  late LocalStore store;

  setUpAll(() async {
    await initializeDateFormatting('vi');
    final dir = await Directory.systemTemp.createTemp('lht_cal_swipe');
    Hive.init(dir.path);
    store = LocalStore();
    await store.initForTest(filesDir: '${dir.path}/files');
    services = Services.forTest(store);
    store.put(E.appSettings, {'baseCurrencyCode': 'VND', 'financeMonthStartDay': 1, 'firstDayOfWeek': 1});
    store.put(E.currencies, {'code': 'VND', 'name': 'VND', 'symbol': '₫', 'decimals': 0, 'symbolPosition': 1, 'isBase': true});
    final acc = store.put(E.accounts, {'name': 'Tiền mặt', 'type': 1, 'currencyCode': 'VND', 'openingBalance': 0})['id'];
    final cat = store.put(E.categories, {'name': 'Ăn uống', 'type': 1, 'icon': 'restaurant', 'color': '#F76B15'})['id'];
    final now = DateTime.now();
    for (var i = 0; i < 5000; i++) {
      store.put(E.transactions, {
        'type': i % 6 == 0 ? 2 : 1,
        'amount': 10000 + i,
        'currencyCode': 'VND',
        'accountId': acc,
        'categoryId': cat,
        'occurredAt': now.subtract(Duration(hours: i * 3)).toUtc().toIso8601String(),
      }, notify: false);
    }
    store.commit();
  });

  testWidgets('vuốt lịch sang tháng trước: mượt, tháng mới có số liệu, tiêu đề đổi sau khi trượt xong', (t) async {
    t.view.physicalSize = const Size(390 * 3, 800 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildTheme(Brightness.light, AppColors.seeds.first),
          locale: const Locale('vi'),
          supportedLocales: const [Locale('vi')],
          localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
          home: const TransactionsPage(),
        ),
      ),
    );
    for (var i = 0; i < 120; i++) {
      await t.pump(const Duration(milliseconds: 16));
    }
    final now = DateTime.now();
    final prev = DateTime(now.year, now.month - 1, 15);
    expect(find.text('Tháng ${Fmt.month(DateTime(now.year, now.month, 1))}'), findsOneWidget);

    // Vuốt phải trên lịch (sang tháng trước), đo từng khung hình đến khi xong.
    final cal = find.byWidgetPredicate((w) => w is TableCalendar);
    final g = await t.startGesture(t.getCenter(cal));
    final sw = Stopwatch();
    var worst = 0, total = 0, frames = 0, dragWorst = 0;
    final slow = <String>[];
    Future<void> frame(Future<void> Function() step) async {
      sw
        ..reset()
        ..start();
      await step();
      sw.stop();
      worst = sw.elapsedMicroseconds > worst ? sw.elapsedMicroseconds : worst;
      // Khung giữa lúc đang kéo (bỏ khung đầu: dựng trang bên cạnh) — trước đây đổi tháng + mờ chéo chen vào đây.
      if (frames >= 2 && frames <= 11 && sw.elapsedMicroseconds > dragWorst) dragWorst = sw.elapsedMicroseconds;
      if (sw.elapsedMicroseconds > 30000) slow.add('#$frames=${sw.elapsedMicroseconds ~/ 1000}ms');
      total += sw.elapsedMicroseconds;
      frames++;
    }

    for (var k = 0; k < 12; k++) {
      await frame(() async {
        await g.moveBy(const Offset(25, 0));
        await t.pump(const Duration(milliseconds: 16));
      });
    }
    await g.up();
    // Phần đầu trang đổi CÙNG LÚC với lịch (không đợi trượt xong mới đổi): sau 3 khung đã thấy tháng mới.
    for (var k = 0; k < 3; k++) {
      await frame(() => t.pump(const Duration(milliseconds: 16)));
    }
    expect(find.text('Tháng ${Fmt.month(DateTime(prev.year, prev.month, 1))}'), findsWidgets, reason: 'tiêu đề đổi ngay khi lịch trượt');
    for (var k = 0; k < 47; k++) {
      await frame(() => t.pump(const Duration(milliseconds: 16)));
    }
    // ignore: avoid_print
    print(
      'Vuốt đổi tháng: ${frames} khung, trung bình ${(total / frames / 1000).toStringAsFixed(1)} ms, chậm nhất ${(worst / 1000).toStringAsFixed(1)} ms · khung > 30 ms: $slow',
    );

    expect(find.text('Tháng ${Fmt.month(DateTime(prev.year, prev.month, 1))}'), findsOneWidget, reason: 'đã sang tháng trước');
    expect(dragWorst, lessThan(60000), reason: 'giữa lúc đang kéo không được có khung nặng (đổi tháng phải đợi trượt xong)');
    expect(t.takeException(), isNull);
  }, retry: 2); // đo thời gian thật: máy bận có thể trượt ngẫu nhiên
}
