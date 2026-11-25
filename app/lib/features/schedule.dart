import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';

import '../core/format.dart';
import '../core/icons.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../data/api.dart';
import '../data/calendar_look.dart';
import '../data/local_store.dart';
import '../data/logic.dart';
import '../data/models.dart';
import '../data/schedule_index.dart';
import '../data/time_config.dart';
import '../providers.dart';
import 'categories.dart';
import 'common.dart';

const _kinds = {1: ('Đi chơi', Icons.beach_access_rounded), 2: ('Công việc', Icons.work_rounded), 99: ('Khác', Icons.event_rounded)};

/// Lịch trình diễn ra trong [from, to). Hỏi đúng 1 ngày → tra chỉ mục dựng sẵn (nhanh); khoảng khác → tính trực tiếp.
List<(DateTime, EventRec)> occurrencesIn(LocalStore store, DateTime from, DateTime to) {
  final idx = ScheduleIndex.of(store);
  if (to.difference(from).inHours == 24 && from == dateOnly(from)) return idx.on(from);
  return [
    for (final e in idx.events)
      for (final o in Recurrence.occurrences(e, from, to)) (o, e),
  ]..sort((a, b) => a.$1.compareTo(b.$1));
}

/// Các ngày của một lịch trình: lịch lặp → chỉ ngày của lần đó; nhiều ngày → từng ngày từ bắt đầu đến kết thúc.
List<DateTime> eventDays(EventRec e, DateTime occurrence) {
  if (e.rrule != null) return [dateOnly(occurrence)];
  final start = dateOnly(e.startAt);
  final end = dateOnly(e.endAt ?? e.startAt);
  final n = end.difference(start).inDays.clamp(0, 30);
  return [for (var i = 0; i <= n; i++) start.add(Duration(days: i))];
}

/// Hoạt động theo giờ của lịch trình trong một ngày, sắp theo giờ.
List<EventItemRec> eventItemsOn(LocalStore store, String eventId, DateTime day) => ScheduleIndex.of(store).itemsOn(eventId, day);

// ============================================================================ Danh sách lịch trình

/// Lịch trình: timeline theo ngày hoặc lịch tháng; lời mời từ bạn bè.
class SchedulePage extends ConsumerStatefulWidget {
  const SchedulePage({super.key});

