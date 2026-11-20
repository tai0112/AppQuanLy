import 'dart:convert';

import 'local_store.dart';

/// Cấu hình thời gian của từng người dùng (lưu trong CaiDat.CauHinhThoiGianJson, đồng bộ giữa các máy).
/// Không có hằng số thời gian cố định trong giao diện: mọi giá trị đọc từ đây.
class TimeConfig {
  TimeConfig({
    required this.remindOptions,
    required this.defaultRemind,
    required this.itemRemindMinutes,
    required this.dayStartHour,
    required this.dayEndHour,
    required this.snapMinutes,
    required this.defaultActivityMinutes,
    required this.firstDayOfWeek,
  });

  /// Các mốc "nhắc trước" (phút) hiện khi chọn nhắc nhở.
  final List<int> remindOptions;

  /// Nhắc mặc định cho lịch trình mới (null = không nhắc).
  final int? defaultRemind;

  /// Nhắc trước bao nhiêu phút cho từng hoạt động theo giờ (null = không nhắc).
  final int? itemRemindMinutes;

  /// Khung giờ luôn hiển thị trên timeline trong ngày.
  final int dayStartHour;
  final int dayEndHour;

  /// Chạm vào trục giờ sẽ làm tròn theo bước này (phút).
  final int snapMinutes;

  /// Thời lượng mặc định của hoạt động mới (phút).
  final int defaultActivityMinutes;

  /// Ngày đầu tuần trên lịch: 1 = Thứ 2, 7 = Chủ nhật.
  final int firstDayOfWeek;

  static TimeConfig defaults() => TimeConfig(
    remindOptions: [0, 10, 30, 60, 120, 1440],
    defaultRemind: 30,
    itemRemindMinutes: 10,
    dayStartHour: 6,
    dayEndHour: 22,
    snapMinutes: 15,
    defaultActivityMinutes: 60,
    firstDayOfWeek: 1,
  );

  factory TimeConfig.of(LocalStore store) {
    final s = store.all(E.appSettings).firstOrNull;
    final d = defaults();
    final raw = s?['timeConfigJson'] as String?;
    Map<String, dynamic> m = {};
    if (raw != null) {
      try {
        m = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {}
    }
    int? optInt(String k, int? def) => m.containsKey(k) ? (m[k] as num?)?.toInt() : def;
    return TimeConfig(
      remindOptions: ((m['remindOptions'] as List?)?.map((e) => (e as num).toInt()).toList() ?? d.remindOptions)..sort(),
      defaultRemind: optInt('defaultRemind', d.defaultRemind),
      itemRemindMinutes: optInt('itemRemindMinutes', d.itemRemindMinutes),
      dayStartHour: optInt('dayStartHour', d.dayStartHour)!,
      dayEndHour: optInt('dayEndHour', d.dayEndHour)!,
      snapMinutes: optInt('snapMinutes', d.snapMinutes)!,
      defaultActivityMinutes: optInt('defaultActivityMinutes', d.defaultActivityMinutes)!,
      firstDayOfWeek: (s?['firstDayOfWeek'] as num?)?.toInt() ?? d.firstDayOfWeek,
    );
  }

  TimeConfig copyWith({
    List<int>? remindOptions,
    Object? defaultRemind = _keep,
    Object? itemRemindMinutes = _keep,
    int? dayStartHour,
    int? dayEndHour,
    int? snapMinutes,
    int? defaultActivityMinutes,
    int? firstDayOfWeek,
  }) => TimeConfig(
    remindOptions: remindOptions ?? this.remindOptions,
    defaultRemind: defaultRemind == _keep ? this.defaultRemind : defaultRemind as int?,
    itemRemindMinutes: itemRemindMinutes == _keep ? this.itemRemindMinutes : itemRemindMinutes as int?,
    dayStartHour: dayStartHour ?? this.dayStartHour,
    dayEndHour: dayEndHour ?? this.dayEndHour,
    snapMinutes: snapMinutes ?? this.snapMinutes,
    defaultActivityMinutes: defaultActivityMinutes ?? this.defaultActivityMinutes,
    firstDayOfWeek: firstDayOfWeek ?? this.firstDayOfWeek,
  );

  void save(LocalStore store) {
    final s = store.all(E.appSettings).firstOrNull ?? {};
    Map<String, dynamic> old = {};
    try {
      old = jsonDecode(s['timeConfigJson'] as String? ?? '{}') as Map<String, dynamic>;
    } catch (_) {}
    store.put(E.appSettings, {
      ...s,
      'firstDayOfWeek': firstDayOfWeek,
      'timeConfigJson': jsonEncode({
        if (old['calendar'] != null) 'calendar': old['calendar'], // giữ cấu hình giao diện lịch
        'remindOptions': remindOptions,
        'defaultRemind': defaultRemind,
        'itemRemindMinutes': itemRemindMinutes,
        'dayStartHour': dayStartHour,
        'dayEndHour': dayEndHour,
        'snapMinutes': snapMinutes,
        'defaultActivityMinutes': defaultActivityMinutes,
      }),
    });
  }

  /// "Đúng giờ" / "Trước 30 phút" / "Trước 2 giờ" / "Trước 1 ngày"
  static String remindLabel(int? m) {
    if (m == null) return 'Không nhắc';
    if (m == 0) return 'Đúng giờ';
    if (m % 1440 == 0) return 'Trước ${m ~/ 1440} ngày';
    if (m % 60 == 0) return 'Trước ${m ~/ 60} giờ';
    return 'Trước $m phút';
  }
}

const _keep = Object();
