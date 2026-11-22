import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../core/config.dart';
import 'api.dart';
import 'local_store.dart';
import 'seed.dart';

enum SyncState { idle, syncing, offline, error, localOnly }

/// Đồng bộ offline-first:
///  1. Upload ảnh đang chờ (tệp ảnh vẫn giữ trên máy)
///  2. Đẩy bản ghi đã sửa (push) → bỏ cờ "dirty"
///  3. Gửi bài viết / tin nhắn soạn lúc offline (outbox)
///  4. Lấy thay đổi từ server (pull) theo mốc thời gian
///  5. Tải về các ảnh còn thiếu trên máy, dọn tệp ảnh không còn dùng
/// Tự động đồng bộ (mặc định bật, cài đặt riêng từng máy): chạy khi mở app, có mạng trở lại, sau khi sửa dữ liệu (chờ 1,5s),
/// mỗi 60s, khi server báo SyncHint. Tắt → dữ liệu chỉ lưu trên máy, chỉ đồng bộ khi người dùng bấm "Đồng bộ"
/// (bài viết / tin nhắn vẫn gửi ngay vì là chức năng trực tuyến).
class SyncEngine extends ChangeNotifier {
  SyncEngine(this.store, this.api);

  final LocalStore store;
  final ApiClient api;

  SyncState state = SyncState.idle;
  String? lastError;
  DateTime? lastSyncedAt;
  bool _running = false;
  bool _again = false;
  Timer? _debounce;
  Timer? _timer;
  StreamSubscription<List<ConnectivityResult>>? _conn;

  /// Phát sự kiện khi bài viết/tin nhắn trong outbox được gửi (để màn hình làm mới).
  final _sent = StreamController<({String kind, Map<String, dynamic> result})>.broadcast();
  Stream<({String kind, Map<String, dynamic> result})> get outboxSent => _sent.stream;

  /// Tự động đồng bộ (lưu riêng trên máy này).
  bool get autoSync => store.meta('autoSync') != '0';

  set autoSync(bool v) {
    store.setMeta('autoSync', v ? null : '0');
    notifyListeners();
    if (v) schedule(const Duration(milliseconds: 200));
  }

  /// Ảnh tải về trong lần đồng bộ đang chạy: (đã xong, tổng).
  (int, int)? fileProgress;

  void start() {
    store.onLocalChange = schedule;
    _timer = Timer.periodic(AppConfig.syncInterval, (_) => _autoRun());
    _conn = Connectivity().onConnectivityChanged.listen((r) {
      if (r.any((x) => x != ConnectivityResult.none)) schedule(const Duration(milliseconds: 300));
    });
    _autoRun();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _debounce?.cancel();
    _conn?.cancel();
    super.dispose();
  }

  void schedule([Duration delay = const Duration(milliseconds: 1500)]) {
    _debounce?.cancel();
    _debounce = Timer(delay, _autoRun);
    notifyListeners();
  }

  /// Lần chạy tự động: bật tự động đồng bộ → đồng bộ đủ; tắt → chỉ gửi bài viết / tin nhắn đang chờ.
  Future<void> _autoRun() async {
    if (autoSync) return sync();
    if (!api.isLoggedIn || _running || store.outbox().isEmpty) return;
    _running = true;
    try {
      await _sendOutbox();
    } catch (_) {
      // mất mạng → lần sau gửi tiếp
    } finally {
      _running = false;
      _runQueued();
    }
  }

