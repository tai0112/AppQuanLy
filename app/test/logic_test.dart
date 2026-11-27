import 'package:flutter_test/flutter_test.dart';
import 'package:lht_money/data/logic.dart';
import 'package:lht_money/data/models.dart';

List<Tier> evnTiers() => [
  for (final (i, t) in [(0, 50, 1984), (51, 100, 2050), (101, 200, 2380), (201, 300, 2998), (301, 400, 3350), (401, null, 3460)].indexed)
    Tier({'id': '$i', 'priceTableId': 't', 'tierOrder': i + 1, 'fromKwh': t.$1, 'toKwh': t.$2, 'price': t.$3}),
];

void main() {
  group('Tiền điện bậc thang', () {
    test('250 kWh tính đúng từng bậc + VAT 8%', () {
      final r = Electricity.calc(250, evnTiers(), 8, 0);
      expect(r.uses.map((u) => u.kwh), [50, 50, 100, 50]);
      expect(r.subtotal, 50 * 1984 + 50 * 2050 + 100 * 2380 + 50 * 2998);
      expect(r.total, closeTo(589600 * 1.08, 0.001));
    });

    test('Tính ngược từ tiền ra kWh khớp với tính xuôi', () {
      for (final kwh in [30, 100, 175, 420, 900]) {
        final money = Electricity.calc(kwh, evnTiers(), 8, 0).total;
        expect(Electricity.reverse(money + 0.01, evnTiers(), 8, 0), kwh);
      }
    });

    test('Bảng giá tuỳ biến 2 bậc + phí cố định', () {
      final tiers = [
        Tier({'id': 'a', 'priceTableId': 'x', 'tierOrder': 1, 'fromKwh': 0, 'toKwh': 100, 'price': 1000}),
        Tier({'id': 'b', 'priceTableId': 'x', 'tierOrder': 2, 'fromKwh': 101, 'toKwh': null, 'price': 2000}),
      ];
      final r = Electricity.calc(150, tiers, 10, 5000);
      expect(r.total, closeTo(200000 * 1.1 + 5000, 0.001));
    });
  });

  group('Chu kỳ kinh nguyệt', () {
    CyclePeriod p(String d) => CyclePeriod({'id': d, 'subject': 1, 'startDate': d});

    test('Trung bình chu kỳ, ngày rụng trứng, cửa sổ thụ thai', () {
      final r = Cycle.predict([p('2026-07-01'), p('2026-07-29'), p('2026-08-28'), p('2026-09-25')], null)!;
      expect(r.cycles, [28, 30, 28]);
      expect(r.avgCycle, closeTo(28.67, 0.01));
      expect(r.nextStart, DateTime(2026, 10, 24)); // 25/09 + 29 ngày
      expect(r.ovulation, DateTime(2026, 10, 10)); // trước kỳ sau 14 ngày
      // Chu kỳ dao động 28–30 ngày: rụng trứng có thể sớm 1 ngày (chu kỳ ngắn nhất) hoặc muộn 1 ngày (dài nhất)
      // → cửa sổ 5 ngày trước / 1 ngày sau rụng trứng được nới thêm mỗi bên 1 ngày.
      expect(r.extraBefore, 1);
      expect(r.extraAfter, 1);
      expect(r.fertileStart, DateTime(2026, 10, 4));
      expect(r.fertileEnd, DateTime(2026, 10, 12));
      expect(r.irregular, isFalse);
      expect(r.standardDays, true);
    });

    test('Phương pháp lịch Ogino–Knaus cần ≥ 6 chu kỳ: ngắn nhất − 18, dài nhất − 11', () {
      final dates = ['2026-01-01', '2026-01-31', '2026-03-05', '2026-04-04', '2026-05-08', '2026-06-07', '2026-07-12'];
      final r = Cycle.predict(dates.map(p).toList(), null)!;
      expect(r.cycles, [30, 33, 30, 34, 30, 35]);
      expect(r.calendarFertile, (30 - 18, 35 - 11));
    });

    test('Cảnh báo chu kỳ bất thường', () {
      final r = Cycle.predict([p('2026-01-01'), p('2026-01-18')], null)!;
      expect(r.warnings, isNotEmpty);
    });
  });

  group('Lịch lặp', () {
    EventRec ev(String rrule, {String start = '2026-11-02T09:00:00'}) => EventRec({'id': 'e', 'title': 't', 'startAt': start, 'rRule': rrule});

    test('Hằng tuần thứ 2 và thứ 4', () {
      final o = Recurrence.occurrences(ev('FREQ=WEEKLY;BYDAY=MO,WE'), DateTime(2026, 11, 1), DateTime(2026, 11, 15));
      expect(o.map((d) => d.day), [2, 4, 9, 11]);
    });

    test('Hằng tháng cố định ngày', () {
      final o = Recurrence.occurrences(ev('FREQ=MONTHLY', start: '2026-01-15T08:00:00'), DateTime(2026, 3, 1), DateTime(2026, 6, 1));
      expect(o.map((d) => d.month), [3, 4, 5]);
      expect(o.every((d) => d.day == 15), true);
    });

    test('Build / parse RRULE', () {
      expect(Recurrence.build('WEEKLY', weekdays: [1, 3]), 'FREQ=WEEKLY;BYDAY=MO,WE');
      expect(Recurrence.describe('FREQ=WEEKLY;BYDAY=MO,WE'), 'Hằng tuần (T2, T4)');
    });
  });
}
