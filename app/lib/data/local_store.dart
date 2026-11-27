import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import 'file_store.dart';

/// Tên bảng đồng bộ (khớp SyncService.Entities phía server).
class E {
  static const appSettings = 'appSettings';
  static const currencies = 'currencies';
  static const exchangeRates = 'exchangeRates';
  static const accounts = 'accounts';
  static const categories = 'categories';
  static const savingsJars = 'savingsJars';
  static const plans = 'plans';
  static const events = 'events';
  static const eventParticipants = 'eventParticipants';
  static const eventPhotos = 'eventPhotos';
  static const eventItems = 'eventItems';
  static const recurringRules = 'recurringRules';
  static const transactions = 'transactions';
  static const jarTransactions = 'jarTransactions';
  static const budgets = 'budgets';
  static const attachments = 'attachments';
  static const priceTables = 'electricityPriceTables';
  static const tiers = 'electricityTiers';
  static const meters = 'electricityMeters';
  static const bills = 'electricityBills';
  static const loveCounters = 'loveCounters';
  static const cycleSettings = 'cycleSettings';
  static const cyclePeriods = 'cyclePeriods';
  static const cycleLogs = 'cycleLogs';
  static const reminders = 'reminders';

  /// Thứ tự đẩy lên server (bảng cha trước).
  static const pushOrder = [
    appSettings,
    currencies,
    exchangeRates,
    accounts,
    categories,
    savingsJars,
    plans,
    events,
    eventPhotos,
    eventItems,
    recurringRules,
    transactions,
    jarTransactions,
    budgets,
    attachments,
    priceTables,
    tiers,
    meters,
    bills,
    loveCounters,
    cycleSettings,
    cyclePeriods,
    cycleLogs,
    reminders,
  ];

  /// Bảng chỉ đọc từ server.
  static const pullOnly = {eventParticipants};
}

const _uuid = Uuid();
String newId() => _uuid.v7();

/// Kho dữ liệu trên máy (offline-first). Mọi màn hình đọc/ghi ở đây; SyncEngine lo đẩy lên server.
///  - records: dữ liệu (JSON) theo "bảng|id"
///  - dirty:   bản ghi đã sửa chưa đồng bộ (giá trị = số lần thử lỗi)
///  - files:   ảnh chụp/chọn chưa upload → nội dung nằm trong FileStore (file trên đĩa / IndexedDB, KHÔNG nạp vào RAM),
///             ở đây chỉ giữ mô tả (file_meta). Upload xong thì xoá (dọn cache)
///  - outbox:  hàng đợi bài viết / tin nhắn soạn lúc offline
///  - meta:    token, mốc đồng bộ, cài đặt máy
class LocalStore extends ChangeNotifier {
  /// Tăng mỗi khi dữ liệu thay đổi — dùng để biết khi nào cần dựng lại các chỉ mục/bộ đệm.
  int version = 0;

  /// Phiên bản riêng từng bảng: thêm 1 giao dịch thì chỉ phần tính toán liên quan giao dịch phải làm lại,
  /// lịch trình / danh mục / tài khoản… giữ nguyên kết quả đã tính.
  final _entityVer = <String, int>{};
  int _epoch = 0; // tăng khi xoá sạch dữ liệu
  int entityVersion(String entity) => (_entityVer[entity] ?? 0) + _epoch * 1000000;
  void _bump(String entity) => _entityVer[entity] = (_entityVer[entity] ?? 0) + 1;

  /// Khoá phiên bản cho nhiều bảng (dùng làm khoá bộ đệm).
  String versionKey(List<String> entities) => '${identityHashCode(this)}:${entities.map(entityVersion).join(',')}';

  @override
  void notifyListeners() {
    version++;
    super.notifyListeners();
  }

  late Box<String> _records;
  late Box<int> _dirty;
  late Box<String> _meta;
  late FileStore _blobs;

  /// Ảnh vừa chọn đang được ghi xuống đĩa (vài trăm ms) — giữ tạm để hiển thị/tải lên ngay, ghi xong thì bỏ.
  final Map<String, Uint8List> _writing = {};
  final Map<String, Future<void>> _writes = {};
  late Box<String> _fileMeta; // ảnh chờ tải lên
  late Box<String> _localFiles; // ảnh đã có trong tệp trên máy (đã tải lên hoặc tải về) — id → "mime|thời điểm lưu (ms)"
  late Box<String> _outbox;

