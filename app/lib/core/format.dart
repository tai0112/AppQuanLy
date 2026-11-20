import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Định dạng tiền, ngày theo tiếng Việt.
class Fmt {
  static final _date = DateFormat('dd/MM/yyyy');
  static final _dateShort = DateFormat('dd/MM');
  static final _time = DateFormat('HH:mm');
  static final _month = DateFormat('MM/yyyy');

  static String money(num value, {String symbol = '₫', int decimals = 0, bool before = false, bool sign = false}) {
    final f = NumberFormat.decimalPatternDigits(locale: 'vi_VN', decimalDigits: decimals);
    final s = f.format(value.abs());
    final prefix = sign ? (value < 0 ? '-' : '+') : (value < 0 ? '-' : '');
    return before ? '$prefix$symbol$s' : '$prefix$s $symbol';
  }

  /// Rút gọn: 1,2tr · 350k
  static String compact(num value) {
    final v = value.abs();
    final sign = value < 0 ? '-' : '';
    if (v >= 1e9) return '$sign${(v / 1e9).toStringAsFixed(v >= 1e10 ? 0 : 1)}tỷ';
    if (v >= 1e6) return '$sign${(v / 1e6).toStringAsFixed(v >= 1e7 ? 0 : 1)}tr';
    if (v >= 1e3) return '$sign${(v / 1e3).toStringAsFixed(0)}k';
    return '$sign${v.toStringAsFixed(0)}';
  }

  /// Chuẩn hoá chuỗi để tìm kiếm: chữ thường, bỏ dấu tiếng Việt.
  static String fold(String s) {
    const from = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
    const to = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
    final b = StringBuffer();
    for (final ch in s.toLowerCase().split('')) {
      final k = from.indexOf(ch);
      b.write(k < 0 ? ch : to[k]);
    }
    return b.toString();
  }

  static String date(DateTime d) => _date.format(d);
  static String dateShort(DateTime d) => _dateShort.format(d);
  static String time(DateTime d) => _time.format(d);
  static String month(DateTime d) => _month.format(d);
  static String dateTime(DateTime d) => '${_time.format(d)} · ${_date.format(d)}';

  static const weekdays = ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ nhật'];
  static const weekdaysShort = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  static String dayHeader(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Hôm nay';
    if (diff == 1) return 'Hôm qua';
    if (diff == -1) return 'Ngày mai';
    return '${weekdays[d.weekday - 1]}, ${_date.format(d)}';
  }

  static String relative(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inSeconds < 60) return 'vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return _date.format(d);
  }

  /// Chuỗi ngày dạng yyyy-MM-dd (DateOnly của .NET).
  static String isoDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Hiển thị số trong ô nhập: 1250000 → "1.250.000", 12.5 → "12,5".
String amountText(num? v) {
  if (v == null) return '';
  final s = v == v.roundToDouble() ? v.round().toString() : v.toString().replaceAll('.', ',');
  return ThousandsInputFormatter.format(s);
}

/// Tự chèn dấu "." ngăn cách hàng nghìn khi gõ số tiền; dùng "," cho phần thập phân.
class ThousandsInputFormatter extends TextInputFormatter {
  const ThousandsInputFormatter();

  static String format(String raw) {
    var s = raw.replaceAll(RegExp(r'[^0-9,]'), '');
    final comma = s.indexOf(',');
    var intPart = comma < 0 ? s : s.substring(0, comma);
    final dec = comma < 0 ? null : s.substring(comma + 1).replaceAll(',', '');
    intPart = intPart.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    final buf = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buf.write('.');
      buf.write(intPart[i]);
    }
    if (dec != null) buf.write(',${dec.length > 4 ? dec.substring(0, 4) : dec}');
    return buf.toString();
  }

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text;
    final cursor = newValue.selection.baseOffset.clamp(0, text.length);
    // Bàn phím số chỉ có "." → dấu "." vừa gõ được hiểu là dấu thập phân.
    if (text.length == oldValue.text.length + 1 && cursor > 0 && text[cursor - 1] == '.' && !text.contains(',')) {
      text = '${text.substring(0, cursor - 1)},${text.substring(cursor)}';
    }
    // Giữ vị trí con trỏ theo số chữ số đứng trước nó.
    final digitsBefore = text.substring(0, cursor).replaceAll(RegExp(r'[^0-9,]'), '').length;
    final out = format(text);
    var pos = 0, seen = 0;
    while (pos < out.length && seen < digitsBefore) {
      if (out[pos] != '.') seen++;
      pos++;
    }
    return TextEditingValue(
      text: out,
      selection: TextSelection.collapsed(offset: pos),
    );
  }
}

/// Parse số tiền người dùng nhập ("1.250.000" hoặc "1250000,5").
double parseAmount(String text) {
  final cleaned = text.replaceAll('.', '').replaceAll(' ', '').replaceAll(',', '.');
  return double.tryParse(cleaned) ?? 0;
}
