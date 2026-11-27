// Bộ đọc hoá đơn / biên lai từ văn bản OCR (thuần Dart, chạy trên máy, không gửi dữ liệu đi đâu).
//
// Cách làm: nhận dạng LOẠI chứng từ (chuyển khoản ngân hàng, ví điện tử, siêu thị / cửa hàng, quán ăn – cà phê,
// hoá đơn điện tử VAT, điện – nước – internet, gọi xe / giao đồ ăn, đổ xăng) rồi chấm điểm từng con số theo
// từ khoá của dòng chứa nó (so không dấu để chịu được OCR sai dấu), kèm các "kỹ năng" phụ:
// - đọc số tiền bằng chữ ("Sáu mươi nghìn đồng") để xác nhận tổng tiền;
// - lấy ngày giờ, nội dung chuyển khoản, nơi bán / người nhận, gợi ý danh mục, tiền vào hay tiền ra.
// Đo trên 866 hoá đơn bán lẻ thật (bộ MC-OCR 2021): xem test/receipt_bench_test.dart.

/// Loại chứng từ nhận dạng được.
enum ReceiptKind { bankTransfer, eWallet, retail, foodDrink, eInvoice, utility, rideFood, fuel, generic }

/// Kết quả đọc một hoá đơn.
class ReceiptInfo {
  const ReceiptInfo({
    required this.amount,
    required this.candidates,
    required this.rawText,
    this.kind = ReceiptKind.generic,
    this.date,
    this.note,
    this.merchant,
    this.categoryHint,
    this.isIncome = false,
  });

  /// Tổng tiền tốt nhất (null = không tìm thấy).
  final double? amount;

  /// Các số tiền khác (xếp theo độ tin cậy) để người dùng chọn.
  final List<double> candidates;
  final String rawText;
  final ReceiptKind kind;

  /// Thời điểm giao dịch đọc được trên chứng từ.
  final DateTime? date;

  /// Nội dung chuyển khoản / ghi chú.
  final String? note;

  /// Nơi bán (hoá đơn) hoặc người nhận / người chuyển (biên lai chuyển khoản).
  final String? merchant;

  /// Tên danh mục gợi ý (khớp tên danh mục mặc định của app: "Cà phê", "Đi chợ", "Xăng xe"…).
  final String? categoryHint;

  /// Tiền vào (nhận chuyển khoản) thay vì tiền ra.
  final bool isIncome;
}

class ReceiptReader {
  ReceiptReader._();

  // ------------------------------------------------------------------ Chuẩn hoá

  static const _from = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
  static const _to = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';