  final Map<String, Map<String, Map<String, dynamic>>> _cache = {};

  /// Gọi khi có thay đổi local cần đồng bộ (SyncEngine đăng ký).
  VoidCallback? onLocalChange;

  Future<void> init() async {
    await Hive.initFlutter('lht_money');
    await _open();
  }

  /// Dùng trong test: Hive.init(path) đã được gọi trước.
  @visibleForTesting
  Future<void> initForTest({String? filesDir}) => _open(filesDir: filesDir);

  Future<void> _open({String? filesDir}) async {
    _records = await Hive.openBox<String>('records');
    _dirty = await Hive.openBox<int>('dirty');
    _meta = await Hive.openBox<String>('meta');
    _blobs = await FileStore.open(dir: filesDir);
    _fileMeta = await Hive.openBox<String>('file_meta');
    _localFiles = await Hive.openBox<String>('local_files');
    _outbox = await Hive.openBox<String>('outbox');
    await _migrateOldFilesBox();
    for (final key in _records.keys.cast<String>()) {
      final i = key.indexOf('|');
      final entity = key.substring(0, i);
      _cache.putIfAbsent(entity, () => {})[key.substring(i + 1)] = jsonDecode(_records.get(key)!) as Map<String, dynamic>;
    }
  }

  /// Bản cũ để nội dung ảnh trong Hive box 'files' (nạp hết vào RAM khi mở app) → chuyển sang FileStore một lần rồi xoá box.
  Future<void> _migrateOldFilesBox() async {
    try {
      if (!await Hive.boxExists('files')) return;
      final old = await Hive.openBox<Uint8List>('files');
      for (final id in old.keys.cast<String>().toList()) {
        final b = old.get(id);
        if (b != null) await _blobs.write(id, b);
      }
      await old.deleteFromDisk();
    } catch (e) {
      debugPrint('Chuyển kho ảnh cũ lỗi: $e'); // lần mở sau thử lại, không chặn app
    }
  }

  // ------------------------------------------------------------------ Đọc

  List<Map<String, dynamic>> all(String entity, {bool includeDeleted = false}) {
    final m = _cache[entity];
    if (m == null) return [];
    return includeDeleted ? m.values.toList() : m.values.where((r) => r['deletedAt'] == null).toList();
  }

  Map<String, dynamic>? get(String entity, String? id) {
    if (id == null) return null;
    final r = _cache[entity]?[id];
    return r == null || r['deletedAt'] != null ? null : r;
  }

  bool isDirty(String entity, String id) => _dirty.containsKey('$entity|$id');
  int get pendingCount => _dirty.length + _fileMeta.length + _outbox.length;

  // ------------------------------------------------------------------ Ghi

  /// Thêm/sửa bản ghi (đánh dấu cần đồng bộ). Trả về bản ghi đã lưu.
  /// [localOnly] = chỉ lưu trên máy, không bao giờ tự đẩy lên server (kể cả khi sửa sau này) cho tới khi gọi [promoteLocalOnly].
  Map<String, dynamic> put(String entity, Map<String, dynamic> data, {bool notify = true, bool localOnly = false}) {
    final now = DateTime.now().toUtc().toIso8601String();
    final id = (data['id'] as String?) ?? newId();
    final existing = _cache[entity]?[id];
    final rec = <String, dynamic>{...?existing, ...data, 'id': id, 'updatedAt': now};
    rec['createdAt'] ??= now;
    if (localOnly) rec[kLocalOnly] = true;
    _write(entity, rec);
    if (rec[kLocalOnly] == true) {
      if (notify) notifyListeners();
      return rec;
    }
    _dirty.put('$entity|$id', 0);
    _unmarkSeed('$entity|$id');
    if (notify) _changed();
    return rec;
  }

  /// Báo thay đổi sau một loạt put(notify: false).
  void commit() => _changed();

  void putAll(String entity, Iterable<Map<String, dynamic>> items) {
    for (final i in items) {
      put(entity, i, notify: false);
    }
    _changed();
  }

