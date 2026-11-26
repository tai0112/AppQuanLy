import 'dart:io' show Directory, File, Platform;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Kết quả đọc số tiền từ ảnh hoá đơn / biên lai chuyển khoản.
class OcrResult {
  const OcrResult({required this.bestAmount, required this.candidates, required this.rawText});
  final double? bestAmount;
  final List<double> candidates;
  final String rawText;
}

/// Bộ phân tích văn bản OCR tiếng Việt/Anh thành danh sách số tiền hợp lệ.
class OcrNumberParser {
  static final _dateRe = RegExp(r'\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b|\b\d{4}[/-]\d{1,2}[/-]\d{1,2}\b');
  static final _timeRe = RegExp(r'\b\d{1,2}:\d{2}(:\d{2})?\b');
  static final _phoneRe = RegExp(r'(\+84|0)(3|5|7|8|9)\d{8}\b');
  // Số tài khoản / số thẻ kiểu 9595 3689 999 hoặc 3600 8904 18 (nhiều cụm 4 chữ số cách nhau bằng khoảng trắng)
  static final _accountNumRe = RegExp(r'\b\d{4}(?:\s+\d{2,4}){1,3}\b');
  // Hỗ trợ 150.000 / 150,000 / 150 000, kèm đơn vị k / đ / d / vnd / vnđ / ₫ (không dùng \b cuối vì đ/₫ là non-word)
  static final _numRe = RegExp(
    r'(\d{1,3}(?:[.,\s]\d{3})+|\d{4,9}|\d{1,4})\s*(k|đ|d|vnd|vnđ|₫)?(?=$|[\s.,;:!?()/\-])',
    caseSensitive: false,
  );

  static const _positiveKeys = [
    'tổng cộng',
    'tong cong',
    'tổng tiền',
    'tong tien',
    'thành tiền',
    'thanh tien',
    'thanh toán',
    'thanh toan',
    'phải trả',
    'phai tra',
    'số tiền',
    'so tien',
    'chuyển khoản',
    'chuyen khoan',
    'giao dịch thành công',
    'giao dich thanh cong',
    'chuyển tiền thành công',
    'chuyen tien thanh cong',
    'thanh toán thành công',
    'thanh toan thanh cong',
    'total',
    'amount',
    'grand total',
  ];

  static const _negativeKeys = [
    'tiền thừa',
    'tien thua',
    'tiền thối',
    'tien thoi',
    'khách đưa',
    'khach dua',
    'tiền mặt',
    'tien mat',
    'giảm giá',
    'giam gia',
    'chiết khấu',
    'chiet khau',
    'số dư',
    'so du',
    'hotline',
    'sđt',
    'sdt',
    'tel',
    'mã gd',
    'ma gd',
    'mã đơn',
    'ma don',
    'mst',
  ];

  static OcrResult parseReceiptText(String text) {
    if (text.trim().isEmpty) return const OcrResult(bestAmount: null, candidates: [], rawText: '');

    final scores = <double, int>{};
    final lines = text.split('\n');
    var carryBonus = 0;

    for (final rawLine in lines) {
      final lineLower = rawLine.toLowerCase();
      // Loại bỏ ngày, giờ, số điện thoại, số tài khoản/thẻ trước khi bắt số tiền
      final cleaned = rawLine
          .replaceAll(_dateRe, ' ')
          .replaceAll(_timeRe, ' ')
          .replaceAll(_phoneRe, ' ')
          .replaceAll(_accountNumRe, ' ');

      var lineBonus = 0;
      for (final k in _positiveKeys) {
        if (lineLower.contains(k)) {
          lineBonus += 100;
          break;
        }
      }
      for (final k in _negativeKeys) {
        if (lineLower.contains(k)) {
          lineBonus -= 60;
          break;
        }
      }

      final effectiveBonus = lineBonus != 0 ? lineBonus : carryBonus;
      var matchedAnyOnLine = false;

      for (final m in _numRe.allMatches(cleaned)) {
        final rawNum = m.group(1) ?? '';
        final unit = (m.group(2) ?? '').toLowerCase();
        final hasGrouping = rawNum.contains('.') || rawNum.contains(',') || rawNum.contains(' ');
        final digitsOnly = rawNum.replaceAll(RegExp(r'[.,\s]'), '');
        final parsed = double.tryParse(digitsOnly);
        if (parsed == null) continue;

        final value = unit == 'k' ? parsed * 1000 : parsed;

        // Bỏ qua số quá nhỏ (SL 1, 2, 3...) hoặc quá lớn bất hợp lý (mã vạch, STK > 500 triệu)
        if (value < 1000 || value > 500000000) continue;
        // Bỏ qua số 4 chữ số đứng trơ trọi kiểu năm 1990..2100 nếu không có đơn vị tiền và không có grouping
        if (!hasGrouping && unit.isEmpty && value >= 1990 && value <= 2100) continue;
        // Số 6-9 chữ số không có grouping và không có đơn vị dễ là mã hoá đơn -> chỉ giữ nếu dòng có từ khoá
        if (!hasGrouping && unit.isEmpty && digitsOnly.length >= 6 && effectiveBonus <= 0) continue;

        matchedAnyOnLine = true;
        var score = effectiveBonus;
        if (hasGrouping) score += 25;
        if (unit.isNotEmpty) score += 35;

        final prev = scores[value];
        if (prev == null || score > prev) scores[value] = score;
      }

      // Nếu dòng này có từ khóa (vd "Tổng cộng:") nhưng số tiền nằm ở dòng ngay dưới thì chuyển tiếp bonus
      carryBonus = (!matchedAnyOnLine && lineBonus > 0) ? 70 : 0;
    }

    if (scores.isEmpty) return OcrResult(bestAmount: null, candidates: const [], rawText: text);

    final sorted = scores.entries.toList()
      ..sort((a, b) {
        final c = b.value.compareTo(a.value);
        return c != 0 ? c : b.key.compareTo(a.key);
      });

    final candidates = [for (final e in sorted.take(6)) e.key];
    return OcrResult(bestAmount: candidates.first, candidates: candidates, rawText: text);
  }
}

/// Dịch vụ nhận diện chữ & số trực tiếp trên thiết bị (On-Device Google ML Kit).
class OcrService {
  static bool get isSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static Future<OcrResult?> scanImagePath(String path) async {
    if (!isSupported) return null;
    if (!File(path).existsSync()) {
      throw Exception('Không tìm thấy tệp ảnh trên thiết bị');
    }
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final input = InputImage.fromFilePath(path);
      final recognized = await recognizer.processImage(input);
      return OcrNumberParser.parseReceiptText(recognized.text);
    } finally {
      await recognizer.close();
    }
  }

  /// Quét ảnh từ dữ liệu bytes (dùng cho ảnh đã lưu sẵn trên máy khi sửa giao dịch).
  static Future<OcrResult?> scanImageBytes(Uint8List bytes) async {
    if (!isSupported || bytes.isEmpty) return null;
    final tmp = File('${Directory.systemTemp.path}${Platform.pathSeparator}ocr_${DateTime.now().microsecondsSinceEpoch}.jpg');
    try {
      await tmp.writeAsBytes(bytes, flush: true);
      return await scanImagePath(tmp.path);
    } finally {
      if (tmp.existsSync()) {
        try {
          tmp.deleteSync();
        } catch (_) {}
      }
    }
  }
}
