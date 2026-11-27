import 'package:flutter_test/flutter_test.dart';
import 'package:lht_money/data/ocr.dart';

void main() {
  group('OcrNumberParser', () {
    test('ưu tiên dòng Tổng cộng và loại bỏ ngày tháng, SĐT, tiền thừa', () {
      const receipt = '''
CUA HANG TIEN LOI LINTIN
Ngay: 25/11/2026 16:15
SDT: 0987654321
Tra sua tran chau: 45.000 d
Banh mi: 25.000 d
Tong cong: 70.000 d
Tien khach dua: 100.000 d
Tien thua: 30.000 d
''';
      final res = OcrNumberParser.parseReceiptText(receipt);
      expect(res.bestAmount, 70000);
      expect(res.candidates, containsAll([70000, 45000, 25000]));
      expect(res.candidates.contains(2026), isFalse);
    });

    test('đọc biên lai chuyển khoản ngân hàng', () {
      const transfer = '''
Chuyen khoan thanh cong
So tien: 1,550,000 VND
Ma GD: 9988776655
Ngay giao dich: 25-11-2026
''';
      final res = OcrNumberParser.parseReceiptText(transfer);
      expect(res.bestAmount, 1550000);
    });
    // Biên lai BIDV (chữ số to, đậm): các kiểu văn bản ML Kit có thể trả về.
    const bidvTail = '''
27/11/2026 21:56:15
Đến: LE THI LOAN
Tài khoản định danh: V3GSTPB00601666
Đơn vị thụ hưởng: 4504657727
Tại: BIDV
Nội dung
LE HUU TAI Chuyen tien
Số tham chiếu
0551D4fs-8DvugDU9T
Về trang chủ
Giao dịch mới''';
    for (final (name, amountLine) in [
      ('chuẩn', '295,000 VND'),
      ('VND tách dòng', '295,000\nVND'),
      ('dấu cách sau dấu phẩy', '295, 000 VND'),
      ('chữ O thay số 0', '295,OOO VND'),
      ('chữ o thường + dấu cách', '295, ooo VND'),
      ('dấu chấm', '295.000 VND'),
      ('dính VND', '295,000VND'),
    ]) {
      test('biên lai BIDV: $name', () {
        final res = OcrNumberParser.parseReceiptText('21:56\nBIDV\nGiao dịch thành công\n$amountLine\n$bidvTail');
        expect(res.bestAmount, 295000);
      });
    }

    test('không đổi chữ O trong từ thường (BIDV, LOAN, Số tham chiếu)', () {
      final res = OcrNumberParser.parseReceiptText('LE THI LOAN\nCông ty ABC\nTổng cộng: 120.000 đ');
      expect(res.bestAmount, 120000);
      expect(res.rawText, contains('LOAN'));
    });
  });
}