  /// Xoá mềm (đồng bộ việc xoá lên server).
  /// [notify] = false: ghi ngay nhưng chưa báo (gọi [commit] sau), như [put].
  void remove(String entity, String id, {bool notify = true}) {
    final existing = _cache[entity]?[id];
    if (existing == null) return;
    put(entity, {...existing, 'deletedAt': DateTime.now().toUtc().toIso8601String()}, notify: notify);
    // Tự động xoá mềm các bản ghi con đính kèm ảnh
    if (entity == E.transactions) {
      final atts = all(E.attachments).where((a) => a['ownerId'] == id).toList();
      for (final a in atts) {
        remove(E.attachments, a['id'] as String, notify: notify);
      }
    } else if (entity == E.events) {
      final photos = all(E.eventPhotos).where((p) => p['eventId'] == id).toList();
      for (final p in photos) {
        remove(E.eventPhotos, p['id'] as String, notify: notify);
      }
    }
  }

  void _write(String entity, Map<String, dynamic> rec) {
    _bump(entity);
    _cache.putIfAbsent(entity, () => {})[rec['id'] as String] = rec;
    _records.put('$entity|${rec['id']}', jsonEncode(rec));
  }

  void _changed() {
    notifyListeners();
    onLocalChange?.call();
  }

  // ------------------------------------------------------------------ Đồng bộ

  /// Đếm nhanh số bản ghi chờ đẩy (không dựng danh sách), tuỳ chọn bỏ qua dữ liệu chu kỳ.
  int dirtyCount({bool includeCycle = true}) {
    if (includeCycle) return _dirty.length;
    var n = 0;
    for (final k in _dirty.keys) {
      if (!(k as String).startsWith('cycle')) n++;
    }
    return n;
  }

  /// Danh sách thay đổi chờ đẩy lên, theo thứ tự phụ thuộc.
  List<({String entity, Map<String, dynamic> data})> dirtyRecords() {
    final out = <({String entity, Map<String, dynamic> data})>[];
    final byEntity = <String, List<String>>{};
    for (final k in _dirty.keys.cast<String>()) {
      final i = k.indexOf('|');
      (byEntity[k.substring(0, i)] ??= []).add(k.substring(i + 1));
    }
    for (final entity in E.pushOrder) {
      for (final id in byEntity[entity] ?? const <String>[]) {
        final rec = _cache[entity]?[id];
        if (rec != null) out.add((entity: entity, data: rec));
      }
    }
    return out;
  }

  void markSynced(String entity, String id) => _dirty.delete('$entity|$id');

  // ------------------------------------------------------------------ Chỉ lưu trên máy

  /// Trường đánh dấu bản ghi chỉ lưu trên máy (không gửi lên server; trường bắt đầu bằng "_" cũng bị lọc khi đẩy).
  static const kLocalOnly = '_localOnly';

  /// Số bản ghi (chưa xoá) đang chỉ lưu trên máy, theo bảng.
  Map<String, int> localOnlyCounts() {
    final out = <String, int>{};
    for (final e in _cache.entries) {
      final n = e.value.values.where((r) => r[kLocalOnly] == true && r['deletedAt'] == null).length;
      if (n > 0) out[e.key] = n;
    }
    return out;
  }

  /// Đưa mọi bản ghi "chỉ lưu trên máy" vào hàng đợi đồng bộ, kèm ảnh của chúng (xếp hàng tải lên).
  void promoteLocalOnly() {
    final files = <String>{};
    for (final entity in E.pushOrder) {
      for (final rec in (_cache[entity]?.values ?? const <Map<String, dynamic>>[]).where((r) => r[kLocalOnly] == true).toList()) {
        final copy = {...rec}..remove(kLocalOnly);
        _write(entity, copy);
        _dirty.put('$entity|${copy['id']}', 0);
        if (copy['deletedAt'] == null) {
          for (final e in copy.entries) {
            if (e.value is String && (e.key == 'fileId' || e.key.endsWith('FileId'))) files.add(e.value as String);
          }
        }
      }
    }
    files.forEach(queueUpload);
    _changed();
  }

  /// Xếp hàng tải lên một ảnh đã có trong tệp trên máy.
  void queueUpload(String id) {
    final local = _localFiles.get(id);
    if (local == null || _fileMeta.containsKey(id)) return;
    final mime = local.split('|').first;
    _fileMeta.put(id, jsonEncode({'mime': mime, 'name': mime == 'image/png' ? 'photo.png' : 'photo.jpg'}));
  }

  /// Có bản ghi [id] trên máy không (kể cả đã xoá).
  bool exists(String entity, String id) => _cache[entity]?.containsKey(id) ?? false;

