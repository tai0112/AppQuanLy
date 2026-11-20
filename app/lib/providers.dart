import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'data/api.dart';
import 'data/couple.dart';
import 'data/local_store.dart';
import 'data/logic.dart';
import 'data/notifications.dart';
import 'data/notify_prefs.dart';
import 'data/realtime.dart';
import 'data/session.dart';
import 'data/sync.dart';
import 'data/unread.dart';

/// Các service dùng chung, khởi tạo một lần trong main().
class Services {
  Services._(this.store, this.api, this.sync, this.realtime, this.session, this.notifier);

  final LocalStore store;
  final ApiClient api;
  final SyncEngine sync;
  final Realtime realtime;
  final Session session;
  final LocalNotifier notifier;

  static Future<Services> create() async {
    final store = LocalStore();
    await store.init();
    final api = ApiClient(store);
    final sync = SyncEngine(store, api);
    final realtime = Realtime();
    final session = Session(store, api, sync, realtime);
    final notifier = LocalNotifier()..prefs = () => NotifyPrefs.of(store);
    await notifier.init();
    return Services._(store, api, sync, realtime, session, notifier);
  }

  /// Dùng trong test: không gọi plugin (thông báo, đường dẫn máy), không mạng.
  static Services forTest(LocalStore store) {
    final api = ApiClient(store);
    final sync = SyncEngine(store, api);
    final realtime = Realtime();
    final session = Session(store, api, sync, realtime);
    final notifier = LocalNotifier()..prefs = () => NotifyPrefs.of(store);
    return Services._(store, api, sync, realtime, session, notifier);
  }
}

late Services services;

final storeProvider = ChangeNotifierProvider<LocalStore>((ref) => services.store);
final syncProvider = ChangeNotifierProvider<SyncEngine>((ref) => services.sync);
final realtimeProvider = ChangeNotifierProvider<Realtime>((ref) => services.realtime);
final sessionProvider = ChangeNotifierProvider<Session>((ref) => services.session);
final apiProvider = Provider<ApiClient>((ref) => services.api);
final notifierProvider = Provider<LocalNotifier>((ref) => services.notifier);

/// Truy vấn tài chính, tự tính lại khi dữ liệu local thay đổi.
/// Nhóm bảng của màn Lịch trình.
const scheduleTables = [E.appSettings, E.events, E.eventItems, E.eventPhotos, E.eventParticipants, E.categories, E.plans];

extension WatchTables on WidgetRef {
  /// Chỉ dựng lại khi các bảng [tables] thực sự đổi (thay cho ref.watch(storeProvider) — vốn dựng lại với MỌI thay đổi).
  LocalStore watchTables(List<String> tables) {
    watch(storeProvider.select((s) => s.versionKey(tables)));
    return read(storeProvider);
  }
}

/// Bảng mà Finance đọc — chỉ khi một trong các bảng này đổi thì màn tài chính mới dựng lại
/// (đồng bộ xong, sửa lịch trình, chat... không làm màn Giao dịch / Thống kê vẽ lại).
const financeTables = [E.appSettings, E.currencies, E.exchangeRates, E.accounts, E.categories, E.transactions, E.attachments, E.jarTransactions, E.budgets];

final financeProvider = Provider<Finance>((ref) {
  ref.watch(storeProvider.select((s) => s.versionKey(financeTables)));
  return Finance(ref.read(storeProvider));
});

/// Số tin nhắn chưa đọc (huy hiệu trên menu "Tin nhắn").
final unreadChatProvider = ChangeNotifierProvider<UnreadCounter>(
  (ref) => UnreadCounter(
    services.api,
    services.session,
    services.realtime,
    events: const {'MessageReceived', 'ConversationCreated'},
    load: (api) async {
      final list = await api.get<List<dynamic>>('/conversations');
      return list.fold<int>(0, (s, c) => s + (((c as Map)['unreadCount'] as num?)?.toInt() ?? 0));
    },
  ),
);

/// Số thông báo chưa đọc (huy hiệu trên menu "Thông báo").
final unreadNotificationsProvider = ChangeNotifierProvider<UnreadCounter>(
  (ref) => UnreadCounter(
    services.api,
    services.session,
    services.realtime,
    events: const {'Notification'},
    load: (api) async => ((await api.get<num>('/notifications/unread-count'))).toInt(),
  ),
);

/// Người yêu xác nhận hai chiều + lời mời.
final coupleProvider = ChangeNotifierProvider<CoupleStore>((ref) => CoupleStore(services.api, services.session, services.realtime, services.store));

/// Số đếm hiện trên ô chức năng (0 = không hiện).
int featureCount(WidgetRef ref, String featureId) => switch (featureId) {
  'chat' => ref.watch(unreadChatProvider).count,
  'notifications' => ref.watch(unreadNotificationsProvider).count,
  'friends' || 'love' => ref.watch(coupleProvider).incoming.length,
  _ => 0,
};
