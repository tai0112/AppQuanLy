// Chấm điểm bộ đọc hoá đơn trên bộ dữ liệu hoá đơn thật (văn bản OCR + nhãn tổng tiền).
// Dữ liệu KHÔNG nằm trong repo: đặt đường dẫn file JSON vào biến môi trường LHT_RECEIPT_BENCH
// (mỗi phần tử: {id, text, total, totals, seller, timestamp}). Không có file → bỏ qua.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lht_money/data/ocr.dart';

void main() {
  final path = Platform.environment['LHT_RECEIPT_BENCH'];
  final file = path == null ? null : File(path);

  test('độ chính xác đọc tổng tiền trên hoá đơn thật', () {
    final items = (jsonDecode(file!.readAsStringSync()) as List).cast<Map<String, dynamic>>();
    var best = 0, inCand = 0;
    final misses = <String>[];
    for (final it in items) {
      final total = (it['total'] as num).toDouble();
      final ok = (it['totals'] as List).map((e) => (e as num).toDouble()).toSet();
      final r = OcrNumberParser.parseReceiptText(it['text'] as String);
      if (r.bestAmount != null && ok.contains(r.bestAmount)) {
        best++;
      } else if (misses.length < 25) {
        misses.add('${it['id']}: đúng=$total, đọc=${r.bestAmount}, gợi ý=${r.candidates}');
      }
      if (r.candidates.any(ok.contains)) inCand++;
    }
    final n = items.length;
    // ignore: avoid_print
    print('HOÁ ĐƠN: $n · đúng tổng tiền ${(best * 100 / n).toStringAsFixed(1)}% · có trong gợi ý ${(inCand * 100 / n).toStringAsFixed(1)}%');
    // ignore: avoid_print
    print('SAI MẪU:\n${misses.join('\n')}');
  }, skip: file == null || !file.existsSync() ? 'chưa có dữ liệu chấm điểm (LHT_RECEIPT_BENCH)' : false);
}