  /// Lưu ảnh vào tệp trên máy mà KHÔNG xếp hàng tải lên (dữ liệu chỉ lưu trên máy).
  Future<void> saveLocalFile(String id, Uint8List bytes, String mime) => saveDownloadedFile(id, bytes, mime);

  /// Bản ghi bị server từ chối: thử lại tối đa 5 lần rồi bỏ cờ.
  void markRejected(String entity, String id, String reason) {
    final key = '$entity|$id';
    if (reason == 'conflict' || reason == 'forbidden') {
      // Server đã có bản khác → bỏ bản local, lần pull tới sẽ lấy bản server.
      _dirty.delete(key);
      _cache[entity]?.remove(id);
      _bump(entity);
      _records.delete(key);
      return;
    }
    final tries = (_dirty.get(key) ?? 0) + 1;
    if (tries >= 5) {
      _dirty.delete(key);
    } else {
      _dirty.put(key, tries);
    }
  }

  /// Ghi dữ liệu từ server. Bỏ qua nếu local đang có sửa đổi chưa đẩy lên.
  void applyRemote(String entity, Map<String, dynamic> data) {
    final id = data['id'] as String;
    if (_dirty.containsKey('$entity|$id')) return;
    // Server trả về đúng bản máy vừa đẩy lên (chỉ khác mốc thời gian / định dạng) → giữ nguyên, KHÔNG tăng phiên bản bảng:
    // tránh mọi màn tính lại lần nữa vài giây sau mỗi lần lưu.
    final cur = _cache[entity]?[id];
    if (cur != null && sameContent(cur, data)) return;
    _write(entity, data);
  }

  static const _ignoredOnCompare = {'updatedAt', 'createdAt', 'userId'};

  /// [remote] có cùng nội dung với [local] không (bỏ qua mốc thời gian, `userId`; số so theo giá trị, ngày giờ so theo thời điểm).
  /// Trường chỉ có ở máy (vd `accountName`) không tính.
  @visibleForTesting
  static bool sameContent(Map<String, dynamic> local, Map<String, dynamic> remote) {
    for (final e in remote.entries) {
      if (_ignoredOnCompare.contains(e.key)) continue;
      if (!_sameValue(local[e.key], e.value)) return false;
    }
    return true;
  }

