import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/format.dart';
import 'api.dart';
import 'local_store.dart';
import 'models.dart';
import 'realtime.dart';
import 'session.dart';

/// Người yêu xác nhận hai chiều (server là nguồn chuẩn) + lời mời đến/đi.
/// Khi đã thành đôi: tự liên kết vào "Ngày yêu" trên máy (tạo mới nếu chưa có); khi huỷ: tự bỏ liên kết.
class CoupleStore extends ChangeNotifier {
  CoupleStore(this.api, this.session, this.realtime, this.store) {
    session.addListener(_onSession);
    _sub = realtime.events.listen((e) {
      if (e.method == 'Notification') refresh();
    });
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => refresh());
    refresh();
  }

  final ApiClient api;
  final Session session;
  final Realtime realtime;
  final LocalStore store;
  StreamSubscription? _sub;
  Timer? _timer, _debounce;
  bool _wasLoggedIn = false;

  Map<String, dynamic>? partner;
  DateTime? since;
  List<Map<String, dynamic>> incoming = [];
  Map<String, dynamic>? outgoing; // {friendshipId, user, createdAt}

  String? get partnerId => partner?['id'] as String?;
  String? get outgoingUserId => (outgoing?['user'] as Map?)?['id'] as String?;

  void _onSession() {
    if (session.isLoggedIn != _wasLoggedIn) {
      _wasLoggedIn = session.isLoggedIn;
      refresh();
    }
  }

  void refresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _load);
  }

  Future<void> _load() async {
    if (!session.isLoggedIn) {
      partner = null;
      since = null;
      incoming = [];
      outgoing = null;
      notifyListeners();
      return;
    }
    try {
      final d = await api.get<Map<String, dynamic>>('/friends/couple');
      partner = (d['partner'] as Map?)?.cast<String, dynamic>();
      since = DateTime.tryParse(d['since'] as String? ?? '')?.toLocal();
      incoming = ((d['incoming'] as List?) ?? []).cast<Map>().map((m) => m.cast<String, dynamic>()).toList();
      outgoing = (d['outgoing'] as Map?)?.cast<String, dynamic>();
      _syncLove();
      notifyListeners();
    } catch (_) {
      // mất mạng: giữ trạng thái cũ
    }
  }

  /// Đồng bộ liên kết vào bản ghi "Ngày yêu".
  void _syncLove() {
    final rec = store.all(E.loveCounters).firstOrNull;
    final love = rec == null ? null : LoveCounter(rec);
    final p = partner;
    if (p != null) {
      if (love == null) {
        store.put(E.loveCounters, {
          'partnerName': p['displayName'],
          'partnerUserId': p['id'],
          'partnerPhotoFileId': p['avatarFileId'],
          'startDate': Fmt.isoDate(since ?? DateTime.now()),
          'milestoneReminderDays': 3,
        });
      } else if (love.partnerUserId != p['id']) {
        store.put(E.loveCounters, {
          'id': love.id,
          'partnerUserId': p['id'],
          if (love.partnerName.isEmpty) 'partnerName': p['displayName'],
          if (love.partnerPhoto == null && p['avatarFileId'] != null) 'partnerPhotoFileId': p['avatarFileId'],
        });
      }
    } else if (love?.partnerUserId != null) {
      store.put(E.loveCounters, {'id': love!.id, 'partnerUserId': null});
    }
  }

  Future<void> request(String userId) async {
    await api.post('/friends/$userId/couple');
    await _load();
  }

  Future<void> accept(String userId) async {
    await api.post('/friends/$userId/couple/accept');
    await _load();
  }

  /// Từ chối / huỷ lời mời / huỷ liên kết.
  Future<void> end(String userId) async {
    await api.delete('/friends/$userId/couple');
    await _load();
  }

  @override
  void dispose() {
    session.removeListener(_onSession);
    _sub?.cancel();
    _timer?.cancel();
    _debounce?.cancel();
    super.dispose();
  }
}
