import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'notify_prefs.dart';

/// Thông báo trên máy: nhắc lịch, cảnh báo định mức, mốc ngày yêu, kỳ kinh...
/// Mobile: thông báo hệ thống (iOS/Android). Web: thông báo trình duyệt + banner trong app.
class LocalNotifier {
  final _plugin = FlutterLocalNotificationsPlugin();
  final messengerKey = GlobalKey<ScaffoldMessengerState>();
  bool _ready = false;

  /// Cấu hình âm thanh hiện tại (gán khi khởi tạo Services).
  NotifyPrefs Function() prefs = () => NotifyPrefs({});

  /// Phòng chat đang mở (không báo tin nhắn của phòng này).
  String? activeConversation;

  // Tạo khi phát âm lần đầu (không khởi tạo plugin âm thanh lúc mở app).
  late final _player = AudioPlayer();

  /// Chi tiết thông báo theo nhóm + âm thanh. Android: mỗi tổ hợp âm/rung là một kênh riêng (kênh không đổi được âm sau khi tạo).
  NotificationDetails _details(String kind, {bool quiet = false}) {
    final p = prefs();
    final sound = quiet ? NotifySound.silent : p.sound(kind);
    final vib = !quiet && p.vibrate(kind);
    final k = NotifyKind.all.firstWhere((x) => x.id == kind, orElse: () => NotifyKind.all.first);
    final file = NotifySound.of(sound).file;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'lht_${kind}_${sound}_${vib ? 1 : 0}',
        '${k.label} · ${NotifySound.of(sound).label}${vib ? '' : ' · không rung'}',
        channelDescription: k.description,
        importance: sound == NotifySound.silent ? Importance.low : Importance.high,
        priority: Priority.high,
        playSound: sound != NotifySound.silent,
        sound: file == null ? null : RawResourceAndroidNotificationSound(file.replaceAll('.wav', '')),
        enableVibration: vib,
      ),
      iOS: DarwinNotificationDetails(presentSound: sound != NotifySound.silent, sound: file),
    );
  }

  /// Phát thử / phát trong app một âm thanh.
  Future<void> playSound(String soundId, {double? volume}) async {
    final f = NotifySound.of(soundId == NotifySound.system ? 'ting' : soundId).file;
    if (f == null) return;
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/$f'), volume: volume ?? prefs().volume);
    } catch (e) {
      debugPrint('sound: $e');
    }
  }

  Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
          web: WebInitializationSettings(),
        ),
      );
      _ready = true;
    } catch (e) {
      debugPrint('Notifications: $e');
    }
  }

  Future<void> requestPermission() async {
    try {
      await _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, badge: true, sound: true);
      await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    } catch (_) {}
  }

  /// Hiện thông báo ngay + banner trong app (kèm âm thanh theo cấu hình của nhóm [kind]).
  Future<void> show(String title, String body, {bool inApp = true, int? id, String kind = NotifyKind.social}) async {
    final p = prefs();
    if (!p.enabled || !p.kindEnabled(kind)) return;
    final quiet = p.isQuiet(DateTime.now());
    if (inApp) {
      messengerKey.currentState?.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(body),
            ],
          ),
        ),
      );
      if (p.inAppSound && !quiet) playSound(p.sound(kind));
    }
    if (!_ready || (kIsWeb && inApp)) return;
    try {
      await _plugin.show(
        id: id ?? DateTime.now().millisecondsSinceEpoch ~/ 1000 % 100000,
        title: title,
        body: body,
        notificationDetails: _details(kind, quiet: quiet),
      );
    } catch (_) {}
  }

  /// Hẹn giờ thông báo (chỉ mobile; iOS giới hạn 64 thông báo chờ).
  Future<void> schedule(int id, DateTime when, String title, String body, {String kind = NotifyKind.reminder}) async {
    final p = prefs();
    if (!_ready || kIsWeb || when.isBefore(DateTime.now()) || !p.enabled || !p.kindEnabled(kind)) return;
    try {
      await _plugin.zonedSchedule(
        id: id,
        scheduledDate: tz.TZDateTime.from(when, tz.local),
        notificationDetails: _details(kind, quiet: p.isQuiet(when)),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: title,
        body: body,
      );
    } catch (e) {
      debugPrint('schedule: $e');
    }
  }

  Future<void> cancelAll() async {
    if (!_ready || kIsWeb) return;
    try {
      await _plugin.cancelAllPendingNotifications();
    } catch (_) {}
  }
}