  @override
  ConsumerState<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends ConsumerState<SchedulePage> {
  DateTime day = dateOnly(DateTime.now());

  /// Kiểu xem: 0 = ngày (dải tuần + danh sách), 1 = cả tuần (lưới giờ), 2 = tháng. Nhớ trên máy.
  late int view = (int.tryParse(ref.read(storeProvider).meta('scheduleView') ?? '') ?? 0).clamp(0, 2);
  bool get monthView => view == 2;

  void _setView(int v) {
    setState(() => view = v);
    ref.read(storeProvider).setMeta('scheduleView', '$v');
  }

  /// Bảng nhỏ chọn ngày đầu tuần (dùng chung cho mọi lịch trong app).
  void _pickFirstDay() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    sheetAnimationStyle: kSheetAnim,
    builder: (c) => const SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ngày đầu tuần', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            SizedBox(height: 4),
            Text('Áp dụng cho mọi lịch trong ứng dụng', style: TextStyle(fontSize: 12)),
            SizedBox(height: 16),
            FirstDayPicker(),
          ],
        ),
      ),
    ),
  );
  List<Map<String, dynamic>> invitations = [];

  @override
  void initState() {
    super.initState();
    _loadInvites();
  }

  Future<void> _loadInvites() async {
    if (!ref.read(sessionProvider).isLoggedIn) return;
    try {
      final r = await ref.read(apiProvider).get<List<dynamic>>('/events/invitations');
      if (mounted) setState(() => invitations = r.cast<Map<String, dynamic>>());
    } catch (_) {}
  }

  Future<void> _respond(String eventId, bool accept) async {
    try {
      await ref.read(apiProvider).post('/events/$eventId/respond', {'accept': accept});
      await ref.read(syncProvider).sync();
      await _loadInvites();
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  int _dir = 1; // hướng trượt khi đổi tuần/tháng

  /// Chọn ngày, nhớ hướng (trước/sau) để hiệu ứng trượt đúng chiều.
  void _select(DateTime d) {
    if (isSameDay(d, day)) return;
    setState(() {
      _dir = d.isAfter(day) ? 1 : -1;
      day = d;
    });
  }

  /// Lùi/tiến 1 tuần (dạng tuần) hoặc 1 tháng (dạng tháng).
  void _shift(int delta) {
    HapticFeedback.selectionClick();
    setState(() {
      _dir = delta;
      day = monthView ? DateTime(day.year, day.month + delta, 1) : day.add(Duration(days: 7 * delta));
    });
  }

  /// Một ngày trong dải tuần: thứ, ngày, tối đa 3 chấm màu theo các lịch trình trong ngày.
  Widget _weekCell(LocalStore store, DateTime d) {
    final scheme = Theme.of(context).colorScheme;
    final look = CalendarLook.of(store);
    final sel = isSameDay(d, day);
    final isToday = isSameDay(d, DateTime.now());
    final evs = occurrencesIn(store, d, d.add(const Duration(days: 1)));
    final wc = look.weekdayColor(d.weekday, scheme);
    return Pressable(
      onTap: () {
        HapticFeedback.selectionClick();
        _select(d);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        height: 76,
        margin: const EdgeInsets.symmetric(horizontal: 2.5),
        decoration: BoxDecoration(
          gradient: sel
              ? LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [scheme.primary, accentOf(scheme.primary, hue: 18)])
              : null,
          color: sel ? null : (isToday ? scheme.primary.withValues(alpha: 0.10) : scheme.surfaceContainerHigh.withValues(alpha: 0.6)),
          borderRadius: BorderRadius.circular(18),
          border: isToday && !sel ? Border.all(color: scheme.primary.withValues(alpha: 0.6), width: 1.4) : null,
          boxShadow: sel ? [BoxShadow(color: scheme.primary.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 5))] : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              Fmt.weekdaysShort[d.weekday - 1],
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: sel ? scheme.onPrimary.withValues(alpha: 0.85) : (wc ?? scheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 2),
            AnimatedScale(
              scale: sel ? 1.12 : 1,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack,
              child: Text(
                '${d.day}',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19, color: sel ? scheme.onPrimary : (isToday ? scheme.primary : null)),
              ),
            ),
            const SizedBox(height: 5),
            SizedBox(
              height: 6,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final (_, e) in evs.take(3))
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 1.2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: sel ? scheme.onPrimary : hexColor(e.color, scheme.primary),
                        border: sel ? null : Border.all(color: scheme.surface.withValues(alpha: 0.6), width: 0.5),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watchTables(scheduleTables);
    final scheme = Theme.of(context).colorScheme;
    final cfg = TimeConfig.of(store);
    final fdw = cfg.firstDayOfWeek; // 1 = Thứ 2 … 7 = Chủ nhật
    final start = cfg.weekStart(day);
    final items = occurrencesIn(store, day, day.add(const Duration(days: 1)));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch trình'),
        actions: [IconButton(tooltip: 'Ngày đầu tuần', onPressed: _pickFirstDay, icon: const Icon(Icons.tune_rounded))],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Thêm lịch',
        onPressed: () => context.push('/schedule/edit', extra: {'date': day}),
        child: const Icon(Icons.add_rounded, size: 30),
      ),
      // Vuốt từ mép trái / phải màn hình để lùi / tiến một tuần hoặc một tháng (theo kiểu xem).
      body: EdgeSwipe(
        onPrev: () => _shift(-1),
        onNext: () => _shift(1),
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(syncProvider).sync();
            await _loadInvites();
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            children: [
              for (final inv in invitations)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    color: scheme.primaryContainer,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${(inv['owner'] as Map)['displayName']} mời bạn tham gia', style: const TextStyle(fontSize: 12)),
                        Text(inv['title'] as String, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        Text(Fmt.dateTime(DateTime.parse(inv['startAt'] as String).toLocal())),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(onPressed: () => _respond(inv['eventId'] as String, false), child: const Text('Từ chối')),
                            FilledButton(
                              style: FilledButton.styleFrom(minimumSize: const Size(64, 38)),
                              onPressed: () => _respond(inv['eventId'] as String, true),
                              child: const Text('Tham gia'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ).animate().fadeIn().slideY(begin: -0.2),
                ),
              // Khối lịch: tiêu đề tháng + Hôm nay + Tuần/Tháng, bên dưới là dải tuần hoặc lịch tháng (chỉ dựng phần đang hiện)
              AppCard(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                child: Column(
                  children: [
                    // Một hàng gọn: [‹ Tháng 12, 2026 ›] … [hôm nay] [Ngày|Tuần|Tháng]
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 42,
                            decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(21)),
                            child: Row(
                              children: [
                                _RoundBtn(icon: Icons.chevron_left_rounded, onTap: () => _shift(-1), flat: true),
                                Expanded(
                                  child: Tooltip(
                                    message: const ['Vuốt ngang để đổi tuần', 'Chạm ô trống để thêm · giữ lịch để kéo', 'Chạm một ngày để xem'][view],
                                    child: AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 250),
                                      transitionBuilder: (c, a) => FadeTransition(
                                        opacity: a,
                                        child: SlideTransition(
                                          position: Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(a),
                                          child: c,
                                        ),
                                      ),
                                      child: FittedBox(
                                        key: ValueKey('${day.year}-${day.month}'),
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          'Tháng ${day.month}, ${day.year}',
                                          maxLines: 1,
                                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                _RoundBtn(icon: Icons.chevron_right_rounded, onTap: () => _shift(1), flat: true),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                          child: isSameDay(day, DateTime.now())
                              ? const SizedBox.shrink()
                              : Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: Tooltip(
                                    message: 'Về hôm nay',
                                    child: Pressable(
                                      onTap: () => _select(dateOnly(DateTime.now())),
                                      child: Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.15), shape: BoxShape.circle),
                                        child: Icon(Icons.today_rounded, size: 18, color: scheme.primary),
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                        PillToggle<int>(
                          value: view,
                          values: const [0, 1, 2],
                          icons: const [Icons.view_day_rounded, Icons.view_week_rounded, Icons.calendar_month_rounded],
                          tips: const ['Ngày', 'Cả tuần', 'Tháng'],
                          onChanged: _setView,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Tuần ↔ tháng: chiều cao co giãn mượt + mờ chéo; lịch tháng là lưới tự vẽ (nhẹ, không dùng PageView) để không khựng
                    AnimatedSize(
                      duration: const Duration(milliseconds: 380),
                      curve: Curves.easeInOutCubic,
                      alignment: Alignment.topCenter,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        layoutBuilder: (cur, prev) => Stack(alignment: Alignment.topCenter, children: [...prev, ?cur]),
                        transitionBuilder: (c, a) => FadeTransition(
                          opacity: a,
                          child: ScaleTransition(scale: Tween(begin: 0.98, end: 1.0).animate(a), alignment: Alignment.topCenter, child: c),
                        ),
                        child: GestureDetector(
                          key: ValueKey(view),
                          onHorizontalDragEnd: (d) {
                            final v = d.primaryVelocity ?? 0;
                            if (v.abs() > 200) _shift(v < 0 ? 1 : -1);
                          },
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 280),
                            layoutBuilder: (cur, prev) => Stack(alignment: Alignment.topCenter, children: [...prev, ?cur]),
                            transitionBuilder: (c, a) {
                              final inc = c.key == ValueKey(monthView ? DateTime(day.year, day.month) : (view, start));
                              return FadeTransition(
                                opacity: a,
                                child: SlideTransition(
                                  position: Tween(begin: Offset((inc ? _dir : -_dir) * 0.25, 0), end: Offset.zero).animate(a),
                                  child: c,
                                ),
                              );
                            },
                            child: monthView
                                ? _MonthGrid(
                                    key: ValueKey(DateTime(day.year, day.month)),
                                    month: DateTime(day.year, day.month),
                                    selected: day,
                                    firstDayOfWeek: fdw,
                                    store: store,
                                    onSelect: _select,
                                  )
                                : view == 1
                                ? _WeekGrid(
                                    key: ValueKey((view, start)),
                                    start: start,
                                    selected: day,
                                    onOpenDay: (d) {
                                      _select(d);
                                      _setView(0);
                                    },
                                  )
                                : Row(
                                    key: ValueKey((view, start)),
                                    children: [for (var i = 0; i < 7; i++) Expanded(child: _weekCell(store, start.add(Duration(days: i))))],
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (view != 1)
                // Chuyển ngày: cả phần danh sách trượt theo hướng (ngày sau → từ phải, ngày trước → từ trái), từng thẻ hiện lần lượt
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  layoutBuilder: (cur, prev) => Stack(alignment: Alignment.topCenter, children: [...prev, ?cur]),
                  transitionBuilder: (c, a) {
                    final incoming = c.key == ValueKey(day);
                    return FadeTransition(
                      opacity: a,
                      child: SlideTransition(
                        position: Tween(begin: Offset((incoming ? _dir : -_dir) * 0.18, 0), end: Offset.zero).animate(a),
                        child: c,
                      ),
                    );
                  },
                  child: Column(
                    key: ValueKey(day),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SectionTitle(
                        Fmt.dayHeader(day),
                        trailing: items.isEmpty
                            ? null
                            : Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                                child: Text(
                                  '${items.length} lịch trình',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.primary),
                                ),
                              ),
                      ),
                      if (items.isEmpty)
                        const EmptyState(icon: Icons.event_available_rounded, title: 'Chưa có lịch trình', subtitle: 'Bấm nút + để lên kế hoạch cho ngày này')
                      else
                        for (final (i, (o, e)) in items.indexed)
                          _TimelineItem(occurrence: o, day: day, event: e, last: i == items.length - 1)
                              .animate(delay: (70 * i + 60).ms)
                              .fadeIn(duration: 320.ms)
                              .slideX(begin: 0.08 * _dir, end: 0, duration: 380.ms, curve: Curves.easeOutCubic),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lưới lịch tháng nhẹ: hàng tên thứ + 5–6 hàng ô vuông, mỗi ô dùng _EventDayCell.
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({super.key, required this.month, required this.selected, required this.firstDayOfWeek, required this.store, required this.onSelect});
  final DateTime month;
  final DateTime selected;
  final int firstDayOfWeek;
  final LocalStore store;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final look = CalendarLook.of(store);
    final today = dateOnly(DateTime.now());
    final lead = (month.weekday - firstDayOfWeek + 7) % 7;
    final first = month.subtract(Duration(days: lead));
    final days = DateTime(month.year, month.month + 1, 0).day;
    final rows = ((lead + days) / 7).ceil();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 26,
          child: Row(
            children: [for (var i = 0; i < 7; i++) Expanded(child: calendarDow(context, first.add(Duration(days: i)), look))],
          ),
        ),
        for (var r = 0; r < rows; r++)
          Row(
            children: [
              for (var c = 0; c < 7; c++)
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Builder(
                      builder: (context) {
                        final d = DateTime(first.year, first.month, first.day + r * 7 + c);
                        final outside = d.month != month.month;
                        final evs = outside ? const <(DateTime, EventRec)>[] : occurrencesIn(store, d, d.add(const Duration(days: 1)));
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            onSelect(d);
                          },
                          child: _EventDayCell(
                            day: d,
                            events: evs.map((x) => x.$2).toList(),
                            selected: isSameDay(d, selected),
                            isToday: d == today,
                            outside: outside,
                            look: look,
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({required this.icon, required this.onTap, this.flat = false});
  final IconData icon;
  final VoidCallback onTap;

  /// Không nền (nằm trong một khối đã có nền).
  final bool flat;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    child: Container(
      width: flat ? 38 : 34,
      height: flat ? 42 : 34,
      decoration: flat ? null : BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, shape: BoxShape.circle),
      child: Icon(icon, size: flat ? 26 : 22),
    ),
  );
}

class _TimelineItem extends ConsumerWidget {
  const _TimelineItem({required this.occurrence, required this.day, required this.event, required this.last});
  final DateTime occurrence;
  final DateTime day;
  final EventRec event;
  final bool last;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final color = hexColor(event.color, scheme.primary);
    final store = ref.watchTables(scheduleTables);
    final cat = ref.watch(financeProvider).category(event.categoryId);
    final idx = ScheduleIndex.of(store);
    final photos = idx.photosOf(event.id);
    final shared = idx.isShared(event.id);
    final subItems = eventItemsOn(store, event.id, day);
    final done = subItems.where((x) => x.isDone).length;
    final duration = event.endAt?.difference(event.startAt);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 52,
            child: Column(
              children: [
                Text(
                  event.isAllDay ? 'Cả\nngày' : Fmt.time(occurrence),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (duration != null && !event.isAllDay && duration.inHours < 24)
                  Text(Fmt.time(occurrence.add(duration)), style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          Column(
            children: [
              Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.only(top: 3),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withValues(alpha: 0.3), width: 3),
                ),
              ),
              if (!last) Expanded(child: Container(width: 2, color: scheme.outlineVariant)),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: OpenCard(
                page: EventDetailPage(id: event.id, occurrence: occurrence),
                padding: EdgeInsets.zero,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(left: BorderSide(color: color, width: 4)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(cat != null ? iconOf(cat.icon) : (_kinds[event.kind]?.$2 ?? Icons.event), size: 18, color: color),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(event.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                          ),
                          if (shared) const Icon(Icons.group_rounded, size: 16),
                          if (event.rrule != null) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.repeat_rounded, size: 16)),
                        ],
                      ),
                      if (cat != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            cat.name,
                            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
                          ),
                        ),
                      if (event.location?.isNotEmpty == true)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('📍 ${event.location}', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                        ),
                      if (subItems.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        for (final it in subItems.take(4))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Row(
                              children: [
                                Icon(
                                  it.isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                  size: 14,
                                  color: it.isDone ? AppColors.income : scheme.outline,
                                ),
                                const SizedBox(width: 6),
                                Text(timeStr(it.start), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    it.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12, decoration: it.isDone ? TextDecoration.lineThrough : null),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (subItems.length > 4) Text('+${subItems.length - 4} hoạt động', style: TextStyle(fontSize: 12, color: scheme.primary)),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: done / subItems.length,
                            minHeight: 4,
                            color: color,
                            backgroundColor: color.withValues(alpha: 0.15),
                          ),
                        ),
                      ],
                      if (photos.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 52,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              for (final p in photos.take(6))
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: SizedBox(width: 52, child: FileImage2(p.fileId, radius: 10)),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================ Thêm / sửa lịch trình

/// Viên chọn (pill) có hiệu ứng, dùng cho loại lịch, kiểu lặp, thứ trong tuần.
class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.selected, required this.onTap, this.color, this.round = false});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;
  final bool round;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = color ?? scheme.primary;
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: round ? 40 : null,
        height: 40,
        padding: round ? null : const EdgeInsets.symmetric(horizontal: 14),
        alignment: round ? Alignment.center : null,
        decoration: BoxDecoration(color: selected ? c : scheme.surfaceContainerHighest.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(16)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: selected ? Colors.white : scheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}

class EventEditPage extends ConsumerStatefulWidget {
  const EventEditPage({super.key, this.id, this.date, this.endDate, this.timed = false});
  final String? id;
  final DateTime? date;

  /// Giờ kết thúc khi tạo bằng cách quét khoảng giờ trên lưới tuần.
  final DateTime? endDate;

  /// true: [date] đã có giờ cụ thể (chạm vào ô giờ trên lưới tuần) → dùng đúng giờ đó.
  final bool timed;

  @override
  ConsumerState<EventEditPage> createState() => _EventEditPageState();
}

class _EventEditPageState extends ConsumerState<EventEditPage> {
  // Giải phóng tài nguyên khi đóng màn (tránh tích tụ khi mở/đóng nhiều lần)
  @override
  void dispose() {
    title.dispose();
    location.dispose();
    note.dispose();
    cost.dispose();
    super.dispose();
  }

  final title = TextEditingController();
  final location = TextEditingController();
  final note = TextEditingController();
  final cost = TextEditingController();
  late DateTime start;
  DateTime? end;
  bool allDay = false;
  int kind = 99;
  String? categoryId;
  Color color = AppColors.palette[5];
  String freq = 'NONE';
  Set<int> weekdays = {};
  DateTime? until;
  int? remind = 30;
  String? cover;

  @override
  void initState() {
    super.initState();
    final d = widget.date ?? DateTime.now();
    start = widget.timed ? d : DateTime(d.year, d.month, d.day, (DateTime.now().hour + 1).clamp(0, 23));
    if (widget.timed) end = widget.endDate ?? d.add(Duration(minutes: TimeConfig.of(ref.read(storeProvider)).defaultActivityMinutes));
    final rec = ref.read(storeProvider).get(E.events, widget.id);
    if (rec != null) {
      final e = EventRec(rec);
      title.text = e.title;
      location.text = e.location ?? '';
      note.text = e.note ?? '';
      cost.text = amountText(e.estimatedCost);
      start = e.startAt;
      end = e.endAt;
      allDay = e.isAllDay;
      kind = e.kind;
      categoryId = e.categoryId;
      color = hexColor(e.color, color);
      final r = Recurrence.parse(e.rrule);
      freq = r['FREQ'] ?? 'NONE';
      weekdays = r['BYDAY']?.split(',').map((x) => ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'].indexOf(x) + 1).toSet() ?? {};
      until = e.repeatUntil;
      remind = e.remindBefore;
      cover = e.coverFileId;
    } else {
      remind = TimeConfig.of(ref.read(storeProvider)).defaultRemind;
      // Lịch mới: chọn sẵn danh mục lịch trình đầu tiên và lấy màu của nó.
      final first = _eventCategories().firstOrNull;
      if (first != null) {
        categoryId = first.id;
        color = hexColor(first.color, color);
      }
    }
  }

  List<Category> _eventCategories() => ref.read(financeProvider).categories.where((c) => c.type == 3).toList();

  void _save() {
    if (title.text.trim().isEmpty) return showToast(context, 'Nhập tên lịch trình', error: true);
    if (end != null && end!.isBefore(start)) return showToast(context, 'Kết thúc phải sau bắt đầu', error: true);
    final store = ref.read(storeProvider);
    final existing = store.get(E.events, widget.id);
    final saved = store.put(E.events, {
      ...?existing,
      'title': title.text.trim(),
      'startAt': toIso8601WithOffset(start),
      'endAt': end != null ? toIso8601WithOffset(end!) : null,
      'isAllDay': allDay,
      'location': location.text.trim().isEmpty ? null : location.text.trim(),
      'note': note.text.trim().isEmpty ? null : note.text.trim(),
      'kind': kind,
      'categoryId': categoryId,
      'color': colorHex(color),
      'rRule': Recurrence.build(freq, weekdays: weekdays.toList()..sort()),
      'repeatUntil': until == null ? null : Fmt.isoDate(until!),
      'remindBeforeMinutes': remind,
      'coverFileId': cover,
      'estimatedCost': cost.text.isEmpty ? null : parseAmount(cost.text),
      'currencyCode': ref.read(financeProvider).baseCurrency,
    });
    HapticFeedback.lightImpact();
    if (widget.id == null) {
      context.pushReplacement('/schedule/detail', extra: {'id': saved['id'], 'occurrence': start});
    } else {
      Navigator.of(context).maybePop();
    }
  }

  String _remindLabel(int? m) => TimeConfig.remindLabel(m);

  String _short(DateTime d) => '${Fmt.weekdaysShort[d.weekday - 1]}, ${Fmt.dateShort(d)}${d.year == DateTime.now().year ? '' : '/${d.year}'}';

  Widget _head(IconData icon, String text, {Widget? trailing}) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 22, 2, 10),
    child: Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        ),
        ?trailing,
      ],
    ),
  );

  /// Ô thời gian lớn: ngày + giờ.
  Widget _timeBlock(String label, DateTime? d, VoidCallback onTap, {VoidCallback? onClear, String? duration}) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 98,
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          decoration: BoxDecoration(
            color: d == null ? scheme.surfaceContainerHigh : color.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: d == null ? scheme.outlineVariant.withValues(alpha: 0.6) : color.withValues(alpha: 0.45)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: d == null ? scheme.onSurfaceVariant : color),
                    ),
                  ),
                  if (d != null && onClear != null)
                    GestureDetector(
                      onTap: onClear,
                      child: Icon(Icons.close_rounded, size: 16, color: scheme.onSurfaceVariant),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Column(
                  key: ValueKey('$d$allDay'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d == null ? 'Không đặt' : (allDay ? Fmt.dateShort(d) : Fmt.time(d)),
                      style: TextStyle(fontSize: d == null ? 17 : 26, fontWeight: FontWeight.w900, color: d == null ? scheme.onSurfaceVariant : null),
                    ),
                    Text(
                      d == null ? 'Bấm để chọn' : '${_short(d)}${duration != null ? ' · $duration' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, bool on, VoidCallback onTap, {IconData? icon}) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Pressable(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: on ? color : scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
            boxShadow: on ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 3))] : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 16, color: on ? Colors.white : scheme.onSurfaceVariant), const SizedBox(width: 6)],
              Text(
                label,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: on ? Colors.white : null),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cats = ref.watch(financeProvider).categories.where((c) => c.type == 3).toList();
    final cat = cats.where((c) => c.id == categoryId).firstOrNull;
    final mins = end == null ? null : end!.difference(start).inMinutes;
    final remindOpts = [-1, ...TimeConfig.of(ref.read(storeProvider)).remindOptions];

    return Scaffold(
      appBar: AppBar(title: Text(widget.id == null ? 'Lịch trình mới' : 'Sửa lịch trình')),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Pressable(
          onTap: _save,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(colors: [heroOf(color), accentOf(heroOf(color), hue: 20)]),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  widget.id == null ? 'Tạo lịch trình' : 'Lưu thay đổi',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          // ---------- Bìa + tên (gõ thẳng trên bìa)
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            height: cover == null ? 168 : 210,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [heroOf(color), accentOf(heroOf(color), hue: 25)]),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (cover != null) FileImage2(cover!, radius: 0),
                // Lớp tối phía dưới cho chữ dễ đọc
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.05),
                        Colors.black.withValues(alpha: cover == null ? 0.15 : 0.55),
                      ],
                    ),
                  ),
                ),
                if (cover == null) Positioned(right: -20, top: -20, child: Icon(iconOf(cat?.icon), size: 150, color: Colors.white.withValues(alpha: 0.12))),
                Positioned(
                  left: 14,
                  top: 14,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Container(
                      key: ValueKey(cat?.id),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(iconOf(cat?.icon), size: 15, color: Colors.white),
                          const SizedBox(width: 5),
                          Text(
                            cat?.name ?? 'Lịch trình',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: Pressable(
                    onTap: () async {
                      final ids = await pickPhotos(context, ref, multiple: false);
                      if (ids.isNotEmpty) setState(() => cover = ids.first);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_photo_alternate_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 5),
                          Text(
                            cover == null ? 'Ảnh bìa' : 'Đổi ảnh',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 10,
                  child: TextField(
                    controller: title,
                    autofocus: widget.id == null,
                    cursorColor: Colors.white,
                    maxLines: 2,
                    minLines: 1,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, height: 1.15),
                    decoration: InputDecoration(
                      hintText: 'Tên lịch trình…',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 26, fontWeight: FontWeight.w900),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ---------- Danh mục (cuộn ngang, nhấn giữ để sửa)
          _head(
            Icons.category_rounded,
            'Loại lịch trình',
            trailing: Text('Nhấn giữ để sửa', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
          ),
          SizedBox(
            height: 88,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final (i, c) in cats.indexed)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onLongPress: () => editCategory(context, ref, type: 3, existing: c),
                      child: Pressable(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            categoryId = c.id;
                            color = hexColor(c.color, color);
                          });
                        },
                        child: Builder(
                          builder: (_) {
                            final on = categoryId == c.id;
                            final cc = hexColor(c.color, color);
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              width: 78,
                              decoration: BoxDecoration(
                                color: on ? cc.withValues(alpha: 0.18) : scheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: on ? cc : Colors.transparent, width: 1.6),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AnimatedScale(
                                    scale: on ? 1.1 : 1,
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeOutBack,
                                    child: CircleIcon(icon: c.icon, color: cc, size: 36),
                                  ),
                                  const SizedBox(height: 6),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: Text(
                                      c.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 11.5, fontWeight: on ? FontWeight.w800 : FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ).stagger(i),
                  ),
                Pressable(
                  onTap: () async {
                    final before = cats.map((c) => c.id).toSet();
                    await editCategory(context, ref, type: 3);
                    final added = _eventCategories().where((c) => !before.contains(c.id)).firstOrNull;
                    if (added != null) {
                      setState(() {
                        categoryId = added.id;
                        color = hexColor(added.color, color);
                      });
                    }
                  },
                  child: Container(
                    width: 78,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded, color: scheme.onSurfaceVariant),
                        const SizedBox(height: 6),
                        Text('Thêm', style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ---------- Thời gian
          _head(
            Icons.schedule_rounded,
            'Thời gian',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Cả ngày', style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
                const SizedBox(width: 6),
                Transform.scale(
                  scale: 0.85,
                  child: Switch(value: allDay, onChanged: (v) => setState(() => allDay = v)),
                ),
              ],
            ),
          ),
          Row(
            children: [
              _timeBlock('Bắt đầu', start, () async {
                final d = await pickDateTime(context, start, withTime: !allDay, title: 'Bắt đầu');
                if (d != null) {
                  setState(() {
                    // Dời cả giờ kết thúc theo để giữ nguyên thời lượng
                    if (end != null) end = d.add(end!.difference(start));
                    start = d;
                  });
                }
              }),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.arrow_forward_rounded, size: 18, color: scheme.onSurfaceVariant),
              ),
              _timeBlock(
                'Kết thúc',
                end,
                () async {
                  final d = await pickDateTime(
                    context,
                    end ?? start.add(const Duration(hours: 1)),
                    withTime: !allDay,
                    firstDate: dateOnly(start),
                    title: 'Kết thúc',
                  );
                  if (d != null) setState(() => end = d);
                },
                onClear: () => setState(() => end = null),
                duration: mins != null && mins > 0 ? (allDay ? '${(mins / 1440).ceil()} ngày' : durationText(mins)) : null,
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final (label, d)
                    in allDay
                        ? [
                            ('1 ngày', const Duration(days: 0)),
                            ('2 ngày', const Duration(days: 1)),
                            ('3 ngày', const Duration(days: 2)),
                            ('1 tuần', const Duration(days: 6)),
                          ]
                        : [
                            ('30 phút', const Duration(minutes: 30)),
                            ('1 giờ', const Duration(hours: 1)),
                            ('2 giờ', const Duration(hours: 2)),
                            ('Nửa ngày', const Duration(hours: 4)),
                          ])
                  _chip(label, end != null && end!.difference(start) == d, () => setState(() => end = start.add(d))),
              ],
            ),
          ),

          // ---------- Nhắc
          _head(
            Icons.notifications_active_rounded,
            'Nhắc trước',
            trailing: TextButton(onPressed: () => context.push('/settings/time'), child: const Text('Sửa mốc')),
          ),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final m in remindOpts)
                  _chip(
                    m == -1 ? 'Không nhắc' : _remindLabel(m).replaceFirst('Trước ', ''),
                    m == -1 ? remind == null : remind == m,
                    () => setState(() => remind = m == -1 ? null : m),
                    icon: m == -1 ? Icons.notifications_off_rounded : null,
                  ),
              ],
            ),
          ),

          // ---------- Lặp lại
          _head(Icons.repeat_rounded, 'Lặp lại'),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final e in {'NONE': 'Không lặp', 'DAILY': 'Mỗi ngày', 'WEEKLY': 'Mỗi tuần', 'MONTHLY': 'Mỗi tháng', 'YEARLY': 'Mỗi năm'}.entries)
                  _chip(e.value, freq == e.key, () => setState(() => freq = e.key)),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            child: Column(
              children: [
                if (freq == 'WEEKLY')
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (var i = 1; i <= 7; i++)
                          _Pill(
                            label: Fmt.weekdaysShort[i - 1],
                            round: true,
                            color: color,
                            selected: weekdays.contains(i),
                            onTap: () => setState(() => weekdays.contains(i) ? weekdays.remove(i) : weekdays.add(i)),
                          ),
                      ],
                    ),
                  ),
                if (freq == 'MONTHLY')
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Lặp vào ngày ${start.day} hằng tháng', style: TextStyle(color: scheme.onSurfaceVariant)),
                    ),
                  ),
                if (freq != 'NONE')
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                      child: InfoTile(
                        icon: Icons.event_busy_rounded,
                        label: 'Lặp đến',
                        value: until == null ? 'Mãi mãi' : Fmt.date(until!),
                        color: color,
                        onTap: () async {
                          final d = await pickDateTime(context, until ?? start.add(const Duration(days: 30)), withTime: false, title: 'Lặp đến ngày');
                          setState(() => until = d);
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ---------- Chi tiết
          _head(Icons.notes_rounded, 'Chi tiết'),
          FormSection(
            children: [
              SectionField(controller: location, hint: 'Địa điểm', icon: Icons.place_rounded),
              SectionField(
                controller: cost,
                hint: 'Chi phí dự kiến',
                icon: Icons.payments_rounded,
                keyboardType: TextInputType.number,
                inputFormatters: const [ThousandsInputFormatter()],
              ),
              SectionField(controller: note, hint: 'Ghi chú', icon: Icons.edit_note_rounded, maxLines: 4),
            ],
          ),

          _head(Icons.palette_rounded, 'Màu'),
          AppCard(
            padding: const EdgeInsets.all(14),
            child: ColorPickerRow(value: color, onChanged: (c) => setState(() => color = c)),
          ),

          if (widget.id == null)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  Icon(Icons.tips_and_updates_rounded, color: color, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tạo xong bạn có thể thêm các hoạt động theo giờ trong ngày (ăn sáng, di chuyển, tham quan…)',
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================ Hoạt động theo giờ

Future<(int, int)?> _pickTime(BuildContext context, (int, int) initial) async {
  final t = await showModernTimePicker(
    context,
    initial: TimeOfDay(hour: initial.$1, minute: initial.$2),
  );
  return t == null ? null : (t.hour, t.minute);
}

/// Thêm / sửa một hoạt động theo giờ.
Future<void> editEventItem(
  BuildContext context,
  WidgetRef ref, {
  required EventRec event,
  required DateTime day,
  EventItemRec? item,
  (int, int)? suggestStart,
  (int, int)? suggestEnd,
}) async {
  final title = TextEditingController(text: item?.title);
  final location = TextEditingController(text: item?.location);
  final note = TextEditingController(text: item?.note);
  final cost = TextEditingController(text: amountText(item?.cost));
  final cfg = TimeConfig.of(ref.read(storeProvider));
  var start = item?.start ?? suggestStart ?? (cfg.dayStartHour, 0);
  (int, int)? end = item?.end;
  if (item == null && suggestEnd != null) {
    end = suggestEnd;
  } else if (item == null && cfg.defaultActivityMinutes > 0) {
    final m = (start.$1 * 60 + start.$2 + cfg.defaultActivityMinutes).clamp(0, 23 * 60 + 59);
    end = (m ~/ 60, m % 60);
  }
  var icon = item?.icon ?? 'event';
  final color = hexColor(event.color, Theme.of(context).colorScheme.primary);
  // Ảnh của hoạt động: chỉ ghi vào kho khi bấm Lưu/Thêm.
  final itemId = item?.id ?? newId();
  final oldPhotos = ref.read(storeProvider).all(E.eventPhotos).map(EventPhoto.new).where((p) => p.eventItemId == itemId).toList();
  final photoIds = [for (final p in oldPhotos) p.fileId];

  await showModalBottomSheet(
    sheetAnimationStyle: kSheetAnim,
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item == null ? 'Thêm hoạt động · ${Fmt.dayHeader(day)}' : 'Sửa hoạt động',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _TimeBox(
                      label: 'Bắt đầu',
                      value: timeStr(start),
                      color: color,
                      onTap: () async {
                        final t = await _pickTime(ctx, start);
                        if (t != null) set(() => start = t);
                      },
                    ),
                  ),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Icon(Icons.arrow_forward_rounded)),
                  Expanded(
                    child: _TimeBox(
                      label: 'Kết thúc',
                      value: end == null ? '--:--' : timeStr(end!),
                      color: color,
                      onTap: () async {
                        final t = await _pickTime(ctx, end ?? ((start.$1 + 1) % 24, start.$2));
                        if (t != null) set(() => end = t);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: title,
                autofocus: item == null,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                decoration: const InputDecoration(hintText: 'Làm gì? (VD: Ăn sáng phở)'),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    // Mẫu hoạt động do người dùng cấu hình (Danh mục → Hoạt động)
                    for (final t in ref.read(financeProvider).categories.where((c) => c.type == 4))
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          avatar: Icon(iconOf(t.icon), size: 16, color: hexColor(t.color)),
                          label: Text(t.name),
                          onPressed: () => set(() {
                            title.text = t.name;
                            icon = t.icon ?? 'event';
                          }),
                        ),
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.tune_rounded, size: 16),
                      label: const Text('Sửa mẫu'),
                      onPressed: () => GoRouter.of(ctx).push('/categories', extra: {'type': 4}),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              FormSection(
                children: [
                  SectionField(controller: location, hint: 'Địa điểm', icon: Icons.place_rounded),
                  SectionField(
                    controller: cost,
                    hint: 'Chi phí',
                    icon: Icons.payments_rounded,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [ThousandsInputFormatter()],
                  ),
                  SectionField(controller: note, hint: 'Ghi chú', icon: Icons.notes_rounded, maxLines: 3),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(Icons.photo_library_rounded, size: 18, color: color),
                  const SizedBox(width: 6),
                  Text('Ảnh${photoIds.isEmpty ? '' : ' · ${photoIds.length}'}', style: const TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 8),
              PhotoGrid(
                size: 76,
                fileIds: photoIds,
                onAdd: () async {
                  final ids = await pickPhotos(ctx, ref);
                  if (ids.isNotEmpty) set(() => photoIds.addAll(ids));
                },
                onRemove: (id) => set(() => photoIds.remove(id)),
              ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                  if (item != null)
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: AppColors.expense),
                      onPressed: () {
                        final store = ref.read(storeProvider);
                        for (final p in oldPhotos) {
                          store.remove(E.eventPhotos, p.id);
                        }
                        store.remove(E.eventItems, item.id);
                        Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Xoá'),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () {
                      if (title.text.trim().isEmpty) return showToast(ctx, 'Nhập tên hoạt động', error: true);
                      final store = ref.read(storeProvider);
                      store.put(E.eventItems, {
                        ...?item?.m,
                        'id': itemId,
                        'eventId': event.id,
                        'occurrenceDate': Fmt.isoDate(day),
                        'startTime': timeIso(start),
                        'endTime': end == null ? null : timeIso(end!),
                        'title': title.text.trim(),
                        'location': location.text.trim().isEmpty ? null : location.text.trim(),
                        'note': note.text.trim().isEmpty ? null : note.text.trim(),
                        'cost': cost.text.trim().isEmpty ? null : parseAmount(cost.text),
                        'icon': icon,
                        'isDone': item?.isDone ?? false,
                        'sortOrder': 0,
                        'addedByUserId': item?.m['addedByUserId'] ?? ref.read(sessionProvider).userId ?? '00000000-0000-0000-0000-000000000000',
                      });
                      for (final p in oldPhotos) {
                        if (!photoIds.contains(p.fileId)) store.remove(E.eventPhotos, p.id);
                      }
                      final had = {for (final p in oldPhotos) p.fileId};
                      for (final (i, fid) in photoIds.indexed) {
                        if (had.contains(fid)) continue;
                        store.put(E.eventPhotos, {
                          'eventId': event.id,
                          'eventItemId': itemId,
                          'fileId': fid,
                          'occurrenceDate': Fmt.isoDate(day),
                          'addedByUserId': ref.read(sessionProvider).userId ?? '00000000-0000-0000-0000-000000000000',
                          'sortOrder': i,
                        });
                      }
                      HapticFeedback.lightImpact();
                      Navigator.pop(ctx);
                    },
                    child: Text(item == null ? 'Thêm' : 'Lưu'),
                  ),
                ],
              ),
          ],
        ),
      ),
    ),
  );
}

