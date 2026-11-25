import 'dart:ui' show ImageFilter;

import 'package:animations/animations.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/ui.dart';
import '../data/session.dart';
import '../data/sync.dart';
import '../data/local_store.dart';
import '../providers.dart';
import 'accounts.dart';
import 'admin.dart';
import 'budgets.dart';
import 'categories.dart';
import 'chat.dart';
import 'cycle.dart';
import 'electricity.dart';
import 'home.dart';
import 'jars.dart';
import 'love.dart';
import 'recurring.dart';
import 'registry.dart';
import 'schedule.dart';
import 'settings.dart';
import 'social.dart';
import 'stats.dart';
import 'transactions.dart';

Widget pageFor(String id) => switch (id) {
  'home' => const HomePage(),
  'transactions' => const TransactionsPage(),
  'stats' => const StatsPage(),
  'accounts' => const AccountsPage(),
  'categories' => const CategoriesPage(),
  'budgets' => const BudgetsPage(),
  'jars' => const JarsPage(),
  'recurring' => const RecurringPage(),
  'electricity' => const ElectricityPage(),
  'love' => const LovePage(),
  'cycle' => const CyclePage(),
  'schedule' => const SchedulePage(),
  'feed' => const FeedPage(),
  'chat' => const ChatListPage(),
  'friends' => const FriendsPage(),
  'notifications' => const NotificationsPage(),
  'admin' => const AdminPage(),
  'settings' => const SettingsPage(),
  _ => const MenuPage(),
};

