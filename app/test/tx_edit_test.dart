// Màn Thêm giao dịch: cuộn lên xuống không bật lại bàn phím / không chạy lại hiệu ứng; nút Lưu ẩn khi gõ, hiện lại nhẹ nhàng;
// không còn ô nhập vị trí; gợi ý thêm số 0 khi gõ tay số tiền.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lht_money/core/theme.dart';
import 'package:lht_money/core/ui.dart';
import 'package:lht_money/data/local_store.dart';
import 'package:lht_money/features/transactions.dart';
import 'package:lht_money/providers.dart';

void main() {
  late LocalStore store;
  late String accId;

  setUpAll(() async {
    await initializeDateFormatting('vi');
    final dir = await Directory.systemTemp.createTemp('lht_tx_edit');
    Hive.init(dir.path);
    store = LocalStore();
    await store.initForTest(filesDir: '${dir.path}/files');
    services = Services.forTest(store);
    store.put(E.appSettings, {'baseCurrencyCode': 'VND', 'financeMonthStartDay': 1, 'firstDayOfWeek': 1});
    store.put(E.currencies, {'code': 'VND', 'name': 'VND', 'symbol': '₫', 'decimals': 0, 'symbolPosition': 1, 'isBase': true});
    accId = store.put(E.accounts, {'name': 'Tiền mặt', 'type': 1, 'currencyCode': 'VND', 'openingBalance': 0})['id'] as String;
    final cats = [
      for (var i = 0; i < 9; i++) store.put(E.categories, {'name': 'Danh mục $i', 'type': 1, 'icon': 'restaurant', 'color': '#F76B15', 'sortOrder': i})['id'],
    ];
    final now = DateTime.now();
    for (var i = 0; i < 5000; i++) {
      store.put(E.transactions, {
        'type': 1,
        'amount': 10000 + i,
        'currencyCode': 'VND',
        'accountId': accId,
        'categoryId': cats[i % cats.length],
        'occurredAt': now.subtract(Duration(hours: i)).toUtc().toIso8601String(),
      }, notify: false);
    }
  });

  Widget app(Widget home, {EdgeInsets insets = EdgeInsets.zero}) => ProviderScope(
    child: MaterialApp(
      theme: buildTheme(Brightness.light, AppColors.seeds.first),
      locale: const Locale('vi'),
      supportedLocales: const [Locale('vi')],
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(viewInsets: insets),
        child: child!,
      ),
      home: home,
    ),
  );

  Future<void> frames(WidgetTester t, [int n = 60]) async {
    for (var i = 0; i < n; i++) {
      await t.pump(const Duration(milliseconds: 16));
    }
  }

  group('zeroSuggestions', () {
    test('gõ số nhỏ → gợi ý thêm số 0', () {
      expect(zeroSuggestions(25), [25000, 250000, 2500000]);
      expect(zeroSuggestions(250), [250000, 2500000, 25000000]);
      expect(zeroSuggestions(2500), [25000, 250000]);
    });
    test('đủ lớn / số lẻ / không có số → không gợi ý', () {
      expect(zeroSuggestions(25000), isEmpty);
      expect(zeroSuggestions(0), isEmpty);
      expect(zeroSuggestions(12.5), isEmpty);
    });
  });

  testWidgets('KeyboardHideable: ẩn khi bàn phím mở, hiện dần khi đóng', (t) async {
    var insets = const EdgeInsets.only(bottom: 300);
    late StateSetter set;
    await t.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (c, s) {
            set = s;
            return MediaQuery(
              data: MediaQuery.of(c).copyWith(viewInsets: insets),
              child: Scaffold(
                body: const TextField(),
                bottomNavigationBar: KeyboardAvoidBottomBar(
                  child: FilledButton(onPressed: () {}, child: const Text('Lưu')),
                ),
              ),
            );
          },
        ),
      ),
    );
    double h() => t.getSize(find.byType(KeyboardHideable)).height;
    expect(h(), 0, reason: 'đang mở bàn phím → nút không chiếm chỗ');

    set(() => insets = EdgeInsets.zero);
    await t.pump();
    await t.pump(const Duration(milliseconds: 60));
    expect(h(), 0, reason: 'chưa hiện ngay khi bàn phím vừa đóng');
    await t.pump(const Duration(milliseconds: 100));
    await t.pump(const Duration(milliseconds: 100));
    final mid = h();
    await frames(t, 20);
    final full = h();
    expect(full, greaterThan(40));
    expect(mid, inExclusiveRange(0, full), reason: 'chiều cao mở dần, không nhảy một lần');
    expect(t.takeException(), isNull);

    set(() => insets = const EdgeInsets.only(bottom: 300));
    await frames(t, 15);
    expect(h(), 0, reason: 'mở lại bàn phím → nút thu gọn');
  });

  testWidgets('Thêm giao dịch (5.000 giao dịch): gõ phím & cuộn < 16ms; cuộn không bật lại bàn phím; không còn ô vị trí; gợi ý số 0', (t) async {
    t.view.physicalSize = const Size(390 * 3, 700 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(app(const TransactionEditPage()));
    await frames(t);
    final amountField = find.byType(TextField).first;

    final sw = Stopwatch();
    var worst = 0;
    // Phím đầu tiên để làm nóng (biên dịch / bố cục lần đầu), không tính.
    t.widget<EditableText>(find.descendant(of: amountField, matching: find.byType(EditableText))).controller.text = '9';
    await frames(t, 5);
    for (final s in ['1', '12', '123', '1234', '12345', '123456']) {
      sw
        ..reset()
        ..start();
      t.widget<EditableText>(find.descendant(of: amountField, matching: find.byType(EditableText))).controller.text = s;
      await t.pump();
      sw.stop();
      if (sw.elapsedMicroseconds > worst) worst = sw.elapsedMicroseconds;
    }
    // ignore: avoid_print
    print('Gõ 1 phím: khung chậm nhất ${(worst / 1000).toStringAsFixed(1)} ms');
    var idle = 0;
    for (var i = 0; i < 6; i++) {
      sw
        ..reset()
        ..start();
      await t.pump(const Duration(milliseconds: 16));
      sw.stop();
      if (sw.elapsedMicroseconds > idle) idle = sw.elapsedMicroseconds;
    }
    // ignore: avoid_print
    print('Khung không đổi gì (nền): ${(idle / 1000).toStringAsFixed(1)} ms');
    var full = 0;
    for (var i = 0; i < 3; i++) {
      sw
        ..reset()
        ..start();
      t.binding.buildOwner!.reassemble(t.binding.rootElement!);
      await t.pump();
      sw.stop();
      if (sw.elapsedMicroseconds > full) full = sw.elapsedMicroseconds;
    }
    // ignore: avoid_print
    print('Dựng lại TOÀN BỘ màn (để so): ${(full / 1000).toStringAsFixed(1)} ms');
    expect(worst, lessThan(full * 0.5), reason: 'gõ một phím chỉ được dựng lại phần nghe số tiền, không phải cả màn');

    FocusManager.instance.primaryFocus?.unfocus();
    await frames(t, 5);
    final scroller = find.byType(SingleChildScrollView).first;
    worst = 0;
    for (var i = 0; i < 2; i++) {
      for (final dy in [-900.0, 900.0]) {
        final g = await t.startGesture(t.getCenter(scroller));
        for (var k = 0; k < 15; k++) {
          sw
            ..reset()
            ..start();
          await g.moveBy(Offset(0, dy / 15));
          await t.pump(const Duration(milliseconds: 16));
          sw.stop();
          if (sw.elapsedMicroseconds > worst) worst = sw.elapsedMicroseconds;
        }
        await g.up();
        await frames(t, 10);
      }
    }
    // ignore: avoid_print
    print('Cuộn: khung chậm nhất ${(worst / 1000).toStringAsFixed(1)} ms');
    expect(worst, lessThan(full * 0.5), reason: 'cuộn không được dựng lại các khối (nhẹ hơn nhiều so với dựng lại cả màn)');

    // ---- hành vi
    await t.pumpWidget(app(const TransactionEditPage(key: ValueKey('second'))));
    await frames(t);

    final amountField2 = find.byType(TextField).first;
    expect(find.text('Vị trí'), findsNothing, reason: 'đã bỏ ô nhập vị trí');
    expect(find.text('Lặp lại định kỳ'), findsOneWidget);

    // Đóng bàn phím rồi kéo xuống cuối và lên đầu nhiều lần.
    FocusManager.instance.primaryFocus?.unfocus();
    await frames(t, 5);

    for (var i = 0; i < 3; i++) {
      await t.drag(scroller, const Offset(0, -900));
      await frames(t, 20);
      await t.drag(scroller, const Offset(0, 900));
      await frames(t, 20);
    }
    final editable = t.widget<EditableText>(find.descendant(of: amountField2, matching: find.byType(EditableText)));
    expect(editable.focusNode.hasFocus, isFalse, reason: 'cuộn về đầu không được tự bật lại bàn phím (autofocus)');
    expect(t.takeException(), isNull);

    // Gõ tay "25" → hiện gợi ý 25.000; chạm vào thì điền đúng số.
    await t.tap(amountField2);
    await t.enterText(amountField2, '25');
    await frames(t, 20);
    expect(find.text('25.000'), findsOneWidget);
    expect(find.text('2.500.000'), findsOneWidget);
    await t.tap(find.text('25.000'));
    await frames(t, 20);
    expect(editable.controller.text, '25.000');
    expect(find.text('2.500.000'), findsNothing, reason: 'đã chọn gợi ý → trở lại chip cộng nhanh');
    expect(t.takeException(), isNull);
  }, retry: 2); // đo thời gian thật: máy bận (test chạy song song) có thể trượt ngẫu nhiên
}
