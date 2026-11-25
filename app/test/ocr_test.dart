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
  });
}
