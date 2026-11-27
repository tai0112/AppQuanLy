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
import 'cycle_range_picker.dart';

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
    final firstDow = TimeConfig.of(ref.read(storeProvider)).firstDayOfWeek;
    // Ô lịch: kỳ kinh / dự đoán / dễ thụ thai tô thành DẢI LIỀN giữa các ngày liên tiếp (đầu tuần / cuối tuần bo tròn).
    Widget dayCell(DateTime raw, {bool today = false}) {
      final d = dateOnly(raw);
      final prev = d.subtract(const Duration(days: 1)), next = d.add(const Duration(days: 1));
      final weekStart = (d.weekday - firstDow + 7) % 7 == 0, weekEnd = (d.weekday - firstDow + 7) % 7 == 6;
      // Một hàm dùng chung với thẻ "Hôm nay" / 7 ngày tới (chiếu chu kỳ ra các tháng sau, nới cửa sổ khi chu kỳ không đều)
      int kindOf(DateTime x) => switch (p == null ? (inPeriod(x) ? CycleMark.period : CycleMark.none) : Cycle.markOf(p, periods, settings, x)) {
        CycleMark.period => 1,
        CycleMark.predicted => 2,
        CycleMark.fertile || CycleMark.ovulation => 3,
        CycleMark.safe => 4,
        CycleMark.safeRelative => 5,
        CycleMark.none => 0,
      };
      final kind = kindOf(d);
      return _day(
        d,
        kind: kind,
        joinLeft: kind != 0 && !weekStart && kindOf(prev) == kind,
        joinRight: kind != 0 && !weekEnd && kindOf(next) == kind,
        ovulation: p != null && Cycle.markOf(p, periods, settings, d) == CycleMark.ovulation,
        today: today,
      );
    }

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
            if (p != null) ...[const SectionTitle('7 ngày tới'), _weekStrip(p, periods, settings)],
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
                  defaultBuilder: (c, d, _) => dayCell(d),
                  todayBuilder: (c, d, _) => dayCell(d, today: true),
                  outsideBuilder: (c, d, _) => Opacity(opacity: 0.35, child: dayCell(d)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _legend(AppColors.cycle, 'Hành kinh'),
                _legend(AppColors.cycle.withValues(alpha: 0.3), 'Dự đoán'),
                _legend(AppColors.income.withValues(alpha: 0.35), 'Dễ thụ thai'),
                _legend(AppColors.income, 'Rụng trứng'),
                _legend(_safeColor.withValues(alpha: 0.45), 'An toàn'),
                _legend(_safeColor.withValues(alpha: 0.18), 'An toàn tương đối'),
              ],
            ),
            if (p != null) ...[
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
                        if (p.safeEarly case final r?)
                          _stat(Icons.shield_outlined, 'An toàn tương đối', '${Fmt.dateShort(r.$1)}–${Fmt.dateShort(r.$2)}', _safeColor),
                        if (p.safeLate case final r?) _stat(Icons.shield_rounded, 'An toàn hơn', '${Fmt.dateShort(r.$1)}–${Fmt.dateShort(r.$2)}', _safeColor),
                      ],
                    ),
                    if (p.irregular)
                      Container(
                        margin: const EdgeInsets.only(top: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Chu kỳ chưa đều: cửa sổ dễ thụ thai đã được nới rộng, ngày an toàn kém tin cậy — đừng dựa vào để tránh thai.',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
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
            const SectionTitle('Các kỳ đã ghi'),
            if (periods.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('Chưa ghi kỳ nào', style: TextStyle(color: scheme.onSurfaceVariant)),
              ),
            for (final (i, x) in periods.indexed) _periodCard(x, i < periods.length - 1 ? x.start.difference(periods[i + 1].start).inDays : null).stagger(i),
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
          const SizedBox(height: 12),
          _quickAction(periods, settings),
        ],
      ),
    );
  }

  /// Ghi nhanh một chạm: "Bắt đầu kỳ hôm nay" / "Kết thúc kỳ hôm nay" (khi đang có kỳ chưa kết thúc) / "Sửa kỳ này".
  Widget _quickAction(List<CyclePeriod> periods, CycleSettings settings) {
    final c = subject == 1 ? AppColors.cycle : AppColors.love;
    final today = dateOnly(DateTime.now());
    final store = ref.read(storeProvider);
    // Kỳ đang mở: chưa có ngày kết thúc, bắt đầu trong vòng 15 ngày qua
    final open = periods.where((x) => x.end == null && !dateOnly(x.start).isAfter(today) && today.difference(dateOnly(x.start)).inDays < 15).firstOrNull;
    // Hôm nay nằm trong một kỳ đã ghi đủ ngày
    final current = periods.where((x) => x.end != null && !today.isBefore(dateOnly(x.start)) && !today.isAfter(dateOnly(x.end!))).firstOrNull;

    final (IconData icon, String label, VoidCallback onTap) = switch ((open, current)) {
      (final o?, _) => (
        Icons.stop_circle_rounded,
        'Kết thúc kỳ hôm nay (ngày ${today.difference(dateOnly(o.start)).inDays + 1})',
        () {
          store.put(E.cyclePeriods, {'id': o.id, 'endDate': Fmt.isoDate(today)});
          showToast(context, 'Đã ghi kết thúc kỳ: ${today.difference(dateOnly(o.start)).inDays + 1} ngày');
        },
      ),
      (_, final cur?) => (Icons.edit_calendar_rounded, 'Sửa kỳ này', () => _editPeriod(cur)),
      _ => (
        Icons.play_circle_rounded,
        'Bắt đầu kỳ hôm nay',
        () {
          final rec = store.put(E.cyclePeriods, {'subject': subject, 'startDate': Fmt.isoDate(today), 'endDate': null, 'flow': 2});
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                content: const Text('Đã ghi bắt đầu kỳ hôm nay 🌸 — khi hết, bấm "Kết thúc kỳ hôm nay"'),
                action: SnackBarAction(label: 'Hoàn tác', onPressed: () => store.remove(E.cyclePeriods, rec['id'] as String)),
              ),
            );
        },
      ),
    };
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: c, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(44)),
            onPressed: onTap,
            icon: Icon(icon, size: 20),
            label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          tooltip: 'Ghi kỳ khác (chọn ngày)',
          style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
          onPressed: () => _editPeriod(null),
          icon: const Icon(Icons.date_range_rounded),
        ),
      ],
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

  /// Màu ngày an toàn (xanh dương dịu, tách hẳn khỏi hồng – kinh nguyệt và xanh lá – dễ thụ thai).
  static const _safeColor = Color(0xFF3E63DD);

  /// Một ô lịch: [kind] 1 = hành kinh, 2 = dự đoán, 3 = dễ thụ thai, 4 = an toàn, 5 = an toàn tương đối, 0 = thường.
  Widget _day(DateTime d, {required int kind, bool joinLeft = false, bool joinRight = false, bool ovulation = false, bool today = false}) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (kind) {
      1 => AppColors.cycle,
      2 => AppColors.cycle.withValues(alpha: 0.18),
      3 => AppColors.income.withValues(alpha: 0.18),
      4 => _safeColor.withValues(alpha: 0.16),
      5 => _safeColor.withValues(alpha: 0.07),
      _ => Colors.transparent,
    };
    final fg = kind == 1
        ? Colors.white
        : kind == 2
        ? AppColors.cycle
        : kind == 3
        ? AppColors.income
        : kind == 4
        ? _safeColor
        : null;
    return Stack(
      alignment: Alignment.center,
      children: [
        // Dải nền liền
        Positioned.fill(
          top: 6,
          bottom: 6,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.horizontal(left: Radius.circular(joinLeft ? 0 : 17), right: Radius.circular(joinRight ? 0 : 17)),
              // Kỳ dự đoán: viền nét mảnh để phân biệt với kỳ đã ghi
              border: kind == 2 ? Border.all(color: AppColors.cycle.withValues(alpha: 0.45)) : null,
            ),
          ),
        ),
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ovulation ? AppColors.income : null,
            border: today ? Border.all(color: kind == 1 ? Colors.white : scheme.primary, width: 2) : null,
          ),
          child: Text(
            '${d.day}',
            style: TextStyle(color: ovulation ? Colors.white : fg, fontWeight: today || kind == 1 || ovulation ? FontWeight.w800 : FontWeight.w500),
          ),
        ),
      ],
    );
  }

  /// Thẻ một kỳ đã ghi: khoảng ngày, số ngày, độ dài chu kỳ, lượng máu, ghi chú.
  Widget _periodCard(CyclePeriod x, int? cycleLen) {
    final scheme = Theme.of(context).colorScheme;
    final c = subject == 1 ? AppColors.cycle : AppColors.love;
    final ongoing = x.end == null;
    final len = ongoing ? DateTime.now().difference(x.start).inDays + 1 : x.end!.difference(x.start).inDays + 1;
    Widget chip(IconData icon, String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: c),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c),
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        onTap: () => _editPeriod(x),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 46,
              decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ongoing ? '${Fmt.dateShort(x.start)} → đang diễn ra' : '${Fmt.dateShort(x.start)} → ${Fmt.dateShort(x.end!)}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      chip(Icons.water_drop_rounded, '$len ngày'),
                      if (cycleLen != null) chip(Icons.loop_rounded, 'Chu kỳ $cycleLen ngày'),
                      if (x.flow != null && x.flow! > 0) chip(Icons.opacity_rounded, ['', 'Ít', 'Vừa', 'Nhiều'][x.flow!]),
                    ],
                  ),
                  if (x.note?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        x.note!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  /// Ô nhỏ tóm tắt ngày bắt đầu / kết thúc trong bảng ghi kỳ kinh.
  Widget _rangePill(BuildContext ctx, String label, String value, Color c, {required bool filled}) {
    final scheme = Theme.of(ctx).colorScheme;
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: filled ? c.withValues(alpha: 0.12) : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: filled ? c.withValues(alpha: 0.45) : scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: filled ? c : scheme.onSurfaceVariant),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Text(
                value,
                key: ValueKey(value),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: filled ? null : scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
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
    final store = ref.read(storeProvider);
    final settings = _settings(store);
    final firstDow = TimeConfig.of(store).firstDayOfWeek;
    // Ngày của các kỳ khác đã ghi → chấm nhỏ trên lịch để tránh ghi trùng
    final otherDays = <DateTime>{
      for (final o in store.all(E.cyclePeriods).map(CyclePeriod.new).where((o) => o.subject == subject && o.id != x?.id))
        for (var d = dateOnly(o.start); !d.isAfter(dateOnly(o.end ?? o.start.add(Duration(days: settings.periodDays - 1)))); d = d.add(const Duration(days: 1)))
          d,
    };

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

          return FormSheetBody(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            action: Row(
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
              // Tóm tắt khoảng ngày đang chọn
              Row(
                children: [
                  _rangePill(ctx, 'Bắt đầu', Fmt.dateShort(s), c, filled: true),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.arrow_forward_rounded, size: 16, color: scheme.onSurfaceVariant),
                  ),
                  _rangePill(ctx, 'Kết thúc', e == null ? 'Đang diễn ra' : Fmt.dateShort(e!), c, filled: e != null),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Bấm ngày bắt đầu rồi kéo tới ngày kết thúc · hoặc chạm ngày đầu, rồi chạm ngày cuối',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.fromLTRB(4, 2, 4, 6),
                decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(18)),
                child: CycleRangePicker(
                  start: s,
                  end: e,
                  color: c,
                  firstDayOfWeek: firstDow,
                  expectedDays: settings.periodDays,
                  otherDays: otherDays,
                  onChanged: (a, b) => set(() {
                    s = dateOnly(a);
                    e = b == null ? null : dateOnly(b);
                  }),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
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
            ],
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
        builder: (ctx, set) => FormSheetBody(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          action: FilledButton(
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
          ],
        ),
      ),
    );
  }
}
