// Ngày an toàn + cửa sổ dễ thụ thai (nới rộng khi chu kỳ không đều) + lịch và thẻ "Hôm nay" dùng chung một cách chiếu chu kỳ.
import 'package:flutter_test/flutter_test.dart';
import 'package:lht_money/core/format.dart';
import 'package:lht_money/data/logic.dart';
import 'package:lht_money/data/models.dart';

void main() {
  final today = dateOnly(DateTime.now());
  CyclePeriod period(DateTime start, {int days = 5}) =>
      CyclePeriod({'id': '$start', 'subject': 1, 'startDate': Fmt.isoDate(start), 'endDate': Fmt.isoDate(start.add(Duration(days: days - 1)))});

  group('chu kỳ đều 28 ngày, hành kinh 5 ngày (kỳ gần nhất bắt đầu D)', () {
    final d0 = today.subtract(const Duration(days: 3));
    final h = [for (var i = 3; i >= 0; i--) period(d0.subtract(Duration(days: i * 28)))];
    final p = Cycle.predict(h, null)!;
    DateTime day(int n) => d0.add(Duration(days: n - 1)); // ngày thứ n của chu kỳ

    test('rụng trứng ngày 14, dễ thụ thai ngày 9 → 15, không bị coi là không đều', () {
      expect(p.irregular, isFalse);
      expect(p.extraBefore, 0);
      expect(p.extraAfter, 0);
      expect(Cycle.markOf(p, h, null, day(15)), CycleMark.ovulation);
      expect(Cycle.markOf(p, h, null, day(10)), CycleMark.fertile);
      expect(Cycle.markOf(p, h, null, day(16)), CycleMark.fertile);
    });

    test('an toàn tương đối: ngày 6 → 9 (sau kỳ kinh, trước cửa sổ); an toàn hơn: ngày 17 → 28', () {
      expect(p.safeEarly, (day(6), day(9)));
      expect(p.safeLate, (day(17), day(28)));
      for (var n = 1; n <= 28; n++) {
        final m = Cycle.markOf(p, h, null, day(n));
        final expected = n <= 5
            ? CycleMark.period
            : n <= 9
            ? CycleMark.safeRelative
            : n == 15
            ? CycleMark.ovulation
            : n <= 16
            ? CycleMark.fertile
            : CycleMark.safe;
        expect(m, expected, reason: 'ngày $n của chu kỳ');
      }
    });

    test('chiếu ra các chu kỳ sau: kỳ dự đoán, rụng trứng, an toàn lặp lại đúng nhịp 28 ngày', () {
      for (var k = 1; k <= 4; k++) {
        DateTime c(int n) => d0.add(Duration(days: k * 28 + n - 1));
        expect(Cycle.markOf(p, h, null, c(1)), CycleMark.predicted, reason: 'chu kỳ +$k ngày 1');
        expect(Cycle.markOf(p, h, null, c(5)), CycleMark.predicted);
        expect(Cycle.markOf(p, h, null, c(7)), CycleMark.safeRelative);
        expect(Cycle.markOf(p, h, null, c(15)), CycleMark.ovulation);
        expect(Cycle.markOf(p, h, null, c(20)), CycleMark.safe);
      }
    });

    test('lịch và thẻ "Hôm nay" khớp nhau 120 ngày tới', () {
      for (var i = 1; i < 120; i++) {
        final d = today.add(Duration(days: i));
        final mark = Cycle.markOf(p, h, null, d);
        final info = CycleDays.of(p, h, null, d)!;
        final phase = info.phase;
        final ok = switch (mark) {
          CycleMark.period || CycleMark.predicted => phase == CyclePhase.period,
          CycleMark.ovulation => phase == CyclePhase.ovulation,
          CycleMark.fertile => phase == CyclePhase.fertile,
          CycleMark.safeRelative => phase == CyclePhase.follicular || phase == CyclePhase.pms || phase == CyclePhase.soon,
          CycleMark.safe => phase == CyclePhase.luteal || phase == CyclePhase.pms || phase == CyclePhase.soon,
          CycleMark.none => false,
        };
        expect(ok, isTrue, reason: '${Fmt.isoDate(d)}: lịch=$mark, thẻ=$phase');
      }
    });

    test('lời nhắc ngày an toàn có kèm cảnh báo chỉ mang tính tham khảo', () {
      final info = CycleDays.of(p, h, null, day(20))!;
      expect(info.title, contains('an toàn'));
      expect(info.body, contains('tham khảo'));
    });
  });

  test('chu kỳ không đều (25–35 ngày): nới rộng cửa sổ dễ thụ thai, đánh dấu không đều', () {
    var d = today.subtract(const Duration(days: 130));
    final h = <CyclePeriod>[];
    for (final len in [25, 35, 26, 34]) {
      h.add(period(d));
      d = d.add(Duration(days: len));
    }
    h.add(period(d)); // kỳ gần nhất
    final p = Cycle.predict(h, null)!;
    expect(p.irregular, isTrue);
    expect(p.extraBefore, greaterThan(0));
    expect(p.extraAfter, greaterThan(0));
    final window = p.fertileEnd.difference(p.fertileStart).inDays + 1;
    expect(window, greaterThan(7), reason: 'cửa sổ phải rộng hơn 7 ngày chuẩn');
    final info = CycleDays.of(p, h, null, p.safeLate?.$1 ?? p.fertileEnd.add(const Duration(days: 1)))!;
    expect(info.body, contains('KHÔNG đáng tin'));
  });
}
