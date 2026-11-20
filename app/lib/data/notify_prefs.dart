import 'dart:convert';

import 'local_store.dart';

/// Một âm thanh thông báo có thể chọn.
class NotifySound {
  const NotifySound(this.id, this.label);
  final String id;
  final String label;

  /// File trong assets/sounds, res/raw (Android) và bundle iOS. null = âm mặc định hệ thống / im lặng.
  String? get file => id == system || id == silent ? null : '$id.wav';

  static const system = 'system', silent = 'silent';
  static const all = [
    NotifySound(system, 'Mặc định của máy'),
    NotifySound('ting', 'Ting'),
    NotifySound('pop', 'Pop'),
    NotifySound('chime', 'Chuông gió'),
    NotifySound('dingdong', 'Ding dong'),
    NotifySound('soft', 'Nhẹ nhàng'),
    NotifySound('alert', 'Khẩn'),
    NotifySound(silent, 'Im lặng'),
  ];

  static NotifySound of(String id) => all.firstWhere((s) => s.id == id, orElse: () => all.first);
}

/// Nhóm thông báo, mỗi nhóm cấu hình âm thanh/rung riêng.
class NotifyKind {
  const NotifyKind(this.id, this.label, this.description, this.defaultSound);
  final String id;
  final String label;
  final String description;
  final String defaultSound;

  static const chat = 'chat', social = 'social', reminder = 'reminder', finance = 'finance';
  static const all = [
    NotifyKind(chat, 'Tin nhắn', 'Tin nhắn mới từ bạn bè, nhóm', 'pop'),
    NotifyKind(social, 'Bạn bè & bảng tin', 'Lời mời kết bạn, bình luận, cảm xúc, lịch trình chung', 'ting'),
    NotifyKind(reminder, 'Nhắc nhở', 'Lịch trình, chu kỳ, ngày yêu, sinh nhật', 'chime'),
    NotifyKind(finance, 'Tài chính', 'Vượt định mức, hũ tiết kiệm đạt mục tiêu', 'alert'),
  ];
}

/// Cấu hình thông báo của người dùng (lưu ở CaiDat.NotificationJson, đồng bộ giữa các máy).
class NotifyPrefs {
  NotifyPrefs(this.raw);
  final Map<String, dynamic> raw;

  factory NotifyPrefs.of(LocalStore store) {
    final s = store.all(E.appSettings).firstOrNull?['notificationJson'] as String?;
    if (s == null || s.isEmpty) return NotifyPrefs({});
    try {
      return NotifyPrefs((jsonDecode(s) as Map).cast<String, dynamic>());
    } catch (_) {
      return NotifyPrefs({});
    }
  }

  bool get enabled => raw['enabled'] != false;
  bool get inAppSound => raw['inAppSound'] != false;
  double get volume => (raw['volume'] as num?)?.toDouble() ?? 0.8;

  bool get quietEnabled => raw['quietEnabled'] == true;

  /// Giờ yên lặng tính theo phút trong ngày.
  int get quietFrom => (raw['quietFrom'] as num?)?.toInt() ?? 22 * 60;
  int get quietTo => (raw['quietTo'] as num?)?.toInt() ?? 7 * 60;

  Map<String, dynamic> _kind(String id) => ((raw['kinds'] as Map?)?[id] as Map?)?.cast<String, dynamic>() ?? {};
  String sound(String kind) =>
      _kind(kind)['sound'] as String? ?? NotifyKind.all.firstWhere((k) => k.id == kind, orElse: () => NotifyKind.all.first).defaultSound;
  bool vibrate(String kind) => _kind(kind)['vibrate'] != false;
  bool kindEnabled(String kind) => _kind(kind)['enabled'] != false;

  /// Đang trong giờ yên lặng? (hỗ trợ khoảng qua nửa đêm, vd 22:00 → 07:00)
  bool isQuiet(DateTime t) {
    if (!quietEnabled) return false;
    final m = t.hour * 60 + t.minute;
    return quietFrom <= quietTo ? (m >= quietFrom && m < quietTo) : (m >= quietFrom || m < quietTo);
  }

  NotifyPrefs copyWith(Map<String, dynamic> patch) => NotifyPrefs({...raw, ...patch});

  NotifyPrefs withKind(String kind, Map<String, dynamic> patch) {
    final kinds = {...((raw['kinds'] as Map?)?.cast<String, dynamic>() ?? {})};
    kinds[kind] = {..._kind(kind), ...patch};
    return copyWith({'kinds': kinds});
  }

  void save(LocalStore store) {
    final s = store.all(E.appSettings).firstOrNull ?? {};
    store.put(E.appSettings, {...s, 'notificationJson': jsonEncode(raw)});
  }
}
