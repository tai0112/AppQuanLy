import 'package:flutter_test/flutter_test.dart';
import 'package:lht_money/core/format.dart';
import 'package:lht_money/data/models.dart';

void main() {
  group('Xử lý múi giờ và ngày giờ giao dịch', () {
    test('toIso8601WithOffset tạo chuỗi ISO có múi giờ và khôi phục đúng giờ địa phương', () {
      final now = DateTime(2026, 11, 23, 17, 30, 45);
      final s = toIso8601WithOffset(now);

      // Chuỗi phải chứa offset dạng +HH:MM hoặc -HH:MM thay vì Z
      expect(s.contains('Z'), isFalse);
      expect(RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(s), isTrue);

      // Parse lại với _dt / tryParse.toLocal() phải đúng 17:30:45
      final parsed = DateTime.tryParse(s)?.toLocal();
      expect(parsed?.year, 2026);
      expect(parsed?.month, 11);
      expect(parsed?.day, 23);
      expect(parsed?.hour, 17);
      expect(parsed?.minute, 30);
      expect(parsed?.second, 45);
    });

    test('dateOnly chuẩn hoá ngày trên cả DateTime UTC và DateTime Local', () {
      // 05:00 sáng ngày 23/11 ở UTC+7 tương ứng 22:00 ngày 22/11 ở UTC
      final utcTime = DateTime.utc(2026, 11, 22, 22, 0); // 05:00 Nov 23 in Vietnam
      final localDate = dateOnly(utcTime);

      // dateOnly phải chuyển sang giờ địa phương trước khi lấy year/month/day
      expect(localDate.year, utcTime.toLocal().year);
      expect(localDate.month, utcTime.toLocal().month);
      expect(localDate.day, utcTime.toLocal().day);
      expect(localDate.hour, 0);
      expect(localDate.minute, 0);
    });

    test('Bánh xe giờ cuộn vòng (looping) không bị số âm hoặc tràn ngày', () {
      int normHour(int i) => (i % 24 + 24) % 24;
      int normMinute(int i) => (i % 60 + 60) % 60;

      // Cuộn ngược qua mốc 00:00 (chỉ số âm)
      expect(normHour(-1), 23);
      expect(normHour(-2), 22);
      expect(normHour(-24), 0);
      expect(normHour(-25), 23);

      // Cuộn tới qua mốc 23:00 (chỉ số >= 24)
      expect(normHour(24), 0);
      expect(normHour(25), 1);
      expect(normHour(48), 0);

      // Cuộn phút ngược qua 00
      expect(normMinute(-1), 59);
      expect(normMinute(-60), 0);
      expect(normMinute(60), 0);
      expect(normMinute(61), 1);

      // Khi kết hợp với DateTime không bị lùi ngày
      final selected = DateTime(2026, 11, 23);
      final rawHour = -1; // người dùng cuộn ngược từ 00 lên 23
      final fixedHour = normHour(rawHour);
      final dt = DateTime(selected.year, selected.month, selected.day, fixedHour, 0);

      expect(dt.year, 2026);
      expect(dt.month, 11);
      expect(dt.day, 23); // Vẫn là ngày 23, không bị lùi sang ngày 22!
      expect(dt.hour, 23);
    });

    test('Txn parse occurredAt giữ đúng giờ địa phương', () {
      final isoWithOffset = '2026-11-23T17:45:00.000+07:00';
      final txn = Txn({'id': 'test', 'occurredAt': isoWithOffset});
      expect(txn.occurredAt.hour, 17);
      expect(txn.occurredAt.minute, 45);
    });
  });
}
