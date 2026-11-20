import 'package:flutter_test/flutter_test.dart';
import 'package:lht_money/data/notify_prefs.dart';

void main() {
  test('Mặc định: bật, âm theo nhóm, rung', () {
    final p = NotifyPrefs({});
    expect(p.enabled, isTrue);
    expect(p.sound(NotifyKind.chat), 'pop');
    expect(p.sound(NotifyKind.reminder), 'chime');
    expect(p.vibrate(NotifyKind.chat), isTrue);
  });

  test('Đổi âm / rung từng nhóm không ảnh hưởng nhóm khác', () {
    final p = NotifyPrefs({}).withKind(NotifyKind.chat, {'sound': 'dingdong', 'vibrate': false});
    expect(p.sound(NotifyKind.chat), 'dingdong');
    expect(p.vibrate(NotifyKind.chat), isFalse);
    expect(p.sound(NotifyKind.social), 'ting');
  });

  test('Giờ yên lặng qua nửa đêm 22:00 → 07:00', () {
    final p = NotifyPrefs({'quietEnabled': true, 'quietFrom': 22 * 60, 'quietTo': 7 * 60});
    expect(p.isQuiet(DateTime(2026, 1, 1, 23, 30)), isTrue);
    expect(p.isQuiet(DateTime(2026, 1, 1, 6, 59)), isTrue);
    expect(p.isQuiet(DateTime(2026, 1, 1, 7, 0)), isFalse);
    expect(p.isQuiet(DateTime(2026, 1, 1, 12, 0)), isFalse);
  });

  test('Giờ yên lặng trong ngày 13:00 → 14:00', () {
    final p = NotifyPrefs({'quietEnabled': true, 'quietFrom': 13 * 60, 'quietTo': 14 * 60});
    expect(p.isQuiet(DateTime(2026, 1, 1, 13, 30)), isTrue);
    expect(p.isQuiet(DateTime(2026, 1, 1, 22, 0)), isFalse);
  });
}
