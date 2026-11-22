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
import '../data/local_store.dart';
import '../data/logic.dart';
import '../data/models.dart';
import '../data/time_config.dart';
import '../providers.dart';
import 'pickers.dart';

const _icons = [
  'alarm',
  'local_drink',
  'medication',
  'bedtime',
  'fitness_center',
  'directions_run',
  'self_improvement',
  'book',
  'work',
  'restaurant',
  'pets',
  'favorite',
];
const _accent = Color(0xFFF76B15);

/// "Hôm nay 21:00" / "Ngày mai 07:30" / "T4 25/11 · 07:30"
String _nextLabel(DateTime d) {
  final today = dateOnly(DateTime.now());
  final diff = dateOnly(d).difference(today).inDays;
  final t = Fmt.time(d);
  if (diff == 0) return 'Hôm nay $t';
  if (diff == 1) return 'Ngày mai $t';
  return '${Fmt.weekdaysShort[d.weekday - 1]} ${Fmt.dateShort(d)} · $t';
}

/// Danh sách nhắc nhở tự đặt: lặp hằng ngày, theo thứ trong tuần hoặc từng ngày cụ thể.
class RemindersPage extends ConsumerWidget {
  const RemindersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watchTables(const [E.reminders]);
    final now = DateTime.now();
    final all = store.all(E.reminders).map(Reminder.new).map((r) => (r, Reminders.next(r, now))).toList()
      ..sort((a, b) {
        if ((a.$2 == null) != (b.$2 == null)) return a.$2 == null ? 1 : -1;
        final c = a.$2 != null ? a.$2!.compareTo(b.$2!) : 0;
        return c != 0 ? c : a.$1.title.compareTo(b.$1.title);
      });
    final tomorrow = dateOnly(now).add(const Duration(days: 1));
    final today = [for (final (r, _) in all) ...Reminders.occurrences(r, now, tomorrow).map((t) => (t, r))]..sort((a, b) => a.$1.compareTo(b.$1));

    return Scaffold(
      appBar: AppBar(title: const Text('Nhắc nhở')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/reminders/edit'),
        icon: const Icon(Icons.add_alarm_rounded),
        label: const Text('Thêm nhắc nhở'),
      ),
      body: all.isEmpty
          ? EmptyState(
              icon: Icons.alarm_rounded,
              title: 'Chưa có nhắc nhở',
              subtitle: 'Đặt nhắc uống nước, uống thuốc, tập thể dục... lặp lại hằng ngày, theo thứ trong tuần hoặc vào từng ngày bạn chọn.',
              action: FilledButton(onPressed: () => context.push('/reminders/edit'), child: const Text('Tạo nhắc nhở')),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                _TodayCard(items: today).stagger(0),
                const SizedBox(height: 14),
                for (final (i, (r, next)) in all.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ReminderCard(reminder: r, next: next).stagger(i + 1),
                  ).withKey(ValueKey(r.id)),
              ],
            ),
    );
  }
}

