import 'package:flutter_test/flutter_test.dart';
import 'package:lht_money/core/format.dart';
import 'package:lht_money/data/logic.dart';
import 'package:lht_money/data/models.dart';

void main() {
  final today = dateOnly(DateTime.now());
  CyclePeriod p(DateTime d) => CyclePeriod({'id': '$d', 'subject': 1, 'startDate': Fmt.isoDate(d), 'endDate': Fmt.isoDate(d.add(const Duration(days: 4)))});
  // 3 kỳ đều 28 ngày, kỳ gần nhất bắt đầu cách hôm nay `ago` ngày
  List<CyclePeriod> hist(int ago) => [for (var i = 2; i >= 0; i--) p(today.subtract(Duration(days: ago + i * 28)))];
  CycleDay at(int ago, {int offset = 0, bool partner = false}) {
    final h = hist(ago);
    return CycleDays.of(Cycle.predict(h, null), h, null, today.add(Duration(days: offset)), partner: partner)!;
  }

  test('Đang hành kinh', () => expect(at(1).phase, CyclePhase.period));
  test('Nang noãn', () => expect(at(6).phase, CyclePhase.follicular));
  test('Dễ thụ thai', () => expect(at(10).phase, CyclePhase.fertile));
  test('Rụng trứng ngày 14 (28 − 14)', () => expect(at(14).phase, CyclePhase.ovulation));
  test('Hoàng thể', () => expect(at(17).phase, CyclePhase.luteal));
  test('Tiền kinh nguyệt (còn 4–7 ngày)', () => expect(at(22).phase, CyclePhase.pms));
  test('Sắp đến kỳ (còn 1–3 ngày)', () {
    final d = at(26);
    expect(d.phase, CyclePhase.soon);
    expect(d.title, 'Còn 2 ngày đến kỳ kinh');
  });
  test('Đúng ngày dự kiến', () => expect(at(28).level, 2));
  test('Trễ kinh', () {
    final d = at(31);
    expect(d.phase, CyclePhase.late);
    expect(d.title, 'Trễ kinh 3 ngày');
  });
  test('Người yêu dùng lời nhắc riêng', () => expect(at(26, partner: true).title, 'Còn 2 ngày đến kỳ của người ấy'));
  test('Mỗi ngày trong 60 ngày tới đều có lời nhắc', () {
    final h = hist(5);
    final pr = Cycle.predict(h, null);
    for (var i = 0; i < 60; i++) {
      expect(CycleDays.of(pr, h, null, today.add(Duration(days: i))), isNotNull);
    }
  });
}