/// Khung chính: thanh điều hướng dưới (tab do người dùng cấu hình + lọc theo quyền) + nút thêm giao dịch.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int index = 0;
  final _pages = <String, Widget>{};

  /// Huy hiệu trên thanh điều hướng: tab của chính chức năng, hoặc tab "Menu" gom số của các chức năng không nằm trên thanh.
  int _navCount(WidgetRef ref, Feature f, List<Feature> all) {
    if (f.id != 'menu') return featureCount(ref, f.id);
    final onBar = all.map((x) => x.id).toSet();
    return features.where((x) => !onBar.contains(x.id)).fold(0, (s, x) => s + featureCount(ref, x.id));
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final store = ref.watchTables(const [E.appSettings]);
    final layout = MenuLayout.of(store);
    final tabs = [
      for (final id in layout.tabs)
        if (featureById(id) case final f? when f.allowed(session)) f,
    ].take(4).toList();
    final all = [...tabs, const Feature('menu', 'Menu', Icons.apps_rounded, '/menu')];
    if (index >= all.length) index = 0;
    final current = all[index];
    _pages.putIfAbsent(current.id, () => pageFor(current.id));
    final canAdd = session.can(Perm.giaoDich);

    return Scaffold(
      // Chỉ giữ tab đang xem (không tốn thêm bộ nhớ). Hiệu ứng mờ chuyển ngắn, nhẹ hơn trượt ngang.
      body: PageTransitionSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, a, b) =>
            FadeThroughTransition(animation: a, secondaryAnimation: b, fillColor: Theme.of(context).scaffoldBackgroundColor, child: child),
        child: KeyedSubtree(key: ValueKey(current.id), child: _pages[current.id]!),
      ),
      floatingActionButton: canAdd && (current.id == 'home' || current.id == 'transactions')
          ? OpenContainer(
              transitionDuration: const Duration(milliseconds: 450),
              closedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              closedColor: Theme.of(context).colorScheme.primary,
              closedElevation: 4,
              openBuilder: (c, _) =>
                  TransactionEditPage(type: 1, preset: {if (current.id == 'transactions' && txAddDate.value != null) 'date': txAddDate.value!}),
              closedBuilder: (c, open) => InkWell(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  open();
                },
                child: SizedBox(width: 60, height: 60, child: Icon(Icons.add_rounded, size: 30, color: Theme.of(context).colorScheme.onPrimary)),
              ),
            )
          : null,
      extendBody: false, // không cho nội dung tràn dưới thanh điều hướng → nút + của các trang không bị che
      // Thanh điều hướng nổi, bo tròn, nền mờ kính
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: _Glass(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  // Web không làm mờ nền (rất tốn khung hình trên trình duyệt) → nền đặc hơn bù lại.
                  color: Theme.of(context).colorScheme.surfaceContainer.withValues(alpha: kIsWeb ? 0.97 : 0.82),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: _NavBar(
                  items: [for (final f in all) (f.icon, f.title, _navCount(ref, f, all))],
                  selected: index,
                  onSelect: (i) {
                    if (i == index) return;
                    HapticFeedback.selectionClick();
                    setState(() => index = i);
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Nền kính mờ cho thanh điều hướng — chỉ trên app gốc (iOS/Android); web bỏ qua vì làm mờ nền rất nặng.
class _Glass extends StatelessWidget {
  const _Glass({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => kIsWeb ? child : BackdropFilter(filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18), child: child);
}

/// Trang "Menu": toàn bộ chức năng được phép (theo quyền động), tài khoản, đồng bộ.
class MenuPage extends ConsumerWidget {
  const MenuPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final sync = ref.watch(syncProvider);
    final scheme = Theme.of(context).colorScheme;
    final allowed = features.where((f) => f.id != 'home' && f.visible(session)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Menu')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            onTap: () => context.push(session.isLoggedIn ? '/settings' : '/login'),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: scheme.primaryContainer,
                  child: Text(
                    (session.user?['displayName'] as String? ?? '?').characters.first.toUpperCase(),
                    style: TextStyle(fontSize: 22, color: scheme.onPrimaryContainer, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.isLoggedIn ? (session.user?['displayName'] as String? ?? '') : 'Chưa đăng nhập',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        session.isLoggedIn ? '@${session.user?['username']} · ${session.roles.join(', ')}' : 'Đăng nhập để đồng bộ, kết bạn, nhắn tin',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SyncBanner(sync: sync),
          const SectionTitle('Chức năng'),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            childAspectRatio: 0.95,
            children: [for (final (i, f) in allowed.indexed) FeatureTile(feature: f, onTap: () => context.push(f.route)).stagger(i)],
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.dashboard_customize_rounded),
            title: const Text('Tuỳ chỉnh menu'),
            subtitle: const Text('Chọn tab dưới cùng và tiện ích trang chủ'),
            onTap: () => context.push('/settings/menu'),
          ),
        ],
      ),
    );
  }
}

/// Trạng thái đồng bộ (dùng ở trang chủ & menu).
/// Thanh trạng thái đồng bộ tự theo dõi bộ đồng bộ — màn chứa nó không phải dựng lại mỗi khi trạng thái đồng bộ đổi.
class LiveSyncBanner extends ConsumerWidget {
  const LiveSyncBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => SyncBanner(sync: ref.watch(syncProvider));
}

class SyncBanner extends StatelessWidget {
  const SyncBanner({super.key, required this.sync});
  final SyncEngine sync;

  @override
  Widget build(BuildContext context) {
    final (icon, text, color) = switch (sync.state) {
      SyncState.localOnly => (Icons.phone_iphone_rounded, 'Dữ liệu đang lưu trên máy (chưa đăng nhập)', Colors.blueGrey),
      SyncState.syncing => (
        Icons.sync_rounded,
        sync.fileProgress == null ? 'Đang đồng bộ...' : 'Đang tải ảnh về máy ${sync.fileProgress!.$1 + 1}/${sync.fileProgress!.$2}...',
        Colors.blue,
      ),
      SyncState.idle when !sync.autoSync => (
        Icons.pause_circle_outline_rounded,
        sync.pending > 0 ? 'Đồng bộ tự động đang tắt · ${sync.pending} thay đổi lưu trên máy' : 'Đồng bộ tự động đang tắt · bấm để đồng bộ',
        Colors.blueGrey,
      ),
      SyncState.offline => (Icons.cloud_off_rounded, 'Mất kết nối · ${sync.pending} thay đổi chờ đẩy lên', Colors.orange),
      SyncState.error => (Icons.error_outline_rounded, 'Lỗi đồng bộ: ${sync.lastError ?? ''}', Colors.red),
      SyncState.idle =>
        sync.pending > 0
            ? (Icons.cloud_upload_rounded, '${sync.pending} thay đổi chờ đồng bộ', Colors.orange)
            : (Icons.cloud_done_rounded, 'Đã đồng bộ', Colors.green),
    };
    return Pressable(
      onTap: () => GoRouter.of(context).push('/settings/sync'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            sync.state == SyncState.syncing
                ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: color))
                : Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thanh điều hướng: ô được chọn là một khối bo tròn phủ trọn cả icon lẫn chữ, trượt mượt giữa các tab.
class _NavBar extends StatelessWidget {
  const _NavBar({required this.items, required this.selected, required this.onSelect});
  final List<(IconData, String, int)> items;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 68,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth / items.length;
            return Stack(
              children: [
                // Khối nền của tab đang chọn (trượt theo tab)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 380),
                  curve: Curves.easeOutBack,
                  left: selected * w,
                  top: 0,
                  bottom: 0,
                  width: w,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [scheme.primary.withValues(alpha: 0.30), scheme.primary.withValues(alpha: 0.16)],
                        ),
                        border: Border.all(color: scheme.primary.withValues(alpha: 0.35)),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (final (i, (icon, label, count)) in items.indexed)
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onSelect(i),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedScale(
                                scale: i == selected ? 1.12 : 1,
                                duration: const Duration(milliseconds: 260),
                                curve: Curves.easeOutBack,
                                child: Badge(
                                  isLabelVisible: count > 0,
                                  label: Text(count > 99 ? '99+' : '$count'),
                                  child: Icon(icon, size: 24, color: i == selected ? scheme.primary : scheme.onSurfaceVariant),
                                ),
                              ),
                              const SizedBox(height: 3),
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: i == selected ? FontWeight.w800 : FontWeight.w500,
                                  color: i == selected ? scheme.primary : scheme.onSurfaceVariant,
                                ),
                                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
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
    );
  }
}