  /// Chữ thường, bỏ dấu, gộp khoảng trắng → so từ khoá chịu được OCR sai dấu ("TỔNG TIẾN" = "tong tien").
  static String fold(String s) {
    final b = StringBuffer();
    for (final r in s.toLowerCase().runes) {
      final ch = String.fromCharCode(r);
      final i = _from.indexOf(ch);
      b.write(i < 0 ? ch : _to[i]);
    }
    return b.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  // Chữ O / o bị đọc nhầm thay cho số 0 (chữ số đậm, tròn): chỉ sửa khi đứng sát chữ số / dấu phân cách của một số.
  static final _oAfterDigit = RegExp(r'(?<=\d[.,]?\s?)[Oo]');
  static final _oBeforeDigit = RegExp(r'[Oo](?=[Oo]*[.,]?\d)');

  static String _fixDigits(String line) {
    var out = line;
    for (var i = 0; i < 6; i++) {
      final next = out.replaceAll(_oAfterDigit, '0').replaceAll(_oBeforeDigit, '0');
      if (next == out) break;
      out = next;
    }
    return out;
  }

  // ------------------------------------------------------------------ Mẫu số

  static final _dateRe = RegExp(r'\b\d{1,2}\s?[/.-]\s?\d{1,2}\s?[/.-]\s?\d{2,4}\b|\b\d{4}[/-]\d{1,2}[/-]\d{1,2}\b');
  static final _timeRe = RegExp(r'\b\d{1,2}[:h]\d{2}(:\d{2})?\b');
  static final _phoneRe = RegExp(r'(\+84|0)\s?(2\d|3|5|7|8|9)\d[\d .]{6,10}\d');
  // Số tài khoản / số thẻ: nhiều cụm 4 chữ số cách nhau bằng khoảng trắng, hoặc thẻ che XXXX
  static final _accountNumRe = RegExp(r'\b\d{4}(?:\s+\d{2,4}){1,3}\b|[Xx*]{4,}\d*');
  // 150.000 / 150,000 / 150 000 / 150, 000 · kèm đơn vị k / đ / d / vnd / vnđ / ₫ / dong · có thể có dấu +/- phía trước
  static final _numRe = RegExp(
    r'([+-]\s?)?(\d{1,3}(?:[.,]\s?\d{3})+(?:[.,]\d{1,2})?|\d{1,3}(?:\s\d{3})+(?![.,]\d)|\d{4,9}|\d{1,4})\s*(k|đ|d|vnd|vnđ|₫|dong|đồng)?(?=$|[\s.,;:!?()/\-*"\x27\u201D\u2019])',
    caseSensitive: false,
  );

  // ------------------------------------------------------------------ Từ khoá (đã bỏ dấu)

  /// Dòng tổng cuối cùng (phải trả) — mạnh nhất.
  static const _finalTotal = [
    'tong tien phai thanh toan',
    'tong tien phai t',
    'phai thanh toan',
    'phai t.toan',
    'phai t toan',
    'khach phai tra',
    'khach can tra',
    'tong thanh toan',
    'tong tien thanh toan',
    'tong cong tien thanh toan',
    'tong so tien thanh toan',
    'so tien thanh toan',
    'so tien can thanh toan',
    'can thanh toan',
    'tong tien phai tra',
    'thanh toan',
    'total due',
    'amount due',
    'grand total',
    'total payment',
    'tong phai tra',
  ];

  /// Dòng tổng thường.
  static const _total = ['tong cong', 'tong tien', 'tong so tien', 'tong gia tri', 'cong thanh tien', 'total', 'tong:', 'tong '];

  /// Số tiền trên biên lai chuyển khoản / ví.
  static const _transfer = [
    'so tien',
    'amount',
    'giao dich thanh cong',
    'chuyen tien thanh cong',
    'chuyen khoan thanh cong',
    'thanh toan thanh cong',
    'gd thanh cong',
    'ban da chuyen',
    'da chuyen',
    'transfer successful',
    'successful',
  ];

  /// Tạm tính / tiền hàng (trước giảm giá, thuế) — yếu.
  static const _subtotal = ['cong tien hang', 'tam tinh', 'tong tien hang', 'thanh tien', 'subtotal', 'sub total', 'tien hang'];

  /// Dòng chắc chắn KHÔNG phải tổng tiền.
  static final _negative = RegExp(
    r'tien khach dua|khach dua|tien thu\b|tien nhan\b|tien khach tra|khach tra\b|tien thua|tien thoi|tra lai|\bthoi lai|change\b|tien mat|cash\b|'
    r'giam gia|da giam|giam\b|chiet khau|khuyen mai|discount|voucher|uu dai|'
    r'so du|balance|hotline|dien thoai|\bdt\b|\bsdt\b|\btel\b|\bfax\b|\bmst\b|ma so thue|tax code|'
    r'ma gd|ma giao dich|so tham chieu|ma tham chieu|ma don|so hd|so hoa don|so phieu|so ct|ky hieu|mau so|'
    r'diem\b|tich luy|tich diem|point|'
    r'\bphi\b|phi giao dich|phi dich vu|\bfee\b|\bvat\b|thue gtgt|tien thue|thue suat|'
    r'so luong|tong so luong|tong sl|\bsl\b|\bqty\b|so lit|don gia|\bdg\b|'
    r'tai khoan|\bstk\b|so the|the khach hang|\bvisa\b|master|\bid\b|kwh|chi so',
  );

  static final _inclVat = RegExp(r'(da|bao)?\s?gom\s?(vat|thue)|incl\.?\s?vat|\(-?\s?vat\)|\(vat\)|vat incl');

  /// Dấu hiệu tiền vào (nhận tiền).
  static final _incomeRe = RegExp(r'nhan tien|da nhan|ban nhan duoc|nhan duoc|tien ve|tien vao|received|credit\b|\+\s?\d');

  // ------------------------------------------------------------------ Nhận dạng loại chứng từ

  static const _kindKeys = <ReceiptKind, List<String>>{
    ReceiptKind.bankTransfer: [
      'vietcombank',
      'vcb',
      'techcombank',
      'tcb',
      'bidv',
      'vietinbank',
      'agribank',
      'mbbank',
      'mb bank',
      'tpbank',
      'vpbank',
      'acb',
      'sacombank',
      'hdbank',
      'vib',
      'shb',
      'ocb',
      'msb',
      'seabank',
      'eximbank',
      'lpbank',
      'nam a bank',
      'bac a bank',
      'abbank',
      'pvcombank',
      'kienlongbank',
      'cake',
      'timo',
      'vikki',
      'ngan hang',
      'chuyen tien',
      'chuyen khoan',
      'so tham chieu',
      'nguoi nhan',
      'nguoi huong',
      'thu huong',
      'tai khoan nhan',
      'noi dung',
      'napas',
      'giao dich thanh cong',
    ],
    ReceiptKind.eWallet: ['momo', 'zalopay', 'shopeepay', 'vnpay', 'viettel money', 'vnpt money', 'moca', 'payoo', 'vi dien tu'],
    ReceiptKind.retail: [
      'hoa don ban hang',
      'phieu thanh toan',
      'sieu thi',
      'mart',
      'circle k',
      'gs25',
      '7-eleven',
      'familymart',
      'bach hoa xanh',
      'coop',
      'co.op',
      'winmart',
      'vinmart',
      'lotte',
      'aeon',
      'emart',
      'big c',
      'go!',
      'mega market',
      'tien khach dua',
      'tien thua',
      'ma vach',
      'quay',
      'thu ngan',
      'nvbh',
    ],
    ReceiptKind.foodDrink: [
      'ban so',
      'ban:',
      'phuc vu',
      'order',
      'tra sua',
      'cafe',
      'coffee',
      'ca phe',
      'nha hang',
      'quan an',
      'lau',
      'nuong',
      'bia',
      'highlands',
      'phuc long',
      'starbucks',
      'katinat',
      'the coffee house',
      'trung nguyen',
      'gong cha',
      'tocotoco',
      'phe la',
      'service charge',
      'phi phuc vu',
      'so khach',
    ],
    ReceiptKind.eInvoice: [
      'hoa don gia tri gia tang',
      'hoa don dien tu',
      'ma so thue',
      'ky hieu',
      'mau so',
      'tien thue gtgt',
      'cong tien hang',
      'bang chu',
      'viet bang chu',
      'ma tra cuu',
      'tra cuu hoa don',
    ],
    ReceiptKind.utility: [
      'evn',
      'dien luc',
      'tien dien',
      'kwh',
      'chi so',
      'nuoc sach',
      'cap nuoc',
      'tien nuoc',
      'ky hoa don',
      'viettel',
      'vnpt',
      'fpt telecom',
      'cuoc vien thong',
      'cuoc internet',
      'truyen hinh',
    ],
    ReceiptKind.rideFood: [
      'grab',
      'xanh sm',
      'gojek',
      'be group',
      'shopeefood',
      'baemin',
      'grabfood',
      'gia cuoc',
      'cuoc phi',
      'phi giao hang',
      'diem don',
      'diem den',
      'quang duong',
    ],
    ReceiptKind.fuel: ['xang', 'ron 95', 'ron95', 'e5', 'dau do', 'diesel', 'petrolimex', 'pvoil', 'cua hang xang dau', 'so lit', 'lit'],
  };

  static final _walletBrand = RegExp(r'\bmomo\b|zalopay|shopeepay|vnpay|viettel money|vnpt money|\bmoca\b');

  static ReceiptKind _detectKind(String folded) {
    // Tên ví điện tử là dấu hiệu chắc chắn (dù nội dung có tên quán, tên dịch vụ…)
    if (_walletBrand.hasMatch(folded)) return ReceiptKind.eWallet;
    var best = ReceiptKind.generic;
    var bestScore = 0;
    _kindKeys.forEach((kind, keys) {
      var score = 0;
      for (final k in keys) {
        if (folded.contains(k)) score += k.length > 6 ? 2 : 1;
      }
      if (score > bestScore) {
        bestScore = score;
        best = kind;
      }
    });
    return bestScore >= 2 ? best : ReceiptKind.generic;
  }

  // ------------------------------------------------------------------ Gợi ý danh mục

  static const _categoryKeys = <String, List<String>>{
    'Cà phê': ['cafe', 'coffee', 'ca phe', 'highlands', 'phuc long', 'starbucks', 'katinat', 'trung nguyen', 'phe la', 'cong ca phe'],
    'Đi chợ': [
      'winmart',
      'vinmart',
      'coopmart',
      'co.op',
      'bach hoa xanh',
      'circle k',
      'gs25',
      '7-eleven',
      'familymart',
      'ministop',
      'lotte mart',
      'aeon',
      'emart',
      'big c',
      'go!',
      'mega market',
      'sieu thi',
      'cho ',
    ],
    'Xăng xe': ['xang', 'ron 95', 'ron95', 'petrolimex', 'pvoil', 'diesel', 'dau do'],
    'Điện': ['evn', 'dien luc', 'tien dien', 'kwh'],
    'Nước': ['nuoc sach', 'cap nuoc', 'tien nuoc', 'sawaco'],
    'Internet': ['fpt telecom', 'viettel', 'vnpt', 'internet', 'cuoc vien thong'],
    'Taxi/Grab': ['grab', 'xanh sm', 'gojek', 'taxi', 'mai linh', 'vinasun', 'gia cuoc'],
    'Thuốc': ['nha thuoc', 'pharmacity', 'long chau', 'an khang', 'duoc pham'],
    'Phim ảnh': ['cgv', 'lotte cinema', 'galaxy cinema', 'bhd', 'beta cinemas', 've xem phim'],
    'Quần áo': ['uniqlo', 'zara', 'h&m', 'canifa', 'thoi trang', 'quan ao'],
    'Ăn uống': [
      'tra sua',
      'gong cha',
      'tocotoco',
      'nha hang',
      'quan an',
      'com ',
      'pho ',
      'bun ',
      'lau',
      'nuong',
      'kfc',
      'lotteria',
      'jollibee',
      'mcdonald',
      'pizza',
      'shopeefood',
      'baemin',
      'grabfood',
      'banh mi',
    ],
  };

  static String? _categoryHint(String folded, ReceiptKind kind, {String head = ''}) {
    // Phần đầu chứng từ (tên cửa hàng / dịch vụ) quyết định trước, rồi mới tới toàn bộ nội dung (tên món hàng…)
    for (final text in [head, folded]) {
      if (text.isEmpty) continue;
      for (final e in _categoryKeys.entries) {
        for (final k in e.value) {
          if (text.contains(k)) return e.key;
        }
      }
    }
    return switch (kind) {
      ReceiptKind.fuel => 'Xăng xe',
      ReceiptKind.retail => 'Đi chợ',
      ReceiptKind.foodDrink => 'Ăn uống',
      _ => null,
    };
  }

  // ------------------------------------------------------------------ Số tiền bằng chữ

  static const _digitWords = {'khong': 0, 'mot': 1, 'hai': 2, 'ba': 3, 'bon': 4, 'tu': 4, 'nam': 5, 'lam': 5, 'sau': 6, 'bay': 7, 'tam': 8, 'chin': 9};

  /// "Sáu mươi nghìn đồng" → 60000. Trả null nếu không đọc được.
  static double? wordsToAmount(String text) {
    final words = fold(text).replaceAll(RegExp(r'[^a-z ]'), ' ').split(' ').where((w) => w.isNotEmpty).toList();
    var total = 0.0, group = 0.0, cur = 0.0;
    var any = false;
    for (var i = 0; i < words.length; i++) {
      final w = words[i];
      final d = _digitWords[w];
      if (d != null) {
        cur = cur * 1 + d; // chữ số đơn vị (hoặc hàng chục khi đứng trước "muoi")
        any = true;
      } else if (w == 'muoi' || w == 'chuc') {
        // "mười" (10) khi đứng đầu cụm, "mươi" (×10) khi sau một chữ số
        cur = cur == 0 ? 10 : cur * 10;
        any = true;
      } else if (w == 'tram') {
        group += (cur == 0 ? 1 : cur) * 100;
        cur = 0;
        any = true;
      } else if (w == 'linh' || w == 'le') {
        continue;
      } else if (w == 'nghin' || w == 'ngan') {
        total += (group + cur == 0 ? 1 : group + cur) * 1000;
        group = 0;
        cur = 0;
        any = true;
      } else if (w == 'trieu') {
        total += (group + cur == 0 ? 1 : group + cur) * 1000000;
        group = 0;
        cur = 0;
        any = true;
      } else if (w == 'ty') {
        total = (total + group + cur == 0 ? 1 : total + group + cur) * 1000000000;
        group = 0;
        cur = 0;
        any = true;
      } else if (any && (w == 'dong' || w == 'vnd' || w == 'chan')) {
        break;
      }
    }
    final v = total + group + cur;
    return any && v >= 1000 ? v : null;
  }

  // ------------------------------------------------------------------ Ngày giờ

  static final _dmy = RegExp(r'(\d{1,2})\s?[/.-]\s?(\d{1,2})\s?[/.-]\s?(\d{4}|\d{2})\b');
  static final _ymd = RegExp(r'\b(\d{4})[/-](\d{1,2})[/-](\d{1,2})\b');
  static final _words = RegExp(r'ngay\s*(\d{1,2})\s*thang\s*(\d{1,2})\s*nam\s*(\d{4})');
  static final _hm = RegExp(r'\b(\d{1,2})[:h](\d{2})(?::(\d{2}))?\b');

  /// Mọi bộ (ngày, tháng, năm) có thể đọc được trong dòng — thử từng vị trí (OCR hay dính "18:20 - 26/11/2026").
  static Iterable<(int, int, int)> _dateParts(String line, String folded) sync* {
    final c = _words.firstMatch(folded);
    if (c != null) yield (int.parse(c[3]!), int.parse(c[2]!), int.parse(c[1]!));
    for (final b in _ymd.allMatches(line)) {
      yield (int.parse(b[1]!), int.parse(b[2]!), int.parse(b[3]!));
    }
    for (var i = 0; i < line.length; i++) {
      if (i > 0 && RegExp(r'\d').hasMatch(line[i - 1])) continue; // chỉ bắt đầu ở đầu một số
      final a = _dmy.matchAsPrefix(line, i);
      if (a == null) continue;
      var y = int.parse(a[3]!);
      if (y < 100) y += 2000;
      yield (y, int.parse(a[2]!), int.parse(a[1]!));
    }
  }

  static DateTime? _findDate(List<String> lines, DateTime now) {
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      for (final (y, m, d) in _dateParts(line, fold(line))) {
        if (m < 1 || m > 12 || d < 1 || d > 31 || y < 2000 || y > now.year + 1) continue;
        var date = DateTime(y, m, d);
        if (date.month != m || date.isAfter(now.add(const Duration(days: 2)))) continue;
        // Giờ trên cùng dòng hoặc dòng kề
        for (final l in [line, if (i + 1 < lines.length) lines[i + 1], if (i > 0) lines[i - 1]]) {
          final t = _hm.firstMatch(l); // mẫu giờ cần ':' hoặc 'h' nên không nhầm với ngày
          if (t == null) continue;
          final hh = int.parse(t[1]!), mm = int.parse(t[2]!), ss = int.tryParse(t[3] ?? '') ?? 0;
          if (hh < 24 && mm < 60 && ss < 60) {
            date = DateTime(y, m, d, hh, mm, ss);
            break;
          }
        }
        return date;
      }
    }
    return null;
  }

