// Màn Giao dịch định kỳ: thêm quy tắc mới → bấm vào thẻ để sửa / xoá được; chọn loại chi / thu / chuyển tiền không tràn.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lht_money/core/theme.dart';
import 'package:lht_money/data/local_store.dart';
import 'package:lht_money/features/recurring.dart';
import 'package:lht_money/providers.dart';

void main() {
  late LocalStore store;
  setUpAll(() => initializeDateFormatting('vi'));
  setUp(() async {
    final dir = await Directory.systemTemp.createTemp('lht_rec_ui');
    Hive.init(dir.path);
    store = LocalStore();
    await store.initForTest(filesDir: '${dir.path}/f');
    services = Services.forTest(store);
    store.put(E.appSettings, {'baseCurrencyCode': 'VND', 'financeMonthStartDay': 1, 'firstDayOfWeek': 1});
    store.put(E.currencies, {'code': 'VND', 'name': 'VND', 'symbol': '₫', 'decimals': 0, 'symbolPosition': 1, 'isBase': true});
    store.put(E.accounts, {'name': 'Tiền mặt', 'type': 1, 'currencyCode': 'VND', 'openingBalance': 0});
    store.put(E.categories, {'name': 'Nhà cửa', 'type': 1});
  });

  Future<void> frames(WidgetTester t, [int n = 40]) async {
    for (var i = 0; i < n; i++) {
      await t.pump(const Duration(milliseconds: 16));
    }
  }

  testWidgets('thêm quy tắc → bấm thẻ mở "Sửa", đổi tên lưu được, rồi xoá được', (t) async {
    t.view.physicalSize = const Size(360 * 3, 800 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildTheme(Brightness.light, AppColors.seeds.first),
          locale: const Locale('vi'),
          supportedLocales: const [Locale('vi')],
          localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
          home: const RecurringPage(),
        ),
      ),
    );
    await frames(t);
    await t.tap(find.text('Thêm định kỳ'));
    await frames(t);
    expect(t.takeException(), isNull, reason: 'khối chọn loại không tràn');
    await t.tap(find.text('Chuyển tiền'));
    await frames(t, 20);
    await t.tap(find.text('Khoản chi'));
    await frames(t, 20);
    await t.enterText(find.byType(TextField).at(0), '3000000');
    await t.enterText(find.widgetWithText(TextField, 'Tên quy tắc (VD: Tiền nhà, Lương)'), 'Tiền nhà');
    FocusManager.instance.primaryFocus?.unfocus();
    await frames(t);
    // Ngày chạy kế tiếp để tương lai để không tự sinh giao dịch
    await t.tap(find.text('Lưu quy tắc'));
    await frames(t);
    expect(store.all(E.recurringRules), hasLength(1));

    await t.tap(find.text('Tiền nhà'));
    await frames(t);
    expect(find.text('Sửa giao dịch định kỳ'), findsOneWidget, reason: 'bấm thẻ phải mở màn sửa');
    await t.enterText(find.widgetWithText(TextField, 'Tiền nhà'), 'Tiền nhà trọ');
    FocusManager.instance.primaryFocus?.unfocus();
    await frames(t);
    await t.tap(find.text('Lưu quy tắc'));
    await frames(t);
    expect(store.all(E.recurringRules).single['name'], 'Tiền nhà trọ');

    await t.tap(find.text('Tiền nhà trọ'));
    await frames(t);
    await t.tap(find.text('Xoá'));
    await frames(t);
    expect(store.all(E.recurringRules), isEmpty);
    expect(t.takeException(), isNull);
  });
}
