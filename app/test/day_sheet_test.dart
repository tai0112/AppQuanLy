// Màn Giao dịch dạng lịch: chạm vào một ngày → mở bảng giao dịch của ngày (danh sách / 3 ô / 4 ô), không tràn bố cục.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lht_money/core/theme.dart';
import 'package:lht_money/data/local_store.dart';
import 'package:lht_money/features/transactions.dart';
import 'package:lht_money/providers.dart';
import 'package:table_calendar/table_calendar.dart';

void main() {
  late LocalStore store;

  setUpAll(() async {
    await initializeDateFormatting('vi');
    final dir = await Directory.systemTemp.createTemp('lht_day_sheet');
    Hive.init(dir.path);
    store = LocalStore();
    await store.initForTest();
    services = Services.forTest(store);
    store.put(E.appSettings, {'baseCurrencyCode': 'VND', 'financeMonthStartDay': 1, 'firstDayOfWeek': 1});
    store.put(E.currencies, {'code': 'VND', 'name': 'VND', 'symbol': '₫', 'decimals': 0, 'symbolPosition': 1, 'isBase': true});
    final acc = store.put(E.accounts, {'name': 'Tiền mặt', 'type': 1, 'currencyCode': 'VND', 'openingBalance': 0})['id'];
    final cat = store.put(E.categories, {'name': 'Ăn uống rất là dài tên', 'type': 1, 'icon': 'restaurant', 'color': '#F76B15'})['id'];
    final now = DateTime.now();
    for (var i = 0; i < 7; i++) {
      store.put(E.transactions, {
        'type': i == 6 ? 2 : 1,
        'amount': 1234567 + i * 1000,
        'currencyCode': 'VND',
        'accountId': acc,
        'categoryId': i == 6 ? null : cat,
        'occurredAt': DateTime(now.year, now.month, now.day, 8 + i).toUtc().toIso8601String(),
        'note': 'Ghi chú khá dài cho giao dịch số $i',
      });
    }
  });

  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 90; i++) {
      await t.pump(const Duration(milliseconds: 16));
    }
  }

  testWidgets('chạm ngày mở bảng (danh sách / 3 ô / 4 ô không tràn); vuốt mép đổi tháng', (t) async {
    // Màn hẹp (360dp) để bắt lỗi tràn chữ ở lưới 4 ô
    t.view.physicalSize = const Size(360 * 3, 780 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildTheme(Brightness.dark, AppColors.seeds.first),
          locale: const Locale('vi'),
          supportedLocales: const [Locale('vi')],
          localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
          home: const TransactionsPage(),
        ),
      ),
    );
    await settle(t);

    final today = DateTime.now().day;
    await t.tap(find.descendant(of: find.byWidgetPredicate((w) => w is TableCalendar), matching: find.text('$today')).first);
    await settle(t);

    expect(find.text('3 ô'), findsOneWidget, reason: 'bảng ngày phải mở ra');
    expect(find.textContaining('7 giao dịch'), findsWidgets);

    for (final mode in ['4 ô', 'Danh sách', '3 ô']) {
      await t.tap(find.text(mode));
      await settle(t);
      expect(t.takeException(), isNull, reason: 'chế độ $mode không được lỗi bố cục');
    }
    expect(store.meta('txDayView'), '3', reason: 'nhớ kiểu xem đã chọn');

    // Đóng bảng, rồi thử vuốt mép để đổi tháng (cùng một ProviderScope như app thật).
    Navigator.of(t.element(find.text('3 ô'))).pop();
    await settle(t);
    String label(DateTime d) => 'Tháng ${d.month.toString().padLeft(2, '0')}/${d.year}';
    final now = DateTime.now();
    final next = DateTime(now.year, now.month + 1), prev = DateTime(now.year, now.month - 1);
    expect(find.text(label(now)), findsOneWidget);

    await t.dragFrom(const Offset(358, 500), const Offset(-30, 0)); // ngắn: chưa đủ ngưỡng
    await settle(t);
    expect(find.text(label(now)), findsOneWidget, reason: 'vuốt ngắn không đổi tháng');

    await t.dragFrom(const Offset(358, 500), const Offset(-150, 0)); // mép phải → tháng sau
    await settle(t);
    expect(find.text(label(next)), findsOneWidget);

    await t.dragFrom(const Offset(2, 500), const Offset(150, 0)); // mép trái → tháng trước (2 lần)
    await settle(t);
    await t.dragFrom(const Offset(2, 500), const Offset(150, 0));
    await settle(t);
    expect(find.text(label(prev)), findsOneWidget);

    // Màn thấp → trang dài hơn khung nhìn: vuốt dọc BẮT ĐẦU TRÊN LỊCH vẫn phải cuộn được trang.
    t.view.physicalSize = const Size(360 * 3, 480 * 3);
    await settle(t);
    final cal = find.byWidgetPredicate((w) => w is TableCalendar);
    final scroll = find.ancestor(of: cal, matching: find.byType(Scrollable)).first;
    final before = t.state<ScrollableState>(scroll).position.pixels;
    await t.dragFrom(t.getCenter(cal), const Offset(0, -150));
    await settle(t);
    expect(t.state<ScrollableState>(scroll).position.pixels, greaterThan(before + 50), reason: 'vuốt dọc trên lịch phải cuộn trang');
    expect(t.takeException(), isNull);
  });
}