  // ------------------------------------------------------------------ Trường dạng "Nhãn: giá trị"

  /// Giá trị sau nhãn ("Nội dung: ABC" hoặc nhãn một dòng, giá trị dòng dưới).
  static String? _field(List<String> lines, List<String> labels) {
    for (var i = 0; i < lines.length; i++) {
      final f = fold(lines[i]);
      for (final l in labels) {
        if (!f.startsWith(l)) continue;
        final raw = lines[i];
        final colon = raw.indexOf(':');
        final after = colon >= 0 ? raw.substring(colon + 1).trim() : raw.substring(raw.length.clamp(0, l.length)).trim();
        final value = after.isNotEmpty ? after : (i + 1 < lines.length ? lines[i + 1].trim() : '');
        if (value.isNotEmpty && value.length <= 120) return value;
      }
    }
    return null;
  }

  static const _noteLabels = ['noi dung', 'loi nhan', 'ghi chu', 'dien giai', 'description', 'message', 'memo'];
  static const _payeeLabels = [
    'den:',
    'den tai khoan',
    'nguoi nhan',
    'ten nguoi nhan',
    'nguoi thu huong',
    'ten nguoi thu huong',
    'tai khoan nhan',
    'chuyen den',
    'beneficiary',
    'to:',
    'nguoi huong',
  ];
  static const _payerLabels = ['tu:', 'nguoi chuyen', 'ten nguoi chuyen', 'tu tai khoan', 'from:'];

