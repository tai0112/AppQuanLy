import 'dart:convert';
import 'dart:typed_data';

/// Bộ đọc tệp SQLite tối giản, viết bằng Dart thuần (chạy được cả trên web), CHỈ ĐỌC.
/// Hỗ trợ bảng rowid thường (b-tree bảng, trang tràn, mã hoá UTF-8) — đủ để đọc bản sao lưu của app khác.
/// Không hỗ trợ bảng WITHOUT ROWID, UTF-16, tệp WAL chưa gộp.
class SqliteReader {
  SqliteReader(this._b) {
    if (_b.length < 100 || utf8.decode(_b.sublist(0, 15), allowMalformed: true) != 'SQLite format 3') {
      throw const FormatException('Không phải tệp SQLite');
    }
    final ps = _u16(16);
    _pageSize = ps == 1 ? 65536 : ps;
    _usable = _pageSize - _b[20];
    if (_u32(56) > 1) throw const FormatException('Chỉ hỗ trợ SQLite mã hoá UTF-8');
    _loadSchema();
  }

  final Uint8List _b;
  late final int _pageSize;
  late final int _usable;
  final _tables = <String, ({int root, List<String> cols, int? rowidCol})>{};

  Iterable<String> get tables => _tables.keys;

  /// Đọc mọi dòng của [table] thành map tên cột → giá trị (int / double / String / Uint8List / null).
  List<Map<String, Object?>> rows(String table) {
    final t = _tables[table];
    if (t == null) return const [];
    final out = <Map<String, Object?>>[];
    _walk(t.root, (rowid, values) {
      final m = <String, Object?>{};
      for (var i = 0; i < t.cols.length; i++) {
        m[t.cols[i]] = i == t.rowidCol ? rowid : (i < values.length ? values[i] : null);
      }
      out.add(m);
    });
    return out;
  }

  // ---------------------------------------------------------------- Lược đồ

  void _loadSchema() {
    _walk(1, (_, v) {
      if (v.length < 5 || v[0] != 'table' || v[3] is! int || v[4] is! String) return;
      final sql = v[4] as String;
      if (RegExp(r'WITHOUT\s+ROWID', caseSensitive: false).hasMatch(sql)) return;
      final (cols, rowidCol) = _columns(sql);
      _tables[v[1] as String] = (root: v[3] as int, cols: cols, rowidCol: rowidCol);
    });
  }

  /// Tên cột từ câu CREATE TABLE; cột "INTEGER PRIMARY KEY" là bí danh của rowid.
  static (List<String>, int?) _columns(String sql) {
    final start = sql.indexOf('('), end = sql.lastIndexOf(')');
    if (start < 0 || end <= start) return (const [], null);
    final body = sql.substring(start + 1, end);
    final parts = <String>[];
    var depth = 0, from = 0;
    for (var i = 0; i < body.length; i++) {
      final c = body[i];
      if (c == '(') depth++;
      if (c == ')') depth--;
      if (c == ',' && depth == 0) {
        parts.add(body.substring(from, i));
        from = i + 1;
      }
    }
    parts.add(body.substring(from));
    final cols = <String>[];
    int? rowidCol;
    const constraints = {'PRIMARY', 'UNIQUE', 'CHECK', 'FOREIGN', 'CONSTRAINT'};
    for (final raw in parts) {
      final p = raw.trim();
      if (p.isEmpty) continue;
      final first = p.split(RegExp(r'\s+')).first;
      if (constraints.contains(first.toUpperCase())) continue;
      cols.add(first.replaceAll(RegExp(r'^[`"\[]|[`"\]]$'), ''));
      if (RegExp(r'^\S+\s+INTEGER\s+PRIMARY\s+KEY', caseSensitive: false).hasMatch(p)) rowidCol = cols.length - 1;
    }
    return (cols, rowidCol);
  }

  // ---------------------------------------------------------------- B-tree

