import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../core/config.dart';
import 'local_store.dart';

/// Lỗi API đã dịch sang thông điệp tiếng Việt.
class ApiException implements Exception {
  ApiException(this.message, {this.code, this.status, this.offline = false});
  final String message;
  final String? code;
  final int? status;
  final bool offline;
  @override
  String toString() => message;
}

/// Client REST: tự gắn JWT, tự refresh khi hết hạn, bóc ApiResponse {success,data,error}.
class ApiClient {
  ApiClient(this.store) {
    _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 8), receiveTimeout: const Duration(seconds: 20)));
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          o.baseUrl = baseUrl;
          final t = accessToken;
          if (t != null) o.headers['Authorization'] = 'Bearer $t';
          h.next(o);
        },
        onError: (e, h) async {
          final req = e.requestOptions;
          if (e.response?.statusCode == 401 && refreshToken != null && req.extra['retried'] != true && !req.path.contains('/auth/')) {
            if (await _refresh()) {
              req.extra['retried'] = true;
              req.headers['Authorization'] = 'Bearer $accessToken';
              try {
                return h.resolve(await _dio.fetch(req));
              } on DioException catch (e2) {
                return h.next(e2);
              }
            }
          }
          h.next(e);
        },
      ),
    );
  }

  final LocalStore store;
  late final Dio _dio;
  Completer<bool>? _refreshing;

  /// Gọi khi phiên đăng nhập hết hạn hẳn.
  void Function()? onSessionExpired;

  String get baseUrl => store.meta('apiUrl') ?? AppConfig.defaultApiUrl();
  set baseUrl(String v) => store.setMeta('apiUrl', v.trim().replaceAll(RegExp(r'/+$'), ''));

  String? get accessToken => store.meta('accessToken');
  String? get refreshToken => store.meta('refreshToken');
  bool get isLoggedIn => refreshToken != null;

  String fileUrl(String fileId) => '$baseUrl/files/$fileId';

  void saveTokens(Map<String, dynamic> auth) {
    store.setMeta('accessToken', auth['accessToken'] as String);
    store.setMeta('refreshToken', auth['refreshToken'] as String);
    store.setMeta('user', jsonEncode(auth['user']));
  }

  void clearTokens() {
    store.setMeta('accessToken', null);
    store.setMeta('refreshToken', null);
  }

  Future<bool> _refresh() async {
    if (_refreshing != null) return _refreshing!.future;
    final c = _refreshing = Completer<bool>();
    var ok = false;
    try {
      final r = await Dio(BaseOptions(baseUrl: baseUrl)).post('/api/v1/auth/refresh', data: {'refreshToken': refreshToken});
      saveTokens((r.data as Map)['data'] as Map<String, dynamic>);
      ok = true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        clearTokens();
        onSessionExpired?.call();
      }
    }
    _refreshing = null;
    c.complete(ok);
    return ok;
  }

  Future<T> _call<T>(Future<Response<dynamic>> Function() send) async {
    try {
      final r = await send();
      final body = r.data as Map<String, dynamic>;
      return body['data'] as T;
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['error'] is Map) {
        final err = data['error'] as Map;
        final details = err['details'];
        var msg = err['message'] as String? ?? 'Có lỗi xảy ra';
        if (details is Map && details.isNotEmpty) msg = details.values.first.toString();
        throw ApiException(msg, code: err['code'] as String?, status: e.response?.statusCode);
      }
      if (e.response?.statusCode == 403) throw ApiException('Bạn không có quyền dùng chức năng này', status: 403);
      if (e.response == null) throw ApiException('Không kết nối được máy chủ', offline: true);
      throw ApiException('Lỗi máy chủ (${e.response?.statusCode})', status: e.response?.statusCode);
    }
  }

  Future<T> get<T>(String path, {Map<String, dynamic>? query}) => _call<T>(() => _dio.get('/api/v1$path', queryParameters: query));
  Future<T> post<T>(String path, [Object? body]) => _call<T>(() => _dio.post('/api/v1$path', data: body ?? {}));
  Future<T> put<T>(String path, [Object? body]) => _call<T>(() => _dio.put('/api/v1$path', data: body ?? {}));
  Future<T> delete<T>(String path) => _call<T>(() => _dio.delete('/api/v1$path'));

  Future<Map<String, dynamic>> upload(String id, Uint8List bytes, String mime, String name) {
    final parts = mime.split('/');
    final form = FormData.fromMap({'id': id, 'file': MultipartFile.fromBytes(bytes, filename: name, contentType: DioMediaType(parts.first, parts.last))});
    return _call<Map<String, dynamic>>(() => _dio.post('/api/v1/files', data: form));
  }

  Future<bool> ping() async {
    try {
      final r = await Dio(BaseOptions(connectTimeout: const Duration(seconds: 3))).get('$baseUrl/health');
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
