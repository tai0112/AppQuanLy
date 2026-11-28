// Màn Danh mục: thanh chọn loại + thẻ danh mục chính (mở ra thấy mục con dạng thẻ nhỏ, "Thêm mục con"), không tràn trên màn hẹp.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lht_money/core/theme.dart';
import 'package:lht_money/data/local_store.dart';
import 'package:lht_money/features/categories.dart';
import 'package:lht_money/providers.dart';

void main() {
  late LocalStore store;
  setUpAll(() => initializeDateFormatting('vi'));
  setUp(() async {
    final dir = await Directory.systemTemp.createTemp('lht_cat_ui');
    Hive.init(dir.path);
    store = LocalStore();
    await store.initForTest(filesDir: '${dir.path}/f');
    services = Services.forTest(store);
    final food = store.put(E.categories, {'name': 'Ăn uống ngoài hàng rất dài tên', 'type': 1, 'icon': 'restaurant', 'color': '#E5484D'})['id'];
    store.put(E.categories, {'name': 'Cà phê', 'type': 1, 'parentId': food, 'icon': 'local_cafe'});
    store.put(E.categories, {'name': 'Ăn trưa', 'type': 1, 'parentId': food});
    store.put(E.categories, {'name': 'Lương', 'type': 2});
  });

  Future<void> frames(WidgetTester t, [int n = 40]) async {
    for (var i = 0; i < n; i++) {
      await t.pump(const Duration(milliseconds: 16));
    }
  }

  testWidgets('chọn loại, mở thẻ thấy mục con + "Thêm mục con", bấm mục con mở màn sửa', (t) async {
    t.view.physicalSize = const Size(340 * 3, 780 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildTheme(Brightness.light, AppColors.seeds.first),
          locale: const Locale('vi'),
          supportedLocales: const [Locale('vi')],
          localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
          home: const CategoriesPage(),
        ),
      ),
    );
    await frames(t);
    expect(find.text('Khoản chi · 1'), findsOneWidget);
    expect(find.text('2 mục con'), findsOneWidget);
    expect(find.text('Cà phê'), findsNothing, reason: 'thu gọn lúc đầu');

    await t.tap(find.text('2 mục con'));
    await frames(t);
    expect(find.text('Cà phê'), findsOneWidget);
    expect(find.text('Thêm mục con'), findsOneWidget);

    await t.tap(find.text('Cà phê'));
    await frames(t);
    expect(find.text('Sửa danh mục'), findsOneWidget);
    await t.tap(find.byIcon(Icons.close_rounded));
    await frames(t);

    await t.tap(find.text('Khoản thu · 1'));
    await frames(t);
    expect(find.text('Lương'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
