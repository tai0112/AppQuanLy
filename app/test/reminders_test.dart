import 'package:flutter_test/flutter_test.dart';
import 'package:lht_money/data/logic.dart';
import 'package:lht_money/data/models.dart';

void main() {
  // Thứ 2, 23/11/2026, 10:00
  final now = DateTime(2026, 11, 23, 10);
  final week = now.add(const Duration(days: 7));

  test('Hằng ngày: mỗi ngày mọi giờ, bỏ giờ đã qua hôm nay', () {
    final r = Reminder({'id': 'a', 'title': 'Uống nước', 'repeatMode': 1, 'times': '21:00,08:00'});
    final o = Reminders.occurrences(r, now, week);
    expect(o.first, DateTime(2026, 11, 23, 21));
    expect(o.length, 14); // hôm nay còn 21:00, 6 ngày giữa mỗi ngày 2 lần, ngày cuối 08:00 (trước 10:00)
    expect(Reminders.next(r, now), DateTime(2026, 11, 23, 21));
    expect(r.times, [(8, 0), (21, 0)]);
  });

  test('Theo thứ: chỉ các thứ đã chọn', () {
    final r = Reminder({'id': 'b', 'title': 'Tập gym', 'repeatMode': 2, 'times': '18:30', 'weekdays': '1,3,5'});
    final o = Reminders.occurrences(r, now, week);
    expect(o.map((d) => d.weekday), [1, 3, 5]);
    expect(Reminders.describe(r), 'T2, T4, T6');
    expect(Reminders.describe(Reminder({...r.m, 'weekdays': '1,2,3,4,5'})), 'Thứ 2 – Thứ 6');
  });

  test('Từng ngày: chỉ ngày được chọn, ngày đã qua bị bỏ', () {
    final r = Reminder({'id': 'c', 'title': 'Tái khám', 'repeatMode': 3, 'times': '07:00', 'dates': '2026-12-05,2026-11-20,2026-11-25'});
    expect(Reminders.occurrences(r, now, week), [DateTime(2026, 11, 25, 7)]);
    expect(Reminders.next(r, DateTime(2026, 11, 26)), DateTime(2026, 12, 5, 7));
    expect(Reminders.next(r, DateTime(2026, 12, 6)), isNull);
  });

  test('Tắt thì không nhắc', () {
    final r = Reminder({'id': 'd', 'title': 'x', 'repeatMode': 1, 'times': '12:00', 'isActive': false});
    expect(Reminders.occurrences(r, now, week), isEmpty);
  });
}
