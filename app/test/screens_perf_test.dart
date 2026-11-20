// Đo hiệu năng HIỂN THỊ của mọi màn hình với dữ liệu lớn (build + layout + paint thật của Flutter):
//  - "Lần đầu": thời gian dựng màn khi mở
//  - "Vẽ lại": thời gian 1 khung hình khi dữ liệu đổi (vd vừa thêm giao dịch, đồng bộ xong)
// Chạy: flutter test test/screens_perf_test.dart
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lht_money/core/format.dart';
import 'package:lht_money/core/theme.dart';
import 'package:lht_money/data/local_store.dart';
import 'package:lht_money/features/accounts.dart';
import 'package:lht_money/features/budgets.dart';
import 'package:lht_money/features/categories.dart';
import 'package:lht_money/features/cycle.dart';
import 'package:lht_money/features/electricity.dart';
import 'package:lht_money/features/home.dart';
import 'package:lht_money/features/jars.dart';
import 'package:lht_money/features/love.dart';
import 'package:lht_money/features/schedule.dart';
import 'package:lht_money/features/settings.dart';
import 'package:lht_money/features/shell.dart';
import 'package:lht_money/features/stats.dart';
import 'package:lht_money/features/transactions.dart';
import 'package:lht_money/providers.dart';

late LocalStore store;
late String jarId, eventId;
final results = <String, (double, double)>{};