  static bool _sameValue(Object? a, Object? b) {
    if (a == b) return true;
    if (a is num && b is num) return a.toDouble() == b.toDouble();
    if (a is String && b is String && a.length >= 19 && b.length >= 19 && a[4] == '-' && b[4] == '-') {
      final da = DateTime.tryParse(a), db = DateTime.tryParse(b);
      return da != null && db != null && da.isAtSameMomentAs(db);
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_sameValue(a[i], b[i])) return false;
      }
      return true;
    }
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final k in b.keys) {
        if (!_sameValue(a[k], b[k])) return false;
      }
      return true;
    }
    return false;
  }

  void notifyRemoteApplied() => notifyListeners();

  // ------------------------------------------------------------------ Seed

  Set<String> get _seedKeys => (jsonDecode(_meta.get('seedKeys') ?? '[]') as List).cast<String>().toSet();

  void markSeed(Iterable<String> keys) => _meta.put('seedKeys', jsonEncode({..._seedKeys, ...keys}.toList()));

  void _unmarkSeed(String key) {
    final s = _seedKeys;
    if (s.remove(key)) _meta.put('seedKeys', jsonEncode(s.toList()));
  }

  /// Xoá dữ liệu mặc định chưa sửa (khi đăng nhập vào tài khoản đã có dữ liệu trên server).
  void dropUntouchedSeeds() {
    for (final key in _seedKeys) {
      final i = key.indexOf('|');
      _cache[key.substring(0, i)]?.remove(key.substring(i + 1));
      _bump(key.substring(0, i));
      _records.delete(key);
      _dirty.delete(key);
    }
    _meta.delete('seedKeys');
  }

  /// Xoá toàn bộ dữ liệu người dùng trên máy (đăng xuất).
  Future<void> wipe() async {
    _cache.clear();
    _epoch++;
    await _records.clear();
    await _dirty.clear();
    _writing.clear();
    await _blobs.clear();
    await _fileMeta.clear();
    await _localFiles.clear();
    await _outbox.clear();
    for (final k in _meta.keys.cast<String>().where((k) => k != 'apiUrl').toList()) {
      await _meta.delete(k);
    }
    notifyListeners();
  }

  // ------------------------------------------------------------------ Meta

  String? meta(String key) => _meta.get(key);
  void setMeta(String key, String? value) => value == null ? _meta.delete(key) : _meta.put(key, value);

  // ------------------------------------------------------------------ File ảnh

  /// Lưu ảnh mới (chưa upload) và xếp hàng upload. Trả về fileId dùng ngay được.
  /// Nội dung ghi xuống đĩa (FileStore), không giữ trong RAM.
  String addFile(Uint8List bytes, String mime, {String? name}) {
    final id = newId();
    _writing[id] = bytes;
    _fileMeta.put(id, jsonEncode({'mime': mime, 'name': name ?? 'photo.jpg'}));
    _writes[id] = _blobs.write(id, bytes).whenComplete(() {
      _writing.remove(id);
      _writes.remove(id);
      onLocalChange?.call(); // ghi xong mới báo đồng bộ → lúc upload chắc chắn đọc được file
    });
    return id;
  }

  /// Ảnh này có bản trong tệp trên máy không (chờ tải lên, đã tải lên hoặc đã tải về).
  /// Không đọc nội dung → rẻ, gọi trong build() thoải mái.
  bool hasLocalFile(String? id) => id != null && (_fileMeta.containsKey(id) || _localFiles.containsKey(id));

  /// Số ảnh đang lưu trong tệp trên máy.
  int get localFileCount => _localFiles.length + _fileMeta.length;

  /// Đọc nội dung ảnh trên máy (từ đĩa / IndexedDB), null nếu không có.
  Future<Uint8List?> readFile(String id) async => _writing[id] ?? await _blobs.read(id);

  List<({String id, String mime, String name})> pendingUploads() => [
    for (final id in _fileMeta.keys.cast<String>())
      if (jsonDecode(_fileMeta.get(id)!) as Map case final m) (id: id, mime: m['mime'] as String, name: m['name'] as String),
  ];

  /// Upload xong: bỏ khỏi hàng đợi nhưng GIỮ tệp trên máy (xem được khi không có mạng).
  /// [missing] = ảnh đã mất trên máy (không còn gì để tải) → chỉ bỏ khỏi hàng đợi, tránh kẹt mãi.
  Future<void> fileUploaded(String id, {bool missing = false}) async {
    await _writes[id]; // còn đang ghi thì đợi xong
    final m = _fileMeta.get(id);
    await _fileMeta.delete(id);
    if (missing) {
      await _blobs.delete(id);
    } else {
      await _localFiles.put(id, '${m == null ? 'image/jpeg' : (jsonDecode(m) as Map)['mime']}|${DateTime.now().millisecondsSinceEpoch}');
    }
    notifyListeners();
  }

  /// Ảnh tải về từ server → lưu vào tệp trên máy.
  Future<void> saveDownloadedFile(String id, Uint8List bytes, String mime) async {
    await _blobs.write(id, bytes);
    await _localFiles.put(id, '$mime|${DateTime.now().millisecondsSinceEpoch}');
  }

  /// Các ảnh dữ liệu cá nhân đang dùng: mọi trường "fileId" / "...FileId" của bản ghi chưa xoá.
  Set<String> referencedFileIds() {
    // Chỉ quét lại khi dữ liệu đổi (phiên bản các bảng chỉ tăng) → lượt đồng bộ định kỳ không tốn CPU.
    final sig = _epoch * 1000000 + _entityVer.values.fold<int>(0, (a, b) => a + b);
    if (sig == _refSig) return _refCache;
    final out = <String>{};
    for (final entry in _cache.entries) {
      final entityName = entry.key;
      for (final rec in entry.value.values) {
        if (rec['deletedAt'] != null) continue;
        if (entityName == E.attachments) {
          final ownerId = rec['ownerId'] as String?;
          final ownerType = rec['ownerType'] as int?;
          if (ownerType == 1 && ownerId != null) {
            final tx = get(E.transactions, ownerId);
            if (tx == null) continue;
          }
        } else if (entityName == E.eventPhotos) {
          final eventId = rec['eventId'] as String?;
          if (eventId != null) {
            final ev = get(E.events, eventId);
            if (ev == null) continue;
          }
        }
        for (final e in rec.entries) {
          if (e.value is String && (e.key == 'fileId' || e.key.endsWith('FileId'))) out.add(e.value as String);
        }
      }
    }
    _refSig = sig;
    return _refCache = out;
  }

  int _refSig = -1;
  Set<String> _refCache = const {};

  /// Ảnh cần tải về: đang được dùng nhưng chưa có trong tệp trên máy.
  List<String> missingFiles() => [
    for (final id in referencedFileIds())
      if (!hasLocalFile(id)) id,
  ];

  /// Danh sách fileId cần tải về theo thứ tự ưu tiên:
  /// 1. Ảnh của các giao dịch trong 60 ngày gần nhất (tháng này và tháng trước để lướt lịch mượt 100%).
  /// 2. Toàn bộ các ảnh còn lại.
  List<String> prioritizedMissingFiles() {
    final missing = missingFiles().toSet();
    if (missing.isEmpty) return const [];

    final priority = <String>[];
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: 60));

    // 1. Ảnh của các giao dịch gần đây (cho Lịch giao dịch)
    for (final a in all(E.attachments)) {
      final fid = a['fileId'] as String?;
      if (fid != null && missing.contains(fid)) {
        final tx = get(E.transactions, a['ownerId'] as String? ?? '');
        if (tx != null) {
          final date = DateTime.tryParse(tx['occurredAt'] as String? ?? '');
          if (date != null && date.isAfter(cutoff)) {
            priority.add(fid);
            missing.remove(fid);
          }
        }
      }
    }

    // 2. Các ảnh còn lại
    priority.addAll(missing);
    return priority;
  }

  /// Xoá tệp ảnh không còn bản ghi nào dùng (bản ghi đã xoá). Ảnh chờ tải lên luôn được giữ.
  Future<void> pruneLocalFiles({bool immediate = true}) async {
    final used = referencedFileIds();
    // Dọn ngay các ảnh không còn bản ghi nào tham chiếu (vd giao dịch đã xoá) — TRỪ ảnh mới lưu trong [_freshGrace]:
    // ảnh vừa chọn trong form (chưa bấm Lưu nên chưa có bản ghi dùng) có thể đã được đồng bộ tải lên giữa chừng;
    // xoá nó lúc này sẽ làm ảnh biến mất khỏi form (nhất là khi offline).
    final cutoff = DateTime.now().subtract(immediate ? _freshGrace : const Duration(minutes: 30)).millisecondsSinceEpoch;
    for (final id in _localFiles.keys.cast<String>().toList()) {
      if (_fileMeta.containsKey(id)) continue; // ảnh đang chờ upload luôn giữ
      final at = int.tryParse(_localFiles.get(id)!.split('|').last) ?? 0;
      if (!used.contains(id) && at < cutoff) {
        await _localFiles.delete(id);
        await _blobs.delete(id);
      }
    }
  }

  /// Ảnh mới lưu trong khoảng này chưa bị dọn dù chưa có bản ghi nào dùng (đang nằm trong form chưa bấm Lưu).
  static const _freshGrace = Duration(minutes: 10);

  /// Có lưu ảnh ngoại tuyến trên máy không (mặc định false: chỉ dùng server để tiết kiệm dung lượng).
  bool get offlineImages => meta('offlineImages') == 'true';
  void setOfflineImages(bool enable) {
    setMeta('offlineImages', enable ? 'true' : 'false');
    notifyListeners();
  }

  /// Dọn sạch toàn bộ ảnh đã lưu trong máy (chỉ giữ lại ảnh mới tạo đang chờ tải lên server).
  Future<void> clearDownloadedFiles() async {
    for (final id in _localFiles.keys.cast<String>().toList()) {
      if (_fileMeta.containsKey(id)) continue;
      await _localFiles.delete(id);
      await _blobs.delete(id);
    }
    notifyListeners();
  }

  // ------------------------------------------------------------------ Outbox (bài viết/tin nhắn offline)

  void enqueue(String kind, Map<String, dynamic> payload) {
    final id = payload['id'] as String? ?? newId();
    _outbox.put(id, jsonEncode({'kind': kind, 'payload': payload}));
    notifyListeners();
    onLocalChange?.call();
  }

  List<({String id, String kind, Map<String, dynamic> payload})> outbox() => [
    for (final k in _outbox.keys.cast<String>())
      () {
        final m = jsonDecode(_outbox.get(k)!) as Map<String, dynamic>;
        return (id: k, kind: m['kind'] as String, payload: m['payload'] as Map<String, dynamic>);
      }(),
  ];

  void dequeue(String id) {
    _outbox.delete(id);
    notifyListeners();
  }
}
