import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../data/calendar_look.dart';
import '../data/time_config.dart';
import '../providers.dart';

/// Bộ chọn ngày (và giờ) dạng bottom sheet: lưới ngày bo tròn, chọn nhanh, chuyển tháng mượt,
/// bấm tiêu đề tháng để nhảy nhanh theo tháng/năm, giờ dạng bánh xe.
Future<DateTime?> showModernDatePicker(
  BuildContext context, {
  required DateTime initial,
  bool withTime = false,
  DateTime? firstDate,
  DateTime? lastDate,
  String? title,
}) {
  HapticFeedback.selectionClick();
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    sheetAnimationStyle: kSheetAnim,
    builder: (_) =>
        _DatePickerSheet(initial: initial, withTime: withTime, first: firstDate ?? DateTime(2000), last: lastDate ?? DateTime(2100, 12, 31), title: title),
  );
}

/// Chỉ chọn giờ (bánh xe 24h).
Future<TimeOfDay?> showModernTimePicker(BuildContext context, {required TimeOfDay initial, String title = 'Chọn giờ'}) {
  HapticFeedback.selectionClick();
  var h = (initial.hour % 24 + 24) % 24, m = (initial.minute % 60 + 60) % 60;
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    showDragHandle: true,
    sheetAnimationStyle: kSheetAnim,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            _TimeWheels(hour: h, minute: m, onChanged: (a, b) => (h, m) = (a, b)),
            const SizedBox(height: 16),
            _Actions(
              onDone: () => Navigator.pop(ctx, TimeOfDay(hour: (h % 24 + 24) % 24, minute: (m % 60 + 60) % 60)),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DatePickerSheet extends ConsumerStatefulWidget {
  const _DatePickerSheet({required this.initial, required this.withTime, required this.first, required this.last, this.title});
  final DateTime initial;
  final bool withTime;
  final DateTime first, last;
  final String? title;

  @override
  ConsumerState<_DatePickerSheet> createState() => _DatePickerSheetState();
}

class _DatePickerSheetState extends ConsumerState<_DatePickerSheet> {
  late DateTime selected = dateOnly(widget.initial);
  late DateTime month = DateTime(widget.initial.year, widget.initial.month);
  late int hour = (widget.initial.hour % 24 + 24) % 24, minute = (widget.initial.minute % 60 + 60) % 60;
  bool monthMode = false; // đang ở lưới chọn tháng/năm
  late int yearView = month.year;
  int dir = 1; // hướng trượt khi đổi tháng

  bool _allowed(DateTime d) => !d.isBefore(dateOnly(widget.first)) && !d.isAfter(dateOnly(widget.last));

  void _go(int delta) {
    HapticFeedback.selectionClick();
    setState(() {
      dir = delta;
      month = DateTime(month.year, month.month + delta);
    });
  }

  void _pick(DateTime d) {
    if (!_allowed(d)) return;
    HapticFeedback.selectionClick();
    setState(() {
      dir = d.isAfter(selected) ? 1 : -1;
      selected = d;
      month = DateTime(d.year, d.month);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = dateOnly(DateTime.now());
    final quick = <(String, DateTime)>[
      ('Hôm nay', today),
      ('Hôm qua', today.subtract(const Duration(days: 1))),
      ('Ngày mai', today.add(const Duration(days: 1))),
      ('+1 tuần', today.add(const Duration(days: 7))),
      ('+1 tháng', DateTime(today.year, today.month + 1, today.day)),
    ].where((q) => _allowed(q.$2)).toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Ngày đang chọn (to, đổi có hiệu ứng)
                    Text(widget.title ?? (widget.withTime ? 'Chọn ngày & giờ' : 'Chọn ngày'), style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 2),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (c, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(a),
                    child: c,
                  ),
                ),
                child: Align(
                  key: ValueKey('$selected$hour$minute'),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${Fmt.weekdays[selected.weekday - 1]}, ${Fmt.date(selected)}${widget.withTime ? ' · ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}' : ''}',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final (label, d) in quick)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _QuickChip(label: label, active: d == selected, onTap: () => _pick(d)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
                decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(20)),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Pressable(
                            onTap: () => setState(() {
                              monthMode = !monthMode;
                              yearView = month.year;
                            }),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              child: Row(
                                children: [
                                  Text(
                                    monthMode ? 'Năm $yearView' : 'Tháng ${month.month}, ${month.year}',
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                                  ),
                                  const SizedBox(width: 4),
                                  AnimatedRotation(
                                    turns: monthMode ? 0.5 : 0,
                                    duration: const Duration(milliseconds: 250),
                                    child: Icon(Icons.expand_more_rounded, color: scheme.primary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        _NavBtn(icon: Icons.chevron_left_rounded, onTap: () => monthMode ? setState(() => yearView--) : _go(-1)),
                        const SizedBox(width: 6),
                        _NavBtn(icon: Icons.chevron_right_rounded, onTap: () => monthMode ? setState(() => yearView++) : _go(1)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        transitionBuilder: (c, a) {
                          final incoming = c.key == ValueKey(monthMode ? 'm$yearView' : month);
                          final dx = (incoming ? dir : -dir) * 0.15;
                          return FadeTransition(
                            opacity: a,
                            child: SlideTransition(
                              position: Tween(begin: Offset(monthMode ? 0 : dx, 0), end: Offset.zero).animate(a),
                              child: c,
                            ),
                          );
                        },
                        child: monthMode ? _monthGrid(scheme) : _dayGrid(scheme, today),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.withTime) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 18, color: scheme.primary),
                    const SizedBox(width: 6),
                    const Text('Giờ', style: TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 6),
                _TimeWheels(
                  hour: hour,
                  minute: minute,
                  onChanged: (h, m) => setState(() {
                    hour = h;
                    minute = m;
                  }),
                ),
              ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _Actions(onDone: () => Navigator.pop(context, DateTime(selected.year, selected.month, selected.day, (hour % 24 + 24) % 24, (minute % 60 + 60) % 60))),
          ],
        ),
      ),
    );
  }

  Widget _dayGrid(ColorScheme scheme, DateTime today) {
    final store = ref.read(storeProvider);
    final look = CalendarLook.of(store);
    final fdw = TimeConfig.of(store).firstDayOfWeek; // 1 = T2, 7 = CN
    final first = DateTime(month.year, month.month);
    final lead = (first.weekday - fdw + 7) % 7;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final cells = ((lead + days + 6) ~/ 7) * 7;
    final names = [for (var i = 0; i < 7; i++) (fdw - 1 + i) % 7 + 1]; // weekday của từng cột
    return Column(
      key: ValueKey(month),
      children: [
        Row(
          children: [
            for (final wd in names)
              Expanded(
                child: Center(
                  child: Text(
                    Fmt.weekdaysShort[wd - 1],
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: look.weekdayColor(wd, scheme) ?? scheme.onSurfaceVariant),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cells,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 4, crossAxisSpacing: 4),
          itemBuilder: (_, i) {
            final n = i - lead + 1;
            if (n < 1 || n > days) return const SizedBox.shrink();
            final d = DateTime(month.year, month.month, n);
            final sel = d == selected, isToday = d == today, ok = _allowed(d);
            final wc = look.weekdayColor(d.weekday, scheme);
            return GestureDetector(
              onTap: () => _pick(d),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: sel ? scheme.primary : (isToday ? scheme.primary.withValues(alpha: 0.12) : Colors.transparent),
                  borderRadius: BorderRadius.circular(12),
                  border: isToday && !sel ? Border.all(color: scheme.primary.withValues(alpha: 0.6)) : null,
                  boxShadow: sel ? [BoxShadow(color: scheme.primary.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 3))] : null,
                ),
                alignment: Alignment.center,
                child: AnimatedScale(
                  scale: sel ? 1.08 : 1,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  child: Text(
                    '$n',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: sel || isToday ? FontWeight.w800 : FontWeight.w500,
                      color: !ok
                          ? scheme.onSurfaceVariant.withValues(alpha: 0.3)
                          : sel
                          ? scheme.onPrimary
                          : (isToday ? scheme.primary : (wc ?? scheme.onSurface)),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _monthGrid(ColorScheme scheme) => GridView.count(
    key: ValueKey('m$yearView'),
    crossAxisCount: 4,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: 8,
    crossAxisSpacing: 8,
    childAspectRatio: 1.6,
    padding: const EdgeInsets.only(top: 6),
    children: [
      for (var m = 1; m <= 12; m++)
        Builder(
          builder: (_) {
            final active = month.year == yearView && month.month == m;
            return Pressable(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  month = DateTime(yearView, m);
                  monthMode = false;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? scheme.primary : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Th $m',
                  style: TextStyle(fontWeight: FontWeight.w700, color: active ? scheme.onPrimary : scheme.onSurface),
                ),
              ),
            );
          },
        ),
    ],
  );
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: active ? scheme.primary : scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(17)),
        child: Text(
          label,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: active ? scheme.onPrimary : scheme.onSurface),
        ),
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  const _NavBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Pressable(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: scheme.surfaceContainerHighest, shape: BoxShape.circle),
        child: Icon(icon, size: 22),
      ),
    );
  }
}

/// Hai bánh xe giờ : phút (24h).
class _TimeWheels extends StatefulWidget {
  const _TimeWheels({required this.hour, required this.minute, required this.onChanged});
  final int hour, minute;
  final void Function(int h, int m) onChanged;

  @override
  State<_TimeWheels> createState() => _TimeWheelsState();
}

class _TimeWheelsState extends State<_TimeWheels> {
  late final _hc = FixedExtentScrollController(initialItem: (widget.hour % 24 + 24) % 24);
  late final _mc = FixedExtentScrollController(initialItem: (widget.minute % 60 + 60) % 60);
  late int h = (widget.hour % 24 + 24) % 24, m = (widget.minute % 60 + 60) % 60;

  @override
  void dispose() {
    _hc.dispose();
    _mc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget wheel(FixedExtentScrollController c, int count, ValueChanged<int> on) => Expanded(
      child: CupertinoPicker(
        scrollController: c,
        itemExtent: 40,
        looping: true,
        selectionOverlay: const SizedBox.shrink(),
        onSelectedItemChanged: (i) {
          HapticFeedback.selectionClick();
          on((i % count + count) % count);
        },
        children: [
          for (var i = 0; i < count; i++)
            Center(
              child: Text(
                i.toString().padLeft(2, '0'),
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: scheme.onSurface),
              ),
            ),
        ],
      ),
    );
    return Container(
      height: 150,
      decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(20)),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: 42,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
          ),
          Row(
            children: [
              wheel(_hc, 24, (v) => widget.onChanged(h = v, m)),
              Text(
                ':',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: scheme.primary),
              ),
              wheel(_mc, 60, (v) => widget.onChanged(h, m = v)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.onDone});
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: () => Navigator.pop(context),
          child: const Text('Huỷ'),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        flex: 2,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: () {
            HapticFeedback.mediumImpact();
            onDone();
          },
          icon: const Icon(Icons.check_rounded),
          label: const Text('Xong'),
        ),
      ),
    ],
  );
}