Future<void> seed() async {
  final rnd = Random(42);
  String iso(DateTime d) => d.toUtc().toIso8601String();
  store.put(E.appSettings, {'baseCurrencyCode': 'VND', 'financeMonthStartDay': 1, 'firstDayOfWeek': 1}, notify: false);
  store.put(E.currencies, {'code': 'VND', 'name': 'VND', 'symbol': '₫', 'decimals': 0, 'symbolPosition': 1, 'isBase': true}, notify: false);
  final accs = [
    for (var i = 0; i < 4; i++)
      store.put(E.accounts, {
            'name': 'TK $i',
            'type': i + 1,
            'icon': 'payments',
            'color': '#30A46C',
            'currencyCode': 'VND',
            'openingBalance': 5000000,
            'includeInTotal': true,
            'sortOrder': i,
          }, notify: false)['id']
          as String,
  ];
  final roots = <String>[];
  final cats = <String>[];
  for (var i = 0; i < 12; i++) {
    final r =
        store.put(E.categories, {'name': 'Nhóm $i', 'type': i < 9 ? 1 : 2, 'icon': 'restaurant', 'color': '#F76B15', 'sortOrder': i * 100}, notify: false)['id']
            as String;
    roots.add(r);
    cats.add(r);
    for (var k = 0; k < 4; k++) {
      cats.add(
        store.put(E.categories, {
              'name': 'Mục $i.$k',
              'type': i < 9 ? 1 : 2,
              'icon': 'local_cafe',
              'color': '#F76B15',
              'parentId': r,
              'sortOrder': i * 100 + k,
            }, notify: false)['id']
            as String,
      );
    }
  }
  for (var i = 0; i < 8; i++) {
    store.put(E.categories, {'name': 'Lịch $i', 'type': 3, 'icon': 'event', 'color': '#0090FF', 'sortOrder': 1000 + i}, notify: false);
  }
  final now = DateTime(2026, 11, 20, 12);
  for (var i = 0; i < 5000; i++) {
    final t = store.put(E.transactions, {
      'type': i % 9 == 0 ? 2 : (i % 41 == 0 ? 3 : 1),
      'amount': 10000 + rnd.nextInt(500) * 1000,
      'currencyCode': 'VND',
      'accountId': accs[i % 4],
      'toAccountId': i % 41 == 0 ? accs[(i + 1) % 4] : null,
      'categoryId': i % 41 == 0 ? null : cats[i % cats.length],
      'occurredAt': iso(now.subtract(Duration(minutes: i * 105))),
      'note': 'Ghi chú $i',
    }, notify: false);
    if (i % 20 == 0) store.put(E.attachments, {'ownerType': 1, 'ownerId': t['id'], 'fileId': 'f$i', 'sortOrder': 0}, notify: false);
  }
  for (var i = 0; i < 6; i++) {
    store.put(E.budgets, {
      'name': 'ĐM $i',
      'scope': i == 0 ? 1 : 2,
      'refId': i == 0 ? null : roots[i],
      'period': 3,
      'limitAmount': 3000000,
      'currencyCode': 'VND',
      'warnPercent': 80,
      'isActive': true,
    }, notify: false);
  }
  for (var j = 0; j < 4; j++) {
    final id = store.put(E.savingsJars, {'name': 'Hũ $j', 'targetAmount': 20000000, 'currencyCode': 'VND', 'color': '#E5484D'}, notify: false)['id'] as String;
    if (j == 0) jarId = id;
    for (var m = 0; m < 12; m++) {
      store.put(E.jarTransactions, {
        'jarId': id,
        'accountId': accs[1],
        'amount': 1000000,
        'occurredAt': iso(now.subtract(Duration(days: m * 30))),
      }, notify: false);
    }
  }
  for (final r in ['FREQ=WEEKLY;BYDAY=MO,WE,FR', 'FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR', 'FREQ=WEEKLY;BYDAY=SA', 'FREQ=MONTHLY', 'FREQ=YEARLY']) {
    store.put(E.events, {'title': r, 'startAt': iso(DateTime(2025, 12, 1, 8)), 'endAt': iso(DateTime(2025, 12, 1, 9)), 'rRule': r}, notify: false);
  }
  for (var i = 0; i < 400; i++) {
    final day = DateTime(2025, 12, 1).add(Duration(days: (i * 0.9).floor()));
    final e = store.put(E.events, {
      'title': 'Lịch $i',
      'startAt': iso(day.add(const Duration(hours: 9))),
      'endAt': iso(day.add(const Duration(hours: 12))),
      'color': '#0090FF',
    }, notify: false);
    if (i == 397) eventId = e['id'] as String;
    for (var k = 0; k < 2; k++) {
      store.put(E.eventItems, {
        'eventId': e['id'],
        'occurrenceDate': Fmt.isoDate(day),
        'startTime': '${9 + k}:00:00'.padLeft(8, '0'),
        'endTime': '${10 + k}:00:00'.padLeft(8, '0'),
        'title': 'HĐ $k',
      }, notify: false);
    }
  }
  store.put(E.loveCounters, {'startDate': '2024-06-20', 'partnerName': 'Lan', 'milestoneReminderDays': 3}, notify: false);
  for (var c = 0; c < 12; c++) {
    final d = DateTime(2025, 12, 1).add(Duration(days: c * 29));
    store.put(E.cyclePeriods, {'subject': 1, 'startDate': Fmt.isoDate(d), 'endDate': Fmt.isoDate(d.add(const Duration(days: 4))), 'flow': 2}, notify: false);
  }
  // Thực tế: dữ liệu đã đồng bộ lên máy chủ, không còn chờ đẩy
  for (final r in store.dirtyRecords()) {
    store.markSynced(r.entity, r.data['id'] as String);
  }
  store.notifyRemoteApplied();
}

/// Giữ cố định ProviderScope (như app thật) — chỉ đổi màn bên trong.
final page = ValueNotifier<Widget>(const SizedBox());

Widget app() => ProviderScope(
  child: MaterialApp(
    theme: buildTheme(Brightness.dark, AppColors.seeds.first),
    locale: const Locale('vi'),
    supportedLocales: const [Locale('vi')],
    localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
    home: ValueListenableBuilder<Widget>(valueListenable: page, builder: (_, p, __) => p),
  ),
);

var _n = 0;

/// Thay đổi giả lập: "đồng bộ xong" (không đổi bảng nào) hoặc "vừa thêm 1 giao dịch".
bool addTxn = false;
void change() {
  if (addTxn) {
    store.put(E.transactions, {
      'type': 1,
      'amount': 15000,
      'currencyCode': 'VND',
      'accountId': store.all(E.accounts).first['id'],
      'categoryId': store.all(E.categories).first['id'],
      'occurredAt': DateTime(2026, 11, 20, 8).toUtc().toIso8601String(),
      'note': 'Mới ${_n++}',
    });
  } else {
    store.notifyRemoteApplied();
  }
}

