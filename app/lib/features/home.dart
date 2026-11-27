import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../data/local_store.dart';
import '../data/logic.dart';
import '../data/models.dart';
import '../data/session.dart';
import '../providers.dart';
import 'budgets.dart';
import 'registry.dart';
import 'schedule.dart';
import 'shell.dart';
import 'transactions.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(financeProvider);
    final store = ref.watchTables(const [...scheduleTables, E.loveCounters, E.savingsJars]);
    final session = ref.watch(sessionProvider);
    final scheme = Theme.of(context).colorScheme;
    final (from, to) = f.monthRange(DateTime.now());
    final month = f.totalsIn(from, to);
    final layout = MenuLayout.of(store);
    final shortcuts = [
      for (final id in layout.shortcuts)
        if (featureById(id) case final ft? when ft.visible(session)) ft,
    ];
    // Mọi chức năng được phép (trừ trang chủ): không chức năng nào bị "ẩn" khỏi trang chủ.
    final allowed = features.where((ft) => ft.id != 'home' && ft.visible(session)).toList();
    // Chưa ghim gì → tự hiện các chức năng không nằm trên thanh điều hướng (tối đa 8 ô), phần còn lại ở ô "Tất cả".
    final pool = shortcuts.isNotEmpty ? shortcuts : allowed.where((ft) => !layout.tabs.contains(ft.id)).toList();
    final grid = shortcuts.isNotEmpty || pool.length <= 8 ? pool : pool.take(7).toList();
    final hasMore = grid.length < allowed.length;
    final quickActions = <_QA>[
      if (session.can(Perm.giaoDich)) ...[
        _QA('Chi tiền', Icons.north_east_rounded, AppColors.expense, () => context.push('/tx/edit', extra: {'type': TxType.expense})),
        _QA('Thu tiền', Icons.south_west_rounded, AppColors.income, () => context.push('/tx/edit', extra: {'type': TxType.income})),
        _QA('Chuyển', Icons.swap_horiz_rounded, AppColors.transfer, () => context.push('/tx/edit', extra: {'type': TxType.transfer})),
      ],
      if (session.can(Perm.lichTrinh))
        _QA('Sự kiện', Icons.event_available_rounded, const Color(0xFF0090FF), () => context.push('/schedule/edit', extra: {'date': DateTime.now()})),
    ];
    final recent = f.transactions.take(6).toList();
    final love = store.all(E.loveCounters).map(LoveCounter.new).firstOrNull;
    final today = dateOnly(DateTime.now());
    // Dùng chỉ mục lịch trình (đã chia sẵn theo ngày) thay vì quét + tính lặp toàn bộ lịch mỗi lần dựng.
    final todayEvents = occurrencesIn(store, today, today.add(const Duration(days: 1)));
    final budgets = f.budgets.take(3).toList();
    final name = session.user?['displayName'] as String?;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.read(syncProvider).sync(),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name == null ? 'Xin chào 👋' : 'Chào $name 👋', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  Text(Fmt.dayHeader(DateTime.now()), style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
                ],
              ),
              actions: [
                if (session.isLoggedIn)
                  IconButton(
                    tooltip: 'Thông báo',
                    onPressed: () => context.push('/notifications'),
                    icon: Badge(
                      isLabelVisible: featureCount(ref, 'notifications') > 0,
                      label: Text(featureCount(ref, 'notifications') > 99 ? '99+' : '${featureCount(ref, 'notifications')}'),
                      child: Icon(featureCount(ref, 'notifications') > 0 ? Icons.notifications_active_rounded : Icons.notifications_none_rounded),
                    ),
                  ),
                IconButton(onPressed: () => context.push('/settings'), icon: const Icon(Icons.settings_outlined)),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
              // Trang chủ ngắn: dựng một lần (không huỷ/dựng lại khi cuộn), mỗi khối có ranh giới vẽ lại riêng.
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Thẻ số dư
                    AppCard(
                      onTap: () => context.push('/accounts'),
                      padding: const EdgeInsets.all(20),
                      gradient: LinearGradient(
                        colors: [heroOf(scheme.primary), accentOf(heroOf(scheme.primary), light: -0.08)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tổng số dư', style: TextStyle(color: Colors.white.withValues(alpha: 0.8))),
                          const SizedBox(height: 4),
                          AnimatedAmount(
                            value: f.totalBalance,
                            format: (v) => f.money(v),
                            style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _MiniStat(label: 'Thu tháng này', value: month.income, format: f.money, icon: Icons.south_west_rounded, color: Colors.white),
                              const SizedBox(width: 12),
                              _MiniStat(label: 'Chi tháng này', value: month.expense, format: f.money, icon: Icons.north_east_rounded, color: Colors.white),
                            ],
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.97, 0.97), curve: Curves.easeOutCubic),
                    const SizedBox(height: 12),
                    const LiveSyncBanner(),

                    // Thao tác nhanh: luôn hiện, không phụ thuộc cấu hình menu
                    if (quickActions.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          for (final (i, a) in quickActions.indexed) ...[
                            if (i > 0) const SizedBox(width: 8),
                            Expanded(child: _QuickAction(action: a).stagger(i)),
                          ],
                        ],
                      ),
                    ],

                    SectionTitle(
                      'Tiện ích',
                      trailing: TextButton.icon(
                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                        onPressed: () => context.push('/settings/menu'),
                        icon: const Icon(Icons.tune_rounded, size: 18),
                        label: const Text('Tuỳ chỉnh'),
                      ),
                    ),
                    GridView.count(
                      crossAxisCount: 4,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 4,
                      childAspectRatio: 1.04,
                      children: [
                        for (final (i, ft) in grid.indexed) FeatureTile(feature: ft, onTap: () => context.push(ft.route)).stagger(i),
                        if (hasMore)
                          FeatureTile(
                            feature: const Feature('all', 'Tất cả', Icons.apps_rounded, '', color: Color(0xFF8D8D86)),
                            badge: allowed.length - grid.length,
                            onTap: () => showAllFeatures(context, allowed),
                          ).stagger(grid.length),
                      ],
                    ),

                    if (love != null) ...[
                      const SizedBox(height: 12),
                      AppCard(
                        onTap: () => context.push('/love'),
                        gradient: LinearGradient(colors: [AppColors.love.withValues(alpha: 0.18), AppColors.love.withValues(alpha: 0.06)]),
                        child: Row(
                          children: [
                            const Icon(Icons.favorite_rounded, color: AppColors.love, size: 32)
                                .animate(onPlay: (c) => c.repeat(reverse: true))
                                .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1), duration: 900.ms)
                                .isolated(),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Bên ${love.partnerName}', style: const TextStyle(fontWeight: FontWeight.w600)),
                                  Text(
                                    '${Love.days(love.startDate)} ngày',
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.love),
                                  ),
                                ],
                              ),
                            ),
                            if (Love.milestones(love.startDate, count: 1).firstOrNull case final m?)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(m.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  Text('còn ${m.daysLeft} ngày', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],

                    if (todayEvents.isNotEmpty) ...[
                      SectionTitle(
                        'Hôm nay',
                        trailing: TextButton(onPressed: () => context.push('/schedule'), child: const Text('Lịch trình')),
                      ),
                      for (final (i, (o, e)) in todayEvents.take(3).indexed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: OpenCard(
                            page: EventDetailPage(id: e.id, occurrence: o),
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 36,
                                  decoration: BoxDecoration(color: hexColor(e.color, scheme.primary), borderRadius: BorderRadius.circular(2)),
                                ),
                                const SizedBox(width: 12),
                                Text(e.isAllDay ? 'Cả ngày' : Fmt.time(o), style: const TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(width: 12),
                                Expanded(child: Text(e.title, overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                          ).stagger(i),
                        ),
                    ],

                    if (budgets.isNotEmpty) ...[
                      SectionTitle(
                        'Định mức',
                        trailing: TextButton(onPressed: () => context.push('/budgets'), child: const Text('Xem tất cả')),
                      ),
                      for (final (i, b) in budgets.indexed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: BudgetCard(budget: b).stagger(i),
                        ),
                    ],

                    SectionTitle(
                      'Gần đây',
                      trailing: TextButton(onPressed: () => context.push('/transactions'), child: const Text('Xem tất cả')),
                    ),
                    if (recent.isEmpty)
                      const EmptyState(icon: Icons.receipt_long_rounded, title: 'Chưa có giao dịch', subtitle: 'Bấm nút + để ghi khoản chi/thu đầu tiên')
                    else
                      AppCard(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(children: [for (final (i, t) in recent.indexed) TxTile(txn: t).stagger(i)]),
                      ),
                  ].map((w) => w is SizedBox || w is SectionTitle ? w : RepaintBoundary(child: w)).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, required this.format, required this.icon, required this.color});
  final String label;
  final double value;
  final String Function(double) format;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 11)),
                SizedBox(
                  height: 20,
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: AnimatedAmount(
                      value: value,
                      format: format,
                      style: TextStyle(color: color, fontWeight: FontWeight.w700),
                    ),
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

class _QA {
  const _QA(this.label, this.icon, this.color, this.onTap);
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.action});
  final _QA action;

  @override
  Widget build(BuildContext context) {
    final c = action.color;
    return Pressable(
      onTap: action.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c.withValues(alpha: 0.20), c.withValues(alpha: 0.07)]),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [c, Color.lerp(c, Colors.black, 0.2)!]),
                boxShadow: [BoxShadow(color: c.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 3))],
              ),
              child: Icon(action.icon, color: Colors.white, size: 19),
            ),
            const SizedBox(height: 6),
            Text(
              action.label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Ô chức năng (icon + tên) dùng ở lưới tiện ích trang chủ và bảng "Tất cả".
/// Ô chức năng. Chức năng cần đăng nhập mà chưa đăng nhập: mờ đi + ổ khoá, bấm vào mở màn đăng nhập.
class FeatureTile extends ConsumerWidget {
  const FeatureTile({super.key, required this.feature, required this.onTap, this.badge});
  final Feature feature;
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final locked = feature.locked(ref.watch(sessionProvider));
    final count = featureCount(ref, feature.id);
    return Pressable(
      onTap: locked
          ? () {
              showToast(context, '"${feature.title}" cần đăng nhập');
              context.push('/login');
            }
          : onTap,
      child: Column(
        children: [
          Badge(
            isLabelVisible: (badge != null && badge! > 0) || (count > 0 && !locked),
            label: Text(count > 0 ? (count > 99 ? '99+' : '$count') : '+${badge ?? 0}'),
            backgroundColor: count > 0 ? AppColors.expense : scheme.primary,
            textColor: count > 0 ? Colors.white : scheme.onPrimary,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: locked ? 0.45 : 1,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(19),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color.lerp(feature.color, Colors.white, 0.12)!, Color.lerp(feature.color, Colors.black, 0.22)!],
                      ),
                      boxShadow: locked ? null : [BoxShadow(color: feature.color.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 5))],
                    ),
                    child: Stack(
                      children: [
                        // Ánh sáng chéo phía trên cho cảm giác "bóng"
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          height: 26,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.white.withValues(alpha: 0.22), Colors.white.withValues(alpha: 0)],
                              ),
                            ),
                          ),
                        ),
                        Center(child: Icon(feature.icon, color: Colors.white, size: 26)),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: AnimatedScale(
                    scale: locked ? 1 : 0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.surface, width: 2),
                      ),
                      child: Icon(Icons.lock_rounded, size: 12, color: scheme.onSurfaceVariant),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            feature.title,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: locked ? scheme.onSurfaceVariant : null),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Bảng tất cả chức năng (có ô tìm kiếm) — mở nhanh mọi chức năng ngay từ trang chủ.
Future<void> showAllFeatures(BuildContext context, List<Feature> all) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (_) => _AllFeaturesSheet(all: all),
);

class _AllFeaturesSheet extends StatefulWidget {
  const _AllFeaturesSheet({required this.all});
  final List<Feature> all;

  @override
  State<_AllFeaturesSheet> createState() => _AllFeaturesSheetState();
}

class _AllFeaturesSheetState extends State<_AllFeaturesSheet> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    final key = Fmt.fold(q);
    final list = widget.all.where((f) => key.isEmpty || Fmt.fold(f.title).contains(key)).toList();
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Tất cả chức năng', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/settings/menu');
                },
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: const Text('Tuỳ chỉnh'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            onChanged: (v) => setState(() => q = v),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Tìm chức năng...', isDense: true),
          ),
          const SizedBox(height: 16),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child: list.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Không tìm thấy chức năng', textAlign: TextAlign.center),
                  )
                : GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 4,
                    childAspectRatio: 1.04,
                    children: [
                      for (final (i, f) in list.indexed)
                        FeatureTile(
                          key: ValueKey(f.id),
                          feature: f,
                          onTap: () {
                            Navigator.pop(context);
                            context.push(f.route);
                          },
                        ).stagger(i),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
