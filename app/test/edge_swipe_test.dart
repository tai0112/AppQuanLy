// Vuốt mép màn hình đổi tuần/tháng ở màn Lịch trình và Chu kỳ.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lht_money/core/theme.dart';
import 'package:lht_money/data/local_store.dart';
import 'package:lht_money/features/cycle.dart';
import 'package:lht_money/features/schedule.dart';
import 'package:lht_money/providers.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('vi');
    final dir = await Directory.systemTemp.createTemp('lht_edge');
    Hive.init(dir.path);
    final store = LocalStore();
    await store.initForTest();
    services = Services.forTest(store);
    store.put(E.appSettings, {'baseCurrencyCode': 'VND', 'financeMonthStartDay': 1, 'firstDayOfWeek': 1});
    store.put(E.cyclePeriods, {'subject': 1, 'startDate': '2026-10-01', 'endDate': '2026-10-05', 'flow': 2});
  });

  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 60; i++) {
      await t.pump(const Duration(milliseconds: 16));
    }
  }

  testWidgets('Lịch trình & Chu kỳ: vuốt mép phải → sau, mép trái → trước', (t) async {
    t.view.physicalSize = const Size(400 * 3, 820 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final page = ValueNotifier<Widget>(const SchedulePage());
    await t.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildTheme(Brightness.dark, AppColors.seeds.first),
          locale: const Locale('vi'),
          supportedLocales: const [Locale('vi')],
          localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
          home: ValueListenableBuilder<Widget>(valueListenable: page, builder: (_, p, _) => p),
        ),
      ),
    );
    await settle(t);
    final now = DateTime.now();
    String label(DateTime d) => 'Tháng ${d.month}, ${d.year}';

    // Lịch trình (xem theo tuần): 5 lần sang tuần sau → chắc chắn sang tháng khác; 5 lần lùi → về tháng hiện tại.
    expect(find.text(label(now)), findsWidgets);
    for (var i = 0; i < 5; i++) {
      await t.dragFrom(const Offset(398, 600), const Offset(-150, 0));
      await settle(t);
    }
    expect(find.text(label(now)), findsNothing, reason: 'đã sang tuần của tháng sau');
    for (var i = 0; i < 5; i++) {
      await t.dragFrom(const Offset(2, 600), const Offset(150, 0));
      await settle(t);
    }
    expect(find.text(label(now)), findsWidgets);

    // Chu kỳ: mép phải → tháng sau, mép trái → về lại.
    page.value = const CyclePage();
    await settle(t);
    expect(find.text(label(now)), findsWidgets);
    await t.dragFrom(const Offset(398, 600), const Offset(-150, 0));
    await settle(t);
    expect(find.text(label(DateTime(now.year, now.month + 1))), findsWidgets);
    await t.dragFrom(const Offset(2, 600), const Offset(150, 0));
    await settle(t);
    expect(find.text(label(now)), findsWidgets);
    expect(t.takeException(), isNull);
  });
}