class _TimeBox extends StatelessWidget {
  const _TimeBox({required this.label, required this.value, required this.color, required this.onTap});
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    ),
  );
}

String durationText(int minutes) {
  if (minutes < 60) return '$minutes phút';
  final h = minutes ~/ 60, m = minutes % 60;
  return m == 0 ? '$h giờ' : '$h giờ $m phút';
}

int _endMin(EventItemRec it) => it.end == null ? it.startMinutes + 60 : (it.end!.$1 * 60 + it.end!.$2).clamp(it.startMinutes + 15, 24 * 60);

/// Thẻ trạng thái: đang diễn ra / tiếp theo / đã xong, tự cập nhật theo phút.
class DayStatusCard extends StatelessWidget {
  const DayStatusCard({super.key, required this.items, required this.day, required this.now, required this.color});
  final List<EventItemRec> items;
  final DateTime day;
  final DateTime now;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = dateOnly(now);
    final nowMin = now.hour * 60 + now.minute;
    final done = items.where((i) => i.isDone).length;
    IconData icon = Icons.schedule_rounded;
    String title;
    String? sub;
    double? progress;

    if (items.isEmpty) {
      title = 'Chưa có hoạt động';
      sub = 'Chạm vào trục giờ để thêm · nhấn giữ rồi kéo để chọn khoảng giờ';
    } else if (dateOnly(day).isAfter(today)) {
      final d = dateOnly(day).difference(today).inDays;
      icon = Icons.hourglass_top_rounded;
      title = d == 1 ? 'Ngày mai bắt đầu lúc ${timeStr(items.first.start)}' : 'Còn $d ngày nữa';
      sub = 'Hoạt động đầu tiên: ${items.first.title}';
    } else if (dateOnly(day).isBefore(today)) {
      icon = Icons.history_rounded;
      title = 'Đã qua · hoàn thành $done/${items.length}';
    } else {
      final current = items.where((i) => !i.isDone && i.startMinutes <= nowMin && nowMin < _endMin(i)).firstOrNull;
      final next = items.where((i) => !i.isDone && i.startMinutes > nowMin).firstOrNull;
      if (current != null) {
        icon = Icons.play_circle_fill_rounded;
        title = 'Đang diễn ra: ${current.title}';
        sub = 'Còn ${durationText(_endMin(current) - nowMin)}${next != null ? ' · tiếp theo ${next.title} lúc ${timeStr(next.start)}' : ''}';
        progress = (nowMin - current.startMinutes) / (_endMin(current) - current.startMinutes);
      } else if (next != null) {
        icon = Icons.skip_next_rounded;
        title = 'Tiếp theo: ${next.title}';
        sub = 'Lúc ${timeStr(next.start)} · còn ${durationText(next.startMinutes - nowMin)}';
      } else {
        icon = Icons.celebration_rounded;
        title = 'Đã xong các hoạt động hôm nay 🎉';
      }
    }

