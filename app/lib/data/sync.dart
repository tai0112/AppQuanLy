import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../core/config.dart';
import 'api.dart';
import 'local_store.dart';
import 'seed.dart';

enum SyncState { idle, syncing, offline, error, localOnly }

/// Đồng bộ offline-first:
///  1. Upload ảnh đang chờ → xoá bản local (dọn cache)
///  2. Đẩy bản ghi đã sửa (push) → bỏ cờ "dirty"
///  3. Gửi bài viết / tin nhắn soạn lúc offline (outbox)
///  4. Lấy thay đổi từ server (pull) theo mốc thời gian
/// Chạy khi: mở app, có mạng trở lại, sau khi sửa dữ liệu (chờ 1,5s), mỗi 60s, khi server báo SyncHint.
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

  void start() {
    store.onLocalChange = schedule;
    _timer = Timer.periodic(AppConfig.syncInterval, (_) => sync());
    _conn = Connectivity().onConnectivityChanged.listen((r) {
      if (r.any((x) => x != ConnectivityResult.none)) schedule(const Duration(milliseconds: 300));
    });
    sync();
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
    _debounce = Timer(delay, sync);
    notifyListeners();
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
      if (_again) {
        _again = false;
        schedule(const Duration(milliseconds: 200));
      }
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
      await store.fileUploaded(f.id); // mất file (không còn gì để tải) cũng bỏ khỏi hàng đợi, tránh kẹt mãi
    }
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
