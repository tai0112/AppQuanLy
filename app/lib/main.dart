import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'data/background.dart';
import 'providers.dart';

Future<void> main() async {
  // Bắt mọi lỗi bất đồng bộ (vd SignalR rớt kết nối khi mất mạng) để app không bị crash.
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('vi');
    services = await Services.create();
    await services.session.boot();
    services.sync.start();
    startBackgroundTasks(services);
    runApp(const ProviderScope(child: LhtApp()));
  }, (error, stack) => debugPrint('Lỗi không xử lý: $error'));
}
