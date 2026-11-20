import 'package:flutter/foundation.dart';

/// Cấu hình chung. Địa chỉ server có thể đổi trong Cài đặt (lưu ở máy).
class AppConfig {
  /// Truyền khi build: --dart-define=API_URL=http://192.168.1.10:5000
  static const _envUrl = String.fromEnvironment('API_URL');

  static String defaultApiUrl() {
    if (_envUrl.isNotEmpty) return _envUrl;
    // Bản web được phục vụ chung cổng với API → dùng luôn origin hiện tại.
    if (kIsWeb) {
      final origin = Uri.base.origin;
      return origin.contains(':5000') || !origin.contains('localhost') ? origin : 'http://localhost:5000';
    }
    // Android emulator truy cập máy host qua 10.0.2.2; iOS simulator dùng localhost.
    if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:5000';
    return 'http://localhost:5000';
  }

  static const syncInterval = Duration(seconds: 60);
  static const appName = 'LHT Money';
}