    return AppCard(
      gradient: LinearGradient(colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0.08)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 22),
              ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(begin: 1, end: progress != null ? 1.08 : 1, duration: 900.ms).isolated(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    if (sub != null) Text(sub, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              if (items.isNotEmpty)
                Column(
                  children: [
                    Text(
                      '$done/${items.length}',
                      style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 16),
                    ),
                    Text('xong', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                  ],
                ),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress.clamp(0, 1)),
                duration: const Duration(milliseconds: 800),
                builder: (_, v, __) => LinearProgressIndicator(value: v, minHeight: 6, color: color, backgroundColor: color.withValues(alpha: 0.15)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Timeline theo trục giờ của 1 ngày: hoạt động đặt đúng giờ, cao theo thời lượng; vạch đỏ "Bây giờ" chạy theo từng phút.
/// Chạm vào chỗ trống để thêm hoạt động đúng giờ đó.
class DayTimeline extends ConsumerStatefulWidget {
  const DayTimeline({super.key, required this.event, required this.day});
  final EventRec event;
  final DateTime day;

  @override
  ConsumerState<DayTimeline> createState() => _DayTimelineState();
}

class _DayTimelineState extends ConsumerState<DayTimeline> {
  static const hourH = 88.0;
  static const labelW = 46.0;
  late Timer _tick;
  DateTime now = DateTime.now();

  // Kéo để chọn khoảng giờ trống
  int? _selFrom, _selTo;
  // Kéo để dời / đổi thời lượng hoạt động
  String? _dragId;
  bool _resizing = false;
  double _dragStartY = 0;
  int _dragDelta = 0;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) => setState(() => now = DateTime.now()));
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  late int _startH;
  late int _endH;
  late int _snap;

  /// Vị trí dọc → phút trong ngày, làm tròn theo bước cấu hình.
  int minuteAt(double dy, {bool floor = false}) {
    final raw = _startH * 60 + dy / hourH * 60;
    final m = floor ? (raw ~/ _snap) * _snap : (raw / _snap).round() * _snap;
    return m.clamp(_startH * 60, _endH * 60);
  }

  void _updateDrag(double globalY, int snap) {
    final d = (((globalY - _dragStartY) / hourH * 60) / snap).round() * snap;
    if (d != _dragDelta) {
      HapticFeedback.selectionClick();
      setState(() => _dragDelta = d);
    }
  }

  void _finishDrag(LocalStore store, EventItemRec it) {
    final delta = _dragDelta, resizing = _resizing;
    setState(() {
      _dragId = null;
      _dragDelta = 0;
    });
    if (delta == 0) return;
    final dur = _endMin(it) - it.startMinutes;
    if (resizing) {
      final end = (_endMin(it) + delta).clamp(it.startMinutes + _snap, 24 * 60 - 1);
      store.put(E.eventItems, {...it.m, 'endTime': timeIso((end ~/ 60, end % 60))});
    } else {
      final start = (it.startMinutes + delta).clamp(0, 24 * 60 - dur);
      final end = (start + dur).clamp(0, 24 * 60 - 1);
      store.put(E.eventItems, {...it.m, 'startTime': timeIso((start ~/ 60, start % 60)), if (it.end != null) 'endTime': timeIso((end ~/ 60, end % 60))});
    }
    HapticFeedback.lightImpact();
  }

  Widget _timePill(int from, int to, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
    child: Text(
      '${timeStr((from ~/ 60, from % 60))} – ${timeStr(((to ~/ 60).clamp(0, 24), to % 60))}',
      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final store = ref.watchTables(scheduleTables);
    final f = ref.watch(financeProvider);
    final scheme = Theme.of(context).colorScheme;
    final e = widget.event;
    final color = hexColor(e.color, scheme.primary);
    final items = eventItemsOn(store, e.id, widget.day);
    final itemPhotos = <String, List<String>>{};
    for (final p in store.all(E.eventPhotos).map(EventPhoto.new)) {
      final iid = p.eventItemId;
      if (iid != null) (itemPhotos[iid] ??= []).add(p.fileId);
    }
    final isToday = isSameDay(now, widget.day);
    final nowMin = now.hour * 60 + now.minute;

    // Khoảng giờ hiển thị: bao các hoạt động, giờ của lịch trình và giờ hiện tại (nếu là hôm nay).
    final marks = <int>[
      for (final i in items) ...[i.startMinutes, _endMin(i)],
      if (!e.isAllDay && isSameDay(e.startAt, widget.day)) e.startAt.hour * 60 + e.startAt.minute,
      if (isToday) nowMin,
    ];
    final cfg = TimeConfig.of(store);
    marks.addAll([cfg.dayStartHour * 60 + 60, cfg.dayEndHour * 60 - 60]); // khung giờ người dùng cấu hình
    var startH = (marks.reduce((a, b) => a < b ? a : b) ~/ 60 - 1).clamp(0, 23);
    var endH = ((marks.reduce((a, b) => a > b ? a : b) + 59) ~/ 60 + 1).clamp(1, 24);
    if (endH - startH < 6) endH = (startH + 6).clamp(1, 24);
    if (endH - startH < 6) startH = (endH - 6).clamp(0, 23);
    _startH = startH;
    _endH = endH;
    _snap = cfg.snapMinutes;
    double y(int min) => (min - startH * 60) / 60 * hourH;
    final height = (endH - startH) * hourH;

    // Xếp làn cho hoạt động trùng giờ.
    final laneOf = <String, int>{};
    final laneEnds = <int>[];
    for (final it in items) {
      var lane = laneEnds.indexWhere((end) => end <= it.startMinutes);
      if (lane == -1) {
        laneEnds.add(_endMin(it));
        lane = laneEnds.length - 1;
      } else {
        laneEnds[lane] = _endMin(it);
      }
      laneOf[it.id] = lane;
    }
    final lanes = laneEnds.isEmpty ? 1 : laneEnds.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DayStatusCard(items: items, day: widget.day, now: now, color: color),
        const SizedBox(height: 14),
        AppCard(
          padding: const EdgeInsets.fromLTRB(8, 12, 12, 12),
          child: LayoutBuilder(
            builder: (context, box) {
              final laneW = (box.maxWidth - labelW - 8) / lanes;
              return SizedBox(
                height: height + 8,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Vạch giờ
                    for (var h = startH; h <= endH; h++)
                      Positioned(
                        top: y(h * 60) - 7,
                        left: 0,
                        right: 0,
                        child: Row(
                          children: [
                            SizedBox(
                              width: labelW,
                              child: Text(
                                '${h.toString().padLeft(2, '0')}:00',
                                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant, fontFeatures: const [FontFeature.tabularFigures()]),
                              ),
                            ),
                            Expanded(child: Container(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.5))),
                          ],
                        ),
                      ),
                    for (var h = startH; h < endH; h++)
                      Positioned(
                        top: y(h * 60 + 30),
                        left: labelW + 8,
                        right: 0,
                        child: Container(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.18)),
                      ),
                    // Vùng chạm để thêm hoạt động: chạm = thêm đúng giờ; nhấn giữ rồi kéo = chọn khoảng giờ
                    Positioned(
                      left: labelW,
                      right: 0,
                      top: 0,
                      height: height,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (d) {
                          final m = minuteAt(d.localPosition.dy, floor: true);
                          HapticFeedback.selectionClick();
                          editEventItem(context, ref, event: e, day: widget.day, suggestStart: (m ~/ 60, m % 60));
                        },
                        onLongPressStart: (d) {
                          HapticFeedback.mediumImpact();
                          final m = minuteAt(d.localPosition.dy, floor: true);
                          setState(() {
                            _selFrom = m;
                            _selTo = (m + cfg.snapMinutes).clamp(0, endH * 60);
                          });
                        },
                        onLongPressMoveUpdate: (d) {
                          final m = minuteAt(d.localPosition.dy);
                          if (m != _selTo) HapticFeedback.selectionClick();
                          setState(() => _selTo = m);
                        },
                        onLongPressEnd: (_) {
                          final a = _selFrom, b = _selTo;
                          setState(() => _selFrom = _selTo = null);
                          if (a == null || b == null) return;
                          final from = a < b ? a : b;
                          var to = a < b ? b : a;
                          if (to - from < cfg.snapMinutes) to = from + cfg.snapMinutes;
                          editEventItem(
                            context,
                            ref,
                            event: e,
                            day: widget.day,
                            suggestStart: (from ~/ 60, from % 60),
                            suggestEnd: ((to ~/ 60).clamp(0, 23), to >= 24 * 60 ? 59 : to % 60),
                          );
                        },
                      ),
                    ),
                    // Khối đang chọn khi kéo
                    if (_selFrom != null && _selTo != null)
                      Positioned(
                        left: labelW + 6,
                        right: 0,
                        top: y(_selFrom! < _selTo! ? _selFrom! : _selTo!),
                        height: ((_selTo! - _selFrom!).abs() / 60 * hourH).clamp(4, 5000),
                        child: IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: color, width: 2),
                            ),
                            alignment: Alignment.topLeft,
                            padding: const EdgeInsets.all(8),
                            child: _timePill(_selFrom! < _selTo! ? _selFrom! : _selTo!, _selFrom! < _selTo! ? _selTo! : _selFrom!, color),
                          ),
                        ),
                      ),
                    // Phần đã qua trong ngày hôm nay được phủ mờ
                    if (isToday && nowMin > startH * 60)
                      Positioned(
                        left: labelW,
                        right: 0,
                        top: 0,
                        height: y(nowMin.clamp(startH * 60, endH * 60)),
                        child: IgnorePointer(child: Container(color: scheme.onSurface.withValues(alpha: 0.03))),
                      ),
                    // Các hoạt động: nhấn giữ rồi kéo để dời giờ; kéo thanh dưới cùng để đổi thời lượng
                    for (final (i, it) in items.indexed)
                      (() {
                        final dragging = _dragId == it.id;
                        var s0 = it.startMinutes, e0 = _endMin(it);
                        if (dragging && !_resizing) {
                          s0 = (s0 + _dragDelta).clamp(0, 24 * 60 - (e0 - s0));
                          e0 = s0 + (_endMin(it) - it.startMinutes);
                        } else if (dragging && _resizing) {
                          e0 = (e0 + _dragDelta).clamp(s0 + cfg.snapMinutes, 24 * 60);
                        }
                        return AnimatedPositioned(
                          duration: Duration(milliseconds: dragging ? 0 : 250),
                          curve: Curves.easeOutCubic,
                          top: y(s0) + 1,
                          left: labelW + 6 + laneOf[it.id]! * laneW,
                          width: laneW - 6,
                          height: ((e0 - s0) / 60 * hourH - 3).clamp(34, 5000),
                          child: GestureDetector(
                            onLongPressStart: (d) {
                              HapticFeedback.mediumImpact();
                              setState(() {
                                _dragId = it.id;
                                _resizing = false;
                                _dragStartY = d.globalPosition.dy;
                                _dragDelta = 0;
                              });
                            },
                            onLongPressMoveUpdate: (d) => _updateDrag(d.globalPosition.dy, cfg.snapMinutes),
                            onLongPressEnd: (_) => _finishDrag(store, it),
                            child: AnimatedScale(
                              scale: dragging && !_resizing ? 1.03 : 1,
                              duration: const Duration(milliseconds: 150),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child:
                                        _TimelineBlock(
                                              item: it,
                                              photos: itemPhotos[it.id] ?? const [],
                                              color: color,
                                              money: (v) => f.money(v),
                                              past: (isToday && _endMin(it) <= nowMin) || dateOnly(widget.day).isBefore(dateOnly(now)),
                                              current: isToday && it.startMinutes <= nowMin && nowMin < _endMin(it),
                                              onTap: () => editEventItem(context, ref, event: e, day: widget.day, item: it),
                                              onToggle: () {
                                                HapticFeedback.selectionClick();
                                                store.put(E.eventItems, {...it.m, 'isDone': !it.isDone});
                                              },
                                              onExpense: it.cost == null
                                                  ? null
                                                  : () => context.push(
                                                      '/tx/edit',
                                                      extra: {'type': 1, 'amount': it.cost!.round(), 'note': '${e.title} · ${it.title}', 'eventId': e.id},
                                                    ),
                                            )
                                            .animate()
                                            .fadeIn(delay: (50 * i).ms, duration: 350.ms)
                                            .slideX(begin: 0.08, end: 0, delay: (50 * i).ms, curve: Curves.easeOutCubic),
                                  ),
                                  // Thanh kéo đổi thời lượng
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 0,
                                    height: 16,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onVerticalDragStart: (d) {
                                        HapticFeedback.selectionClick();
                                        setState(() {
                                          _dragId = it.id;
                                          _resizing = true;
                                          _dragStartY = d.globalPosition.dy;
                                          _dragDelta = 0;
                                        });
                                      },
                                      onVerticalDragUpdate: (d) => _updateDrag(d.globalPosition.dy, cfg.snapMinutes),
                                      onVerticalDragEnd: (_) => _finishDrag(store, it),
                                      child: MouseRegion(
                                        cursor: SystemMouseCursors.resizeUpDown,
                                        child: Center(
                                          child: Container(
                                            width: 28,
                                            height: 4,
                                            decoration: BoxDecoration(color: color.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(2)),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (dragging) Positioned(right: 30, top: 4, child: _timePill(s0, e0, color)),
                                ],
                              ),
                            ),
                          ),
                        );
                      })(),
                    // Vạch "Bây giờ"
                    if (isToday && nowMin >= startH * 60 && nowMin <= endH * 60)
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutCubic,
                        top: y(nowMin) - 10,
                        left: 0,
                        right: 0,
                        child: IgnorePointer(
                          child: Row(
                            children: [
                              Container(
                                width: labelW,
                                padding: const EdgeInsets.symmetric(vertical: 3),
                                decoration: BoxDecoration(color: AppColors.expense, borderRadius: BorderRadius.circular(8)),
                                alignment: Alignment.center,
                                child: Text(
                                  Fmt.time(now),
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                                ),
                              ),
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(color: AppColors.expense, shape: BoxShape.circle),
                              ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(begin: 0.8, end: 1.4, duration: 700.ms).isolated(),
                              Expanded(child: Container(height: 2, color: AppColors.expense)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.touch_app_rounded, size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Flexible(
                  child: Text('Chạm vào trục giờ để thêm · nhấn giữ rồi kéo để chọn khoảng', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                ),
              ],
            ),
          ),
        FilledButton.tonalIcon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
          onPressed: () {
            final last = items.lastOrNull;
            final m = last == null ? (isToday ? ((nowMin ~/ cfg.snapMinutes) + 1) * cfg.snapMinutes : cfg.dayStartHour * 60) : _endMin(last);
            editEventItem(context, ref, event: e, day: widget.day, suggestStart: ((m ~/ 60).clamp(0, 23), m % 60));
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text('Thêm hoạt động'),
        ),
      ],
    );
  }
}