  void _walk(int page, void Function(int rowid, List<Object?> values) onRow) {
    final stack = [page];
    var guard = 0;
    while (stack.isNotEmpty) {
      if (++guard > 1000000) throw const FormatException('Tệp SQLite hỏng');
      final p = stack.removeLast();
      final base = (p - 1) * _pageSize;
      final h = p == 1 ? base + 100 : base;
      final type = _b[h];
      final cells = _u16(h + 3);
      if (type == 0x05) {
        // Trang trong: duyệt con theo thứ tự (đẩy ngược vào ngăn xếp).
        final children = <int>[for (var i = 0; i < cells; i++) _u32(base + _u16(h + 12 + i * 2)), _u32(h + 8)];
        stack.addAll(children.reversed);
      } else if (type == 0x0D) {
        for (var i = 0; i < cells; i++) {
          var off = base + _u16(h + 8 + i * 2);
          final (size, n1) = _varint(off);
          off += n1;
          final (rowid, n2) = _varint(off);
          off += n2;
          onRow(rowid, _record(_payload(off, size)));
        }
      } else {
        throw FormatException('Trang SQLite lạ ($type)');
      }
    }
  }

  /// Nội dung một ô lá, ghép cả phần nằm ở các trang tràn.
  Uint8List _payload(int off, int size) {
    final x = _usable - 35;
    if (size <= x) return Uint8List.sublistView(_b, off, off + size);
    final m = ((_usable - 12) * 32 ~/ 255) - 23;
    final k = m + ((size - m) % (_usable - 4));
    final local = k <= x ? k : m;
    final out = BytesBuilder(copy: false)..add(Uint8List.sublistView(_b, off, off + local));
    var next = _u32(off + local);
    var left = size - local;
    while (next != 0 && left > 0) {
      final base = (next - 1) * _pageSize;
      final take = left < _usable - 4 ? left : _usable - 4;
      out.add(Uint8List.sublistView(_b, base + 4, base + 4 + take));
      left -= take;
      next = _u32(base);
    }
    return out.takeBytes();
  }

  List<Object?> _record(Uint8List r) {
    final bd = ByteData.sublistView(r);
    final (hdr, n0) = _varintIn(r, 0);
    var hp = n0, dp = hdr;
    final out = <Object?>[];
    while (hp < hdr) {
      final (t, n) = _varintIn(r, hp);
      hp += n;
      switch (t) {
        case 0:
          out.add(null);
        case >= 1 && <= 6:
          final len = const [0, 1, 2, 3, 4, 6, 8][t];
          // Dùng phép nhân thay cho dịch bit: trên web phép dịch bị cắt còn 32 bit.
          var v = 0;
          for (var i = 0; i < len; i++) {
            v = v * 256 + r[dp + i];
          }
          if ((r[dp] & 0x80) != 0) v -= _pow256[len]; // số âm (bù hai)
          out.add(v);
          dp += len;
        case 7:
          out.add(bd.getFloat64(dp));
          dp += 8;
        case 8:
          out.add(0);
        case 9:
          out.add(1);
        default:
          final len = (t - (t.isEven ? 12 : 13)) ~/ 2;
          final bytes = Uint8List.sublistView(r, dp, dp + len);
          out.add(t.isEven ? Uint8List.fromList(bytes) : utf8.decode(bytes, allowMalformed: true));
          dp += len;
      }
    }
    return out;
  }

  // ---------------------------------------------------------------- Số

  static const _pow256 = [1, 256, 65536, 16777216, 4294967296, 1099511627776, 281474976710656, 72057594037927936, 0];

  int _u16(int o) => _b[o] * 256 + _b[o + 1];
  int _u32(int o) => ((_b[o] * 256 + _b[o + 1]) * 256 + _b[o + 2]) * 256 + _b[o + 3];
  (int, int) _varint(int o) => _varintIn(_b, o);

  static (int, int) _varintIn(Uint8List b, int o) {
    var v = 0;
    for (var i = 0; i < 8; i++) {
      final c = b[o + i];
      v = v * 128 + (c & 0x7F);
      if (c < 0x80) return (v, i + 1);
    }
    return (v * 256 + b[o + 8], 9);
  }
}
