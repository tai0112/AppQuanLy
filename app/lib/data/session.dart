import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'api.dart';
import 'local_store.dart';
import 'realtime.dart';
import 'seed.dart';
import 'sync.dart';

/// Mã chức năng (khớp PermissionCatalog phía server).
class Perm {
  static const giaoDich = 'TAI_CHINH.GIAO_DICH';
  static const taiKhoan = 'TAI_CHINH.TAI_KHOAN';
  static const thongKe = 'TAI_CHINH.THONG_KE';
  static const danhMuc = 'TAI_CHINH.DANH_MUC';
  static const dinhMuc = 'TAI_CHINH.DINH_MUC';
  static const huTietKiem = 'TAI_CHINH.HU_TIET_KIEM';
  static const tienDien = 'TIEN_ICH.TIEN_DIEN';
  static const ngayYeu = 'TIEN_ICH.NGAY_YEU';
  static const chuKy = 'TIEN_ICH.CHU_KY';
  static const lichTrinh = 'LICH_TRINH.LICH';
  static const banBe = 'XA_HOI.BAN_BE';
  static const tinNhan = 'XA_HOI.TIN_NHAN';
  static const baiViet = 'XA_HOI.BAI_VIET';
  static const qtVaiTro = 'QUAN_TRI.VAI_TRO';
  static const qtNguoiDung = 'QUAN_TRI.NGUOI_DUNG';
  static const qtChucNang = 'QUAN_TRI.CHUC_NANG';
  static const qtBaoCao = 'QUAN_TRI.BAO_CAO';

  /// Chức năng cá nhân dùng được khi chưa đăng nhập (offline).
  static const offline = {giaoDich, taiKhoan, thongKe, danhMuc, dinhMuc, huTietKiem, tienDien, ngayYeu, chuKy, lichTrinh};
}

/// Phiên đăng nhập + quyền động (menu do server trả về theo vai trò).
class Session extends ChangeNotifier {
  Session(this.store, this.api, this.sync, this.realtime) {
    api.onSessionExpired = () {
      expired = true;
      realtime.disconnect();
      notifyListeners();
    };
    _loadCached();
  }

  final LocalStore store;
  final ApiClient api;
  final SyncEngine sync;
  final Realtime realtime;

  Map<String, dynamic>? user;
  Set<String> codes = {};
  List<String> roles = [];
  List<Map<String, dynamic>> menu = [];
  bool expired = false;

  bool get isLoggedIn => api.isLoggedIn;
  String? get userId => user?['id'] as String?;

  /// Có quyền dùng chức năng? Chưa đăng nhập → chỉ chức năng cá nhân.
  bool can(String code) => isLoggedIn ? codes.contains(code) : Perm.offline.contains(code);
  bool get isAdmin => codes.any((c) => c.startsWith('QUAN_TRI.'));

  void _loadCached() {
    final u = store.meta('user');
    if (u != null) user = jsonDecode(u) as Map<String, dynamic>;
    final p = store.meta('perms');
    if (p != null) _applyPerms(jsonDecode(p) as Map<String, dynamic>);
  }

  void _applyPerms(Map<String, dynamic> p) {
    codes = (p['codes'] as List).cast<String>().toSet();
    roles = (p['roles'] as List).cast<String>();
    menu = (p['menu'] as List).cast<Map<String, dynamic>>();
  }

  /// Khởi động: kết nối realtime + làm mới quyền nếu đã đăng nhập.
  Future<void> boot() async {
    seedDefaults(store);
    if (!isLoggedIn) {
      ensureEventCategories(store);
      ensureActivityTemplates(store);
    }
    if (isLoggedIn) {
      unawaited(_connectRealtime());
      unawaited(refreshPermissions());
    }
  }

  Future<void> refreshPermissions() async {
    try {
      final p = await api.get<Map<String, dynamic>>('/me/permissions');
      store.setMeta('perms', jsonEncode(p));
      _applyPerms(p);
      notifyListeners();
    } on ApiException catch (_) {
      // offline: giữ quyền đã cache
    }
  }

  Future<void> _connectRealtime() => realtime.connect(api.baseUrl, () async => api.accessToken ?? '');

  Future<void> login(String login, String password) async {
    final r = await api.post<Map<String, dynamic>>('/auth/login', {'login': login, 'password': password});
    await _afterAuth(r);
  }

  Future<void> register(String email, String username, String password, String displayName, {required bool acceptTerms}) async {
    final r = await api.post<Map<String, dynamic>>('/auth/register', {
      'email': email,
      'username': username,
      'password': password,
      'displayName': displayName,
      'acceptTerms': acceptTerms,
    });
    await _afterAuth(r);
  }

  Future<void> _afterAuth(Map<String, dynamic> r) async {
    final previousUser = store.meta('lastUserId');
    final newUser = (r['user'] as Map)['id'] as String;
    // Đăng nhập tài khoản khác với dữ liệu đang có trên máy → xoá dữ liệu cũ.
    if (previousUser != null && previousUser != newUser) {
      await store.wipe();
      seedDefaults(store);
    }
    api.saveTokens(r);
    store.setMeta('lastUserId', newUser);
    user = Map<String, dynamic>.from(r['user'] as Map);
    expired = false;
    await refreshPermissions();
    notifyListeners();
    unawaited(_connectRealtime());
    await sync.firstSyncAfterLogin();
  }

  void updateUser(Map<String, dynamic> u) {
    user = u;
    store.setMeta('user', jsonEncode(u));
    notifyListeners();
  }

  /// Xoá tài khoản vĩnh viễn trên máy chủ (cần mật khẩu), rồi xoá sạch dữ liệu trên máy. Không đẩy dữ liệu chờ lên nữa.
  Future<void> deleteAccount(String password) async {
    await api.post('/me/delete', {'password': password});
    await realtime.disconnect();
    api.clearTokens();
    await store.wipe();
    store.setMeta('lastUserId', null);
    user = null;
    codes = {};
    roles = [];
    menu = [];
    seedDefaults(store);
    notifyListeners();
  }

  /// Đăng xuất: đẩy nốt dữ liệu rồi xoá dữ liệu trên máy.
  Future<void> logout() async {
    try {
      await sync.sync();
      final rt = api.refreshToken;
      if (rt != null) await api.post('/auth/logout', {'refreshToken': rt});
    } catch (_) {}
    await realtime.disconnect();
    api.clearTokens();
    await store.wipe();
    user = null;
    codes = {};
    roles = [];
    menu = [];
    seedDefaults(store);
    notifyListeners();
  }
}
