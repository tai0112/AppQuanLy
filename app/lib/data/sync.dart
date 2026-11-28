import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../core/config.dart';
import 'api.dart';
import 'local_store.dart';
import 'logic.dart';
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

  Future<void> sync({bool forceFull = false}) async {
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
      runDueRecurringRules(store);
      await _uploadFiles();
      await _push();
      await _sendOutbox();
      await _pull(forceFull: forceFull);
      _healOrphanTransactions();
      runDueRecurringRules(store);
      ensureActivityTemplates(store);
      ensureEventCategories(store); // tài khoản cũ chưa có danh mục lịch trình → tạo sau khi đã lấy dữ liệu server
      lastSyncedAt = DateTime.now();
      lastError = null;
      _setState(SyncState.idle);

      // Tải ảnh ngầm không chặn luồng đăng nhập hay đồng bộ dữ liệu chính
      unawaited(_downloadFiles());
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

  /// Đặt lại mốc đồng bộ và kéo lại toàn bộ dữ liệu từ máy chủ.
  Future<void> resetAndPullAll() async {
    store.setMeta('lastPulledAt', null);
    await sync(forceFull: true);
  }

  /// Xoá sạch bộ nhớ máy và kéo mới 100% từ máy chủ (dùng khi dữ liệu máy bị lệch hoặc muốn đồng bộ sạch).
  Future<void> wipeAndResync() async {
    await store.wipe();
    seedDefaults(store);
    store.setMeta('lastPulledAt', null);
    await sync(forceFull: true);
  }

  /// Lần đầu đăng nhập: lấy dữ liệu server trước; nếu tài khoản đã có dữ liệu thì bỏ dữ liệu mặc định chưa sửa trên máy.
  Future<void> firstSyncAfterLogin() async {
    try {
      store.setMeta('lastPulledAt', null);
      final res = await api.get<Map<String, dynamic>>('/sync/pull');
      final changes = (res['changes'] as Map<String, dynamic>? ?? {});
      _remapLocalReferences(changes);
      if ((changes[E.categories] as List?)?.isNotEmpty == true || (changes[E.accounts] as List?)?.isNotEmpty == true) {
        store.dropUntouchedSeeds();
      }
      _apply(changes);
      store.setMeta('lastPulledAt', res['serverTime'] as String);
      await sync();
    } catch (e) {
      debugPrint('firstSyncAfterLogin error: $e');
      // Không để lỗi đồng bộ ban đầu chặn luồng đăng nhập
    }
  }

  /// Ánh xạ lại ID danh mục / tài khoản cho các giao dịch local chưa sync trước khi dropUntouchedSeeds.
  void _remapLocalReferences(Map<String, dynamic> changes) {
    final rawCats = changes[E.categories] as List?;
    final rawAccs = changes[E.accounts] as List?;
    final serverCats = rawCats?.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList() ?? [];
    final serverAccs = rawAccs?.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList() ?? [];

    if (serverCats.isEmpty && serverAccs.isEmpty) return;
    final remappedOldAccIds = <String>{};

    for (final tx in store.all(E.transactions)) {
      var updated = false;
      final m = Map<String, dynamic>.from(tx);

      // 1. Ánh xạ Danh mục
      final catId = m['categoryId'] as String?;
      if (catId != null && serverCats.isNotEmpty) {
        final exact = serverCats.any((c) => c['id'] == catId);
        if (!exact) {
          final localCat = store.get(E.categories, catId);
          final catName = (m['categoryName'] ?? localCat?['name'])?.toString().trim().toLowerCase();
          final catType = localCat?['type'] ?? m['type'];
          if (catName != null && catName.isNotEmpty) {
            final match = serverCats.firstWhere(
              (c) => c['name']?.toString().trim().toLowerCase() == catName && (catType == null || c['type'] == null || c['type'] == catType),
              orElse: () => <String, dynamic>{},
            );
            if (match.isNotEmpty) {
              m['categoryId'] = match['id'];
              m['categoryName'] = match['name'];
              updated = true;
            }
          }
        }
      }

      // 2. Ánh xạ Tài khoản nguồn
      final accId = m['accountId'] as String?;
      if (accId != null && serverAccs.isNotEmpty) {
        final exact = serverAccs.any((a) => a['id'] == accId);
        if (!exact) {
          final localAcc = store.get(E.accounts, accId);
          final accName = (m['accountName'] ?? localAcc?['name'])?.toString().trim().toLowerCase();
          if (accName != null && accName.isNotEmpty) {
            final match = serverAccs.firstWhere((a) => a['name']?.toString().trim().toLowerCase() == accName, orElse: () => <String, dynamic>{});
            if (match.isNotEmpty) {
              m['accountId'] = match['id'];
              m['accountName'] = match['name'];
              remappedOldAccIds.add(accId);
              updated = true;
            }
          }
        }
      }

      // 3. Ánh xạ Tài khoản đích (chuyển khoản)
      final toAccId = m['toAccountId'] as String?;
      if (toAccId != null && serverAccs.isNotEmpty) {
        final exact = serverAccs.any((a) => a['id'] == toAccId);
        if (!exact) {
          final localToAcc = store.get(E.accounts, toAccId);
          final toAccName = (m['toAccountName'] ?? localToAcc?['name'])?.toString().trim().toLowerCase();
          if (toAccName != null && toAccName.isNotEmpty) {
            final match = serverAccs.firstWhere((a) => a['name']?.toString().trim().toLowerCase() == toAccName, orElse: () => <String, dynamic>{});
            if (match.isNotEmpty) {
              m['toAccountId'] = match['id'];
              m['toAccountName'] = match['name'];
              remappedOldAccIds.add(toAccId);
              updated = true;
            }
          }
        }
      }

      if (updated) {
        store.put(E.transactions, m, notify: false);
      }
    }

    // 4. Dọn dẹp tài khoản local cũ đã chuyển hết giao dịch sang tài khoản server
    for (final oldId in remappedOldAccIds) {
      final hasRemainingTxs = store.all(E.transactions).any((t) => t['accountId'] == oldId || t['toAccountId'] == oldId);
      if (!hasRemainingTxs) {
        store.remove(E.accounts, oldId);
      }
    }

    // 5. Nếu có tài khoản local trùng tên với tài khoản server mà không có bất kỳ giao dịch nào, tự động xoá
    if (serverAccs.isNotEmpty) {
      for (final localAcc in store.all(E.accounts)) {
        final localId = localAcc['id'] as String;
        final localName = localAcc['name']?.toString().trim().toLowerCase();
        if (localName == null || localName.isEmpty) continue;
        final serverMatch = serverAccs.firstWhere((s) => s['name']?.toString().trim().toLowerCase() == localName, orElse: () => <String, dynamic>{});
        if (serverMatch.isNotEmpty && serverMatch['id'] != localId) {
          final hasTxs = store.all(E.transactions).any((t) => t['accountId'] == localId || t['toAccountId'] == localId);
          if (!hasTxs) {
            store.remove(E.accounts, localId);
          }
        }
      }
    }
  }

  /// Tự động khắc phục các giao dịch có CategoryId hoặc AccountId không tồn tại trong store (orphan) bằng cách tìm theo tên.
  void _healOrphanTransactions() {
    final categories = store.all(E.categories);
    final accounts = store.all(E.accounts);
    if (categories.isEmpty && accounts.isEmpty) return;

    for (final tx in store.all(E.transactions)) {
      var updated = false;
      final m = Map<String, dynamic>.from(tx);

      final catId = m['categoryId'] as String?;
      if (catId != null && store.get(E.categories, catId) == null) {
        final catName = m['categoryName']?.toString().trim().toLowerCase();
        final catType = m['type'];
        if (catName != null && catName.isNotEmpty) {
          final match = categories.firstWhere(
            (c) => c['name']?.toString().trim().toLowerCase() == catName && (catType == null || c['type'] == null || c['type'] == catType),
            orElse: () => <String, dynamic>{},
          );
          if (match.isNotEmpty) {
            m['categoryId'] = match['id'];
            updated = true;
          }
        }
      }

      final accId = m['accountId'] as String?;
      if (accId != null && store.get(E.accounts, accId) == null) {
        final accName = m['accountName']?.toString().trim().toLowerCase();
        if (accName != null && accName.isNotEmpty) {
          final match = accounts.firstWhere((a) => a['name']?.toString().trim().toLowerCase() == accName, orElse: () => <String, dynamic>{});
          if (match.isNotEmpty) {
            m['accountId'] = match['id'];
            updated = true;
          }
        }
      }

      final toAccId = m['toAccountId'] as String?;
      if (toAccId != null && store.get(E.accounts, toAccId) == null) {
        final toAccName = m['toAccountName']?.toString().trim().toLowerCase();
        if (toAccName != null && toAccName.isNotEmpty) {
          final match = accounts.firstWhere((a) => a['name']?.toString().trim().toLowerCase() == toAccName, orElse: () => <String, dynamic>{});
          if (match.isNotEmpty) {
            m['toAccountId'] = match['id'];
            updated = true;
          }
        }
      }

      if (updated) {
        final wasDirty = store.isDirty(E.transactions, m['id'] as String);
        store.put(E.transactions, m, notify: false);
        if (!wasDirty) {
          store.markSynced(E.transactions, m['id'] as String);
        }
      }
    }
  }

  Future<void> _uploadFiles() async {
    for (final f in store.pendingUploads()) {
      // Đọc từng ảnh từ đĩa ngay lúc tải lên → mỗi lúc chỉ 1 ảnh nằm trong RAM.
      final bytes = await store.readFile(f.id);
      if (bytes != null) await api.upload(f.id, bytes, f.mime, f.name);
      await store.fileUploaded(f.id, missing: bytes == null); // mất file cũng bỏ khỏi hàng đợi, tránh kẹt mãi
    }
  }

  /// Tải về các ảnh còn thiếu cho Session Cache dưới nền (ưu tiên ảnh lịch giao dịch trước).
  Future<void> _downloadFiles() async {
    if (kIsWeb) {
      await store.pruneLocalFiles(immediate: true);
      return;
    }
    final missing = store.prioritizedMissingFiles();
    final gone = (store.meta('goneFiles') ?? '').split(',').where((s) => s.isNotEmpty).toSet();
    final todo = missing.where((id) => !gone.contains(id)).toList();
    if (todo.isEmpty) {
      await store.pruneLocalFiles(immediate: true);
      return;
    }

    try {
      var done = 0;
      fileProgress = (0, todo.length);
      notifyListeners();

      const concurrency = 3;
      var index = 0;

      Future<void> worker() async {
        while (true) {
          final i = index++;
          if (i >= todo.length) break;
          final id = todo[i];
          try {
            final f = await api.download(id);
            if (f == null) {
              gone.add(id);
            } else {
              await store.saveDownloadedFile(id, f.bytes, f.mime);
            }
          } catch (_) {}
          done++;
          fileProgress = (done, todo.length);
          notifyListeners();
        }
      }

      await Future.wait(List.generate(concurrency, (_) => worker()));
    } finally {
      fileProgress = null;
      store.setMeta('goneFiles', gone.isEmpty ? null : gone.join(','));
      if (todo.isNotEmpty) store.notifyRemoteApplied();
    }
    await store.pruneLocalFiles(immediate: true);
  }

  Future<void> _push() async {
    final cycleOk = _cycleSyncEnabled;
    final all = store.dirtyRecords().where((r) => cycleOk || !r.entity.startsWith('cycle')).toList();
    for (var i = 0; i < all.length; i += 200) {
      final chunk = all.sublist(i, i + 200 > all.length ? all.length : i + 200);
      final res = await api.post<Map<String, dynamic>>('/sync/push', {
        'changes': [
          for (final r in chunk) {'entity': r.entity, 'data': _prepareData(r.entity, r.data)},
        ],
      });
      final accepted = (res['accepted'] as List?)?.map((x) => x.toString()).toSet() ?? <String>{};
      for (final r in chunk) {
        if (accepted.contains(r.data['id'])) store.markSynced(r.entity, r.data['id'] as String);
      }
      final rejList = res['rejected'] as List?;
      if (rejList != null) {
        for (final raw in rejList) {
          if (raw is Map) {
            final rej = Map<String, dynamic>.from(raw);
            store.markRejected(rej['entity'] as String, rej['id'] as String, rej['reason'] as String);
          }
        }
      }
    }
  }

  Map<String, dynamic> _prepareData(String entity, Map<String, dynamic> data) {
    final clean = _clean(data);
    if (entity == E.transactions) {
      final catId = clean['categoryId'] as String?;
      if (catId != null) {
        final cat = store.get(E.categories, catId);
        if (cat != null) {
          clean['categoryName'] ??= cat['name'];
          clean['categoryIcon'] ??= cat['icon'];
          clean['categoryColor'] ??= cat['color'];
        }
      }
      final accId = clean['accountId'] as String?;
      if (accId != null) {
        final acc = store.get(E.accounts, accId);
        if (acc != null) clean['accountName'] ??= acc['name'];
      }
      final toAccId = clean['toAccountId'] as String?;
      if (toAccId != null) {
        final toAcc = store.get(E.accounts, toAccId);
        if (toAcc != null) clean['toAccountName'] ??= toAcc['name'];
      }
    }
    return clean;
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

  Future<void> _pull({bool forceFull = false}) async {
    // Nếu máy chưa có giao dịch và tài khoản nào, tự động kéo toàn bộ (full pull) để tránh kẹt mốc since cũ
    final isEmpty = store.all(E.transactions).isEmpty && store.all(E.accounts).isEmpty;
    final shouldFullPull = forceFull || isEmpty;

    final since = shouldFullPull ? null : store.meta('lastPulledAt');
    final query = <String, dynamic>{if (since != null) 'since': since, if (shouldFullPull) 'full': 'true'};
    final res = await api.get<Map<String, dynamic>>('/sync/pull', query: query.isEmpty ? null : query);
    _apply(res['changes'] as Map<String, dynamic>? ?? {});
    store.setMeta('lastPulledAt', res['serverTime'] as String);
  }

  void _apply(Map<String, dynamic> changes) {
    if (changes.isEmpty) return;
    for (final e in changes.entries) {
      final list = e.value as List?;
      if (list == null) continue;
      for (final raw in list) {
        if (raw is Map) {
          store.applyRemote(e.key, Map<String, dynamic>.from(raw));
        }
      }
    }
    store.notifyRemoteApplied();
  }

  void _setState(SyncState s) {
    state = s;
    notifyListeners();
  }
}