class _TimelineBlock extends StatelessWidget {
  const _TimelineBlock({
    required this.item,
    required this.photos,
    required this.color,
    required this.money,
    required this.past,
    required this.current,
    required this.onTap,
    required this.onToggle,
    this.onExpense,
  });
  final EventItemRec item;
  final List<String> photos;
  final Color color;
  final String Function(num) money;
  final bool past;
  final bool current;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback? onExpense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final done = item.isDone;
    final dim = (past || done) && !current;
    final minutes = (item.end == null ? 60 : (item.end!.$1 * 60 + item.end!.$2) - item.startMinutes).clamp(0, 24 * 60);
    return Pressable(
      scale: 0.97,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: current
                ? [color.withValues(alpha: 0.42), color.withValues(alpha: 0.22)]
                : dim
                ? [color.withValues(alpha: 0.10), color.withValues(alpha: 0.04)]
                : [color.withValues(alpha: 0.24), color.withValues(alpha: 0.10)],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border(left: BorderSide(color: dim ? color.withValues(alpha: 0.5) : color, width: 4)),
          boxShadow: current ? [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 14)] : null,
        ),
        child: LayoutBuilder(
          builder: (context, box) {
            final compact = box.maxHeight < 48;
            final tall = box.maxHeight >= 110;
            // Đủ chỗ thì hiện dải ảnh; khối thấp chỉ hiện chồng ảnh nhỏ cạnh nút hoàn thành.
            final strip = photos.isNotEmpty && box.maxHeight >= 150;
            final time = '${timeStr(item.start)}${item.end != null ? ' – ${timeStr(item.end!)}' : ''}';
            final titleStyle = TextStyle(
              fontWeight: FontWeight.w800,
              decoration: done ? TextDecoration.lineThrough : null,
              decorationColor: scheme.onSurfaceVariant,
              color: dim ? scheme.onSurface.withValues(alpha: 0.6) : null,
            );
            // Nội dung trên cùng được cắt gọn theo chiều cao khối (không bao giờ tràn)
            final head = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: dim ? 0.15 : 0.28),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(iconOf(item.icon ?? 'event'), size: 14, color: color),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(compact ? '${item.title} · $time' : item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: titleStyle),
                    ),
                    if (photos.isNotEmpty && !strip && !compact) ...[_PhotoStack(ids: photos, color: color), const SizedBox(width: 6)],
                    Pressable(
                      onTap: onToggle,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                        child: Icon(
                          done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                          key: ValueKey(done),
                          size: 22,
                          color: done ? AppColors.income : scheme.outline,
                        ),
                      ),
                    ),
                  ],
                ),
                if (!compact) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (item.location != null) ...[
                        Text('  ·  ', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                        Icon(Icons.place_rounded, size: 13, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            item.location!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (item.cost != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.expense.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(6)),
                          child: Text(
                            money(item.cost!),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.expense),
                          ),
                        ),
                        const Spacer(),
                        if (onExpense != null)
                          Pressable(
                            onTap: onExpense,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: color.withValues(alpha: 0.6)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add_card_rounded, size: 13, color: color),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Ghi chi',
                                    style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (tall && item.note != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      item.note!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, height: 1.35, color: scheme.onSurfaceVariant),
                    ),
                  ],
                  if (strip) ...[const SizedBox(height: 8), _PhotoStrip(ids: photos, size: box.maxHeight >= 260 ? 72 : 52, dim: dim)],
                ],
              ],
            );
            return Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(9, 6, 6, 6),
                    child: ClipRect(
                      child: OverflowBox(alignment: Alignment.topLeft, maxHeight: double.infinity, child: head),
                    ),
                  ),
                ),
                // Khối dài: thời lượng / "Đang diễn ra" ở góc dưới
                if (tall)
                  Positioned(
                    left: 9,
                    bottom: 14,
                    child: current
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
                            child: const Text(
                              'Đang diễn ra',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                            ),
                          ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(begin: 0.6, end: 1, duration: 800.ms).isolated()
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.timelapse_rounded, size: 13, color: color.withValues(alpha: dim ? 0.5 : 0.9)),
                              const SizedBox(width: 4),
                              Text(
                                durationText(minutes),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: color.withValues(alpha: dim ? 0.5 : 0.9),
                                ),
                              ),
                            ],
                          ),
                  )
                else if (current && !compact)
                  Positioned(
                    right: 8,
                    bottom: 10,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(begin: 0.7, end: 1.3, duration: 700.ms).isolated(),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Dải ảnh vuông trong khối hoạt động; chạm để xem toàn màn hình. Quá chỗ thì ô cuối hiện "+N".
class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({required this.ids, required this.size, required this.dim});
  final List<String> ids;
  final double size;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        const gap = 6.0;
        final fit = ((box.maxWidth + gap) / (size + gap)).floor().clamp(1, 99);
        final shown = ids.length > fit ? fit : ids.length;
        final more = ids.length - shown;
        return Row(
          children: [
            for (var i = 0; i < shown; i++)
              Padding(
                padding: EdgeInsets.only(right: i == shown - 1 ? 0 : gap),
                child:
                    Pressable(
                          scale: 0.94,
                          onTap: () => openGallery(context, ids, i),
                          child: SizedBox(
                            width: size,
                            height: size,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Opacity(opacity: dim ? 0.7 : 1, child: FileImage2(ids[i], radius: 10)),
                                if (i == shown - 1 && more > 0)
                                  Container(
                                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(10)),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '+${more + 1}',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        )
                        .animate()
                        .fadeIn(delay: (60 * i + 120).ms, duration: 300.ms)
                        .scaleXY(begin: 0.85, end: 1, delay: (60 * i + 120).ms, curve: Curves.easeOutCubic),
              ),
          ],
        );
      },
    );
  }
}

