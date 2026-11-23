import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';

import '../app.dart';
import 'models.dart';

/// Nút trên widget màn hình chính mở app bằng URI `lhtmoney://tx/add?type=1|2`
/// → mở thẳng màn thêm giao dịch (ngày mặc định là hôm nay).
void listenHomeWidgetLaunch() {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  HomeWidget.initiallyLaunchedFromHomeWidget()
      .then((uri) {
        if (uri != null) WidgetsBinding.instance.addPostFrameCallback((_) => _open(uri));
      })
      .catchError((_) {});
  HomeWidget.widgetClicked.listen(_open, onError: (_) {});
}

void _open(Uri? uri) {
  if (uri == null || uri.host != 'tx' || uri.path != '/add') return;
  final type = int.tryParse(uri.queryParameters['type'] ?? '') ?? TxType.expense;
  router.push('/tx/edit', extra: {'type': type == TxType.income ? TxType.income : TxType.expense});
}