/// Thẻ đầu trang: các lần nhắc còn lại trong hôm nay.
class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.items});
  final List<(DateTime, Reminder)> items;

  @override
  Widget build(BuildContext context) {
    final base = heroOf(_accent);
    return AppCard(
      gradient: LinearGradient(colors: [base, accentOf(base)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.today_rounded, color: Colors.white),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Hôm nay', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
                Text(items.isEmpty ? 'Không còn lần nhắc' : 'Còn ${items.length} lần nhắc', style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            if (items.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 64,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final (t, r) = items[i];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: i == 0 ? 0.28 : 0.16),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(Fmt.time(t), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 120),
                            child: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReminderCard extends ConsumerWidget {
  const _ReminderCard({required this.reminder, required this.next});
  final Reminder reminder;
  final DateTime? next;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = reminder;
    final color = hexColor(r.color, _accent);
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      onTap: () => context.push('/reminders/edit', extra: {'id': r.id}),
      child: AnimatedOpacity(
        opacity: r.isActive ? 1 : 0.5,
        duration: const Duration(milliseconds: 250),
        child: Row(
          children: [
            CircleIcon(icon: r.icon ?? 'alarm', color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final t in r.times)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8)),
                          child: Text(
                            timeStr(t),
                            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.repeat_rounded, size: 14, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          [
                            Reminders.describe(r),
                            if (r.isActive && next != null) 'Lần tới: ${_nextLabel(next!)}',
                            if (r.isActive && next == null) 'Đã hết lịch',
                          ].join(' · '),
                          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Switch(
              value: r.isActive,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                ref.read(storeProvider).put(E.reminders, {...r.m, 'isActive': v});
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Thêm / sửa nhắc nhở.
class ReminderEditPage extends ConsumerStatefulWidget {
  const ReminderEditPage({super.key, this.id});
  final String? id;

  @override
  ConsumerState<ReminderEditPage> createState() => _ReminderEditPageState();
}

class _ReminderEditPageState extends ConsumerState<ReminderEditPage> {
  Reminder? _orig;
  final _title = TextEditingController();
  final _note = TextEditingController();
  String _icon = 'alarm';
  Color _color = _accent;
  int _mode = ReminderRepeat.daily;
  List<(int, int)> _times = [];
  Set<int> _weekdays = {1, 2, 3, 4, 5};
  Set<String> _dates = {};
  bool _active = true;
  DateTime _focused = DateTime.now();

  @override
  void initState() {
    super.initState();
    final rec = widget.id == null ? null : ref.read(storeProvider).get(E.reminders, widget.id!);
    if (rec != null) {
      final r = _orig = Reminder(rec);
      _title.text = r.title;
      _note.text = r.note ?? '';
      _icon = r.icon ?? 'alarm';
      _color = hexColor(r.color, _accent);
      _mode = r.repeatMode;
      _times = r.times;
      if (r.weekdays.isNotEmpty) _weekdays = r.weekdays;
      _dates = r.dates.toSet();
      _active = r.isActive;
      final first = _dates.map(DateTime.tryParse).whereType<DateTime>().where((d) => !d.isBefore(dateOnly(DateTime.now()))).firstOrNull;
      if (first != null) _focused = first;
    } else {
      final n = DateTime.now().add(const Duration(hours: 1));
      _times = [(n.hour, 0)];
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickTime([int? index]) async {
    final cur = index == null ? (_times.lastOrNull ?? (8, 0)) : _times[index];
    final t = await showModernTimePicker(
      context,
      initial: TimeOfDay(hour: cur.$1, minute: cur.$2),
      title: index == null ? 'Thêm giờ nhắc' : 'Đổi giờ nhắc',
    );
    if (t == null) return;
    final v = (t.hour, t.minute);
    setState(() {
      if (index != null) _times.removeAt(index);
      if (!_times.contains(v)) _times.add(v);
      _times.sort((a, b) => (a.$1 * 60 + a.$2).compareTo(b.$1 * 60 + b.$2));
    });
  }

  void _save() {
    final title = _title.text.trim();
    String? err;
    if (title.isEmpty) {
      err = 'Nhập nội dung nhắc';
    } else if (_times.isEmpty) {
      err = 'Thêm ít nhất một giờ nhắc';
    } else if (_mode == ReminderRepeat.weekdays && _weekdays.isEmpty) {
      err = 'Chọn ít nhất một thứ trong tuần';
    } else if (_mode == ReminderRepeat.dates && _dates.isEmpty) {
      err = 'Chọn ít nhất một ngày';
    }
    if (err != null) return showToast(context, err, error: true);
    final store = ref.read(storeProvider);
    store.put(E.reminders, {
      if (_orig != null) ..._orig!.m,
      'title': title,
      'note': _note.text.trim().isEmpty ? null : _note.text.trim(),
      'icon': _icon,
      'color': colorHex(_color),
      'repeatMode': _mode,
      'times': _times.map(timeStr).join(','),
      'weekdays': _mode == ReminderRepeat.weekdays ? (_weekdays.toList()..sort()).join(',') : null,
      'dates': _mode == ReminderRepeat.dates ? (_dates.toList()..sort()).join(',') : null,
      'isActive': _active,
      'sortOrder': _orig?.sortOrder ?? store.all(E.reminders).length,
    });
    context.pop();
  }

  Future<void> _delete() async {
    if (!await confirm(context, 'Xoá nhắc nhở này?', ok: 'Xoá', danger: true)) return;
    ref.read(storeProvider).remove(E.reminders, _orig!.id);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_orig == null ? 'Thêm nhắc nhở' : 'Sửa nhắc nhở'),
        actions: [
          if (_orig != null) IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline_rounded), tooltip: 'Xoá'),
          TextButton(onPressed: _save, child: const Text('Lưu')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        children: [
          FormSection(
            title: 'Nội dung',
            children: [
              SectionField(controller: _title, hint: 'VD: Uống nước, Uống thuốc', icon: iconOf(_icon)),
              SectionField(controller: _note, hint: 'Ghi chú (tuỳ chọn)', icon: Icons.notes_rounded, maxLines: 3),
            ],
          ),
          FormSection(
            title: 'Biểu tượng & màu',
            padding: const EdgeInsets.all(14),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final ic in _icons)
                    Pressable(
                      onTap: () => setState(() => _icon = ic),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(color: ic == _icon ? _color : _color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                        child: Icon(iconOf(ic), color: ic == _icon ? Colors.white : _color, size: 22),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ColorPickerRow(value: _color, onChanged: (c) => setState(() => _color = c)),
              ),
            ],
          ),
          FormSection(
            title: 'Giờ nhắc',
            padding: const EdgeInsets.all(14),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (i, t) in _times.indexed)
                    InputChip(
                      key: ValueKey(t),
                      avatar: Icon(Icons.schedule_rounded, size: 18, color: _color),
                      label: Text(timeStr(t), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      onPressed: () => _pickTime(i),
                      onDeleted: () => setState(() => _times.removeAt(i)),
                    ).animate().fadeIn(duration: 200.ms).scaleXY(begin: 0.8, end: 1, duration: 260.ms, curve: Curves.easeOutBack),
                  ActionChip(avatar: const Icon(Icons.add_rounded, size: 18), label: const Text('Thêm giờ'), onPressed: _pickTime),
                ],
              ),
            ],
          ),
          FormSection(
            title: 'Lặp lại',
            padding: const EdgeInsets.all(14),
            children: [
              Center(
                child: PillToggle<int>(
                  value: _mode,
                  values: const [ReminderRepeat.daily, ReminderRepeat.weekdays, ReminderRepeat.dates],
                  icons: const [Icons.repeat_rounded, Icons.view_week_rounded, Icons.event_available_rounded],
                  labels: const ['Hằng ngày', 'Theo thứ', 'Chọn ngày'],
                  itemWidth: 100,
                  onChanged: (v) => setState(() => _mode = v),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (c, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(a),
                      child: c,
                    ),
                  ),
                  child: KeyedSubtree(key: ValueKey(_mode), child: _repeatPanel(scheme)),
                ),
              ),
            ],
          ),
          FormSection(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _active,
                onChanged: (v) => setState(() => _active = v),
                title: const Text('Đang bật'),
                secondary: Icon(Icons.notifications_active_rounded, color: _color),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check_rounded), label: const Text('Lưu nhắc nhở')),
        ],
      ),
    );
  }

  Widget _repeatPanel(ColorScheme scheme) {
    switch (_mode) {
      case ReminderRepeat.weekdays:
        final firstSunday = TimeConfig.of(ref.read(storeProvider)).firstDayOfWeek == 7;
        final order = firstSunday ? const [7, 1, 2, 3, 4, 5, 6] : const [1, 2, 3, 4, 5, 6, 7];
        return Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final d in order)
                    Pressable(
                      onTap: () => setState(() => _weekdays.contains(d) ? _weekdays.remove(d) : _weekdays.add(d)),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: _weekdays.contains(d) ? _color : scheme.surfaceContainerHighest, shape: BoxShape.circle),
                        child: Text(
                          Fmt.weekdaysShort[d - 1],
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _weekdays.contains(d) ? Colors.white : scheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  for (final (label, days) in const [
                    ('T2 – T6', {1, 2, 3, 4, 5}),
                    ('Cuối tuần', {6, 7}),
                    ('Cả tuần', {1, 2, 3, 4, 5, 6, 7}),
                  ])
                    ChoiceChip(
                      label: Text(label),
                      selected: _weekdays.length == days.length && _weekdays.containsAll(days),
                      onSelected: (_) => setState(() => _weekdays = {...days}),
                    ),
                ],
              ),
            ],
          ),
        );
      case ReminderRepeat.dates:
        final today = dateOnly(DateTime.now());
        final sorted = _dates.map(DateTime.tryParse).whereType<DateTime>().toList()..sort();
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Chạm vào từng ngày để chọn / bỏ chọn',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              TableCalendar(
                locale: 'vi',
                // Chỉ nhận vuốt ngang (đổi tháng); vuốt dọc nhường cho cuộn màn hình — bắt đầu vuốt trên lịch vẫn cuộn được.
                availableGestures: AvailableGestures.horizontalSwipe,
                firstDay: today,
                lastDay: DateTime(today.year + 5, 12, 31),
                focusedDay: _focused.isBefore(today) ? today : _focused,
                startingDayOfWeek: TimeConfig.of(ref.read(storeProvider)).firstDayOfWeek == 7 ? StartingDayOfWeek.sunday : StartingDayOfWeek.monday,
                availableCalendarFormats: const {CalendarFormat.month: 'Tháng'},
                rowHeight: 42,
                daysOfWeekHeight: 26,
                headerStyle: HeaderStyle(
                  titleCentered: true,
                  formatButtonVisible: false,
                  titleTextStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  titleTextFormatter: (d, _) => 'Tháng ${d.month}, ${d.year}',
                ),
                calendarStyle: CalendarStyle(
                  selectedDecoration: BoxDecoration(color: _color, shape: BoxShape.circle),
                  todayDecoration: BoxDecoration(color: _color.withValues(alpha: 0.18), shape: BoxShape.circle),
                  todayTextStyle: TextStyle(color: _color, fontWeight: FontWeight.w800),
                ),
                selectedDayPredicate: (d) => _dates.contains(Fmt.isoDate(d)),
                onPageChanged: (d) => _focused = d,
                onDaySelected: (d, f) {
                  HapticFeedback.selectionClick();
                  final k = Fmt.isoDate(d);
                  setState(() {
                    _focused = f;
                    _dates.contains(k) ? _dates.remove(k) : _dates.add(k);
                  });
                },
              ),
              if (sorted.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Đã chọn ${sorted.length} ngày', style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final d in sorted)
                      InputChip(
                        key: ValueKey(d),
                        label: Text('${Fmt.weekdaysShort[d.weekday - 1]} ${Fmt.dateShort(d)}'),
                        onPressed: () => setState(() => _focused = d),
                        onDeleted: () => setState(() => _dates.remove(Fmt.isoDate(d))),
                      ),
                  ],
                ),
              ],
            ],
          ),
        );
      default:
        return Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Text(
            'Nhắc mỗi ngày vào các giờ đã chọn.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        );
    }
  }
}
