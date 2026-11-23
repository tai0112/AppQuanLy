import 'package:flutter/cupertino.dart' show CupertinoPage;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/config.dart';
import 'core/theme.dart';
import 'core/ui.dart';
import 'data/local_store.dart';
import 'features/accounts.dart';
import 'features/admin.dart';
import 'features/api_logs.dart';
import 'features/moderation.dart';
import 'features/budgets.dart';
import 'features/categories.dart';
import 'features/chat.dart';
import 'features/cycle.dart';
import 'features/electricity.dart';
import 'features/import_mm.dart';
import 'features/notify_settings.dart';
import 'features/jars.dart';
import 'features/love.dart';
import 'features/reminders.dart';
import 'features/schedule.dart';
import 'features/settings.dart';
import 'features/shell.dart';
import 'features/social.dart';
import 'features/stats.dart';
import 'features/transactions.dart';
import 'providers.dart';

Map<String, dynamic> _extra(GoRouterState s) => (s.extra as Map<String, dynamic>?) ?? const {};

/// Chuyển trang mượt: trượt nhẹ + mờ dần + phóng nhẹ; trang cũ lùi và mờ. Trên iOS giữ kiểu vuốt-để-quay-lại.
Page<void> _page(GoRouterState s, Widget child) {
  if (defaultTargetPlatform == TargetPlatform.iOS) return CupertinoPage(key: s.pageKey, child: child);
  return CustomTransitionPage(
    key: s.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 460),
    reverseTransitionDuration: const Duration(milliseconds: 340),
    transitionsBuilder: (context, a, sa, child) {
      final inC = CurvedAnimation(parent: a, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      final outC = CurvedAnimation(parent: sa, curve: Curves.easeOutCubic);
      return SlideTransition(
        position: Tween(begin: Offset.zero, end: const Offset(-0.06, 0)).animate(outC),
        child: FadeTransition(
          opacity: Tween(begin: 1.0, end: 0.6).animate(outC),
          child: SlideTransition(
            position: Tween(begin: const Offset(0.14, 0), end: Offset.zero).animate(inC),
            child: FadeTransition(
              opacity: inC,
              child: ScaleTransition(scale: Tween(begin: 0.97, end: 1.0).animate(inC), child: child),
            ),
          ),
        ),
      );
    },
  );
}

/// Bỏ chọn ô nhập mỗi khi chuyển / đóng màn.
/// Lý do: trên web, ô nhập còn đang được chọn khi màn bị đóng sẽ để lại <form>/<input> ẩn trong trang
/// → mở/đóng form nhiều lần làm trang phình dần. Bỏ chọn trước khi đóng giúp Flutter dọn sạch.
class UnfocusOnNavigate extends NavigatorObserver {
  void _unfocus() => FocusManager.instance.primaryFocus?.unfocus();

  /// Kết thúc phiên tự điền: Flutter web giữ <form> autofill trong trang tới khi gọi hàm này.
  void _finishAutofill() => Future.delayed(const Duration(milliseconds: 400), () => TextInput.finishAutofillContext(shouldSave: false));

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _unfocus();
    _finishAutofill();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _unfocus();
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => _unfocus();
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _unfocus();
    _finishAutofill();
  }
}