/// Chồng 2 ảnh nhỏ + số lượng, dùng cho khối hoạt động thấp.
class _PhotoStack extends StatelessWidget {
  const _PhotoStack({required this.ids, required this.color});
  final List<String> ids;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final n = ids.length > 2 ? 2 : ids.length;
    return Pressable(
      onTap: () => openGallery(context, ids, 0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 22.0 + (n - 1) * 12,
            height: 22,
            child: Stack(
              children: [
                for (var i = 0; i < n; i++)
                  Positioned(
                    left: i * 12.0,
                    child: Container(
                      width: 22,
                      height: 22,
                      padding: const EdgeInsets.all(1.5),
                      decoration: BoxDecoration(color: scheme.surface, borderRadius: BorderRadius.circular(7)),
                      child: FileImage2(ids[i], radius: 6),
                    ),
                  ),
              ],
            ),
          ),
          if (ids.length > 2) ...[
            const SizedBox(width: 3),
            Text(
              '+${ids.length - 2}',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================ Chi tiết lịch trình

/// Chi tiết lịch trình: hoạt động theo giờ từng ngày, album ảnh, người tham gia, chi phí, đăng bài.
class EventDetailPage extends ConsumerStatefulWidget {
  const EventDetailPage({super.key, required this.id, this.occurrence});
  final String id;
  final DateTime? occurrence;

  @override
  ConsumerState<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends ConsumerState<EventDetailPage> {
  List<Map<String, dynamic>>? participants;
  DateTime? selectedDay;
  int tab = 0;

  @override
  void initState() {
    super.initState();
    _loadParticipants();
  }

  Future<void> _loadParticipants() async {
    if (!ref.read(sessionProvider).isLoggedIn || ref.read(storeProvider).isDirty(E.events, widget.id)) return;
    try {
      final r = await ref.read(apiProvider).get<List<dynamic>>('/events/${widget.id}/participants');
      if (mounted) setState(() => participants = r.cast<Map<String, dynamic>>());
    } catch (_) {}
  }

  Future<void> _invite() async {
    final api = ref.read(apiProvider);
    try {
      await ref.read(syncProvider).sync(); // lịch trình phải có trên server trước khi mời
      final friends = (await api.get<List<dynamic>>('/friends')).cast<Map<String, dynamic>>();
      if (!mounted) return;
      if (friends.isEmpty) return showToast(context, 'Bạn chưa có bạn bè nào');
      final selected = <String>{};
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => StatefulBuilder(
          builder: (c, set) => AlertDialog(
            title: const Text('Mời bạn bè'),
            content: SizedBox(
              width: 320,
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final f in friends)
                    CheckboxListTile(
                      value: selected.contains(f['id']),
                      onChanged: (v) => set(() => v == true ? selected.add(f['id'] as String) : selected.remove(f['id'])),
                      title: Text(f['displayName'] as String),
                      subtitle: Text('@${f['username']}'),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Huỷ')),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Mời')),
            ],
          ),
        ),
      );
      if (ok != true || selected.isEmpty) return;
      await api.post('/events/${widget.id}/participants', {'userIds': selected.toList(), 'role': 2});
      await _loadParticipants();
      if (mounted) showToast(context, 'Đã gửi lời mời');
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watchTables(scheduleTables);
    final session = ref.watch(sessionProvider);
    final f = ref.watch(financeProvider);
    final rec = store.get(E.events, widget.id);
    if (rec == null)
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Lịch trình không còn tồn tại')),
      );
    final e = EventRec(rec);
    final occ = widget.occurrence ?? e.startAt;
    final days = eventDays(e, occ);
    final day = selectedDay != null && days.any((d) => isSameDay(d, selectedDay))
        ? selectedDay!
        : days.firstWhere((d) => isSameDay(d, DateTime.now()), orElse: () => days.first);
    final isOwner = !session.isLoggedIn || e.userId.isEmpty || e.userId == session.userId;
    final occDate = e.rrule == null ? null : Fmt.isoDate(occ);
    final photos = store
        .all(E.eventPhotos)
        .map(EventPhoto.new)
        .where((p) => p.eventId == e.id && (occDate == null || p.m['occurrenceDate'] == null || p.m['occurrenceDate'] == occDate))
        .toList();
    final spent = f.transactions.where((t) => t.eventId == e.id).toList();
    final spentTotal = f.totals(spent).expense;
    final color = hexColor(e.color, Theme.of(context).colorScheme.primary);
    final scheme = Theme.of(context).colorScheme;
    final cat = f.category(e.categoryId);
    final allItems = [for (final d in days) ...eventItemsOn(store, e.id, d)];
    final doneCount = allItems.where((i) => i.isDone).length;
    final planned = e.estimatedCost ?? allItems.fold<double>(0, (s, i) => s + (i.cost ?? 0));
    final occEnd = e.endAt == null ? null : occ.add(e.endAt!.difference(e.startAt));
    final subtitle = days.length > 1
        ? '${Fmt.dateShort(days.first)} – ${Fmt.dateShort(days.last)} · ${days.length} ngày'
        : e.isAllDay
        ? 'Cả ngày · ${Fmt.date(occ)}'
        : '${Fmt.time(occ)}${occEnd != null ? ' – ${Fmt.time(occEnd)}' : ''} · ${Fmt.date(occ)}';
    final tabs = [
      ('Timeline', Icons.view_timeline_rounded),
      ('Ảnh${photos.isEmpty ? '' : ' · ${photos.length}'}', Icons.photo_library_rounded),
      ('Chi phí', Icons.payments_rounded),
      if (session.isLoggedIn) ('Thành viên', Icons.group_rounded),
    ];
    if (tab >= tabs.length) tab = 0;
    final expanded = e.coverFileId == null ? 210.0 : 280.0;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: expanded,
            pinned: true,
            stretch: true,
            foregroundColor: Colors.white,
            backgroundColor: Color.lerp(color, Colors.black, 0.25),
            flexibleSpace: LayoutBuilder(
              builder: (context, box) {
                final top = MediaQuery.paddingOf(context).top;
                final minH = kToolbarHeight + top;
                final t = ((box.maxHeight - minH) / (expanded + top - minH)).clamp(0.0, 1.0);
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // Nền: ảnh bìa (có lớp tối để chữ luôn đọc được) hoặc dải màu của lịch trình + hoạ tiết tròn
                    if (e.coverFileId != null) ...[
                      Hero(tag: 'photo-${e.coverFileId}', child: FileImage2(e.coverFileId!, radius: 0)),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.black54, Colors.transparent, Colors.black26, Colors.black87],
                            stops: [0, 0.3, 0.55, 1],
                          ),
                        ),
                      ),
                    ] else ...[
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color.lerp(color, Colors.white, 0.08)!, Color.lerp(color, Colors.black, 0.4)!],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      Positioned(right: -60, top: -40, child: _Blob(size: 200, alpha: 0.10 * t)),
                      Positioned(left: -40, bottom: -70, child: _Blob(size: 160, alpha: 0.07 * t)),
                      Positioned(
                        right: 12,
                        bottom: 8,
                        child: Opacity(
                          opacity: 0.18 * t,
                          child: Icon(iconOf(cat?.icon ?? 'event'), size: 120, color: Colors.white),
                        ),
                      ),
                    ],
                    // Nội dung khi mở rộng: danh mục, tiêu đề lớn, thời gian
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: t,
                          child: Transform.translate(
                            offset: Offset(0, 14 * (1 - t)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    _HeroChip(iconOf(cat?.icon ?? 'event'), cat?.name ?? 'Lịch trình'),
                                    if (e.rrule != null) const _HeroChip(Icons.repeat_rounded, 'Lặp lại'),
                                    if (ScheduleIndex.of(store).isShared(e.id)) const _HeroChip(Icons.group_rounded, 'Chia sẻ'),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  e.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    height: 1.15,
                                    fontWeight: FontWeight.w900,
                                    shadows: [Shadow(blurRadius: 12, color: Colors.black38)],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.schedule_rounded, size: 16, color: Colors.white70),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        subtitle,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Tiêu đề nhỏ khi thu gọn
                    Positioned(
                      left: 56,
                      right: 150,
                      top: top,
                      height: kToolbarHeight,
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: (1 - t * 2.5).clamp(0.0, 1.0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              e.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            actions: [
              if (session.isLoggedIn)
                IconButton(
                  tooltip: 'Đăng bài',
                  onPressed: () => context.push('/feed/compose', extra: {'eventId': e.id}),
                  icon: const Icon(Icons.share_rounded),
                ),
              IconButton(
                tooltip: 'Sửa',
                onPressed: () => context.push('/schedule/edit', extra: {'id': e.id}),
                icon: const Icon(Icons.edit_rounded),
              ),
              if (isOwner)
                IconButton(
                  tooltip: 'Xoá',
                  onPressed: () async {
                    if (await confirm(context, 'Xoá lịch trình?', danger: true, ok: 'Xoá')) {
                      store.remove(E.events, e.id);
                      if (context.mounted) context.pop();
                    }
                  },
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            sliver: SliverList.list(
              children: [
                // Tổng quan: 3 số chính + thông tin chi tiết
                AppCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          _StatTile(
                            icon: Icons.task_alt_rounded,
                            label: 'Hoạt động',
                            value: allItems.isEmpty ? '—' : '$doneCount/${allItems.length}',
                            color: color,
                            progress: allItems.isEmpty ? null : doneCount / allItems.length,
                            onTap: () => setState(() => tab = 0),
                          ),
                          const SizedBox(width: 8),
                          _StatTile(
                            icon: Icons.account_balance_wallet_rounded,
                            label: 'Dự kiến',
                            value: planned > 0 ? Fmt.compact(planned) : '—',
                            color: AppColors.transfer,
                            onTap: () => setState(() => tab = 2),
                          ),
                          const SizedBox(width: 8),
                          _StatTile(
                            icon: Icons.receipt_long_rounded,
                            label: 'Đã chi',
                            value: spentTotal > 0 ? Fmt.compact(spentTotal) : '—',
                            color: AppColors.expense,
                            progress: planned > 0 && spentTotal > 0 ? spentTotal / planned : null,
                            onTap: () => setState(() => tab = 2),
                          ),
                        ],
                      ),
                      if (e.location != null || e.rrule != null || e.remindBefore != null || e.note != null) const SizedBox(height: 6),
                      if (e.location != null) _InfoRow(Icons.place_rounded, 'Địa điểm', e.location!, color),
                      if (e.rrule != null) _InfoRow(Icons.repeat_rounded, 'Lặp lại', Recurrence.describe(e.rrule), color),
                      if (e.remindBefore != null) _InfoRow(Icons.notifications_active_rounded, 'Nhắc nhở', TimeConfig.remindLabel(e.remindBefore), color),
                      if (e.note != null)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border(left: BorderSide(color: color, width: 3)),
                          ),
                          child: Text(e.note!, style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.85), height: 1.4)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Thanh chọn mục: một rãnh chung, nền màu trượt mượt sang mục được chọn
                Container(
                  height: 58,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: scheme.surfaceContainerHighest.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(10)),
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final w = box.maxWidth / tabs.length;
                      return Stack(
                        children: [
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 320),
                            curve: Curves.easeOutCubic,
                            left: w * tab,
                            top: 0,
                            bottom: 0,
                            width: w,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [color, Color.lerp(color, Colors.black, 0.2)!],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 3))],
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              for (final (i, (label, icon)) in tabs.indexed)
                                Expanded(
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      if (tab != i) HapticFeedback.selectionClick();
                                      setState(() => tab = i);
                                    },
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        AnimatedScale(
                                          scale: tab == i ? 1.12 : 1,
                                          duration: const Duration(milliseconds: 260),
                                          curve: Curves.easeOutBack,
                                          child: Icon(icon, size: 19, color: tab == i ? Colors.white : scheme.onSurfaceVariant),
                                        ),
                                        const SizedBox(height: 2),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: AnimatedDefaultTextStyle(
                                            duration: const Duration(milliseconds: 220),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: tab == i ? Colors.white : scheme.onSurfaceVariant,
                                              fontFamily: DefaultTextStyle.of(context).style.fontFamily,
                                            ),
                                            child: Text(label),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),

                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  switchInCurve: Curves.easeOutCubic,
                  transitionBuilder: (c, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(a),
                      child: c,
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey('$tab-${Fmt.isoDate(day)}'),
                    child: switch (tab) {
                      0 => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (days.length > 1)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: SizedBox(
                                height: 70,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: days.length,
                                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                                  itemBuilder: (context, i) {
                                    final d = days[i];
                                    final sel = isSameDay(d, day);
                                    final isToday = isSameDay(d, DateTime.now());
                                    final n = eventItemsOn(store, e.id, d).length;
                                    return Pressable(
                                      onTap: () => setState(() => selectedDay = d),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 260),
                                        curve: Curves.easeOutCubic,
                                        width: 62,
                                        decoration: BoxDecoration(
                                          gradient: sel
                                              ? LinearGradient(
                                                  colors: [color, Color.lerp(color, Colors.black, 0.2)!],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                )
                                              : null,
                                          color: sel ? null : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                          borderRadius: BorderRadius.circular(10),
                                          border: isToday && !sel ? Border.all(color: color, width: 1.5) : null,
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              isToday ? 'Hôm nay' : 'Ngày ${i + 1}',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: sel ? Colors.white70 : scheme.onSurfaceVariant,
                                              ),
                                            ),
                                            Text(
                                              '${d.day}',
                                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, height: 1.1, color: sel ? Colors.white : null),
                                            ),
                                            Text(
                                              n == 0 ? _dow(d) : '${_dow(d)} · $n',
                                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: sel ? Colors.white : color),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          DayTimeline(event: e, day: day),
                        ],
                      ),
                      1 => PhotoGrid(
                        fileIds: photos.map((p) => p.fileId).toList(),
                        size: (MediaQuery.of(context).size.width - 48) / 3,
                        onAdd: () async {
                          final ids = await pickPhotos(context, ref);
                          for (final id in ids) {
                            store.put(E.eventPhotos, {
                              'eventId': e.id,
                              'fileId': id,
                              'occurrenceDate': occDate,
                              'addedByUserId': session.userId ?? '00000000-0000-0000-0000-000000000000',
                              'sortOrder': 0,
                            });
                          }
                        },
                        onRemove: (fid) {
                          final p = photos.firstWhere((x) => x.fileId == fid);
                          store.remove(E.eventPhotos, p.id);
                        },
                      ),
                      2 => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Đã chi', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                                        AnimatedAmount(
                                          value: spentTotal,
                                          format: (v) => f.money(v),
                                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: AppColors.expense),
                                        ),
                                      ],
                                    ),
                                    const Spacer(),
                                    if (planned > 0)
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text('Dự kiến', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                                          Text(f.money(planned), style: const TextStyle(fontWeight: FontWeight.w700)),
                                        ],
                                      ),
                                  ],
                                ),
                                if (planned > 0) ...[
                                  const SizedBox(height: 10),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: TweenAnimationBuilder<double>(
                                      tween: Tween(begin: 0, end: (spentTotal / planned).clamp(0, 1)),
                                      duration: const Duration(milliseconds: 700),
                                      curve: Curves.easeOutCubic,
                                      builder: (_, v, __) => LinearProgressIndicator(
                                        value: v,
                                        minHeight: 8,
                                        color: spentTotal > planned ? AppColors.expense : color,
                                        backgroundColor: color.withValues(alpha: 0.15),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    spentTotal > planned ? 'Vượt ${f.money(spentTotal - planned)}' : 'Còn ${f.money(planned - spentTotal)}',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: spentTotal > planned ? AppColors.expense : scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                                if (spent.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 16, bottom: 4),
                                    child: Text(
                                      'Chưa ghi khoản chi nào cho lịch trình này',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: scheme.onSurfaceVariant),
                                    ),
                                  )
                                else ...[
                                  const SizedBox(height: 8),
                                  for (final t in spent)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                      child: Row(
                                        children: [
                                          CircleIcon(
                                            icon: f.category(t.categoryId)?.icon,
                                            color: hexColor(f.category(t.categoryId)?.color, AppColors.expense),
                                            size: 36,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  t.note ?? f.category(t.categoryId)?.name ?? 'Khoản chi',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                                ),
                                                Text(Fmt.dateTime(t.occurredAt), style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            '-${f.money(t.amount, t.currencyCode)}',
                                            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.expense),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          FilledButton.tonalIcon(
                            onPressed: () => context.push('/tx/edit', extra: {'type': 1, 'eventId': e.id, 'note': e.title}),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Ghi chi phí'),
                          ),
                        ],
                      ),
                      _ => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (participants == null)
                            Text('Đồng bộ lịch trình để xem / mời người tham gia', style: TextStyle(color: scheme.onSurfaceVariant))
                          else
                            AppCard(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Column(
                                children: [
                                  if (participants!.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Text('Chưa có ai tham gia', style: TextStyle(color: scheme.onSurfaceVariant)),
                                    ),
                                  for (final p in participants!)
                                    (() {
                                      final name = (p['user'] as Map)['displayName'] as String;
                                      final (label, c) = switch (p['status']) {
                                        2 => (p['role'] == 1 ? 'Chủ' : 'Tham gia', p['role'] == 1 ? color : AppColors.income),
                                        3 => ('Từ chối', AppColors.expense),
                                        _ => ('Đã mời', AppColors.warning),
                                      };
                                      return ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: color.withValues(alpha: 0.18),
                                          foregroundColor: color,
                                          child: Text(name.characters.first.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800)),
                                        ),
                                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                        trailing: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                                          child: Text(
                                            label,
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c),
                                          ),
                                        ),
                                      );
                                    })(),
                                ],
                              ),
                            ),
                          if (isOwner) ...[
                            const SizedBox(height: 10),
                            FilledButton.tonalIcon(onPressed: _invite, icon: const Icon(Icons.person_add_rounded), label: const Text('Mời bạn bè')),
                          ],
                        ],
                      ),
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _dow(DateTime d) => const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'][d.weekday - 1];