  static final _headerWords = RegExp(
    r'hoa don|phieu|bill|receipt|welcome|xin chao|cam on|giao dich|thanh cong|chuyen tien|ngay|so:|so hd|lien|ban hang|tam tinh',
  );

  /// Tên nơi bán: dòng đầu có nhiều chữ cái, không phải tiêu đề / ngày / số.
  static String? _merchant(List<String> lines) {
    for (final l in lines.take(6)) {
      final f = fold(l);
      final letters = RegExp(r'[a-z]').allMatches(f).length;
      if (letters < 3 || letters < f.length * 0.5 || _headerWords.hasMatch(f) || RegExp(r'\d{3,}').hasMatch(f)) continue;
      return l.trim();
    }
    return null;
  }

  /// Vài dòng đầu (thường là tên cửa hàng / dịch vụ) + các dòng "Dịch vụ:", "Cửa hàng:", "Đơn vị:".
  static String _head(List<String> lines) {
    final picked = [
      ...lines.take(3),
      for (final l in lines)
        if (RegExp(r'^(dich vu|cua hang|don vi|merchant|noi thanh toan|thanh toan cho)').hasMatch(fold(l))) l,
    ];
    return fold(picked.join(' '));
  }

  // ------------------------------------------------------------------ Đọc

  static int _keyScore(String f, ReceiptKind kind) {
    var best = 0;
    for (final k in _finalTotal) {
      if (f.contains(k)) {
        best = 150;
        break;
      }
    }
    if (best == 0) {
      for (final k in _total) {
        if (f.contains(k)) {
          best = 110;
          break;
        }
      }
    }
    if (best < 120 && (kind == ReceiptKind.bankTransfer || kind == ReceiptKind.eWallet)) {
      for (final k in _transfer) {
        if (f.contains(k)) {
          best = 140;
          break;
        }
      }
    }
    if (best == 0) {
      for (final k in _subtotal) {
        if (f.contains(k)) {
          // Đổ xăng: "Thành tiền" chính là tổng
          best = kind == ReceiptKind.fuel ? 130 : 45;
          break;
        }
      }
    }
    return best;
  }

