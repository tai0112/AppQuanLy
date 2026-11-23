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
  // Web không hẹn được thông báo hệ thống → giữ đúng MỘT bộ hẹn giờ tới lần nhắc kế tiếp (hiện banner + thông báo trình duyệt).
  if (kIsWeb) s.store.addListener(() => _armWebReminder(s));
  if (kIsWeb) _armWebReminder(s);
  s.notifier.requestPermission();
  refresh();
}

Timer? _webTimer;
Timer? _webDebounce;

void _armWebReminder(Services s) {
  _webDebounce?.cancel();
  _webDebounce = Timer(const Duration(seconds: 1), () {
    _webTimer?.cancel();
    final now = DateTime.now();
    (DateTime, Reminder)? next;
    for (final r in s.store.all(E.reminders).map(Reminder.new)) {
      final t = Reminders.next(r, now.add(const Duration(seconds: 1)));
      if (t != null && (next == null || t.isBefore(next.$1))) next = (t, r);
    }
    if (next == null) return;
    final (at, r) = next;
    // Timer dài bị trình duyệt trì hoãn khi tab ngủ → hẹn tối đa 1 giờ rồi tính lại.
    final wait = at.difference(DateTime.now());
    _webTimer = Timer(wait > const Duration(hours: 1) ? const Duration(hours: 1) : wait, () {
      if (!DateTime.now().isBefore(at)) s.notifier.show('⏰ ${r.title}', r.note ?? Fmt.time(at), kind: NotifyKind.reminder, inApp: true);
      _armWebReminder(s);
    });
  });
}

Future<void> _scheduleReminders(Services s) async {
  if (kIsWeb) return;
  final n = s.notifier;
  await n.cancelAll();
  final now = DateTime.now();
  var id = 1000;
  var count = 0;

  // Nhắc nhở tự đặt: ưu tiên trước (người dùng chủ động đặt), 7 ngày tới, tối đa 20 thông báo chờ.
  final custom = <(DateTime, Reminder)>[
    for (final r in s.store.all(E.reminders).map(Reminder.new))
      for (final t in Reminders.occurrences(r, now, now.add(const Duration(days: 7)))) (t, r),
  ]..sort((a, b) => a.$1.compareTo(b.$1));
  for (final (at, r) in custom.take(20)) {
    await n.schedule(id++, at, '⏰ ${r.title}', r.note ?? 'Đến giờ rồi · ${Fmt.time(at)}');
    count++;
  }

  // Lịch trình 14 ngày tới (iOS giới hạn 64 thông báo chờ → tối đa 50).
  final events = s.store.all(E.events).map(EventRec.new).where((e) => e.remindBefore != null);
  final upcoming = <(DateTime, EventRec)>[];
  for (final e in events) {
    for (final o in Recurrence.occurrences(e, now, now.add(const Duration(days: 14)))) {
      upcoming.add((o.subtract(Duration(minutes: e.remindBefore!)), e));
    }
  }
  upcoming.sort((a, b) => a.$1.compareTo(b.$1));
  for (final (at, e) in upcoming.take(50 - count)) {
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
    String day(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    // Lịch 7 ngày tới (mỗi dòng: ngày|giờ|tiêu đề) → widget tự lọc "hôm nay" kể cả khi app không mở qua ngày mới.
    final events =
        s.store
            .all(E.events)
            .map(EventRec.new)
            .expand((e) => Recurrence.occurrences(e, today, today.add(const Duration(days: 7))).map((o) => (o, e.title)))
            .toList()
          ..sort((a, b) => a.$1.compareTo(b.$1));
    final lines = events.take(40).map((x) => '${day(x.$1)}|${Fmt.time(x.$1)}|${x.$2.replaceAll('\n', ' ')}').join('\n');
    // Chi tiêu từng ngày cho biểu đồ cột (bao trọn kỳ tháng + tuần hiện tại) — widget tự cắt theo Tuần/Tháng.
    final tc = TimeConfig.of(s.store);
    final ws = tc.weekStart(today);
    final cFrom = ws.isBefore(from) ? ws : from;
    final wEnd = ws.add(const Duration(days: 7));
    final cTo = wEnd.isAfter(to) ? wEnd : to;
    final daily = <String, double>{};
    for (final t in f.inRange(cFrom, cTo)) {
      if (t.type == TxType.expense) daily.update(day(f.at(t)), (v) => v + f.toBase(t), ifAbsent: () => f.toBase(t));
    }
    final cur = f.currency(f.baseCurrency);
    await HomeWidget.saveWidgetData<String>('daily_expense', daily.entries.map((e) => '${e.key}|${e.value}').join('\n'));
    await HomeWidget.saveWidgetData<int>('first_day_of_week', tc.firstDayOfWeek);
    await HomeWidget.saveWidgetData<int>('month_start_day', f.monthStartDay);
    await HomeWidget.saveWidgetData<String>('cur_symbol', cur?.symbol ?? f.baseCurrency);
    await HomeWidget.saveWidgetData<bool>('cur_before', cur?.symbolBefore ?? false);
    await HomeWidget.saveWidgetData<int>('cur_decimals', cur?.decimals ?? 0);
    await HomeWidget.saveWidgetData<String>('month_label', 'Tháng ${Fmt.month(from)}');
    await HomeWidget.saveWidgetData<String>('month_end', day(to)); // hết kỳ → widget ẩn số cũ
    await HomeWidget.saveWidgetData<String>('month_expense', f.money(t.expense));
    await HomeWidget.saveWidgetData<String>('month_income', f.money(t.income));
    await HomeWidget.saveWidgetData<String>('love_start', love == null ? '' : day(love.startDate));
    await HomeWidget.saveWidgetData<String>('events', lines);
    await HomeWidget.updateWidget(iOSName: 'LHTWidget', androidName: 'LHTWidgetProvider');
  } catch (_) {
    // Widget chưa được thêm vào máy → bỏ qua.
  }
}
