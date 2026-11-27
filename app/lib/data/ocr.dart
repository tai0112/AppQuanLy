import 'dart:io' show Directory, File, Platform;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'receipt_reader.dart';

export 'receipt_reader.dart' show ReceiptKind;

/// Kết quả đọc ảnh hoá đơn / biên lai chuyển khoản (số tiền + thông tin kèm theo).
class OcrResult {
  const OcrResult({
    required this.bestAmount,
    required this.candidates,
    required this.rawText,
    this.kind = ReceiptKind.generic,
    this.date,
    this.note,
    this.merchant,
    this.categoryHint,
    this.isIncome = false,
  });
  final double? bestAmount;
  final List<double> candidates;
  final String rawText;
  final ReceiptKind kind;
  final DateTime? date;
  final String? note;
  final String? merchant;
  final String? categoryHint;
  final bool isIncome;
}

/// Phân tích văn bản OCR (xem [ReceiptReader] — nhận dạng loại chứng từ + nhiều kỹ năng đọc).
class OcrNumberParser {
  static OcrResult parseReceiptText(String text, {DateTime? now}) {
    final r = ReceiptReader.read(text, now: now);
    return OcrResult(
      bestAmount: r.amount,
      candidates: r.candidates,
      rawText: r.rawText,
      kind: r.kind,
      date: r.date,
      note: r.note,
      merchant: r.merchant,
      categoryHint: r.categoryHint,
      isIncome: r.isIncome,
    );
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