  static ReceiptInfo read(String text, {DateTime? now}) {
    final today = now ?? DateTime.now();
    if (text.trim().isEmpty) return const ReceiptInfo(amount: null, candidates: [], rawText: '');
    final lines = [for (final l in text.split('\n')) l.trim()]..removeWhere((l) => l.isEmpty);
    final folded = fold(text);
    final kind = _detectKind(folded);
    final transferLike = kind == ReceiptKind.bankTransfer || kind == ReceiptKind.eWallet;

    final scores = <double, int>{};
    final signs = <double, String>{};
    var carry = 0, carryLeft = 0;
    var firstUnitAmount = true;
    double? words;

    for (var li = 0; li < lines.length; li++) {
      final raw = lines[li];
      final f = fold(raw);

      // Số tiền bằng chữ: dùng để xác nhận tổng tiền
      if (words == null && (f.contains('bang chu') || RegExp(r'(nghin|ngan|trieu|tram).*dong').hasMatch(f))) {
        words = wordsToAmount(f.contains(':') ? f.substring(f.indexOf(':') + 1) : f);
      }

      final cleaned = _fixDigits(raw).replaceAll(_dateRe, ' ').replaceAll(_timeRe, ' ').replaceAll(_phoneRe, ' ').replaceAll(_accountNumRe, ' ');
      // "Tổng cộng (đã gồm VAT)" là dòng tổng, không phải dòng thuế
      final negative = _negative.hasMatch(f.replaceAll(_inclVat, ' '));
      final key = _keyScore(f, kind);
      // Dòng vừa có từ khoá tổng vừa có từ phủ định (vd "Tổng tiền đã giảm", "Tổng số lượng") → không phải tổng
      final lineBonus = negative ? (key >= 150 && !RegExp(r'giam|so luong|\bsl\b|diem').hasMatch(f) ? key - 40 : -80) : key;
      final effective = lineBonus != 0 ? lineBonus : carry;
      var matched = false;

      for (final m in _numRe.allMatches(cleaned)) {
        final sign = (m[1] ?? '').trim();
        final rawNum = m[2] ?? '';
        final unit = (m[3] ?? '').toLowerCase();
        final hasGrouping = RegExp(r'[.,\s]\d{3}').hasMatch(rawNum);
        // Phần lẻ ",50" / ".5" (ngoại tệ) → bỏ; tiền Việt không có phần lẻ
        final whole = rawNum.replaceAll(RegExp(r'[.,]\d{1,2}$'), '');
        final digits = whole.replaceAll(RegExp(r'[.,\s]'), '');
        final parsed = double.tryParse(digits);
        if (parsed == null) continue;
        final value = unit == 'k' ? parsed * 1000 : parsed;

        if (value < 1000 || value > 500000000) continue;
        // Năm 1990–2100 đứng một mình
        if (!hasGrouping && unit.isEmpty && value >= 1990 && value <= 2100) continue;
        // Số 6–9 chữ số không phân tách, không đơn vị: dễ là mã → chỉ giữ khi dòng có từ khoá tổng
        if (!hasGrouping && unit.isEmpty && digits.length >= 6 && effective <= 0) continue;
        // Số không phân tách, dính chữ (mã vạch, mã hàng) → bỏ
        if (!hasGrouping && digits.length >= 8) continue;

        matched = true;
        var score = effective;
        if (hasGrouping) score += 25;
        if (unit.isNotEmpty) score += 35;
        if (sign.isNotEmpty && transferLike) score += 30;
        // Biên lai chuyển khoản: số tiền có đơn vị đầu tiên (chữ to ở đầu) thường là số tiền giao dịch
        if (transferLike && unit.isNotEmpty && firstUnitAmount && !negative) {
          score += 60;
          firstUnitAmount = false;
        }
        final prev = scores[value];
        if (prev == null || score > prev) {
          scores[value] = score;
          if (sign.isNotEmpty) signs[value] = sign;
        }
      }
      // Nhãn ở dòng trên, số ở dòng dưới (OCR hay xếp lệch): chuyển điểm xuống tối đa 2 dòng
      if (!matched && lineBonus > 0) {
        carry = (lineBonus * 0.7).round();
        carryLeft = 2;
      } else if (carryLeft > 1 && !matched) {
        carry = (carry * 0.7).round();
        carryLeft--;
      } else if (carryLeft > 1 && lineBonus < 0) {
        carry = (carry * 0.7).round(); // dòng chen giữa là dòng phủ định có số → vẫn chuyển tiếp cho dòng sau
        carryLeft--;
      } else {
        carry = 0;
        carryLeft = 0;
      }
    }

    // Số tiền bằng chữ khớp một số trên hoá đơn → gần như chắc chắn là tổng
    if (words != null && scores.containsKey(words)) scores[words] = scores[words]! + 200;

    if (scores.isEmpty) {
      return ReceiptInfo(
        amount: words,
        candidates: [?words],
        rawText: text,
        kind: kind,
        date: _findDate(lines, today),
        note: _field(lines, _noteLabels),
        merchant: transferLike ? _field(lines, _payeeLabels) : _merchant(lines),
        categoryHint: _categoryHint(folded, kind, head: _head(lines)),
      );
    }

    final sorted = scores.entries.toList()
      ..sort((a, b) {
        final c = b.value.compareTo(a.value);
        return c != 0 ? c : b.key.compareTo(a.key);
      });
    final best = sorted.first.key;
    final income = transferLike && (signs[best] == '+' || (signs[best] != '-' && _incomeRe.hasMatch(folded) && !folded.contains('chuyen tien thanh cong')));
    return ReceiptInfo(
      amount: best,
      candidates: [for (final e in sorted.take(6)) e.key],
      rawText: text,
      kind: kind,
      date: _findDate(lines, today),
      note: _field(lines, _noteLabels),
      merchant: transferLike ? (income ? _field(lines, _payerLabels) : _field(lines, _payeeLabels)) : _merchant(lines),
      categoryHint: income ? null : _categoryHint(folded, kind, head: _head(lines)),
      isIncome: income,
    );
  }
}