/// Vòng tròn mờ trang trí nền header.
class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.alpha});
  final double size;
  final double alpha;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: alpha),
    ),
  );
}

/// Nhãn nhỏ trên header (danh mục, lặp lại, chia sẻ).
class _HeroChip extends StatelessWidget {
  const _HeroChip(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

/// Ô số liệu ở thẻ tổng quan (có thanh tiến độ mảnh nếu có tỉ lệ).
class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.label, required this.value, required this.color, this.progress, this.onTap});
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final double? progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Pressable(
      scale: 0.96,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.16), color.withValues(alpha: 0.06)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color),
              ),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: (progress ?? 0).clamp(0, 1)),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => LinearProgressIndicator(
                  value: v,
                  minHeight: 3,
                  color: (progress ?? 0) > 1 ? AppColors.expense : color,
                  backgroundColor: color.withValues(alpha: progress == null ? 0.0 : 0.15),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Dòng thông tin: ô icon màu + nhãn + giá trị.
class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.label, this.value, this.color);
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Ô ngày vuông trong lịch tháng của Lịch trình: số ngày, vạch màu từng lịch trình (tối đa 3 + "+N"), số lịch.
/// Viền / màu chữ cuối tuần theo cấu hình "Giao diện lịch".
class _EventDayCell extends StatelessWidget {
  const _EventDayCell({required this.day, required this.events, required this.selected, required this.isToday, required this.outside, required this.look});
  final DateTime day;
  final List<EventRec> events;
  final bool selected, isToday, outside;
  final CalendarLook look;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shown = events.take(3).toList();
    final more = events.length - shown.length;
    final numColor = outside
        ? scheme.onSurfaceVariant.withValues(alpha: 0.4)
        : selected || isToday
        ? scheme.primary
        : look.weekdayColor(day.weekday, scheme) ?? scheme.onSurface;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        color: outside
            ? Colors.transparent
            : selected
            ? scheme.primary.withValues(alpha: 0.18)
            : scheme.surfaceContainerHighest.withValues(alpha: events.isNotEmpty ? 0.55 : 0.22),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: selected
              ? look.selectedBorderColor(scheme)
              : isToday
              ? look.todayBorderColor(scheme)
              : outside
              ? Colors.transparent
              : (look.cellBorderColor(scheme) ?? Colors.transparent),
          width: selected || isToday ? look.borderWidth + 0.6 : look.borderWidth,
        ),
      ),
      child: SizedBox.expand(
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${day.day}',
                  style: TextStyle(fontSize: 12, fontWeight: isToday || selected ? FontWeight.w800 : FontWeight.w600, color: numColor),
                ),
                const SizedBox(height: 3),
                SizedBox(
                  height: 5,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final e in shown)
                        Container(
                          width: 9,
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(color: hexColor(e.color, scheme.primary), borderRadius: BorderRadius.circular(2)),
                        ),
                      if (more > 0)
                        Text(
                          ' +$more',
                          style: TextStyle(fontSize: 7, fontWeight: FontWeight.w800, color: scheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  events.isEmpty ? ' ' : '${events.length} lịch',
                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================ Xem cả tuần (lưới giờ kiểu Google Calendar)

/// Một khối lịch trình trên lưới tuần (đã cắt theo ngày).
class _Blk {
  _Blk(this.e, this.occurrence, this.col, this.start, this.end);
  final EventRec e;
  final DateTime occurrence;
  final int col; // cột ngày 0..6
  final int start, end; // phút trong ngày
  int lane = 0, lanes = 1; // xếp cạnh nhau khi trùng giờ

  /// Nhận diện ổn định qua các lần dựng lại (để kéo không bị mất).
  String get key => '${e.id}|${occurrence.toIso8601String()}|$col';
}

/// Lưới tuần: 7 cột ngày × trục giờ. Chạm ô trống → khung "+ giờ" (chạm lần nữa để thêm); chạm lịch → xem;
/// giữ rồi kéo lịch → dời ngày/giờ (bước theo cài đặt "làm tròn"). Lịch cả ngày nằm ở hàng trên cùng.
class _WeekGrid extends ConsumerStatefulWidget {
  const _WeekGrid({super.key, required this.start, required this.selected, required this.onOpenDay});
  final DateTime start;
  final DateTime selected;
  final ValueChanged<DateTime> onOpenDay;

  @override
  ConsumerState<_WeekGrid> createState() => _WeekGridState();
}

class _WeekGridState extends ConsumerState<_WeekGrid> {
  static const _hourH = 46.0, _gutter = 30.0;

  /// Khung "thêm mới": (cột, phút bắt đầu, phút kết thúc).
  (int, int, int)? _ghost;
  int? _anchor; // phút bắt đầu khi đang giữ-kéo ô trống để quét khoảng giờ
  String? _drag; // khoá của khối đang kéo dời
  (int, int) _dragSnap = (0, 0); // (lệch ngày, lệch phút) đang xem trước
  String? _sel; // lịch đang chọn (id|cột) → hiện núm kéo giãn thời lượng
  int? _resizeEnd; // phút kết thúc đang xem trước khi kéo núm
  double _resizeDy = 0;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Vạch "bây giờ" chỉ cần nhích mỗi phút, và chỉ khi tuần đang xem có hôm nay.
    final today = dateOnly(DateTime.now());
    if (!today.isBefore(widget.start) && today.isBefore(widget.start.add(const Duration(days: 7)))) {
      _tick = Timer.periodic(const Duration(minutes: 1), (_) => mounted ? setState(() {}) : null);
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  DateTime _day(int col) => DateTime(widget.start.year, widget.start.month, widget.start.day + col);

  void _open(_Blk b) => context.push('/schedule/detail', extra: {'id': b.e.id, 'occurrence': b.occurrence});

  /// Mở màn thêm lịch với đúng ngày, giờ bắt đầu và giờ kết thúc của khung.
  void _add((int, int, int) g) {
    final d = _day(g.$1);
    DateTime at(int m) => DateTime(d.year, d.month, d.day, m ~/ 60, m % 60);
    setState(() => _ghost = null);
    context.push('/schedule/edit', extra: {'date': at(g.$2), 'end': at(g.$3), 'timed': true});
  }

  /// Dời lịch theo (lệch ngày, lệch phút); hoạt động theo giờ của các ngày bị dời cũng đi theo.
  void _move(_Blk b, int dDays, int dMin) {
    final store = ref.read(storeProvider);
    final rec = store.get(E.events, b.e.id);
    if (rec == null) return;
    final shift = Duration(days: dDays, minutes: dMin);
    final e = EventRec(rec);
    store.put(E.events, {...rec, 'startAt': toIso8601WithOffset(e.startAt.add(shift)), 'endAt': e.endAt != null ? toIso8601WithOffset(e.endAt!.add(shift)) : null});
    if (dDays != 0) {
      for (final it in store.all(E.eventItems).map(EventItemRec.new).where((i) => i.eventId == e.id && i.occurrenceDate != null).toList()) {
        final od = DateTime.tryParse(it.occurrenceDate!);
        if (od != null) store.put(E.eventItems, {...it.m, 'occurrenceDate': Fmt.isoDate(od.add(Duration(days: dDays)))});
      }
    }
    HapticFeedback.mediumImpact();
  }

  /// Kéo giãn: đổi giờ kết thúc thêm [dMin] phút.
  void _resize(_Blk b, int dMin) {
    final store = ref.read(storeProvider);
    final rec = store.get(E.events, b.e.id);
    if (rec == null || dMin == 0) return;
    final e = EventRec(rec);
    final end = (e.endAt ?? e.startAt.add(const Duration(hours: 1))).add(Duration(minutes: dMin));
    store.put(E.events, {...rec, 'endAt': toIso8601WithOffset(end)});
    HapticFeedback.mediumImpact();
  }

  String _selKey(_Blk b) => '${b.e.id}|${b.col}';

  @override
  Widget build(BuildContext context) {
    final store = ref.watchTables(scheduleTables);
    final scheme = Theme.of(context).colorScheme;
    final look = CalendarLook.of(store);
    final cfg = TimeConfig.of(store);
    final step = cfg.snapMinutes;
    final today = dateOnly(DateTime.now());
    final now = DateTime.now();

    // Gom lịch của 7 ngày: cả ngày → hàng trên; có giờ → khối trên lưới (cắt theo ngày).
    final allDay = List.generate(7, (_) => <(DateTime, EventRec)>[]);
    final blocks = <_Blk>[];
    var minH = cfg.dayStartHour, maxH = cfg.dayEndHour;
    for (var c = 0; c < 7; c++) {
      final d = _day(c);
      for (final (o, e) in occurrencesIn(store, d, d.add(const Duration(days: 1)))) {
        final dur = e.endAt == null ? const Duration(hours: 1) : e.endAt!.difference(e.startAt);
        if (e.isAllDay || dur.inHours >= 24) {
          allDay[c].add((o, e));
          continue;
        }
        final s = o.isBefore(d) ? 0 : o.difference(d).inMinutes;
        final en = (o.add(dur).difference(d).inMinutes).clamp(s + 15, 24 * 60);
        blocks.add(_Blk(e, o, c, s, en));
        if (s ~/ 60 < minH) minH = s ~/ 60;
        if ((en + 59) ~/ 60 > maxH) maxH = (en + 59) ~/ 60;
      }
    }
    minH = minH.clamp(0, 23);
    maxH = maxH.clamp(minH + 1, 24);
    // Xếp làn: các lịch chồng giờ trong cùng ngày chia đều bề ngang cột.
    for (var c = 0; c < 7; c++) {
      final day = blocks.where((b) => b.col == c).toList()..sort((a, b) => a.start != b.start ? a.start.compareTo(b.start) : b.end.compareTo(a.end));
      var group = <_Blk>[];
      final laneEnds = <int>[];
      var groupEnd = -1;
      void flush() {
        for (final b in group) {
          b.lanes = laneEnds.length;
        }
        group = [];
        laneEnds.clear();
      }

      for (final b in day) {
        if (b.start >= groupEnd) flush();
        var lane = laneEnds.indexWhere((end) => end <= b.start);
        if (lane < 0) {
          lane = laneEnds.length;
          laneEnds.add(b.end);
        } else {
          laneEnds[lane] = b.end;
        }
        b.lane = lane;
        group.add(b);
        if (b.end > groupEnd) groupEnd = b.end;
      }
      flush();
    }

    final hasAllDay = allDay.any((l) => l.isNotEmpty);
    final bodyH = (maxH - minH) * _hourH;
    double yOf(int minute) => (minute - minH * 60) / 60 * _hourH;
    int minuteAt(double y, {bool up = false}) {
      final raw = minH * 60 + y / _hourH * 60;
      final m = (up ? (raw / step).round() : (raw / step).floor()) * step; // kéo: làm tròn gần nhất
      return m.clamp(minH * 60, maxH * 60);
    }

    return LayoutBuilder(
      builder: (context, cons) {
        final colW = (cons.maxWidth - _gutter) / 7;
        int colAt(double x) => ((x - _gutter) / colW).floor().clamp(0, 6);

        Widget header() => Row(
          children: [
            const SizedBox(width: _gutter),
            for (var c = 0; c < 7; c++)
              Builder(
                builder: (_) {
                  final d = _day(c);
                  final isToday = d == today, sel = d == widget.selected;
                  final wc = look.weekdayColor(d.weekday, scheme);
                  return SizedBox(
                    width: colW,
                    child: Pressable(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        widget.onOpenDay(d);
                      },
                      child: Column(
                        children: [
                          Text(
                            Fmt.weekdaysShort[d.weekday - 1],
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: isToday ? scheme.primary : (wc ?? scheme.onSurfaceVariant)),
                          ),
                          const SizedBox(height: 3),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: 30,
                            height: 30,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isToday ? scheme.primary : null,
                              border: sel && !isToday ? Border.all(color: scheme.primary, width: 1.5) : null,
                            ),
                            child: Text(
                              '${d.day}',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isToday ? scheme.onPrimary : null),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        );

        Widget allDayRow() => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: _gutter,
                child: Text('Cả\nngày', style: TextStyle(fontSize: 9, height: 1.1, color: scheme.onSurfaceVariant)),
              ),
              for (var c = 0; c < 7; c++)
                SizedBox(
                  width: colW,
                  child: Column(
                    children: [
                      for (final (o, e) in allDay[c].take(2))
                        Pressable(
                          onTap: () => context.push('/schedule/detail', extra: {'id': e.id, 'occurrence': o}),
                          child: Container(
                            height: 18,
                            margin: const EdgeInsets.fromLTRB(1, 0, 1, 2),
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            alignment: Alignment.centerLeft,
                            decoration: BoxDecoration(color: hexColor(e.color, scheme.primary), borderRadius: BorderRadius.circular(5)),
                            child: Text(
                              e.title,
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ),
                        ),
                      if (allDay[c].length > 2)
                        Text(
                          '+${allDay[c].length - 2}',
                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: scheme.primary),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );

        /// Núm tròn kéo dọc để giãn/co giờ kết thúc (dùng cho lịch đang chọn và khung thêm mới).
        Widget handle({
          required Color color,
          required double left,
          required double top,
          required VoidCallback onStart,
          required ValueChanged<double> onDy,
          required VoidCallback onEnd,
        }) => Positioned(
          left: left - 14,
          top: top - 14,
          width: 28,
          height: 28,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            dragStartBehavior: DragStartBehavior.down, // tính từ lúc chạm → núm bám đúng ngón tay
            onVerticalDragStart: (_) => onStart(),
            onVerticalDragUpdate: (u) => onDy(u.delta.dy),
            onVerticalDragEnd: (_) => onEnd(),
            onVerticalDragCancel: onEnd,
            child: Center(
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: scheme.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2.5),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4)],
                ),
              ).animate().scale(duration: 200.ms, curve: Curves.easeOutBack),
            ),
          ),
        );

        Widget block(_Blk b) {
          final dragging = b.key == _drag;
          final selected = _sel == _selKey(b);
          final color = hexColor(b.e.color, scheme.primary);
          final w = colW / b.lanes;
          final (dd, dm) = dragging ? _dragSnap : (0, 0);
          final col = (b.col + dd).clamp(0, 6);
          final s = b.start + dm;
          final e = selected && _resizeEnd != null ? _resizeEnd! : b.end + dm;
          final h = (yOf(e) - yOf(s)).clamp(18.0, double.infinity);
          final wide = dragging || selected;
          final timeText = wide ? '${timeStr((s ~/ 60, s % 60))}–${timeStr((e ~/ 60, e % 60))}' : timeStr((s ~/ 60, s % 60));
          return AnimatedPositioned(
            key: ValueKey(b.key),
            duration: Duration(milliseconds: dragging || _resizeEnd != null ? 90 : 220),
            curve: Curves.easeOutCubic,
            left: _gutter + col * colW + (wide ? 1 : b.lane * w + 1),
            top: yOf(s) + 1,
            width: (wide ? colW : w) - 2,
            height: h - 2,
            child: GestureDetector(
              onTap: () => _open(b),
              onLongPressStart: (_) {
                if (b.e.rrule != null) {
                  showToast(context, 'Lịch lặp lại: mở lịch để đổi giờ');
                  return;
                }
                HapticFeedback.mediumImpact();
                setState(() {
                  _ghost = null;
                  _sel = _selKey(b);
                  _drag = b.key;
                  _dragSnap = (0, 0);
                });
              },
              onLongPressMoveUpdate: (m) {
                if (_drag != b.key) return;
                final dDays = ((b.col + (m.offsetFromOrigin.dx / colW).round()).clamp(0, 6)) - b.col;
                final dur = b.end - b.start;
                var dMin = ((m.offsetFromOrigin.dy / _hourH * 60) / step).round() * step;
                dMin = dMin.clamp(minH * 60 - b.start, maxH * 60 - dur - b.start);
                if ((dDays, dMin) != _dragSnap) {
                  HapticFeedback.selectionClick();
                  setState(() => _dragSnap = (dDays, dMin));
                }
              },
              onLongPressEnd: (_) {
                if (_drag != b.key) return;
                final (dDays, dMin) = _dragSnap;
                // Giữ lịch ở trạng thái chọn (ở cột mới) để kéo núm giãn giờ ngay sau đó.
                setState(() {
                  _drag = null;
                  _sel = '${b.e.id}|${(b.col + dDays).clamp(0, 6)}';
                });
                if (dDays != 0 || dMin != 0) _move(b, dDays, dMin);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.fromLTRB(3, 2, 2, 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: wide ? 1 : 0.9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: wide ? Colors.white : scheme.surface.withValues(alpha: 0.7), width: wide ? 1.5 : 0.8),
                  boxShadow: wide ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 12, offset: const Offset(0, 4))] : null,
                ),
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.topLeft,
                    maxHeight: double.infinity, // khung co giãn khi kéo: chữ thừa bị cắt, không báo tràn
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b.e.title,
                          maxLines: ((h - 8 - (h > 30 || wide ? 11 : 0)) / 11.5).floor().clamp(1, 6),
                          overflow: TextOverflow.clip,
                          style: const TextStyle(fontSize: 10, height: 1.15, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                        if (h > 30 || wide)
                          Text(
                            timeText,
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.9)),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        final selBlk = blocks.where((b) => _sel == _selKey(b) && b.key != _drag).firstOrNull;
        final todayCol = today.difference(widget.start).inDays;
        final nowMin = now.hour * 60 + now.minute;
        final g = _ghost;
        return Column(
          children: [
            header(),
            if (hasAllDay) allDayRow(),
            const SizedBox(height: 8),
            SizedBox(
              height: bodyH,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                // Chạm ô trống: bỏ chọn; nếu không có gì đang chọn → hiện khung "+ giờ" (mặc định 1 giờ).
                onTapUp: (t) {
                  final p = t.localPosition;
                  if (p.dx < _gutter) return;
                  if (_sel != null) return setState(() => _sel = null);
                  final col = colAt(p.dx);
                  final s = (minuteAt(p.dy) ~/ 30 * 30).clamp(minH * 60, maxH * 60 - 30);
                  HapticFeedback.selectionClick();
                  setState(() => _ghost = (col, s, (s + 60).clamp(s + 30, 24 * 60)));
                },
                // Giữ ô trống rồi kéo lên/xuống: quét khoảng giờ cho lịch mới, thả tay là mở màn thêm.
                onLongPressStart: (d) {
                  final p = d.localPosition;
                  if (p.dx < _gutter) return;
                  final s = minuteAt(p.dy);
                  HapticFeedback.mediumImpact();
                  setState(() {
                    _sel = null;
                    _anchor = s;
                    _ghost = (colAt(p.dx), s, (s + (step < 30 ? 30 : step)).clamp(s + step, 24 * 60));
                  });
                },
                onLongPressMoveUpdate: (d) {
                  final a = _anchor, cur = _ghost;
                  if (a == null || cur == null) return;
                  final m = minuteAt(d.localPosition.dy, up: true);
                  final next = m > a ? (cur.$1, a, m.clamp(a + step, 24 * 60)) : (cur.$1, (m - step).clamp(minH * 60, a), a + step);
                  if (next != cur) {
                    HapticFeedback.selectionClick();
                    setState(() => _ghost = next);
                  }
                },
                onLongPressEnd: (_) {
                  final cur = _ghost;
                  if (_anchor == null || cur == null) return;
                  _anchor = null;
                  _add(cur);
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _WeekLinesPainter(
                          hours: maxH - minH,
                          hourH: _hourH,
                          gutter: _gutter,
                          line: scheme.outlineVariant.withValues(alpha: 0.45),
                          todayCol: todayCol >= 0 && todayCol < 7 ? todayCol : null,
                          todayTint: scheme.primary.withValues(alpha: 0.05),
                        ),
                      ),
                    ),
                    for (var h = minH + 1; h < maxH; h++)
                      Positioned(
                        left: 0,
                        width: _gutter - 4,
                        top: (h - minH) * _hourH - 6,
                        child: Text(
                          '$h:00',
                          textAlign: TextAlign.right,
                          style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant, fontFeatures: const [FontFeature.tabularFigures()]),
                        ),
                      ),
                    for (final b in blocks)
                      if (b.key != _drag) block(b),
                    if (todayCol >= 0 && todayCol < 7 && nowMin >= minH * 60 && nowMin <= maxH * 60)
                      Positioned(
                        left: _gutter + todayCol * colW - 4,
                        width: colW + 4,
                        top: yOf(nowMin) - 4,
                        height: 8,
                        child: IgnorePointer(
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(color: AppColors.expense, shape: BoxShape.circle),
                              ),
                              Expanded(child: Container(height: 2, color: AppColors.expense)),
                            ],
                          ),
                        ),
                      ),
                    // Khung "thêm mới": chạm để mở màn thêm, kéo núm dưới để đổi giờ kết thúc
                    if (g != null)
                      AnimatedPositioned(
                        key: const ValueKey('ghost'),
                        duration: const Duration(milliseconds: 90),
                        left: _gutter + g.$1 * colW + 1,
                        top: yOf(g.$2) + 1,
                        width: colW - 2,
                        height: yOf(g.$3) - yOf(g.$2) - 2,
                        child: GestureDetector(
                          onTap: () => _add(g),
                          child: TweenAnimationBuilder<double>(
                            key: ValueKey((g.$1, _anchor == null)),
                            tween: Tween(begin: 0.85, end: 1),
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutBack,
                            builder: (_, v, child) => Transform.scale(
                              scale: v,
                              child: Opacity(opacity: ((v - 0.85) / 0.15).clamp(0, 1), child: child),
                            ),
                            child: Container(
                              alignment: Alignment.topCenter,
                              padding: const EdgeInsets.only(top: 3),
                              decoration: BoxDecoration(
                                color: scheme.primary.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: scheme.primary, width: 1.4),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Column(
                                  children: [
                                    Icon(Icons.add_rounded, size: 16, color: scheme.primary),
                                    Text(
                                      '${timeStr((g.$2 ~/ 60, g.$2 % 60))}\n${timeStr((g.$3 ~/ 60, g.$3 % 60))}',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 10, height: 1.2, fontWeight: FontWeight.w700, color: scheme.primary),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (g != null && _anchor == null)
                      handle(
                        color: scheme.primary,
                        left: _gutter + (g.$1 + 1) * colW - 8,
                        top: yOf(g.$3),
                        onStart: () => _resizeDy = 0,
                        onDy: (dy) {
                          _resizeDy += dy;
                          final m = (g.$3 + ((_resizeDy / _hourH * 60) / step).round() * step).clamp(g.$2 + step, maxH * 60);
                          if (m != _ghost!.$3) {
                            HapticFeedback.selectionClick();
                            setState(() => _ghost = (g.$1, g.$2, m));
                            _resizeDy = 0;
                          }
                        },
                        onEnd: () {},
                      ),
                    // Khối đang kéo vẽ sau cùng để nổi lên trên
                    for (final b in blocks)
                      if (b.key == _drag) block(b),
                    if (selBlk != null)
                      handle(
                        color: hexColor(selBlk.e.color, scheme.primary),
                        left: _gutter + (selBlk.col + 1) * colW - 8,
                        top: yOf(_resizeEnd ?? selBlk.end),
                        onStart: () {
                          _resizeDy = 0;
                          setState(() => _resizeEnd = selBlk.end);
                        },
                        onDy: (dy) {
                          _resizeDy += dy;
                          final m = (selBlk.end + ((_resizeDy / _hourH * 60) / step).round() * step).clamp(selBlk.start + step, maxH * 60);
                          if (m != _resizeEnd) {
                            HapticFeedback.selectionClick();
                            setState(() => _resizeEnd = m);
                          }
                        },
                        onEnd: () {
                          final m = _resizeEnd;
                          setState(() => _resizeEnd = null);
                          if (m != null) _resize(selBlk, m - selBlk.end);
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WeekLinesPainter extends CustomPainter {
  _WeekLinesPainter({required this.hours, required this.hourH, required this.gutter, required this.line, required this.todayCol, required this.todayTint});
  final int hours;
  final double hourH, gutter;
  final Color line, todayTint;
  final int? todayCol;

  @override
  void paint(Canvas canvas, Size size) {
    final colW = (size.width - gutter) / 7;
    if (todayCol != null) canvas.drawRect(Rect.fromLTWH(gutter + todayCol! * colW, 0, colW, size.height), Paint()..color = todayTint);
    final p = Paint()
      ..color = line
      ..strokeWidth = 0.8;
    for (var h = 0; h <= hours; h++) {
      canvas.drawLine(Offset(gutter, h * hourH), Offset(size.width, h * hourH), p);
    }
    for (var c = 0; c <= 7; c++) {
      canvas.drawLine(Offset(gutter + c * colW, 0), Offset(gutter + c * colW, size.height), p);
    }
  }

  @override
  bool shouldRepaint(_WeekLinesPainter o) => o.hours != hours || o.line != line || o.todayCol != todayCol || o.todayTint != todayTint;
}
