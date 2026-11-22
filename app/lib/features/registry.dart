import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/local_store.dart';
import '../data/session.dart';

/// Một chức năng của app (mục menu). Hiện/ẩn theo quyền động từ server.
class Feature {
  const Feature(this.id, this.title, this.icon, this.route, {this.perm, this.color = const Color(0xFF3E63DD), this.loginOnly = false, this.adminOnly = false});
  final String id;
  final String title;
  final IconData icon;
  final String route;
  final String? perm;
  final Color color;
  final bool loginOnly;
  final bool adminOnly;

  /// Cần đăng nhập mà chưa đăng nhập → vẫn hiện (kèm ổ khoá), bấm vào thì mở màn đăng nhập.
  bool locked(Session s) => loginOnly && !adminOnly && !s.isLoggedIn;

  /// Hiện trên menu/lưới tiện ích: được phép dùng, hoặc chỉ đang bị khoá vì chưa đăng nhập.
  bool visible(Session s) => allowed(s) || locked(s);

  bool allowed(Session s) {
    if (adminOnly) return s.isLoggedIn && s.isAdmin;
    if (loginOnly && !s.isLoggedIn) return false;
    return perm == null || s.can(perm!);
  }
}

const features = <Feature>[
  Feature('home', 'Tổng quan', Icons.space_dashboard_rounded, '/', color: Color(0xFF12A594)),
  Feature('transactions', 'Giao dịch', Icons.receipt_long_rounded, '/transactions', perm: Perm.giaoDich, color: Color(0xFF3E63DD)),
  Feature('stats', 'Thống kê', Icons.pie_chart_rounded, '/stats', perm: Perm.thongKe, color: Color(0xFF8E4EC6)),
  Feature('accounts', 'Tài khoản', Icons.account_balance_wallet_rounded, '/accounts', perm: Perm.taiKhoan, color: Color(0xFF30A46C)),
  Feature('categories', 'Danh mục', Icons.category_rounded, '/categories', perm: Perm.danhMuc, color: Color(0xFFF76B15)),
  Feature('budgets', 'Định mức', Icons.speed_rounded, '/budgets', perm: Perm.dinhMuc, color: Color(0xFFE5484D)),
  Feature('jars', 'Hũ tiết kiệm', Icons.savings_rounded, '/jars', perm: Perm.huTietKiem, color: Color(0xFFF5A524)),
  Feature('electricity', 'Tiền điện', Icons.bolt_rounded, '/electricity', perm: Perm.tienDien, color: Color(0xFFFFB224)),
  Feature('love', 'Ngày yêu', Icons.favorite_rounded, '/love', perm: Perm.ngayYeu, color: Color(0xFFE93D82)),
  Feature('cycle', 'Chu kỳ', Icons.water_drop_rounded, '/cycle', perm: Perm.chuKy, color: Color(0xFFD6409F)),
  Feature('reminders', 'Nhắc nhở', Icons.alarm_rounded, '/reminders', perm: Perm.nhacNho, color: Color(0xFFF76B15)),
  Feature('schedule', 'Lịch trình', Icons.event_rounded, '/schedule', perm: Perm.lichTrinh, color: Color(0xFF0090FF)),
  Feature('feed', 'Bảng tin', Icons.dynamic_feed_rounded, '/feed', perm: Perm.baiViet, color: Color(0xFF6E56CF), loginOnly: true),
  Feature('chat', 'Tin nhắn', Icons.chat_bubble_rounded, '/chat', perm: Perm.tinNhan, color: Color(0xFF12A594), loginOnly: true),
  Feature('friends', 'Bạn bè', Icons.group_rounded, '/friends', perm: Perm.banBe, color: Color(0xFF0090FF), loginOnly: true),
  Feature('notifications', 'Thông báo', Icons.notifications_rounded, '/notifications', color: Color(0xFFF76B15), loginOnly: true),
  Feature('admin', 'Quản trị', Icons.admin_panel_settings_rounded, '/admin', color: Color(0xFF8D8D86), adminOnly: true),
  Feature('settings', 'Cài đặt', Icons.settings_rounded, '/settings', color: Color(0xFF8D8D86)),
];

Feature? featureById(String id) => features.where((f) => f.id == id).firstOrNull;

/// Bố cục menu người dùng tự cấu hình (lưu trong AppSettings.menuLayoutJson, đồng bộ giữa các máy).
class MenuLayout {
  MenuLayout(this.tabs, this.shortcuts);
  final List<String> tabs; // tối đa 4 tab + tab "Menu" cố định
  final List<String> shortcuts; // lưới tiện ích ở trang chủ

  static const defaultTabs = ['home', 'transactions', 'stats', 'schedule'];
  static const defaultShortcuts = ['accounts', 'budgets', 'jars', 'electricity', 'love', 'cycle', 'feed', 'chat'];

  factory MenuLayout.of(LocalStore store) {
    final s = store.all(E.appSettings).firstOrNull;
    final raw = s?['menuLayoutJson'] as String?;
    if (raw == null) return MenuLayout(defaultTabs, defaultShortcuts);
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return MenuLayout((m['tabs'] as List).cast<String>(), (m['shortcuts'] as List).cast<String>());
    } catch (_) {
      return MenuLayout(defaultTabs, defaultShortcuts);
    }
  }

  void save(LocalStore store) {
    final s = store.all(E.appSettings).firstOrNull ?? {};
    store.put(E.appSettings, {
      ...s,
      'menuLayoutJson': jsonEncode({'tabs': tabs, 'shortcuts': shortcuts}),
    });
  }
}
