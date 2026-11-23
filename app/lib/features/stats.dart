import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../data/logic.dart';
import '../data/models.dart';
import '../providers.dart';
import 'transactions.dart';

/// Thống kê: theo tháng, theo danh mục (bấm để xem mục con), theo tài khoản, theo năm.
class StatsPage extends ConsumerStatefulWidget {
  const StatsPage({super.key});

  @override
  ConsumerState<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends ConsumerState<StatsPage> with SingleTickerProviderStateMixin {
  // Giải phóng tài nguyên khi đóng màn (tránh tích tụ khi mở/đóng nhiều lần)
  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  late final tabs = TabController(length: 3, vsync: this);
  DateTime month = DateTime.now();
  int year = DateTime.now().year;
  int type = TxType.expense;
  String? drillParent;
  int touched = -1;

  /// Tháng đem ra so sánh; null = tháng liền trước tháng đang xem (tự đi theo khi đổi tháng).
  DateTime? cmpMonth;
  bool cmpAll = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thống kê'),
        bottom: TabBar(
          controller: tabs,
          tabs: const [
            Tab(text: 'Tháng'),
            Tab(text: 'Năm'),
            Tab(text: 'Tài khoản'),
          ],
        ),
      ),
      body: TabBarView(controller: tabs, children: [_month(), _year(), _accounts()]),
    );
  }

  /// Trang thống kê ngắn: dựng một lần (không huỷ khi cuộn → biểu đồ không vẽ lại / chạy lại hiệu ứng), mỗi khối có ranh giới vẽ lại riêng.
  Widget _scroll({required EdgeInsetsGeometry padding, required List<Widget> children}) => SingleChildScrollView(
    padding: padding,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final w in children) w is SizedBox || w is SectionTitle ? w : RepaintBoundary(child: w)],
    ),
  );

  Widget _month() {
    final f = ref.watch(financeProvider);
    final (from, to) = f.monthRange(month);
    final list = f.inRange(from, to);
    final cmp = cmpMonth ?? DateTime(month.year, month.month - 1, 15);
    final (pFrom, pTo) = f.monthRange(cmp);
    final prevList = f.inRange(pFrom, pTo);
    final prev = f.totals(prevList);
    final cmpLabel = cmpMonth == null ? 'tháng trước' : 'tháng ${Fmt.month(pFrom)}';
    final cur = f.totals(list);
    final groups = f.byCategory(list, type, parentId: drillParent);
    final total = groups.fold(0.0, (s, g) => s + g.amount);
    final days = to.difference(from).inDays;
    final daily = List<double>.filled(days, 0);
    for (final t in list.where((t) => t.type == type)) {
      final i = dateOnly(t.occurredAt).difference(from).inDays;
      if (i >= 0 && i < days) daily[i] += f.toBase(t);
    }
    final diff = type == TxType.expense ? cur.expense - prev.expense : cur.income - prev.income;
    final color = type == TxType.expense ? AppColors.expense : AppColors.income;

    return _scroll(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        Row(
          children: [
            IconButton(onPressed: () => setState(() => month = DateTime(month.year, month.month - 1, 15)), icon: const Icon(Icons.chevron_left_rounded)),
            Expanded(
              child: Center(
                child: Text('Tháng ${Fmt.month(from)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ),
            IconButton(onPressed: () => setState(() => month = DateTime(month.year, month.month + 1, 15)), icon: const Icon(Icons.chevron_right_rounded)),
            const SizedBox(width: 4),
            // Nút so sánh ngay đầu trang: bấm để chọn tháng đem ra so sánh.
            Tooltip(
              message: 'So sánh với tháng khác',
              child: ActionChip(
                visualDensity: VisualDensity.compact,
                avatar: const Icon(Icons.compare_arrows_rounded, size: 16),
                label: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(cmpMonth == null ? 'Tháng trước' : Fmt.month(pFrom), key: ValueKey(pFrom)),
                ),
                onPressed: () => _pickCompareMonth(f, from, pFrom),
              ),
            ),
          ],
        ),
        Row(
          children: [
            _StatBox('Thu', cur.income, AppColors.income, f, prev: prev.income, upIsGood: true),
            const SizedBox(width: 8),
            _StatBox('Chi', cur.expense, AppColors.expense, f, prev: prev.expense, upIsGood: false),
            const SizedBox(width: 8),
            _StatBox('Tiết kiệm', cur.income - cur.expense, Theme.of(context).colorScheme.primary, f, prev: prev.income - prev.expense, upIsGood: true),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: CountText(
                values: [diff.abs()],
                text: (cv) => '${type == TxType.expense ? 'Chi' : 'Thu'} ${diff >= 0 ? 'tăng' : 'giảm'} ${f.money(cv[0])} so với $cmpLabel',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(width: 8),
            PillToggle<int>(
              value: type,
              values: const [TxType.expense, TxType.income],
              icons: const [Icons.north_east_rounded, Icons.south_west_rounded],
              labels: const ['Chi', 'Thu'],
              colors: const [AppColors.expense, AppColors.income],
              onChanged: (v) => setState(() {
                type = v;
                drillParent = null;
              }),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            children: [
              Row(
                children: [
                  if (drillParent != null) IconButton(onPressed: () => setState(() => drillParent = null), icon: const Icon(Icons.arrow_back_rounded)),
                  Expanded(
                    child: Text(
                      drillParent == null ? 'Theo danh mục' : 'Chi tiết: ${f.category(drillParent)?.name}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  CountText(
                    values: [total],
                    text: (cv) => f.money(cv[0]),
                    style: TextStyle(fontWeight: FontWeight.w700, color: color),
                  ),
                ],
              ),
              if (groups.isEmpty)
                const Padding(padding: EdgeInsets.all(32), child: Text('Chưa có dữ liệu'))
              else ...[
                SizedBox(
                  height: 220,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 54,
                      pieTouchData: PieTouchData(
                        // Chỉ dựng lại khi lát được chạm THỰC SỰ đổi (trước đây mỗi lần ngón tay lướt qua khi cuộn đều dựng lại cả trang)
                        touchCallback: (e, r) {
                          // Chạm (nhấc tay) vào một lát = mở giống bấm dòng tương ứng: vào chi tiết / xem danh sách giao dịch.
                          if (e is FlTapUpEvent) {
                            final hit = r?.touchedSection?.touchedSectionIndex ?? -1;
                            if (hit >= 0 && hit < groups.length) {
                              HapticFeedback.selectionClick();
                              _openGroup(groups[hit], list);
                            }
                          }
                          final i = e.isInterestedForInteractions ? (r?.touchedSection?.touchedSectionIndex ?? -1) : -1;
                          if (i != touched) setState(() => touched = i);
                        },
                      ),
                      sections: [
                        for (final (i, g) in groups.indexed)
                          PieChartSectionData(
                            value: g.amount,
                            color: hexColor(g.category?.color, AppColors.autoPalette[i % AppColors.autoPalette.length]),
                            radius: touched == i ? 62 : 52,
                            title: total == 0 ? '' : '${(g.amount / total * 100).toStringAsFixed(0)}%',
                            titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                      ],
                    ),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                  ),
                ),
                for (final (i, g) in groups.indexed)
                  Pressable(
                    scale: 0.98,
                    onTap: () => _openGroup(g, list),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              CircleIcon(icon: g.category?.icon, color: hexColor(g.category?.color), size: 36),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(g.category?.name ?? 'Không có danh mục', style: const TextStyle(fontWeight: FontWeight.w600)),
                              ),
                              CountText(
                                values: [g.amount],
                                text: (cv) => f.money(cv[0]),
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: total == 0 ? 0 : g.amount / total),
                              duration: const Duration(milliseconds: 700),
                              curve: Curves.easeOutCubic,
                              builder: (_, v, __) => LinearProgressIndicator(value: v, minHeight: 6, color: hexColor(g.category?.color)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).stagger(i),
              ],
            ],
          ),
        ),
        const SectionTitle('So sánh'),
        _compareCard(f, from, pFrom, cur, prev, list, prevList),
        const SectionTitle('Theo ngày'),
        AppCard(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
          child: _MonthCalendar(from: from, daily: daily, color: color, onTapDay: (d) => _showDay(d, list)),
        ),
      ],
    );
  }

  /// Thẻ so sánh tháng đang xem với một tháng tuỳ chọn: tổng Thu / Chi / Tiết kiệm và từng danh mục.
  Widget _compareCard(
    Finance f,
    DateTime from,
    DateTime pFrom,
    ({double income, double expense}) cur,
    ({double income, double expense}) prev,
    List<Txn> list,
    List<Txn> prevList,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final a = {for (final g in f.byCategory(list, type)) g.category?.id: g};
    final b = {for (final g in f.byCategory(prevList, type)) g.category?.id: g};
    final keys = {...a.keys, ...b.keys}.toList()
      ..sort((x, y) {
        final mx = [a[x]?.amount ?? 0, b[x]?.amount ?? 0].reduce((p, q) => p > q ? p : q);
        final my = [a[y]?.amount ?? 0, b[y]?.amount ?? 0].reduce((p, q) => p > q ? p : q);
        return my.compareTo(mx);
      });
    final maxAmt = keys.isEmpty
        ? 0.0
        : [
            for (final k in keys) ...[a[k]?.amount ?? 0, b[k]?.amount ?? 0],
          ].reduce((p, q) => p > q ? p : q);
    final shown = cmpAll ? keys : keys.take(6).toList();
    final color = type == TxType.expense ? AppColors.expense : AppColors.income;

    Widget row(String label, double now, double then, Color c, {required bool upIsGood}) {
      final d = now - then;
      final good = d == 0 ? null : (d > 0) == upIsGood;
      final dc = good == null ? scheme.onSurfaceVariant : (good ? AppColors.income : AppColors.expense);
      final pct = then == 0 ? null : d / then.abs() * 100;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 72,
              child: Text(
                label,
                style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedAmount(
                    value: now,
                    format: f.money,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  AnimatedAmount(
                    value: then,
                    format: f.money,
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: dc.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${d > 0
                        ? '+'
                        : d < 0
                        ? '−'
                        : ''}${Fmt.compact(d.abs())}',
                    style: TextStyle(color: dc, fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                  if (pct != null) Text('${pct > 0 ? '+' : ''}${pct.toStringAsFixed(pct.abs() >= 10 ? 0 : 1)}%', style: TextStyle(color: dc, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: Fmt.month(from),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(
                        text: '  so với',
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              if (cmpMonth != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Về tháng trước',
                  onPressed: () => setState(() => cmpMonth = null),
                  icon: const Icon(Icons.restart_alt_rounded, size: 20),
                ),
              ActionChip(
                avatar: const Icon(Icons.compare_arrows_rounded, size: 16),
                label: Text(Fmt.month(pFrom)),
                onPressed: () => _pickCompareMonth(f, from, pFrom),
              ),
            ],
          ),
          const SizedBox(height: 4),
          row('Thu', cur.income, prev.income, AppColors.income, upIsGood: true),
          row('Chi', cur.expense, prev.expense, AppColors.expense, upIsGood: false),
          row('Tiết kiệm', cur.income - cur.expense, prev.income - prev.expense, scheme.primary, upIsGood: true),
          const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: Text('${type == TxType.expense ? 'Chi' : 'Thu'} theo danh mục', style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              _legendDot(color, Fmt.month(from)),
              const SizedBox(width: 10),
              _legendDot(scheme.outline, Fmt.month(pFrom)),
            ],
          ),
          const SizedBox(height: 6),
          if (keys.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: Text('Chưa có dữ liệu')),
            )
          else
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: Column(
                children: [for (final k in shown) _cmpCategoryRow(f, (a[k] ?? b[k])!.category, a[k]?.amount ?? 0, b[k]?.amount ?? 0, maxAmt, color, scheme)],
              ),
            ),
          if (keys.length > 6) TextButton(onPressed: () => setState(() => cmpAll = !cmpAll), child: Text(cmpAll ? 'Thu gọn' : 'Xem tất cả (${keys.length})')),
        ],
      ),
    );
  }

  Widget _legendDot(Color c, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 11)),
    ],
  );

  Widget _cmpCategoryRow(Finance f, Category? c, double now, double then, double maxAmt, Color color, ColorScheme scheme) {
    final d = now - then;
    // Chi tăng là xấu, thu tăng là tốt.
    final good = d == 0 ? null : (d > 0) == (type == TxType.income);
    final dc = good == null ? scheme.onSurfaceVariant : (good ? AppColors.income : AppColors.expense);
    Widget bar(double v, Color c) => ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: maxAmt == 0 ? 0 : v / maxAmt),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (_, x, _) => LinearProgressIndicator(value: x, minHeight: 5, color: c, backgroundColor: scheme.surfaceContainerHighest),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleIcon(icon: c?.icon, color: hexColor(c?.color), size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        c?.name ?? 'Không có danh mục',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                    Text('${Fmt.compact(now)} / ${Fmt.compact(then)}', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 4),
                bar(now, color),
                const SizedBox(height: 3),
                bar(then, scheme.outline),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 52,
            child: Text(
              d == 0 ? '—' : '${d > 0 ? '+' : '−'}${Fmt.compact(d.abs())}',
              textAlign: TextAlign.end,
              style: TextStyle(color: dc, fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  /// Chọn tháng để so sánh: lưới 12 tháng, đổi năm bằng mũi tên. Tháng đang xem bị khoá.
  void _pickCompareMonth(Finance f, DateTime from, DateTime pFrom) {
    var y = pFrom.year;
    final curKey = (from.year, from.month);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      sheetAnimationStyle: kSheetAnim,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final scheme = Theme.of(ctx).colorScheme;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('So sánh với tháng', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton.filledTonal(onPressed: () => setSheet(() => y--), icon: const Icon(Icons.chevron_left_rounded)),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Text(
                            'Năm $y',
                            key: ValueKey(y),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                        ),
                      ),
                      IconButton.filledTonal(onPressed: () => setSheet(() => y++), icon: const Icon(Icons.chevron_right_rounded)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.8,
                    children: [
                      for (var m = 1; m <= 12; m++)
                        Builder(
                          builder: (_) {
                            final (mFrom, _) = f.monthRange(DateTime(y, m, 15));
                            final isCur = (mFrom.year, mFrom.month) == curKey;
                            final sel = mFrom.year == pFrom.year && mFrom.month == pFrom.month;
                            return Pressable(
                              scale: 0.95,
                              onTap: isCur
                                  ? null
                                  : () {
                                      HapticFeedback.selectionClick();
                                      final prevOf = DateTime(month.year, month.month - 1, 15);
                                      setState(() {
                                        // Chọn đúng tháng liền trước → quay về chế độ tự đi theo.
                                        cmpMonth = (y == prevOf.year && m == prevOf.month) ? null : DateTime(y, m, 15);
                                        cmpAll = false;
                                      });
                                      Navigator.pop(ctx);
                                    },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: sel ? scheme.primary : scheme.surfaceContainerHighest.withValues(alpha: isCur ? 0.4 : 1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Th $m',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: sel
                                        ? scheme.onPrimary
                                        : isCur
                                        ? scheme.onSurfaceVariant.withValues(alpha: 0.4)
                                        : scheme.onSurface,
                                  ),
                                ),
                              ),
                            );
                          },
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

  void _showDay(DateTime d, List<Txn> list) {
    final items = list.where((t) => dateOnly(t.occurredAt) == d).toList();
    showModalBottomSheet(
      sheetAnimationStyle: kSheetAnim,
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        builder: (ctx, s) => ListView(
          controller: s,
          children: [
            ListTile(
              title: Text(Fmt.dayHeader(d), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            ),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('Không có giao dịch')),
              ),
            for (final t in items) TxTile(txn: t),
          ],
        ),
      ),
    );
  }

  void _openGroup(({Category? category, double amount}) g, List<Txn> list) {
    final c = g.category;
    // Danh mục cha có danh mục con → đi sâu vào chi tiết; còn lại → mở danh sách giao dịch.
    final hasChildren = c != null && ref.read(financeProvider).categories.any((x) => x.parentId == c.id);
    if (drillParent == null && hasChildren) {
      setState(() {
        drillParent = c.id;
        touched = -1;
      });
    } else {
      _showTxs(c, list);
    }
  }

  void _showTxs(Category? c, List<Txn> list) {
    final f = ref.read(financeProvider);
    final items = list.where((t) => t.type == type && (c == null ? t.categoryId == null : t.categoryId == c.id)).toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final sum = items.fold(0.0, (s, t) => s + f.toBase(t));
    final color = type == TxType.expense ? AppColors.expense : AppColors.income;
    showModalBottomSheet(
      sheetAnimationStyle: kSheetAnim,
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (ctx, s) => ListView(
          controller: s,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Row(
              children: [
                CircleIcon(icon: c?.icon, color: hexColor(c?.color), size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c?.name ?? 'Không có danh mục', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                      Text(
                        '${items.length} giao dịch · Tháng ${Fmt.month(f.monthRange(month).$1)}',
                        style: TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                CountText(
                  values: [sum],
                  text: (cv) => f.money(cv[0]),
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: color),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('Chưa có giao dịch')),
              ),
            for (final (i, t) in items.indexed) TxTile(txn: t, showDate: true).stagger(i),
          ],
        ),
      ),
    );
  }

  Widget _year() {
    final f = ref.watch(financeProvider);
    final inc = List<double>.filled(12, 0), exp = List<double>.filled(12, 0);
    for (final t in f.inRange(DateTime(year), DateTime(year + 1))) {
      if (t.type == TxType.income) inc[t.occurredAt.month - 1] += f.toBase(t);
      if (t.type == TxType.expense) exp[t.occurredAt.month - 1] += f.toBase(t);
    }
    final ti = inc.fold(0.0, (a, b) => a + b), te = exp.fold(0.0, (a, b) => a + b);
    return _scroll(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        Row(
          children: [
            IconButton(onPressed: () => setState(() => year--), icon: const Icon(Icons.chevron_left_rounded)),
            Expanded(
              child: Center(
                child: Text('Năm $year', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ),
            IconButton(onPressed: () => setState(() => year++), icon: const Icon(Icons.chevron_right_rounded)),
          ],
        ),
        Row(
          children: [
            _StatBox('Tổng thu', ti, AppColors.income, f),
            const SizedBox(width: 8),
            _StatBox('Tổng chi', te, AppColors.expense, f),
            const SizedBox(width: 8),
            _StatBox('Còn lại', ti - te, Theme.of(context).colorScheme.primary, f),
          ],
        ),
        const SizedBox(height: 12),
        _YearCalendar(
          year: year,
          inc: inc,
          exp: exp,
          onTapMonth: (m) {
            setState(() {
              month = DateTime(year, m, f.monthStartDay > 1 ? f.monthStartDay : 15);
              drillParent = null;
            });
            tabs.animateTo(0);
          },
        ),
      ],
    );
  }

  Widget _accounts() {
    final f = ref.watch(financeProvider);
    final (from, to) = f.monthRange(month);
    final list = f.inRange(from, to);
    return _scroll(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        Text('Tháng ${Fmt.month(from)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 12),
        // Tiền mặt vs tài khoản (ngân hàng, ví, thẻ)
        Builder(
          builder: (c) {
            final cash = f.totalsBySource(list, MoneySource.cash);
            final acc = f.totalsBySource(list, MoneySource.account);
            final total = cash.expense + acc.expense;
            return AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Chi theo nguồn tiền', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: total == 0 ? 0.5 : cash.expense / total),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, __) => Row(
                        children: [
                          Expanded(
                            flex: (v * 1000).round().clamp(1, 999),
                            child: Container(height: 14, color: AppColors.income),
                          ),
                          Expanded(
                            flex: ((1 - v) * 1000).round().clamp(1, 999),
                            child: Container(height: 14, color: AppColors.transfer),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final (label, color, t) in [('💵 Tiền mặt', AppColors.income, cash), ('🏦 Tài khoản (NH, ví, thẻ)', AppColors.transfer, acc)])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
                          const SizedBox(width: 8),
                          Flexible(
                            flex: 2,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: CountText(
                                values: [t.expense, t.income],
                                text: (cv) => 'Chi ${f.money(cv[0])} · Thu ${f.money(cv[1])}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        for (final (i, a) in f.accounts.where((a) => !a.isArchived).indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              child: Builder(
                builder: (c) {
                  final mine = list.where((t) => t.accountId == a.id);
                  final t = f.totals(mine.toList());
                  return Row(
                    children: [
                      CircleIcon(icon: a.icon, color: hexColor(a.color)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            CountText(
                              values: [t.income, t.expense],
                              text: (cv) => 'Thu ${f.money(cv[0])} · Chi ${f.money(cv[1])}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      CountText(
                        values: [f.balance(a)],
                        text: (cv) => f.money(cv[0], a.currencyCode),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  );
                },
              ),
            ).stagger(i),
          ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox(this.label, this.value, this.color, this.f, {this.prev, this.upIsGood = true});
  final String label;
  final double value;
  final Color color;
  final Finance f;

  /// Giá trị của tháng so sánh; có thì hiện dòng chênh lệch nhỏ bên dưới.
  final double? prev;
  final bool upIsGood;

  Widget _delta(BuildContext context) {
    final d = value - prev!;
    final scheme = Theme.of(context).colorScheme;
    final dc = d == 0 ? scheme.onSurfaceVariant : ((d > 0) == upIsGood ? AppColors.income : AppColors.expense);
    final pct = prev == 0 ? null : d / prev!.abs() * 100;
    final text = d == 0
        ? '= không đổi'
        : '${d > 0 ? '▲' : '▼'} ${pct == null ? Fmt.compact(d.abs()) : '${pct.abs().toStringAsFixed(pct.abs() >= 10 ? 0 : 1)}%'}';
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Text(
        text,
        key: ValueKey(text),
        maxLines: 1,
        style: TextStyle(color: dc, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: AnimatedAmount(
              value: value,
              format: (v) => f.money(v),
              style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
          if (prev != null) ...[const SizedBox(height: 2), _delta(context)],
        ],
      ),
    ),
  );
}

/// Lưới lịch tháng: hàng tiêu đề T2..CN, mỗi ô là một ngày, tô đậm theo số tiền.
class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({required this.from, required this.daily, required this.color, required this.onTapDay});
  final DateTime from;
  final List<double> daily;
  final Color color;
  final ValueChanged<DateTime> onTapDay;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = dateOnly(DateTime.now());
    final lead = from.weekday - 1;
    final cells = ((lead + daily.length + 6) ~/ 7) * 7;
    final max = daily.fold(0.0, (m, v) => v > m ? v : m);
    return Column(
      children: [
        Row(
          children: [
            for (final (i, w) in Fmt.weekdaysShort.indexed)
              Expanded(
                child: Center(
                  child: Text(
                    w,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: i == 6 ? AppColors.expense.withValues(alpha: 0.8) : scheme.onSurfaceVariant,
                    ),
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
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 4, crossAxisSpacing: 4, childAspectRatio: 0.82),
          itemBuilder: (_, i) {
            final idx = i - lead;
            if (idx < 0 || idx >= daily.length) return const SizedBox.shrink();
            final d = DateTime(from.year, from.month, from.day + idx);
            final v = daily[idx];
            final isToday = d == today;
            final intensity = max == 0 ? 0.0 : v / max;
            return Pressable(
              scale: 0.92,
              onTap: () => onTapDay(d),
              child: Container(
                decoration: BoxDecoration(
                  color: v > 0 ? color.withValues(alpha: 0.10 + 0.40 * intensity) : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                  border: isToday ? Border.all(color: scheme.primary, width: 1.5) : null,
                ),
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${d.day}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                        color: isToday ? scheme.primary : (d.weekday == 7 ? AppColors.expense.withValues(alpha: 0.85) : scheme.onSurface),
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: CountText(
                        values: [v],
                        text: (cv) => v > 0 ? Fmt.compact(cv[0]) : '',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: intensity > 0.6 ? Colors.white : color),
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
  }
}

/// Lịch năm: 12 ô tháng (3 cột), mỗi ô hiện thu / chi / còn lại; bấm để mở tháng.
class _YearCalendar extends StatelessWidget {
  const _YearCalendar({required this.year, required this.inc, required this.exp, required this.onTapMonth});
  final int year;
  final List<double> inc, exp;
  final ValueChanged<int> onTapMonth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final maxExp = exp.fold(0.0, (m, v) => v > m ? v : m);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 12,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 0.95),
      itemBuilder: (_, m) {
        final isCur = now.year == year && now.month == m + 1;
        final net = inc[m] - exp[m];
        final empty = inc[m] == 0 && exp[m] == 0;
        final intensity = maxExp == 0 ? 0.0 : exp[m] / maxExp;
        return Pressable(
          scale: 0.95,
          onTap: () => onTapMonth(m + 1),
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
              border: isCur ? Border.all(color: scheme.primary, width: 1.5) : null,
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // "Tờ lịch": dải đầu tô màu theo mức chi
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  color: isCur ? scheme.primary : AppColors.expense.withValues(alpha: 0.25 + 0.55 * intensity),
                  child: Text(
                    'Tháng ${m + 1}',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isCur ? scheme.onPrimary : Colors.white),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: empty
                        ? Center(
                            child: Text('—', style: TextStyle(color: scheme.onSurfaceVariant)),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _line(inc[m], (v) => '+${Fmt.compact(v)}', AppColors.income),
                              _line(exp[m], (v) => '-${Fmt.compact(v)}', AppColors.expense),
                              _line(net, Fmt.compact, net >= 0 ? scheme.primary : AppColors.expense, big: true),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _line(double value, String Function(double) fmt, Color color, {bool big = false}) => FittedBox(
    fit: BoxFit.scaleDown,
    child: AnimatedAmount(
      value: value,
      format: fmt,
      style: TextStyle(fontSize: big ? 14 : 11, fontWeight: big ? FontWeight.w800 : FontWeight.w600, color: color),
    ),
  );
}
