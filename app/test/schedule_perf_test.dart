import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:lht_money/core/format.dart';
import 'package:lht_money/data/local_store.dart';
import 'package:lht_money/features/schedule.dart';

/// Đo chi phí dựng màn Lịch trình với dữ liệu dày (≈400 lịch trình, 800 hoạt động theo giờ, có lịch lặp):
/// lịch tháng 42 ô + thanh tuần 7 ngày + danh sách ngày + thẻ từng lịch (hoạt động trong ngày).
void main() {
  late LocalStore store;

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('lht_sched');
    Hive.init(dir.path);
    store = LocalStore();
    await store.initForTest();
    String iso(DateTime d) => d.toUtc().toIso8601String();
    // Lịch lặp
    for (final r in ['FREQ=WEEKLY;BYDAY=MO,WE,FR', 'FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR', 'FREQ=WEEKLY;BYDAY=SA', 'FREQ=MONTHLY', 'FREQ=YEARLY']) {
      store.put(E.events, {'title': r, 'startAt': iso(DateTime(2025, 12, 1, 8)), 'rRule': r}, notify: false);
    }
    // 400 lịch trình rải 12 tháng, mỗi lịch 2 hoạt động
    var d = DateTime(2025, 12, 1);
    for (var i = 0; i < 400; i++) {
      final day = d.add(Duration(days: (i * 0.9).floor()));
      final e = store.put(E.events, {
        'title': 'Lịch $i',
        'startAt': iso(day.add(const Duration(hours: 9))),
        'endAt': iso(day.add(const Duration(hours: 11))),
      }, notify: false);
      for (var k = 0; k < 2; k++) {
        store.put(E.eventItems, {'eventId': e['id'], 'occurrenceDate': Fmt.isoDate(day), 'startTime': '0${9 + k}:00:00', 'title': 'HĐ $k'}, notify: false);
      }
    }
    store.notifyRemoteApplied();
  });

  test('Chi phí dựng màn Lịch trình (1 khung hình)', () {
    final month = DateTime(2026, 11, 1);
    void frame() {
      // lịch tháng: 42 ô
      final first = month.subtract(Duration(days: month.weekday - 1));
      for (var i = 0; i < 42; i++) {
        final day = first.add(Duration(days: i));
        occurrencesIn(store, day, day.add(const Duration(days: 1)));
      }
      // thanh tuần
      for (var i = 0; i < 7; i++) {
        final day = DateTime(2026, 11, 16 + i);
        occurrencesIn(store, day, day.add(const Duration(days: 1)));
      }
      // danh sách ngày + hoạt động trong từng thẻ
      final today = DateTime(2026, 11, 20);
      for (final (_, e) in occurrencesIn(store, today, today.add(const Duration(days: 1)))) {
        eventItemsOn(store, e.id, today);
      }
    }

    // Lần đầu sau khi dữ liệu đổi: phải dựng lại chỉ mục
    store.notifyRemoteApplied();
    var sw = Stopwatch()..start();
    frame();
    final first = sw.elapsedMicroseconds / 1000;
    // Các khung hình tiếp theo (cuộn, chuyển ngày, hiệu ứng): dùng lại chỉ mục
    sw = Stopwatch()..start();
    for (var r = 0; r < 20; r++) {
      frame();
    }
    final steady = sw.elapsedMicroseconds / 1000 / 20;
    // Thực tế nhất: đang ở màn Lịch trình, người dùng sửa 1 thứ → chỉ mục dựng lại (bộ đệm ngày giờ đã ấm)
    var warm = 0.0;
    for (var r = 0; r < 10; r++) {
      store.notifyRemoteApplied();
      sw = Stopwatch()..start();
      frame();
      warm += sw.elapsedMicroseconds / 1000 / 10;
    }
    // ignore: avoid_print
    print('⏱  Sau khi sửa dữ liệu (đang mở màn): ${warm.toStringAsFixed(1)} ms');
    expect(warm, lessThan(16));
    // ignore: avoid_print
    print(
      '⏱  Lịch trình: lần đầu sau khi đổi dữ liệu ${first.toStringAsFixed(1)} ms · các khung hình sau ${steady.toStringAsFixed(2)} ms (≈400 lịch, 800 hoạt động)',
    );
    expect(steady, lessThan(4));
    expect(first, lessThan(60));
  });
}
