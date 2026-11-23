// Màn Lịch trình – xem cả tuần (lưới giờ): chuyển kiểu xem, chạm ô trống, giữ-kéo dời giờ, đổi ngày đầu tuần.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_ce/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lht_money/core/theme.dart';
import 'package:lht_money/data/local_store.dart';
import 'package:lht_money/data/models.dart';
import 'package:lht_money/data/time_config.dart';
import 'package:lht_money/features/schedule.dart';
import 'package:lht_money/providers.dart';

void main() {
  late LocalStore store;
  late String eventId;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  setUpAll(() async {
    await initializeDateFormatting('vi');
    final dir = await Directory.systemTemp.createTemp('lht_week');
    Hive.init(dir.path);
    store = LocalStore();
    await store.initForTest();
    services = Services.forTest(store);
    store.put(E.appSettings, {'baseCurrencyCode': 'VND', 'financeMonthStartDay': 1, 'firstDayOfWeek': 1});
    eventId = store.put(E.events, {
      'title': 'Họp nhóm',
      'startAt': today.add(const Duration(hours: 10)).toUtc().toIso8601String(),
      'endAt': today.add(const Duration(hours: 11)).toUtc().toIso8601String(),
      'color': '#3E63DD',
    })['id'];
    store.put(E.events, {
      'title': 'Nghỉ lễ',
      'isAllDay': true,
      'startAt': today.toUtc().toIso8601String(),
      'endAt': today.toUtc().toIso8601String(),
      'color': '#E5484D',
    });
  });

  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 60; i++) {
      await t.pump(const Duration(milliseconds: 16));
    }
  }

  testWidgets('xem cả tuần: lưới giờ, chạm ô trống, kéo dời giờ, đổi ngày đầu tuần', (t) async {
    String hm(DateTime d) => '${d.hour}:${d.minute.toString().padLeft(2, '0')}';
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const SchedulePage()),
        // Màn thêm lịch giả: chỉ in ra ngày giờ nhận được để kiểm tra.
        GoRoute(
          path: '/schedule/edit',
          builder: (_, s) {
            final x = s.extra as Map;
            return Scaffold(body: Text('THEM ${(x['date'] as DateTime).day} ${hm(x['date'] as DateTime)}-${hm(x['end'] as DateTime)}'));
          },
        ),
      ],
    );
    t.view.physicalSize = const Size(360 * 3, 800 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: buildTheme(Brightness.light, AppColors.seeds.first),
          locale: const Locale('vi'),
          supportedLocales: const [Locale('vi')],
          localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
          routerConfig: router,
        ),
      ),
    );
    await settle(t);

    await t.tap(find.byTooltip('Cả tuần'));
    await settle(t);
    expect(t.takeException(), isNull, reason: 'lưới tuần không lỗi bố cục ở màn 360dp');
    expect(store.meta('scheduleView'), '1', reason: 'nhớ kiểu xem');
    expect(find.text('Họp nhóm'), findsOneWidget);
    expect(find.text('Nghỉ lễ'), findsOneWidget, reason: 'lịch cả ngày ở hàng trên');
    expect(find.text('10:00'), findsWidgets);

    // Chạm ô trống → hiện khung "+ giờ"
    final grid = find.byWidgetPredicate((w) => w is CustomPaint && w.painter.runtimeType.toString() == '_WeekLinesPainter');
    final g = t.getRect(grid);
    await t.tapAt(Offset(g.left + 30 + 5, g.top + 2));
    await settle(t);
    expect(find.byIcon(Icons.add_rounded), findsWidgets);

    // Giữ ô trống ở cột khác rồi kéo xuống: quét 8:00 → 10:00, thả tay là mở màn thêm đúng khoảng giờ đó.
    final colW = (g.width - 30) / 7;
    final todayCol = today.difference(TimeConfig.of(store).weekStart(today)).inDays;
    final otherCol = (todayCol + 1) % 7;
    final otherDay = TimeConfig.of(store).weekStart(today).add(Duration(days: otherCol));
    double yAt(int h) => g.top + (h - 6) * 46.0; // khung giờ mặc định bắt đầu 6:00
    final x = g.left + 30 + otherCol * colW + colW / 2;
    final press = await t.startGesture(Offset(x, yAt(8) + 3));
    await t.pump(const Duration(milliseconds: 700));
    for (var i = 0; i < 4; i++) {
      await press.moveBy(const Offset(0, 23));
      await t.pump(const Duration(milliseconds: 16));
    }
    await press.up();
    await settle(t);
    expect(find.text('THEM ${otherDay.day} 8:00-10:00'), findsOneWidget, reason: 'quét 8:00→10:00 mở màn thêm với đúng giờ');
    router.pop();
    await settle(t);

    // Giữ rồi kéo "Họp nhóm" xuống 2 giờ (46px mỗi giờ) → 12:00
    final ev = t.getCenter(find.text('Họp nhóm'));
    final gesture = await t.startGesture(ev);
    await t.pump(const Duration(milliseconds: 700));
    for (var i = 0; i < 4; i++) {
      await gesture.moveBy(const Offset(0, 23));
      await t.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await settle(t);
    final moved = EventRec(store.get(E.events, eventId)!);
    expect(moved.startAt.hour, 12);
    expect(moved.endAt!.hour, 13);
    expect(moved.startAt.day, today.day, reason: 'kéo dọc không đổi ngày');

    // Sau khi kéo, lịch đang được chọn → núm ở đáy (12:00–13:00 → kết thúc 13:00). Kéo núm xuống 1 giờ → kết thúc 14:00.
    final handleAt = Offset(g.left + 30 + (todayCol + 1) * colW - 8, yAt(13));
    await t.dragFrom(handleAt, const Offset(0, 46));
    await settle(t);
    final resized = EventRec(store.get(E.events, eventId)!);
    expect(resized.startAt.hour, 12);
    expect(resized.endAt!.hour, 14, reason: 'kéo núm giãn giờ kết thúc');

    // Đổi ngày đầu tuần sang Chủ nhật → cột đầu là CN
    TimeConfig.of(store).copyWith(firstDayOfWeek: 7).save(store);
    await settle(t);
    expect(t.getTopLeft(find.text('CN').first).dx, lessThan(t.getTopLeft(find.text('T2').first).dx));
    TimeConfig.of(store).copyWith(firstDayOfWeek: 3).save(store); // Thứ 4
    await settle(t);
    expect(t.getTopLeft(find.text('T4').first).dx, lessThan(t.getTopLeft(find.text('T3').first).dx));
    expect(t.takeException(), isNull);
  });
}
