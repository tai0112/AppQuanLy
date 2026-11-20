import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api.dart';
import 'realtime.dart';
import 'session.dart';

/// Bộ đếm "chưa đọc" dùng cho huy hiệu menu (tin nhắn, thông báo...).
/// Tự làm mới khi: đăng nhập/đăng xuất, có sự kiện realtime liên quan, kết nối lại, và định kỳ 60 giây.
class UnreadCounter extends ChangeNotifier {
  UnreadCounter(this.api, this.session, this.realtime, {required this.events, required this.load}) {
    session.addListener(_onSession);
    realtime.addListener(_onSession);
    _sub = realtime.events.listen((e) {
      if (events.contains(e.method)) refresh();
    });
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => refresh());
    refresh();
  }

  final ApiClient api;
  final Session session;
  final Realtime realtime;

  /// Tên sự kiện realtime làm thay đổi số đếm.
  final Set<String> events;

  /// Lấy số đếm từ server.
  final Future<int> Function(ApiClient api) load;
  StreamSubscription? _sub;
  Timer? _timer;
  Timer? _debounce;
  bool _wasLoggedIn = false;
  int _count = 0;

  int get count => _count;

  /// Đặt số ngay (vd vừa bấm "đọc hết") rồi đối chiếu lại với server.
  void set(int n) {
    if (n != _count) {
      _count = n;
      notifyListeners();
    }
    refresh();
  }

  void _onSession() {
    if (session.isLoggedIn != _wasLoggedIn) {
      _wasLoggedIn = session.isLoggedIn;
      refresh();
    }
  }

  /// Gọi lại server (gộp nhiều lần gọi liên tiếp thành một).
  void refresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  Future<void> _load() async {
    var n = 0;
    if (session.isLoggedIn) {
      try {
        n = await load(api);
      } catch (_) {
        return; // mất mạng: giữ số cũ
      }
    }
    if (n != _count) {
      _count = n;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    session.removeListener(_onSession);
    realtime.removeListener(_onSession);
    _sub?.cancel();
    _timer?.cancel();
    _debounce?.cancel();
    super.dispose();
  }
}
