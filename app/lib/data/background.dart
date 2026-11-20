import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../core/format.dart';
import '../providers.dart';
import 'local_store.dart';
import 'logic.dart';
import 'models.dart';
import 'notify_prefs.dart';
import 'time_config.dart';

/// Việc chạy nền khi app mở:
///  - Nhận sự kiện realtime → hiện thông báo, kích hoạt đồng bộ
///  - Lên lịch thông báo local (lịch trình, mốc ngày yêu, kỳ kinh)
///  - Cập nhật widget màn hình chính (iOS/Android)
void startBackgroundTasks(Services s) {
  s.realtime.events.listen((e) {
    switch (e.method) {
      case 'Notification':
        s.notifier.show(e.data['title'] as String? ?? 'Thông báo', e.data['body'] as String? ?? '', kind: NotifyKind.social);
      case 'MessageReceived':
        // Tin nhắn của người khác, không phải phòng đang mở → báo + âm thanh "Tin nhắn"
        final from = e.data['senderId'];
        if (from != s.session.userId && e.data['conversationId'] != s.notifier.activeConversation) {
          final text = e.data['type'] == 2 ? '📷 Hình ảnh' : (e.data['content'] as String? ?? '');
          s.notifier.show('Tin nhắn mới', text, kind: NotifyKind.chat);
        }
      case 'SyncHint':
        s.sync.schedule(const Duration(milliseconds: 300));
    }
  });

  Timer? debounce;
  void refresh() {
    debounce?.cancel();
    debounce = Timer(const Duration(seconds: 3), () {
      _scheduleReminders(s);
      _updateHomeWidget(s);
    });
  }

  s.store.addListener(refresh);
  s.notifier.requestPermission();
  refresh();
}

Future<void> _scheduleReminders(Services s) async {
  if (kIsWeb) return;
  final n = s.notifier;
  await n.cancelAll();
  final now = DateTime.now();
  var id = 1000;
  var count = 0;

  // Lịch trình 14 ngày tới (iOS giới hạn 64 thông báo chờ → tối đa 50).
  final events = s.store.all(E.events).map(EventRec.new).where((e) => e.remindBefore != null);
  final upcoming = <(DateTime, EventRec)>[];
  for (final e in events) {
    for (final o in Recurrence.occurrences(e, now, now.add(const Duration(days: 14)))) {
      upcoming.add((o.subtract(Duration(minutes: e.remindBefore!)), e));
    }
  }
  upcoming.sort((a, b) => a.$1.compareTo(b.$1));
  for (final (at, e) in upcoming.take(50)) {
    await n.schedule(id++, at, 'Sắp tới: ${e.title}', '${Fmt.time(at.add(Duration(minutes: e.remindBefore!)))}${e.location != null ? ' · ${e.location}' : ''}');
    count++;
  }

  // Hoạt động theo giờ: nhắc trước số phút cấu hình trong "Thời gian & nhắc nhở".
  final itemRemind = TimeConfig.of(s.store).itemRemindMinutes;
  for (final it in s.store.all(E.eventItems).map(EventItemRec.new)) {
    final ev = s.store.get(E.events, it.eventId);
    if (itemRemind == null || ev == null || it.occurrenceDate == null || count >= 60) continue;
    final d = DateTime.parse(it.occurrenceDate!);
    final at = DateTime(d.year, d.month, d.day, it.start.$1, it.start.$2).subtract(Duration(minutes: itemRemind));
    if (at.isAfter(now) && at.isBefore(now.add(const Duration(days: 14)))) {
      await n.schedule(id++, at, '${timeStr(it.start)} · ${it.title}', '${EventRec(ev).title}${it.location != null ? ' · ${it.location}' : ''}');
      count++;
    }
  }

  // Mốc ngày yêu.
  final love = s.store.all(E.loveCounters).map(LoveCounter.new).firstOrNull;
  if (love != null) {
    for (final m in Love.milestones(love.startDate, count: 3)) {
      final when = m.date.subtract(Duration(days: love.reminderDays)).add(const Duration(hours: 9));
      await n.schedule(id++, when, 'Sắp tới ${m.label} 💕', 'Còn ${love.reminderDays} ngày nữa là ${m.label} bên ${love.partnerName}');
      count++;
    }
    final bd = Love.nextBirthday(love.partnerBirthday);
    if (bd != null)
      await n.schedule(id++, bd.subtract(const Duration(days: 3)).add(const Duration(hours: 9)), 'Sinh nhật ${love.partnerName} 🎂', 'Còn 3 ngày nữa');
  }

  // Chu kỳ: mỗi ngày một thông báo (giai đoạn, sắp đến kỳ, trễ kinh, ngày dễ thụ thai...) cho 7 ngày tới, giờ do người dùng cấu hình.
  final allPeriods = s.store.all(E.cyclePeriods).map(CyclePeriod.new).toList();
  for (final subject in const [1, 2]) {
    final periods = allPeriods.where((x) => x.subject == subject).toList();
    if (periods.isEmpty) continue;
    final settings = s.store.all(E.cycleSettings).map(CycleSettings.new).where((x) => x.subject == subject).firstOrNull;
    if (settings != null && !settings.dailyRemind) continue;
    final p = Cycle.predict(periods, settings);
    final hour = settings?.remindHour ?? 8, minute = settings?.remindMinute ?? 0;
    final today = dateOnly(now);
    for (var i = 0; i < 7 && count < 60; i++) {
      final day = today.add(Duration(days: i));
      final at = DateTime(day.year, day.month, day.day, hour, minute);
      if (!at.isAfter(now)) continue;
      final info = CycleDays.of(p, periods, settings, day, partner: subject == 2);
      if (info == null) continue;
      final icon = info.level == 2 ? '🔴' : (info.level == 1 ? '🌸' : '💧');
      await n.schedule(id++, at, '$icon ${info.title}', info.body);
      count++;
    }
  }
}

Future<void> _updateHomeWidget(Services s) async {
  if (kIsWeb) return;
  try {
    await HomeWidget.setAppGroupId('group.vn.lht.money'); // iOS: App Group dùng chung với Widget Extension
    final f = Finance(s.store);
    final (from, to) = f.monthRange(DateTime.now());
    final t = f.totals(f.inRange(from, to));
    final love = s.store.all(E.loveCounters).map(LoveCounter.new).firstOrNull;
    final today = dateOnly(DateTime.now());
    final events = s.store
        .all(E.events)
        .map(EventRec.new)
        .expand((e) => Recurrence.occurrences(e, today, today.add(const Duration(days: 1))).map((o) => '${Fmt.time(o)} ${e.title}'))
        .take(3)
        .join('\n');
    await HomeWidget.saveWidgetData<String>('month_expense', f.money(t.expense));
    await HomeWidget.saveWidgetData<String>('month_income', f.money(t.income));
    await HomeWidget.saveWidgetData<String>('love_days', love == null ? '' : '${Love.days(love.startDate)} ngày');
    await HomeWidget.saveWidgetData<String>('today_events', events.isEmpty ? 'Không có lịch trình' : events);
    await HomeWidget.updateWidget(iOSName: 'LHTWidget', androidName: 'LHTWidgetProvider');
  } catch (_) {
    // Widget chưa được thêm vào máy → bỏ qua.
  }
}
