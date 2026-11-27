// Giao diện công tơ điện: màn chốt số (nhập chỉ số, kWh + tiền, chi tiết bậc giá, báo lỗi, bấm "Tiếp" sang công tơ sau, lưu)
// và màn danh sách công tơ (đã chốt / chưa chốt, so với tháng trước) — không tràn bố cục trên màn hẹp.
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
import 'package:lht_money/features/meters.dart';
import 'package:lht_money/providers.dart';

void main() {
  late LocalStore store;
  final now = DateTime.now();
  final period = DateTime(now.year, now.month);
  final prevPeriod = DateTime(now.year, now.month - 1);

  setUpAll(() => initializeDateFormatting('vi'));
  setUp(() async {
    final dir = await Directory.systemTemp.createTemp('lht_meters_ui');
    Hive.init(dir.path);
    store = LocalStore();
    await store.initForTest(filesDir: '${dir.path}/f');
    services = Services.forTest(store);
    store.put(E.appSettings, {'baseCurrencyCode': 'VND', 'financeMonthStartDay': 1, 'firstDayOfWeek': 1});
    store.put(E.currencies, {'code': 'VND', 'name': 'VND', 'symbol': '₫', 'decimals': 0, 'symbolPosition': 1, 'isBase': true});
    store.put(E.accounts, {'name': 'Tiền mặt', 'type': 1, 'currencyCode': 'VND', 'openingBalance': 0});
    store.put(E.categories, {'name': 'Điện', 'type': 1});
    store.put(E.categories, {'name': 'Thu khác', 'type': 2});
    final table = store.put(E.priceTables, {'name': 'Điện sinh hoạt', 'vatPercent': 8, 'fixedFee': 0, 'isDefault': true})['id'];
    for (final (i, t) in [(0, 50, 1984.0), (51, 100, 2050.0), (101, null, 2380.0)].indexed) {
      store.put(E.tiers, {'priceTableId': table, 'tierOrder': i + 1, 'fromKwh': t.$1, 'toKwh': t.$2, 'price': t.$3});
    }
    final home = store.put(E.meters, {'name': 'Tầng 1', 'kind': 1, 'priceTableId': table, 'initialIndex': 1000, 'sortOrder': 0})['id'];
    store.put(E.meters, {
      'name': 'Phòng thuê tầng 2 rất dài tên',
      'kind': 2,
      'tenantName': 'Anh Nam',
      'priceTableId': table,
      'initialIndex': 500,
      'sortOrder': 1,
    });
    // Tháng trước tầng 1 đã chốt 1000 → 1080 (80 kWh)
    store.put(E.bills, {
      'meterId': home,
      'priceTableId': table,
      'period': Fmt.isoDate(prevPeriod),
      'oldIndex': 1000,
      'newIndex': 1080,
      'kwh': 80,
      'amount': 170000,
    });
  });

  Widget app(Widget home) => ProviderScope(
    child: MaterialApp(
      theme: buildTheme(Brightness.light, AppColors.seeds.first),
      locale: const Locale('vi'),
      supportedLocales: const [Locale('vi')],
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      home: home,
    ),
  );

  Future<void> frames(WidgetTester t, [int n = 40]) async {
    for (var i = 0; i < n; i++) {
      await t.pump(const Duration(milliseconds: 16));
    }
  }

  testWidgets('chốt số: nhập chỉ số → kWh + tiền, chi tiết bậc, báo lỗi, "Tiếp" sang công tơ sau, lưu', (t) async {
    t.view.physicalSize = const Size(360 * 3, 780 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(app(MeterReadingPage(period: period)));
    await frames(t);

    expect(find.text('0/2'), findsOneWidget, reason: 'tiến độ ban đầu');
    final fields = find.byType(TextField);
    // Tầng 1: số cũ 1080 (từ tháng trước) → nhập 1200 = 120 kWh
    await t.enterText(fields.at(0), '1200');
    await frames(t, 20);
    expect(find.text('120 kWh'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

    // Chi tiết bậc giá: 50 + 50 + 20 kWh, có VAT
    await t.tap(find.text('Chi tiết bậc giá'));
    await frames(t, 20);
    expect(find.textContaining('Bậc 1 · 50 kWh'), findsOneWidget);
    expect(find.textContaining('Bậc 3 · 20 kWh'), findsOneWidget);
    expect(find.text('Thuế VAT'), findsOneWidget);

    // "Tiếp" trên bàn phím → con trỏ sang công tơ thứ 2
    await t.showKeyboard(fields.at(0));
    await t.testTextInput.receiveAction(TextInputAction.next);
    await frames(t, 5);
    final second = t.widget<TextField>(fields.at(1));
    expect(second.focusNode!.hasFocus, isTrue);

    // Công tơ 2: nhập số nhỏ hơn số cũ (500) → báo lỗi, không lưu được
    await t.enterText(fields.at(1), '400');
    await frames(t, 20);
    expect(find.textContaining('Số mới nhỏ hơn số cũ (500)'), findsOneWidget);
    expect(find.textContaining('Có chỉ số mới nhỏ hơn'), findsOneWidget);
    await t.enterText(fields.at(1), '560');
    await frames(t, 20);
    expect(find.textContaining('Lưu 2 công tơ'), findsOneWidget, reason: 'đủ 2 công tơ hợp lệ');
    expect(find.textContaining('Số mới nhỏ hơn số cũ'), findsNothing);
    expect(t.takeException(), isNull);

    // Lưu → tạo hoá đơn tháng này cho cả 2 công tơ
    FocusManager.instance.primaryFocus?.unfocus();
    await frames(t, 30);
    await t.tap(find.textContaining('Lưu 2 công tơ'));
    await frames(t, 30);
    final bills = store.all(E.bills).where((b) => b['period'] == Fmt.isoDate(period)).toList();
    expect(bills, hasLength(2));
    expect(bills.map((b) => b['kwh']).toSet(), {120, 60});
  });

  testWidgets('danh sách công tơ: chưa chốt / đã chốt + so với tháng trước, không tràn trên màn hẹp', (t) async {
    t.view.physicalSize = const Size(340 * 3, 780 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    // Tháng này tầng 1 đã chốt 1080 → 1200 (120 kWh, tăng 50% so với 80)
    final home = store.all(E.meters).firstWhere((m) => m['name'] == 'Tầng 1');
    store.put(E.bills, {
      'meterId': home['id'],
      'priceTableId': home['priceTableId'],
      'period': Fmt.isoDate(period),
      'oldIndex': 1080,
      'newIndex': 1200,
      'kwh': 120,
      'amount': 280000,
    });
    await t.pumpWidget(app(const Scaffold(body: MetersView())));
    await frames(t, 60);
    expect(find.text('Chưa chốt'), findsWidgets, reason: 'phòng thuê chưa chốt tháng này');
    expect(find.text('120 kWh'), findsOneWidget);
    expect(find.text('▲ 50%'), findsOneWidget);
    expect(find.text('1080 → 1200'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
