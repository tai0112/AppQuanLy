import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../data/calendar_look.dart';
import '../data/local_store.dart';
import '../data/logic.dart';
import '../data/models.dart';
import '../data/time_config.dart';
import '../providers.dart';
import 'common.dart';

/// Theo dõi kinh nguyệt (bản thân / người yêu). Công thức & nguồn: PLAN.md mục 3.11.
class CyclePage extends ConsumerStatefulWidget {
  const CyclePage({super.key});

  @override
  ConsumerState<CyclePage> createState() => _CyclePageState();
}

class _CyclePageState extends ConsumerState<CyclePage> {
  int subject = 1;
  DateTime focused = DateTime.now();

  /// Lùi / tiến một tháng trên lịch (lịch tự trượt tới trang mới).
  void _moveMonth(int delta) => setState(() => focused = DateTime(focused.year, focused.month + delta, 1));

  CycleSettings _settings(LocalStore store) {
    final rec = store.all(E.cycleSettings).where((s) => (s['subject'] ?? 1) == subject).firstOrNull;
    return CycleSettings(rec ?? {'subject': subject});
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watchTables(const [E.cycleSettings, E.cyclePeriods, E.cycleLogs]);
    final periods = store.all(E.cyclePeriods).map(CyclePeriod.new).where((p) => p.subject == subject).toList()..sort((a, b) => b.start.compareTo(a.start));
    final settings = _settings(store);
    final p = Cycle.predict(periods, settings);
    final scheme = Theme.of(context).colorScheme;

    bool inPeriod(DateTime d) => periods.any((x) {
      final end = x.end ?? x.start.add(Duration(days: settings.periodDays - 1));
      return !d.isBefore(dateOnly(x.start)) && !d.isAfter(dateOnly(end));
    });
    bool predicted(DateTime d) => p != null && !d.isBefore(dateOnly(p.nextStart)) && d.isBefore(dateOnly(p.nextStart).add(Duration(days: p.avgPeriod.round())));
    bool fertile(DateTime d) => p != null && !d.isBefore(dateOnly(p.fertileStart)) && !d.isAfter(dateOnly(p.fertileEnd));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chu kỳ'),
        actions: [IconButton(onPressed: () => _settingsSheet(settings), icon: const Icon(Icons.tune_rounded))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.cycle,
        foregroundColor: Colors.white,
        onPressed: () => _editPeriod(null),
        icon: const Icon(Icons.water_drop_rounded),
        label: const Text('Ghi kỳ kinh'),
      ),
      // Vuốt từ mép trái / phải màn hình để lùi / tiến một tháng.
      body: EdgeSwipe(
        onPrev: () => _moveMonth(-1),
        onNext: () => _moveMonth(1),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            Center(
              child: PillToggle<int>(
                value: subject,
                values: const [1, 2],
                icons: const [Icons.person_rounded, Icons.favorite_rounded],
                labels: const ['Bản thân', 'Người yêu'],
                colors: const [AppColors.cycle, AppColors.love],
                itemWidth: 116,
                onChanged: (v) => setState(() => subject = v),
              ),
            ),
            const SizedBox(height: 14),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (c, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, 0.05), end: Offset.zero).animate(a),
                  child: c,
                ),
              ),
              child: KeyedSubtree(key: ValueKey('$subject-${p == null}'), child: p == null ? _emptyCard() : _todayCard(p, periods, settings)),
            ),
            if (p != null) ...[
              const SectionTitle('7 ngày tới'),
              _weekStrip(p, periods, settings),
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.event_available_rounded, color: AppColors.cycle, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Kỳ tiếp theo: ${Fmt.date(p.nextStart)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    if (p.earliest != p.latest)
                      Padding(
                        padding: const EdgeInsets.only(left: 28, top: 2),
                        child: Text(
                          'Có thể từ ${Fmt.dateShort(p.earliest)} đến ${Fmt.dateShort(p.latest)}',
                          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                        ),
                      ),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 2.6,
                      children: [
                        _stat(Icons.loop_rounded, 'Chu kỳ TB', '${p.avgCycle.toStringAsFixed(1)} ngày', AppColors.cycle),
                        _stat(Icons.water_drop_rounded, 'Hành kinh TB', '${p.avgPeriod.toStringAsFixed(1)} ngày', AppColors.cycle),
                        _stat(Icons.egg_rounded, 'Rụng trứng', Fmt.dateShort(p.ovulation), AppColors.income),
                        _stat(Icons.spa_rounded, 'Dễ thụ thai', '${Fmt.dateShort(p.fertileStart)}–${Fmt.dateShort(p.fertileEnd)}', AppColors.income),
                      ],
                    ),
                    if (p.calendarFertile != null || p.standardDays == true) const SizedBox(height: 8),
                    if (p.calendarFertile != null)
                      Text(
                        'Phương pháp lịch (Ogino–Knaus): ngày ${p.calendarFertile!.$1} → ${p.calendarFertile!.$2} của chu kỳ',
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                    if (p.standardDays == true)
                      Text(
                        'Standard Days Method: ngày 8 → 19 của chu kỳ (chu kỳ đều 26–32 ngày)',
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                    for (final w in p.warnings)
                      Container(
                        margin: const EdgeInsets.only(top: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(w, style: const TextStyle(fontSize: 13))),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            AppCard(
              padding: const EdgeInsets.all(8),
              child: TableCalendar(
                locale: 'vi',
                // Chỉ nhận vuốt ngang (đổi tháng); vuốt dọc nhường cho cuộn màn hình — bắt đầu vuốt trên lịch vẫn cuộn được.
                availableGestures: AvailableGestures.horizontalSwipe,
                firstDay: DateTime(2000),
                lastDay: DateTime(2100),
                focusedDay: focused,
                startingDayOfWeek: StartingDayOfWeek.values[TimeConfig.of(ref.read(storeProvider)).firstDayOfWeek - 1],
                availableCalendarFormats: const {CalendarFormat.month: 'Tháng'},
                daysOfWeekHeight: 30,
                rowHeight: 46,
                headerStyle: HeaderStyle(
                  titleCentered: true,
                  formatButtonVisible: false,
                  titleTextStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  titleTextFormatter: (d, _) => 'Tháng ${d.month}, ${d.year}',
                  leftChevronIcon: _navIcon(Icons.chevron_left_rounded),
                  rightChevronIcon: _navIcon(Icons.chevron_right_rounded),
                ),
                onPageChanged: (d) => focused = d,
                onDayLongPressed: (d, _) => _editPeriod(null, start: d),
                calendarBuilders: CalendarBuilders(
                  dowBuilder: (c, d) => calendarDow(c, d, CalendarLook.of(store)),
                  defaultBuilder: (c, d, _) =>
                      _day(d, inPeriod(dateOnly(d)), predicted(dateOnly(d)), fertile(dateOnly(d)), p != null && isSameDay(d, p.ovulation)),
                  todayBuilder: (c, d, _) =>
                      _day(d, inPeriod(dateOnly(d)), predicted(dateOnly(d)), fertile(dateOnly(d)), p != null && isSameDay(d, p.ovulation), today: true),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _legend(AppColors.cycle, 'Hành kinh'),
                _legend(AppColors.cycle.withValues(alpha: 0.35), 'Dự đoán'),
                _legend(AppColors.income.withValues(alpha: 0.5), 'Dễ thụ thai'),
                _legend(AppColors.income, 'Rụng trứng'),
              ],
            ),
            const SectionTitle('Các kỳ đã ghi'),
            for (final (i, x) in periods.indexed)
              ListTile(
                leading: const Icon(Icons.water_drop_rounded, color: AppColors.cycle),
                title: Text('${Fmt.date(x.start)}${x.end != null ? ' → ${Fmt.date(x.end!)}' : ''}'),
                subtitle: Text(
                  [
                    if (i < periods.length - 1) 'Chu kỳ ${x.start.difference(periods[i + 1].start).inDays} ngày',
                    if (x.flow != null) ['', 'Ít', 'Vừa', 'Nhiều'][x.flow!],
                    if (x.note?.isNotEmpty == true) x.note!,
                  ].join(' · '),
                ),
                onTap: () => _editPeriod(x),
              ).stagger(i),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: scheme.surfaceContainerHighest.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(12)),
              child: const Text(
                '⚠️ Dự đoán chỉ mang tính tham khảo, không dùng để tránh thai (phương pháp lịch có tỷ lệ thất bại ~25%/năm khi dùng thông thường). '
                'Số liệu dựa trên NHS, Cleveland Clinic, womenshealth.gov.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Color phaseColor(CyclePhase ph) => switch (ph) {
    CyclePhase.period => AppColors.cycle,
    CyclePhase.late => AppColors.expense,
    CyclePhase.soon => const Color(0xFFF76B15),
    CyclePhase.pms => AppColors.warning,
    CyclePhase.fertile => AppColors.income,
    CyclePhase.ovulation => const Color(0xFF12A594),
    CyclePhase.follicular => const Color(0xFF3E63DD),
    CyclePhase.luteal => const Color(0xFF8E4EC6),
  };

  static IconData phaseIcon(CyclePhase ph) => switch (ph) {
    CyclePhase.period => Icons.water_drop_rounded,
    CyclePhase.late => Icons.error_rounded,
    CyclePhase.soon => Icons.notifications_active_rounded,
    CyclePhase.pms => Icons.mood_bad_rounded,
    CyclePhase.fertile => Icons.spa_rounded,
    CyclePhase.ovulation => Icons.egg_rounded,
    CyclePhase.follicular => Icons.bolt_rounded,
    CyclePhase.luteal => Icons.nightlight_round,
  };

  static String phaseShort(CyclePhase ph) => switch (ph) {
    CyclePhase.period => 'Kinh',
    CyclePhase.late => 'Trễ',
    CyclePhase.soon => 'Sắp',
    CyclePhase.pms => 'PMS',
    CyclePhase.fertile => 'Thụ thai',
    CyclePhase.ovulation => 'Rụng',
    CyclePhase.follicular => 'Nang',
    CyclePhase.luteal => 'H.thể',
  };

  /// Chưa có dữ liệu: giới thiệu + nút ghi kỳ đầu tiên.
  Widget _emptyCard() {
    final scheme = Theme.of(context).colorScheme;
    final c = subject == 1 ? AppColors.cycle : AppColors.love;
    Widget feat(IconData i, String t) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: c.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Icon(i, size: 16, color: c),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(t, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
    return AppCard(
      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c.withValues(alpha: 0.22), c.withValues(alpha: 0.04)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: c.withValues(alpha: 0.4), blurRadius: 12)],
                ),
                child: Icon(subject == 1 ? Icons.water_drop_rounded : Icons.favorite_rounded, color: Colors.white),
              ).animate(onPlay: (a) => a.repeat(reverse: true)).scaleXY(begin: 1, end: 1.06, duration: 1200.ms, curve: Curves.easeInOut),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject == 1 ? 'Bắt đầu theo dõi chu kỳ' : 'Theo dõi chu kỳ của người ấy',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text('Ghi ít nhất 1 kỳ kinh, càng nhiều kỳ dự đoán càng chính xác.', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          feat(Icons.event_available_rounded, 'Dự đoán ngày bắt đầu kỳ tiếp theo'),
          feat(Icons.notifications_active_rounded, 'Thông báo mỗi ngày: sắp đến kỳ, trễ kinh, ngày dễ thụ thai…'),
          feat(Icons.spa_rounded, 'Biết giai đoạn hiện tại và lời khuyên phù hợp'),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: c, foregroundColor: Colors.white),
              onPressed: () => _editPeriod(null),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Ghi kỳ kinh đầu tiên'),
            ),
          ),
        ],
      ),
    );
  }

  /// Thẻ "Hôm nay": vòng tiến độ chu kỳ + thông báo của ngày.
  Widget _todayCard(CyclePrediction p, List<CyclePeriod> periods, CycleSettings settings) {
    final scheme = Theme.of(context).colorScheme;
    final info = CycleDays.of(p, periods, settings, DateTime.now(), partner: subject == 2)!;
    final c = phaseColor(info.phase);
    final total = p.avgCycle.round();
    final progress = (info.cycleDay / total).clamp(0.0, 1.0);
    final levelText = ['Thông tin', 'Lưu ý', 'Cảnh báo'][info.level];
    return AppCard(
      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c.withValues(alpha: 0.25), c.withValues(alpha: 0.05)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 96,
                height: 96,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, _) => Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: v,
                          strokeWidth: 9,
                          strokeCap: StrokeCap.round,
                          backgroundColor: c.withValues(alpha: 0.15),
                          color: c,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Ngày', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                          CountText(
                            values: [info.cycleDay.toDouble()],
                            text: (v) => '${v[0].round()}',
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: c, height: 1.1),
                          ),
                          Text('/ $total', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(phaseIcon(info.phase), size: 13, color: Colors.white),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Hôm nay · $levelText',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      info.title,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c, height: 1.2),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: scheme.surface.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(14)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(info.level == 2 ? Icons.priority_high_rounded : Icons.tips_and_updates_rounded, size: 18, color: c),
                const SizedBox(width: 8),
                Expanded(child: Text(info.body, style: const TextStyle(fontSize: 13, height: 1.35))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Dải 7 ngày tới, mỗi ngày một màu theo giai đoạn; bấm để xem lời nhắc của ngày đó.
  Widget _weekStrip(CyclePrediction p, List<CyclePeriod> periods, CycleSettings settings) {
    final scheme = Theme.of(context).colorScheme;
    final today = dateOnly(DateTime.now());
    final days = [for (var i = 0; i < 7; i++) CycleDays.of(p, periods, settings, today.add(Duration(days: i)), partner: subject == 2)!];
    return Row(
      children: [
        for (final (i, d) in days.indexed)
          Expanded(
            child: Pressable(
              onTap: () => showToast(context, '${Fmt.dayHeader(d.date)}: ${d.title}'),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: phaseColor(d.phase).withValues(alpha: i == 0 ? 0.28 : 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: i == 0 ? Border.all(color: phaseColor(d.phase), width: 1.5) : null,
                ),
                child: Column(
                  children: [
                    Text(i == 0 ? 'Nay' : Fmt.weekdaysShort[d.date.weekday - 1], style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 2),
                    Text('${d.date.day}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Icon(phaseIcon(d.phase), size: 16, color: phaseColor(d.phase)),
                    const SizedBox(height: 2),
                    FittedBox(
                      child: Text(
                        phaseShort(d.phase),
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: phaseColor(d.phase)),
                      ),
                    ),
                  ],
                ),
              ),
            ).stagger(i),
          ),
      ],
    );
  }

  Widget _stat(IconData icon, String label, String value, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(color: c.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12)),
    child: Row(
      children: [
        Icon(icon, size: 18, color: c),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _navIcon(IconData i) => Container(
    width: 34,
    height: 34,
    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, shape: BoxShape.circle),
    child: Icon(i, size: 22),
  );

  Widget _legend(Color c, String l) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(l, style: const TextStyle(fontSize: 12)),
    ],
  );

  Widget _day(DateTime d, bool period, bool predicted, bool fertile, bool ovulation, {bool today = false}) {
    Color? bg;
    Color? fg;
    if (period) {
      bg = AppColors.cycle;
      fg = Colors.white;
    } else if (predicted) {
      bg = AppColors.cycle.withValues(alpha: 0.3);
    } else if (ovulation) {
      bg = AppColors.income;
      fg = Colors.white;
    } else if (fertile) {
      bg = AppColors.income.withValues(alpha: 0.35);
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: today ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2) : null,
      ),
      alignment: Alignment.center,
      child: Text(
        '${d.day}',
        style: TextStyle(color: fg, fontWeight: today ? FontWeight.w800 : null),
      ),
    );
  }

  static const _symptoms = ['Đau bụng', 'Mệt mỏi', 'Đau đầu', 'Đau lưng', 'Nổi mụn', 'Thèm ngọt', 'Khó ngủ', 'Dễ cáu'];

  Future<void> _editPeriod(CyclePeriod? x, {DateTime? start}) async {
    var s = dateOnly(x?.start ?? start ?? DateTime.now());
    DateTime? e = x?.end == null ? null : dateOnly(x!.end!);
    var flow = x?.flow ?? 2;
    final note = TextEditingController(text: x?.note);
    final c = subject == 1 ? AppColors.cycle : AppColors.love;

    await showModalBottomSheet(
      sheetAnimationStyle: kSheetAnim,
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          final scheme = Theme.of(ctx).colorScheme;
          final days = e == null ? null : e!.difference(s).inDays + 1;
          final picked = {for (final t in _symptoms) t: note.text.contains(t)};

          void toggleSymptom(String t) {
            final parts = note.text.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
            parts.contains(t) ? parts.remove(t) : parts.add(t);
            set(() => note.text = parts.join(', '));
          }

          Widget dateCard(String label, IconData icon, DateTime? d, VoidCallback onTap, {VoidCallback? onClear}) => Expanded(
            child: Pressable(
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 12),
                decoration: BoxDecoration(
                  color: d == null ? scheme.surfaceContainerHigh : c.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: d == null ? scheme.outlineVariant.withValues(alpha: 0.5) : c.withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, size: 15, color: d == null ? scheme.onSurfaceVariant : c),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: d == null ? scheme.onSurfaceVariant : c),
                          ),
                        ),
                        if (onClear != null && d != null)
                          GestureDetector(
                            onTap: onClear,
                            child: Icon(Icons.close_rounded, size: 16, color: scheme.onSurfaceVariant),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Column(
                        key: ValueKey(d),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d == null ? 'Đang diễn ra' : Fmt.dateShort(d),
                            style: TextStyle(fontSize: d == null ? 16 : 22, fontWeight: FontWeight.w800, color: d == null ? scheme.onSurfaceVariant : null),
                          ),
                          Text(
                            d == null ? 'Bấm để chọn ngày' : '${Fmt.weekdays[d.weekday - 1]}, ${d.year}',
                            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

          Widget flowCard(int v, String label) {
            final on = flow == v;
            return Expanded(
              child: Pressable(
                onTap: () => set(() => flow = v),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: on ? c : scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: on ? [BoxShadow(color: c.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 3))] : null,
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < v; i++) Icon(Icons.water_drop_rounded, size: 16, color: on ? Colors.white : c.withValues(alpha: 0.4 + 0.2 * v)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: on ? Colors.white : null),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: [c, Color.lerp(c, Colors.black, 0.25)!]),
                        ),
                        child: const Icon(Icons.water_drop_rounded, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(x == null ? 'Ghi kỳ kinh' : 'Sửa kỳ kinh', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                            Text(subject == 1 ? 'Bản thân' : 'Người yêu', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: days == null
                            ? const SizedBox.shrink()
                            : Container(
                                key: ValueKey(days),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                                child: Text(
                                  '$days ngày',
                                  style: TextStyle(fontWeight: FontWeight.w800, color: c),
                                ),
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      dateCard('Bắt đầu', Icons.play_circle_rounded, s, () async {
                        final d = await pickDateTime(ctx, s, withTime: false, title: 'Ngày bắt đầu');
                        if (d != null) {
                          set(() {
                            s = dateOnly(d);
                            if (e != null && e!.isBefore(s)) e = null;
                          });
                        }
                      }),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.arrow_forward_rounded, size: 18, color: scheme.onSurfaceVariant),
                      ),
                      dateCard('Kết thúc', Icons.stop_circle_rounded, e, () async {
                        final d = await pickDateTime(ctx, e ?? s.add(const Duration(days: 4)), withTime: false, firstDate: s, title: 'Ngày kết thúc');
                        if (d != null) set(() => e = dateOnly(d));
                      }, onClear: () => set(() => e = null)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final n in [3, 5, 7])
                        ChoiceChip(
                          label: Text('$n ngày'),
                          selected: days == n,
                          onSelected: (_) => set(() => e = s.add(Duration(days: n - 1))),
                          visualDensity: VisualDensity.compact,
                        ),
                      ChoiceChip(
                        label: const Text('Đang diễn ra'),
                        selected: e == null,
                        onSelected: (_) => set(() => e = null),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Lượng máu', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Row(children: [flowCard(1, 'Ít'), const SizedBox(width: 8), flowCard(2, 'Vừa'), const SizedBox(width: 8), flowCard(3, 'Nhiều')]),
                  const SizedBox(height: 16),
                  const Text('Triệu chứng', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final t in _symptoms)
                        FilterChip(
                          label: Text(t),
                          selected: picked[t]!,
                          onSelected: (_) => toggleSymptom(t),
                          selectedColor: c.withValues(alpha: 0.2),
                          checkmarkColor: c,
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: note,
                    minLines: 1,
                    maxLines: 3,
                    onChanged: (_) => set(() {}),
                    decoration: InputDecoration(
                      hintText: 'Ghi chú thêm…',
                      prefixIcon: const Icon(Icons.edit_note_rounded),
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      if (x != null) ...[
                        IconButton.outlined(
                          tooltip: 'Xoá',
                          style: IconButton.styleFrom(
                            foregroundColor: AppColors.expense,
                            side: BorderSide(color: AppColors.expense.withValues(alpha: 0.5)),
                            minimumSize: const Size(52, 52),
                          ),
                          onPressed: () {
                            ref.read(storeProvider).remove(E.cyclePeriods, x.id);
                            Navigator.pop(ctx);
                            showToast(context, 'Đã xoá kỳ kinh');
                          },
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: c, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(52)),
                          onPressed: () {
                            ref.read(storeProvider).put(E.cyclePeriods, {
                              if (x != null) 'id': x.id,
                              'subject': subject,
                              'startDate': Fmt.isoDate(s),
                              'endDate': e == null ? null : Fmt.isoDate(e!),
                              'flow': flow,
                              'note': note.text.trim().isEmpty ? null : note.text.trim(),
                            });
                            Navigator.pop(ctx);
                            showToast(context, x == null ? 'Đã ghi kỳ kinh 🌸' : 'Đã cập nhật');
                          },
                          icon: const Icon(Icons.check_rounded),
                          label: Text(x == null ? 'Lưu kỳ kinh' : 'Cập nhật'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _settingsSheet(CycleSettings s) async {
    var cycle = s.cycleDays.toDouble(), period = s.periodDays.toDouble(), luteal = s.lutealDays.toDouble();
    var before = s.fertileBefore.toDouble(), after = s.fertileAfter.toDouble();
    var sync = s.syncEnabled;
    var daily = s.dailyRemind;
    var remindAt = TimeOfDay(hour: s.remindHour, minute: s.remindMinute);
    await showModalBottomSheet(
      sheetAnimationStyle: kSheetAnim,
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Cấu hình chu kỳ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                Text('Chu kỳ mặc định: ${cycle.round()} ngày'),
                Slider(value: cycle, min: 21, max: 45, divisions: 24, onChanged: (v) => set(() => cycle = v)),
                Text('Số ngày hành kinh mặc định: ${period.round()}'),
                Slider(value: period, min: 2, max: 10, divisions: 8, onChanged: (v) => set(() => period = v)),
                Text('Pha hoàng thể: ${luteal.round()} ngày (rụng trứng trước kỳ sau)'),
                Slider(value: luteal, min: 10, max: 16, divisions: 6, onChanged: (v) => set(() => luteal = v)),
                Text('Dễ thụ thai: ${before.round()} ngày trước → ${after.round()} ngày sau rụng trứng'),
                Row(
                  children: [
                    Expanded(
                      child: Slider(value: before, min: 0, max: 7, divisions: 7, onChanged: (v) => set(() => before = v)),
                    ),
                    Expanded(
                      child: Slider(value: after, min: 0, max: 3, divisions: 3, onChanged: (v) => set(() => after = v)),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: daily,
                  onChanged: (v) => set(() => daily = v),
                  secondary: const Icon(Icons.notifications_active_rounded, color: AppColors.cycle),
                  title: const Text('Thông báo mỗi ngày'),
                  subtitle: const Text('Giai đoạn hôm nay, sắp đến kỳ, trễ kinh, ngày dễ thụ thai…'),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  child: !daily
                      ? const SizedBox(width: double.infinity)
                      : ListTile(
                          contentPadding: const EdgeInsets.only(left: 40),
                          leading: const Icon(Icons.schedule_rounded),
                          title: const Text('Giờ nhận thông báo'),
                          trailing: Text(remindAt.format(ctx), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          onTap: () async {
                            final t = await showModernTimePicker(ctx, initial: remindAt, title: 'Giờ nhận thông báo');
                            if (t != null) set(() => remindAt = t);
                          },
                        ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: sync,
                  onChanged: (v) => set(() => sync = v),
                  title: const Text('Đồng bộ dữ liệu chu kỳ lên máy chủ'),
                  subtitle: const Text('Tắt: dữ liệu chỉ lưu trên máy này'),
                ),
                FilledButton(
                  onPressed: () {
                    ref.read(storeProvider).put(E.cycleSettings, {
                      ...s.m,
                      'subject': subject,
                      'defaultCycleDays': cycle.round(),
                      'defaultPeriodDays': period.round(),
                      'lutealDays': luteal.round(),
                      'fertileDaysBefore': before.round(),
                      'fertileDaysAfter': after.round(),
                      'syncEnabled': sync,
                      'remindersJson': jsonEncode({'daily': daily, 'hour': remindAt.hour, 'minute': remindAt.minute}),
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text('Lưu'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