final router = GoRouter(
  observers: [UnfocusOnNavigate()],
  routes: [
    GoRoute(path: '/', pageBuilder: (c, s) => _page(s, const AppShell())),
    GoRoute(path: '/login', pageBuilder: (c, s) => _page(s, const AuthPage())),
    GoRoute(path: '/register', pageBuilder: (c, s) => _page(s, const AuthPage(startWithRegister: true))),
    GoRoute(path: '/transactions', pageBuilder: (c, s) => _page(s, const TransactionsPage())),
    GoRoute(
      path: '/tx/edit',
      pageBuilder: (c, s) => _page(s, TransactionEditPage(id: _extra(s)['id'] as String?, type: _extra(s)['type'] as int? ?? 1, preset: _extra(s))),
    ),
    GoRoute(path: '/stats', pageBuilder: (c, s) => _page(s, const StatsPage())),
    GoRoute(path: '/accounts', pageBuilder: (c, s) => _page(s, const AccountsPage())),
    GoRoute(
      path: '/accounts/edit',
      pageBuilder: (c, s) => _page(s, AccountEditPage(id: _extra(s)['id'] as String?)),
    ),
    GoRoute(path: '/currencies', pageBuilder: (c, s) => _page(s, const CurrenciesPage())),
    GoRoute(
      path: '/categories',
      pageBuilder: (c, s) => _page(s, CategoriesPage(initialType: _extra(s)['type'] as int? ?? 1)),
    ),
    GoRoute(path: '/budgets', pageBuilder: (c, s) => _page(s, const BudgetsPage())),
    GoRoute(path: '/jars', pageBuilder: (c, s) => _page(s, const JarsPage())),
    GoRoute(
      path: '/jars/detail',
      pageBuilder: (c, s) => _page(s, JarDetailPage(id: _extra(s)['id'] as String)),
    ),
    GoRoute(path: '/electricity', pageBuilder: (c, s) => _page(s, const ElectricityPage())),
    GoRoute(path: '/love', pageBuilder: (c, s) => _page(s, const LovePage())),
    GoRoute(path: '/cycle', pageBuilder: (c, s) => _page(s, const CyclePage())),
    GoRoute(path: '/reminders', pageBuilder: (c, s) => _page(s, const RemindersPage())),
    GoRoute(
      path: '/reminders/edit',
      pageBuilder: (c, s) => _page(s, ReminderEditPage(id: _extra(s)['id'] as String?)),
    ),
    GoRoute(path: '/schedule', pageBuilder: (c, s) => _page(s, const SchedulePage())),
    GoRoute(
      path: '/schedule/edit',
      pageBuilder: (c, s) => _page(
        s,
        EventEditPage(
          id: _extra(s)['id'] as String?,
          date: _extra(s)['date'] as DateTime?,
          endDate: _extra(s)['end'] as DateTime?,
          timed: _extra(s)['timed'] == true,
        ),
      ),
    ),
    GoRoute(
      path: '/schedule/detail',
      pageBuilder: (c, s) => _page(s, EventDetailPage(id: _extra(s)['id'] as String, occurrence: _extra(s)['occurrence'] as DateTime?)),
    ),
    GoRoute(path: '/feed', pageBuilder: (c, s) => _page(s, const FeedPage())),
    GoRoute(
      path: '/profile',
      pageBuilder: (c, s) => _page(s, ProfilePage(user: (_extra(s)['user'] as Map).cast<String, dynamic>())),
    ),
    GoRoute(
      path: '/feed/compose',
      pageBuilder: (c, s) => _page(s, ComposePostPage(eventId: _extra(s)['eventId'] as String?, jarId: _extra(s)['jarId'] as String?)),
    ),
    GoRoute(
      path: '/friends',
      pageBuilder: (c, s) => _page(s, FriendsPage(tab: _extra(s)['tab'] as int? ?? 0)),
    ),
    GoRoute(
      path: '/post',
      pageBuilder: (c, s) => _page(s, PostDetailPage(id: _extra(s)['id'] as String, comments: _extra(s)['comments'] == true)),
    ),
    GoRoute(path: '/notifications', pageBuilder: (c, s) => _page(s, const NotificationsPage())),
    GoRoute(path: '/chat', pageBuilder: (c, s) => _page(s, const ChatListPage())),
    GoRoute(
      path: '/chat/room',
      pageBuilder: (c, s) => _page(s, ChatRoomPage(conversation: _extra(s))),
    ),
    GoRoute(path: '/settings', pageBuilder: (c, s) => _page(s, const SettingsPage())),
    GoRoute(path: '/settings/menu', pageBuilder: (c, s) => _page(s, const MenuConfigPage())),
    GoRoute(path: '/settings/sync', pageBuilder: (c, s) => _page(s, const SyncStatusPage())),
    GoRoute(path: '/settings/import-mm', pageBuilder: (c, s) => _page(s, const MoneyManagerImportPage())),
    GoRoute(path: '/settings/notifications', pageBuilder: (c, s) => _page(s, const NotifySettingsPage())),
    GoRoute(path: '/settings/time', pageBuilder: (c, s) => _page(s, const TimeSettingsPage())),
    GoRoute(path: '/admin', pageBuilder: (c, s) => _page(s, const AdminPage())),
    GoRoute(path: '/admin/reports', pageBuilder: (c, s) => _page(s, const AdminReportsPage())),
    GoRoute(path: '/admin/logs', pageBuilder: (c, s) => _page(s, const ApiLogsPage())),
    GoRoute(
      path: '/legal/:doc',
      pageBuilder: (c, s) => _page(s, LegalPage(doc: s.pathParameters['doc'] ?? 'privacy')),
    ),
    GoRoute(path: '/settings/blocked', pageBuilder: (c, s) => _page(s, const BlockedUsersPage())),
    GoRoute(path: '/settings/delete-account', pageBuilder: (c, s) => _page(s, const DeleteAccountPage())),
  ],
);

class LhtApp extends ConsumerWidget {
  const LhtApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watchTables(const [E.appSettings]);
    final settings = store.all(E.appSettings).firstOrNull ?? const {};
    final seed = hexColor(settings['primaryColor'] as String?, AppColors.seeds.first);
    final mode = switch (settings['theme']) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: ref.read(notifierProvider).messengerKey,
      theme: buildTheme(Brightness.light, seed),
      darkTheme: buildTheme(Brightness.dark, seed),
      themeMode: mode,
      themeAnimationDuration: const Duration(milliseconds: 400),
      locale: const Locale('vi'),
      supportedLocales: const [Locale('vi'), Locale('en')],
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      scrollBehavior: const SmoothScrollBehavior(),
      routerConfig: router,
    );
  }
}