/// Chạy ~2,4 giây theo từng khung 16ms để hiệu ứng xuất hiện chạy xong (nhảy 1 khung dài không đủ).
Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 150; i++) {
    await t.pump(const Duration(milliseconds: 16));
  }
}

Future<void> measure(WidgetTester t, String name, Widget screen, {Future<void> Function(WidgetTester)? setup}) async {
  page.value = const SizedBox();
  await t.pump(const Duration(milliseconds: 50));
  final sw = Stopwatch()..start();
  page.value = KeyedSubtree(key: UniqueKey(), child: screen);
  await t.pump();
  if (setup != null) await setup(t);
  final first = sw.elapsedMicroseconds / 1000;
  await settle(t);
  var rebuild = 0.0;
  for (var i = 0; i < 5; i++) {
    change(); // giả lập dữ liệu vừa đổi
    final s = Stopwatch()..start();
    await t.pump(const Duration(milliseconds: 16));
    rebuild += s.elapsedMicroseconds / 1000 / 5;
  }
  results[name] = (first, rebuild);
  page.value = const SizedBox();
  await t.pump(const Duration(seconds: 2));
}

/// Đo thời gian trung bình mỗi khung hình khi cuộn lên xuống liên tục.
Future<void> measureScroll(WidgetTester t, String name, Widget screen, {Future<void> Function(WidgetTester)? setup}) async {
  page.value = KeyedSubtree(key: UniqueKey(), child: screen);
  await t.pump();
  if (setup != null) await setup(t);
  await t.pump(const Duration(seconds: 2));
  // Vùng cuộn chính = Scrollable dọc cao nhất (bỏ qua ô nhập, hàng cuộn ngang)
  final scrollable = find
      .byType(Scrollable)
      .evaluate()
      .where((e) => (e.widget as Scrollable).axisDirection == AxisDirection.down)
      .reduce((a, b) => a.size!.height >= b.size!.height ? a : b);
  var total = 0.0, frames = 0;
  for (var r = 0; r < 6; r++) {
    final g = await t.startGesture((scrollable.renderObject as RenderBox).localToGlobal((scrollable.renderObject as RenderBox).size.center(Offset.zero)));
    for (var i = 0; i < 20; i++) {
      final sw = Stopwatch()..start();
      await g.moveBy(Offset(0, r.isEven ? -40 : 40));
      await t.pump(const Duration(milliseconds: 16));
      total += sw.elapsedMicroseconds / 1000;
      frames++;
    }
    await g.up();
    await t.pump(const Duration(milliseconds: 16));
  }
  results[name] = (0, total / frames);
  page.value = const SizedBox();
  await t.pump(const Duration(seconds: 2));
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('vi');
    final dir = await Directory.systemTemp.createTemp('lht_screens');
    Hive.init(dir.path);
    store = LocalStore();
    await store.initForTest();
    services = Services.forTest(store);
    await seed();
  });

  testWidgets('Hiệu năng hiển thị mọi màn (5.000 giao dịch, 400 lịch trình)', (t) async {
    t.view.physicalSize = const Size(412 * 2.6, 915 * 2.6);
    t.view.devicePixelRatio = 2.6;
    await t.pumpWidget(app());
    // Khởi động: dựng chỉ mục / bộ đệm lần đầu (như khi mở app)
    await measure(t, '— khởi động (lần đầu mở app)', const HomePage());

    await measure(t, 'Trang chủ', const HomePage());
    if (Platform.environment['DEBUG_REBUILD'] == '1') {
      page.value = const HomePage();
      await t.pump();
      await t.pump(const Duration(seconds: 2));
      await t.pump(const Duration(milliseconds: 16));
      debugPrint('=== NOTIFY ===');
      debugPrintRebuildDirtyWidgets = true;
      store.notifyRemoteApplied();
      await t.pump(const Duration(milliseconds: 16));
      debugPrintRebuildDirtyWidgets = false;
    }
    await measure(t, 'Menu', const MenuPage());
    Future<void> listMode(WidgetTester t) async {
      await t.tap(find.byIcon(Icons.view_agenda_rounded).first);
      await t.pump(const Duration(milliseconds: 400));
    }

    await measure(t, 'Giao dịch · danh sách', const TransactionsPage(), setup: listMode);
    await measure(
      t,
      'Giao dịch · lịch',
      const TransactionsPage(),
      setup: (t) async {
        final toggle = find.byIcon(Icons.calendar_month_rounded);
        if (toggle.evaluate().isNotEmpty) {
          await t.tap(toggle.first);
          await t.pump(const Duration(milliseconds: 400));
        }
      },
    );
    await measure(t, 'Thêm giao dịch', const TransactionEditPage(type: 1));
    await measure(t, 'Thống kê · tháng', const StatsPage());
    await measure(
      t,
      'Thống kê · năm',
      const StatsPage(),
      setup: (t) async {
        await t.tap(find.text('Năm').first);
        await t.pump(const Duration(milliseconds: 400));
      },
    );
    await measure(
      t,
      'Thống kê · tài khoản',
      const StatsPage(),
      setup: (t) async {
        await t.tap(find.text('Tài khoản').first);
        await t.pump(const Duration(milliseconds: 400));
      },
    );
    await measure(t, 'Tài khoản', const AccountsPage());
    await measure(t, 'Danh mục', const CategoriesPage());
    await measure(t, 'Định mức', const BudgetsPage());
    await measure(t, 'Hũ tiết kiệm', const JarsPage());
    await measure(t, 'Chi tiết hũ', JarDetailPage(id: jarId));
    await measure(t, 'Tiền điện', const ElectricityPage());
    await measure(t, 'Ngày yêu', const LovePage());
    await measure(t, 'Chu kỳ', const CyclePage());
    await measure(t, 'Lịch trình · tuần', const SchedulePage());
    await measure(
      t,
      'Lịch trình · tháng',
      const SchedulePage(),
      setup: (t) async {
        await t.tap(find.byIcon(Icons.calendar_month_rounded).first);
        await t.pump(const Duration(milliseconds: 400));
      },
    );
    await measure(t, 'Chi tiết lịch trình', EventDetailPage(id: eventId));
    await measure(t, 'Sửa lịch trình', EventEditPage(id: eventId));
    await measure(t, 'Cài đặt', const SettingsPage());
    await measure(t, 'Thời gian & nhắc nhở', const TimeSettingsPage());
    await measure(t, 'Tuỳ chỉnh menu', const MenuConfigPage());
    await measure(t, 'Đồng bộ', const SyncStatusPage());

    // Cuộn lên xuống (cột 2 = ms / khung hình khi cuộn)
    await measureScroll(t, 'Cuộn · Trang chủ', const HomePage());
    await measureScroll(t, 'Cuộn · Giao dịch danh sách', const TransactionsPage(), setup: listMode);
    await measureScroll(t, 'Cuộn · Giao dịch lịch', const TransactionsPage());
    await measureScroll(t, 'Cuộn · Thống kê', const StatsPage());
    await measureScroll(t, 'Cuộn · Lịch trình tuần', const SchedulePage());
    await measureScroll(t, 'Cuộn · Lịch trình tháng', const SchedulePage(), setup: (t) async {
      await t.tap(find.byIcon(Icons.calendar_month_rounded).first);
      await t.pump(const Duration(milliseconds: 400));
    });
    await measureScroll(t, 'Cuộn · Chi tiết lịch trình', EventDetailPage(id: eventId));

    // Kịch bản nặng nhất: vừa thêm 1 giao dịch (bảng giao dịch đổi thật)
    addTxn = true;
    await measure(t, '+1 GD · Trang chủ', const HomePage());
    await measure(t, '+1 GD · Giao dịch danh sách', const TransactionsPage(), setup: listMode);
    await measure(t, '+1 GD · Giao dịch lịch', const TransactionsPage());
    await measure(t, '+1 GD · Thống kê tháng', const StatsPage());
    await measure(t, '+1 GD · Lịch trình tuần', const SchedulePage());

    final buf = StringBuffer('\n${'Màn hình'.padRight(30)} Lần đầu    Vẽ lại\n');
    for (final e in results.entries) {
      final (a, b) = e.value;
      final flag = b > 16 ? '  ⚠️ >16ms' : '';
      buf.writeln('${e.key.padRight(30)} ${a.toStringAsFixed(1).padLeft(7)} ms ${b.toStringAsFixed(1).padLeft(6)} ms$flag');
    }
    // ignore: avoid_print
    print(buf);
  });
}
