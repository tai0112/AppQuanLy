// Bộ đọc hoá đơn: các loại chứng từ (chuyển khoản, ví, VAT, điện, Grab, xăng…) và thông tin kèm theo
// (ngày giờ, nội dung, người nhận / nơi bán, gợi ý danh mục, tiền vào / ra, số tiền bằng chữ).
import 'package:flutter_test/flutter_test.dart';
import 'package:lht_money/data/receipt_reader.dart';

void main() {
  final now = DateTime(2026, 11, 28, 9);
  ReceiptInfo read(String s) => ReceiptReader.read(s, now: now);

  test('biên lai BIDV (ảnh người dùng gửi): số tiền, ngày giờ, người nhận, nội dung', () {
    final r = read('''
21:56
BIDV
Giao dịch thành công
295, 000 VND
27/11/2026 21:56:15
Đến: LE THI LOAN
Tài khoản định danh: V3GSTPB00601666
Đơn vị thụ hưởng: 4504657727
Tại: BIDV
Nội dung
LE HUU TAI Chuyen tien
Số tham chiếu
0551D4fs-8DvugDU9T''');
    expect(r.kind, ReceiptKind.bankTransfer);
    expect(r.amount, 295000);
    expect(r.date, DateTime(2026, 11, 27, 21, 56, 15));
    expect(r.merchant, 'LE THI LOAN');
    expect(r.note, 'LE HUU TAI Chuyen tien');
    expect(r.isIncome, isFalse);
  });

  test('chuyển khoản kiểu Vietcombank / MB: số tiền có dấu trừ, bỏ phí và số dư', () {
    final r = read('''
Chuyển tiền thành công
-1,250,000 VND
Phí giao dịch: 0 VND
Số dư: 12,345,678 VND
Người nhận: NGUYEN VAN A
Ngân hàng: Vietcombank
Nội dung: tra tien nha thang 11
Mã giao dịch: FT26332123456
Thời gian: 15:30 20/11/2026''');
    expect(r.amount, 1250000);
    expect(r.merchant, 'NGUYEN VAN A');
    expect(r.note, 'tra tien nha thang 11');
    expect(r.date, DateTime(2026, 11, 20, 15, 30));
    expect(r.isIncome, isFalse);
  });

  test('nhận tiền (biến động +) → tiền vào, lấy người chuyển', () {
    final r = read('''
Techcombank
Bạn đã nhận tiền
+3.500.000 VND
Từ: TRAN THI B
Nội dung: luong thang 11
Số dư: 20.000.000 VND
25/11/2026 08:01''');
    expect(r.amount, 3500000);
    expect(r.isIncome, isTrue);
    expect(r.merchant, 'TRAN THI B');
    expect(r.categoryHint, isNull, reason: 'tiền vào không gợi ý danh mục chi');
  });

  test('ví MoMo: thanh toán thành công, bỏ phí', () {
    final r = read('''
momo
Thanh toán thành công
89.000đ
Dịch vụ: Highlands Coffee
Phí giao dịch: Miễn phí
Mã giao dịch: 42123456789
Thời gian: 18:20 - 26/11/2026''');
    expect(r.kind, ReceiptKind.eWallet);
    expect(r.amount, 89000);
    expect(r.categoryHint, 'Cà phê');
    expect(r.date, DateTime(2026, 11, 26, 18, 20));
  });

  test('hoá đơn điện tử VAT: chọn tổng thanh toán, xác nhận bằng số tiền bằng chữ', () {
    final r = read('''
HÓA ĐƠN GIÁ TRỊ GIA TĂNG
Ký hiệu: 1C26TAA Số: 00001234
Ngày 15 tháng 11 năm 2026
Đơn vị bán hàng: CÔNG TY TNHH ABC
Mã số thuế: 0312345678
Cộng tiền hàng: 1.000.000
Thuế suất GTGT: 10% Tiền thuế GTGT: 100.000
Tổng cộng tiền thanh toán: 1.100.000
Số tiền viết bằng chữ: Một triệu một trăm nghìn đồng''');
    expect(r.kind, ReceiptKind.eInvoice);
    expect(r.amount, 1100000);
    expect(r.date, DateTime(2026, 11, 15));
  });

  test('số tiền bằng chữ', () {
    expect(ReceiptReader.wordsToAmount('Sáu mươi nghìn đồng chẵn'), 60000);
    expect(ReceiptReader.wordsToAmount('Hai trăm chín mươi lăm nghìn đồng'), 295000);
    expect(ReceiptReader.wordsToAmount('Một triệu một trăm nghìn đồng'), 1100000);
    expect(ReceiptReader.wordsToAmount('Mười hai nghìn năm trăm đồng'), 12500);
    expect(ReceiptReader.wordsToAmount('Ba triệu linh năm nghìn đồng'), 3005000);
  });

  test('tiền điện EVN: tổng số tiền thanh toán, bỏ chỉ số kWh', () {
    final r = read('''
TỔNG CÔNG TY ĐIỆN LỰC TP.HCM
THÔNG BÁO TIỀN ĐIỆN
Kỳ hóa đơn: 11/2026
Chỉ số mới: 12456 Chỉ số cũ: 12111
Điện năng tiêu thụ: 345 kWh
Tiền điện: 875.300
Thuế GTGT (8%): 70.024
Tổng số tiền thanh toán: 945.324''');
    expect(r.kind, ReceiptKind.utility);
    expect(r.amount, 945324);
    expect(r.categoryHint, 'Điện');
  });

  test('Grab: tổng cộng sau khuyến mãi', () {
    final r = read('''
Grab
Chuyến đi của bạn
Điểm đón: 12 Nguyễn Huệ
Điểm đến: Sân bay Tân Sơn Nhất
Giá cước 152.000đ
Khuyến mãi -30.000đ
Tổng cộng 122.000đ
24/11/2026 07:45''');
    expect(r.amount, 122000);
    expect(r.categoryHint, 'Taxi/Grab');
  });

  test('đổ xăng: thành tiền là tổng, bỏ số lít và đơn giá', () {
    final r = read('''
PETROLIMEX - CỬA HÀNG XĂNG DẦU SỐ 5
Mặt hàng: Xăng RON 95-III
Đơn giá: 21.470 đ/lít
Số lít: 3,26
Thành tiền: 70.000 đ
22/11/2026 17:10''');
    expect(r.kind, ReceiptKind.fuel);
    expect(r.amount, 70000);
    expect(r.categoryHint, 'Xăng xe');
  });

  test('siêu thị: tổng phải thanh toán, bỏ tiền khách đưa / trả lại / điểm tích luỹ; lấy tên cửa hàng', () {
    final r = read('''
WinMart+ 12 Lê Lợi
HÓA ĐƠN BÁN HÀNG
Ngày bán: 21/11/2026 19:02
Sữa tươi TH 1L 2 x 32.000 64.000
Bánh mì sandwich 18.500
TỔNG TIỀN PHẢI T.TOÁN 82.500
TIỀN KHÁCH TRẢ 100.000
TIỀN TRẢ LẠI 17.500
Điểm tích (1.000VND:1 điểm) 82''');
    expect(r.amount, 82500);
    expect(r.merchant, 'WinMart+ 12 Lê Lợi');
    expect(r.categoryHint, 'Đi chợ');
    expect(r.date, DateTime(2026, 11, 21, 19, 2));
  });

  test('văn bản rỗng / không có số tiền', () {
    expect(read('').amount, isNull);
    expect(read('Cảm ơn quý khách').amount, isNull);
  });
}
