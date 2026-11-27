// Nhập kỳ kinh dễ hơn: bấm ngày bắt đầu kéo tới ngày kết thúc (không bị vùng cuộn giành thao tác),
// chạm đầu – chạm cuối, và nút một chạm "Bắt đầu / Kết thúc kỳ hôm nay" trên màn Chu kỳ.
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
import 'package:lht_money/features/cycle.dart';
import 'package:lht_money/features/cycle_range_picker.dart';
import 'package:lht_money/providers.dart';

void main() {
  late LocalStore store;
  setUpAll(() async {
    await initializeDateFormatting('vi');
    final dir = await Directory.systemTemp.createTemp('lht_cycle_quick');
    Hive.init(dir.path);
    store = LocalStore();
    await store.initForTest(filesDir: '${dir.path}/f');
    services = Services.forTest(store);
  });

  Future<(DateTime, DateTime?) Function()> pumpPicker(WidgetTester t) async {
    var start = DateTime(2026, 11, 10);
    DateTime? end = DateTime(2026, 11, 14);
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          // Đặt trong vùng cuộn dọc như bảng ghi thật: kéo trên lịch không được làm cuộn trang.
          body: StatefulBuilder(
            builder: (c, set) => SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  CycleRangePicker(
                    start: start,
                    end: end,
                    color: Colors.pink,
                    onChanged: (a, b) => set(() {
                      start = a;
                      end = b;
                    }),
                  ),
                  const SizedBox(height: 900),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    return () => (start, end);
  }

  testWidgets('bấm ngày 12 rồi kéo tới ngày 19 (sang hàng dưới) → chọn 12 → 19, trang không cuộn', (t) async {
    final get = await pumpPicker(t);
    final scroll = t.widget<SingleChildScrollView>(find.byType(SingleChildScrollView));
    final g = await t.startGesture(t.getCenter(find.text('12')));
    await t.pump();
    for (final day in ['13', '14', '15', '19']) {
      await g.moveTo(t.getCenter(find.text(day)));
      await t.pump();
    }
    await t.pump(const Duration(milliseconds: 200));
    expect(find.text('8 ngày'), findsOneWidget, reason: 'bong bóng số ngày bay theo ngón tay khi kéo');
    await g.up();
    await t.pumpAndSettle();
    expect(get(), (DateTime(2026, 11, 12), DateTime(2026, 11, 19)));
    expect(scroll.controller?.offset ?? 0, 0);
    expect(find.text('8 ngày'), findsNothing, reason: 'thả tay thì bong bóng biến mất');
    expect(t.takeException(), isNull);
  });

  testWidgets('kéo ngược (25 về 21) vẫn ra khoảng đúng thứ tự', (t) async {
    final get = await pumpPicker(t);
    final g = await t.startGesture(t.getCenter(find.text('25')));
    await t.pump();
    await g.moveTo(t.getCenter(find.text('21')));
    await t.pump();
    await g.up();
    await t.pumpAndSettle();
    expect(get(), (DateTime(2026, 11, 21), DateTime(2026, 11, 25)));
  });

  testWidgets('chạm ngày đầu rồi chạm ngày cuối', (t) async {
    final get = await pumpPicker(t);
    await t.tap(find.text('20'));
    await t.pump();
    expect(get(), (DateTime(2026, 11, 20), null), reason: 'chạm lần 1: chọn ngày bắt đầu, chưa có ngày kết thúc');
    await t.tap(find.text('24'));
    await t.pump();
    expect(get(), (DateTime(2026, 11, 20), DateTime(2026, 11, 24)));
  });

  testWidgets('màn Chu kỳ: "Bắt đầu kỳ hôm nay" rồi "Kết thúc kỳ hôm nay" chỉ một chạm', (t) async {
    final today = DateTime.now();
    // Một kỳ cũ để có dự đoán (hiện thẻ "Hôm nay")
    store.put(E.cyclePeriods, {
      'subject': 1,
      'startDate': Fmt.isoDate(today.subtract(const Duration(days: 40))),
      'endDate': Fmt.isoDate(today.subtract(const Duration(days: 36))),
      'flow': 2,
    });
    t.view.physicalSize = const Size(400 * 3, 900 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildTheme(Brightness.light, AppColors.seeds.first),
          locale: const Locale('vi'),
          supportedLocales: const [Locale('vi')],
          localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
          home: const CyclePage(),
        ),
      ),
    );
    for (var i = 0; i < 60; i++) {
      await t.pump(const Duration(milliseconds: 16));
    }

    await t.tap(find.text('Bắt đầu kỳ hôm nay'));
    for (var i = 0; i < 40; i++) {
      await t.pump(const Duration(milliseconds: 16));
    }
    final open = store.all(E.cyclePeriods).where((p) => p['startDate'] == Fmt.isoDate(today)).toList();
    expect(open, hasLength(1));
    expect(open.single['endDate'], isNull);

    await t.tap(find.textContaining('Kết thúc kỳ hôm nay (ngày'));
    for (var i = 0; i < 40; i++) {
      await t.pump(const Duration(milliseconds: 16));
    }
    expect(store.get(E.cyclePeriods, open.single['id'] as String)!['endDate'], Fmt.isoDate(today));
    expect(t.takeException(), isNull);
  });
}