  /// Có yêu cầu "Đồng bộ" đến lúc đang chạy → chạy lại đồng bộ ĐẦY ĐỦ (yêu cầu tường minh, không phụ thuộc tự động).
  void _runQueued() {
    if (!_again) return;
    _again = false;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), sync);
  }

  /// Số thay đổi chờ đồng bộ (không tính dữ liệu chu kỳ khi người dùng tắt đồng bộ chu kỳ).
  int get pending {
    final cycleOk = _cycleSyncEnabled;
    return store.dirtyCount(includeCycle: cycleOk) + store.pendingUploads().length + store.outbox().length;
  }

  bool get _cycleSyncEnabled => store.all(E.cycleSettings).any((s) => s['syncEnabled'] == true);

  Future<void> sync() async {
    if (!api.isLoggedIn) {
      _setState(SyncState.localOnly);
      return;
    }
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    _setState(SyncState.syncing);
    try {
      await _uploadFiles();
      await _push();
      await _sendOutbox();
      await _pull();
      await _downloadFiles();
      ensureActivityTemplates(store);
      ensureEventCategories(store); // tài khoản cũ chưa có danh mục lịch trình → tạo sau khi đã lấy dữ liệu server
      lastSyncedAt = DateTime.now();
      lastError = null;
      _setState(SyncState.idle);
    } on ApiException catch (e) {
      lastError = e.message;
      _setState(e.offline ? SyncState.offline : SyncState.error);
    } catch (e) {
      lastError = '$e';
      _setState(SyncState.error);
    } finally {
      _running = false;
      _runQueued();
    }
  }

  /// Lần đầu đăng nhập: lấy dữ liệu server trước; nếu tài khoản đã có dữ liệu thì bỏ dữ liệu mặc định chưa sửa trên máy.
  Future<void> firstSyncAfterLogin() async {
    store.setMeta('lastPulledAt', null);
    final res = await api.get<Map<String, dynamic>>('/sync/pull');
    final changes = (res['changes'] as Map<String, dynamic>? ?? {});
    if ((changes[E.categories] as List?)?.isNotEmpty == true) store.dropUntouchedSeeds();
    _apply(changes);
    store.setMeta('lastPulledAt', res['serverTime'] as String);
    await sync();
  }

  Future<void> _uploadFiles() async {
    for (final f in store.pendingUploads()) {
      // Đọc từng ảnh từ đĩa ngay lúc tải lên → mỗi lúc chỉ 1 ảnh nằm trong RAM.
      final bytes = await store.readFile(f.id);
      if (bytes != null) await api.upload(f.id, bytes, f.mime, f.name);
      await store.fileUploaded(f.id, missing: bytes == null); // mất file cũng bỏ khỏi hàng đợi, tránh kẹt mãi
    }
  }

  /// Tải về từng ảnh còn thiếu (mỗi lúc 1 ảnh trong RAM, ghi ngay xuống tệp), rồi dọn tệp ảnh không còn dùng.
  Future<void> _downloadFiles() async {
    final missing = store.missingFiles();
    final gone = (store.meta('goneFiles') ?? '').split(',').where((s) => s.isNotEmpty).toSet();
    final todo = missing.where((id) => !gone.contains(id)).toList();
    try {
      for (final (i, id) in todo.indexed) {
        fileProgress = (i, todo.length);
        notifyListeners();
        final f = await api.download(id);
        if (f == null) {
          gone.add(id); // server không còn ảnh này → không thử lại mỗi lần
        } else {
          await store.saveDownloadedFile(id, f.bytes, f.mime);
        }
      }
    } finally {
      fileProgress = null;
      store.setMeta('goneFiles', gone.isEmpty ? null : gone.join(','));
      if (todo.isNotEmpty) store.notifyRemoteApplied(); // ảnh đã có trên máy → màn hình chuyển sang đọc tệp
    }
    await store.pruneLocalFiles();
  }

  Future<void> _push() async {
    final cycleOk = _cycleSyncEnabled;
    final all = store.dirtyRecords().where((r) => cycleOk || !r.entity.startsWith('cycle')).toList();
    for (var i = 0; i < all.length; i += 200) {
      final chunk = all.sublist(i, i + 200 > all.length ? all.length : i + 200);
      final res = await api.post<Map<String, dynamic>>('/sync/push', {
        'changes': [
          for (final r in chunk) {'entity': r.entity, 'data': _clean(r.data)},
        ],
      });
      final accepted = (res['accepted'] as List).cast<String>().toSet();
      for (final r in chunk) {
        if (accepted.contains(r.data['id'])) store.markSynced(r.entity, r.data['id'] as String);
      }
      for (final rej in (res['rejected'] as List).cast<Map<String, dynamic>>()) {
        store.markRejected(rej['entity'] as String, rej['id'] as String, rej['reason'] as String);
      }
    }
  }

  /// Bỏ các trường chỉ dùng trên máy (bắt đầu bằng "_").
  Map<String, dynamic> _clean(Map<String, dynamic> m) => {
    for (final e in m.entries)
      if (!e.key.startsWith('_')) e.key: e.value,
  };

  Future<void> _sendOutbox() async {
    for (final item in store.outbox()) {
      try {
        final Map<String, dynamic> result;
        if (item.kind == 'post') {
          result = await api.post<Map<String, dynamic>>('/posts', item.payload);
        } else if (item.kind == 'message') {
          final p = Map<String, dynamic>.from(item.payload);
          final cid = p.remove('conversationId');
          result = await api.post<Map<String, dynamic>>('/conversations/$cid/messages', p);
        } else {
          result = {};
        }
        store.dequeue(item.id);
        _sent.add((kind: item.kind, result: result));
      } on ApiException catch (e) {
        if (e.offline) rethrow;
        store.dequeue(item.id); // lỗi nghiệp vụ (vd hết quyền) → bỏ, tránh kẹt hàng đợi
      }
    }
  }

  Future<void> _pull() async {
    final since = store.meta('lastPulledAt');
    final res = await api.get<Map<String, dynamic>>('/sync/pull', query: since == null ? null : {'since': since});
    _apply(res['changes'] as Map<String, dynamic>? ?? {});
    store.setMeta('lastPulledAt', res['serverTime'] as String);
  }

  void _apply(Map<String, dynamic> changes) {
    if (changes.isEmpty) return;
    for (final e in changes.entries) {
      for (final rec in (e.value as List).cast<Map<String, dynamic>>()) {
        store.applyRemote(e.key, rec);
      }
    }
    store.notifyRemoteApplied();
  }

  void _setState(SyncState s) {
    state = s;
    notifyListeners();
  }
}
