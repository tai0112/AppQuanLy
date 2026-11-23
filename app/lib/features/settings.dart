import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/config.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../data/api.dart';
import '../data/local_store.dart';
import '../data/models.dart';
import '../data/session.dart';
import '../data/sync.dart';
import '../data/calendar_look.dart';
import '../data/time_config.dart';
import '../providers.dart';
import 'common.dart';
import 'registry.dart';
import 'shell.dart';
import 'social.dart';

/// Một dòng cài đặt (dữ liệu) — để lọc theo ô tìm kiếm.
class _S {
  const _S({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.value,
    this.onTap,
    this.switchValue,
    this.onSwitch,
    this.danger = false,
    this.keywords = '',
  });
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final String? value;
  final VoidCallback? onTap;
  final bool? switchValue;
  final ValueChanged<bool>? onSwitch;
  final bool danger;
  final String keywords;

  bool matches(String q) => q.isEmpty || Fmt.fold('$title ${subtitle ?? ''} ${value ?? ''} $keywords').contains(q);
}

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final search = TextEditingController();
  String q = '';

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watchTables(const [E.appSettings]);
    final session = ref.watch(sessionProvider);
    final f = ref.watch(financeProvider);
    final settings = AppSettingsRec(store.all(E.appSettings).firstOrNull ?? {});
    void update(Map<String, dynamic> v) => store.put(E.appSettings, {...settings.m, ...v});
    final seed = hexColor(settings.primaryColor, AppColors.seeds.first);
    final scheme = Theme.of(context).colorScheme;
    final host = Uri.tryParse(ref.read(apiProvider).baseUrl)?.authority ?? ref.read(apiProvider).baseUrl;

    final groups = <(String, List<_S>)>[
      (
        'Tài chính',
        [
          _S(
            icon: Icons.currency_exchange_rounded,
            color: const Color(0xFF30A46C),
            title: 'Tiền tệ & tỷ giá',
            value: f.baseCurrency,
            keywords: 'tien te ty gia currency',
            onTap: () => context.push('/currencies'),
          ),
          _S(
            icon: Icons.category_rounded,
            color: const Color(0xFFF76B15),
            title: 'Danh mục thu / chi',
            keywords: 'danh muc',
            onTap: () => context.push('/categories'),
          ),
          _S(
            icon: Icons.account_balance_wallet_rounded,
            color: const Color(0xFF0090FF),
            title: 'Nguồn tiền mặc định',
            subtitle: 'Chọn sẵn khi thêm giao dịch',
            value: f.account(settings.defaultAccountId)?.name ?? 'Tài khoản đầu tiên',
            keywords: 'tai khoan tien mat vi',
            onTap: () async {
              final v = await pickFromList<String>(
                context,
                title: 'Nguồn tiền mặc định',
                selected: settings.defaultAccountId ?? '',
                items: [
                  ('', 'Tài khoản đầu tiên', Icons.looks_one_rounded),
                  for (final a in f.accounts.where((a) => !a.isArchived)) (a.id, a.name, a.isCash ? Icons.payments_rounded : Icons.account_balance_rounded),
                ],
              );
              if (v != null) update({'defaultAccountId': v.isEmpty ? null : v});
            },
          ),
          _S(
            icon: Icons.history_rounded,
            color: const Color(0xFF8E4EC6),
            title: 'Nhớ nguồn tiền lần trước',
            subtitle: 'Tự chọn tài khoản / tiền mặt vừa dùng',
            keywords: 'nho tai khoan',
            switchValue: settings.rememberLastAccount,
            onSwitch: (v) => update({'rememberLastAccount': v}),
          ),
          _S(
            icon: Icons.event_repeat_rounded,
            color: const Color(0xFFE5484D),
            title: 'Ngày bắt đầu tháng',
            subtitle: 'Ví dụ: ngày nhận lương',
            value: 'Ngày ${settings.monthStartDay}',
            keywords: 'thang tai chinh luong ky',
            onTap: () async {
              final v = await pickFromList<int>(
                context,
                title: 'Tháng tài chính bắt đầu từ',
                selected: settings.monthStartDay,
                items: [for (var i = 1; i <= 28; i++) (i, 'Ngày $i hằng tháng', null)],
              );
              if (v != null) update({'financeMonthStartDay': v});
            },
          ),
        ],
      ),
      (
        'Lịch trình & thông báo',
        [
          _S(
            icon: Icons.schedule_rounded,
            color: const Color(0xFF0090FF),
            title: 'Thời gian & nhắc nhở',
            subtitle: 'Mốc nhắc, khung giờ, ngày đầu tuần, màu lịch',
            keywords: 'gio nhac nho tuan lich vien mau',
            onTap: () => context.push('/settings/time'),
          ),
          _S(
            icon: Icons.label_rounded,
            color: const Color(0xFF12A594),
            title: 'Danh mục lịch trình',
            subtitle: 'Loại lịch trình & mẫu hoạt động',
            keywords: 'danh muc mau hoat dong',
            onTap: () => context.push('/categories', extra: {'type': 3}),
          ),
          _S(
            icon: Icons.notifications_active_rounded,
            color: const Color(0xFFFFB224),
            title: 'Âm thanh thông báo',
            subtitle: 'Âm từng loại, rung, giờ yên lặng',
            keywords: 'thong bao am thanh rung',
            onTap: () => context.push('/settings/notifications'),
          ),
        ],
      ),
      (
        'Ứng dụng',
        [
          _S(
            icon: Icons.dashboard_customize_rounded,
            color: const Color(0xFF3E63DD),
            title: 'Tuỳ chỉnh menu',
            subtitle: 'Thanh điều hướng & lối tắt trang chủ',
            keywords: 'menu tab loi tat',
            onTap: () => context.push('/settings/menu'),
          ),
          _S(
            icon: Icons.cloud_sync_rounded,
            color: const Color(0xFF12A594),
            title: 'Đồng bộ & bộ nhớ đệm',
            keywords: 'dong bo sync offline',
            onTap: () => context.push('/settings/sync'),
          ),
          _S(
            icon: Icons.move_to_inbox_rounded,
            color: const Color(0xFFF76B15),
            title: 'Nhập từ Money Manager',
            subtitle: 'Giao dịch, tài khoản, danh mục & ảnh từ file .mmbackup',
            keywords: 'nhap import money manager mmbackup sao luu khoi phuc chuyen du lieu',
            onTap: () => context.push('/settings/import-mm'),
          ),
          _S(
            icon: Icons.dns_rounded,
            color: const Color(0xFF6F6E77),
            title: 'Địa chỉ máy chủ',
            value: host,
            keywords: 'server may chu',
            onTap: () => _serverUrl(context, ref),
          ),
        ],
      ),
      (
        'Quyền riêng tư',
        [
          if (session.isLoggedIn)
            _S(
              icon: Icons.block_rounded,
              color: const Color(0xFFE5484D),
              title: 'Người đã chặn',
              keywords: 'chan',
              onTap: () => context.push('/settings/blocked'),
            ),
          _S(
            icon: Icons.privacy_tip_rounded,
            color: const Color(0xFF30A46C),
            title: 'Chính sách quyền riêng tư',
            keywords: 'rieng tu privacy',
            onTap: () => context.push('/legal/privacy'),
          ),
          _S(
            icon: Icons.gavel_rounded,
            color: const Color(0xFF6F6E77),
            title: 'Điều khoản sử dụng',
            keywords: 'dieu khoan terms',
            onTap: () => context.push('/legal/terms'),
          ),
        ],
      ),
      if (session.isAdmin)
        (
          'Quản trị',
          [
            if (session.can(Perm.qtVaiTro) || session.can(Perm.qtNguoiDung))
              _S(
                icon: Icons.admin_panel_settings_rounded,
                color: const Color(0xFF3E63DD),
                title: 'Người dùng & phân quyền',
                subtitle: 'Tạo tài khoản, vai trò, quyền, khoá / mở khoá',
                keywords: 'quan tri admin nguoi dung vai tro phan quyen role',
                onTap: () => context.push('/admin'),
              ),
            if (session.can(Perm.qtBaoCao))
              _S(
                icon: Icons.flag_rounded,
                color: AppColors.warning,
                title: 'Báo cáo vi phạm',
                subtitle: 'Xử lý trong vòng 24 giờ',
                keywords: 'bao cao vi pham quan tri',
                onTap: () => context.push('/admin/reports'),
              ),
            if (session.can(Perm.qtNhatKy) || session.isAdmin)
              _S(
                icon: Icons.history_rounded,
                color: const Color(0xFF10B981),
                title: 'Nhật ký hệ thống & API',
                subtitle: 'Xem lịch sử gọi API, thời gian xử lý, lỗi và IP',
                keywords: 'nhat ky he thong log api audit system',
                onTap: () => context.push('/admin/logs'),
              ),
          ],
        ),
      if (session.isLoggedIn)
        (
          'Tài khoản',
          [
            _S(
              icon: Icons.password_rounded,
              color: const Color(0xFF0090FF),
              title: 'Đổi mật khẩu',
              subtitle: 'Các thiết bị khác sẽ bị đăng xuất',
              keywords: 'doi mat khau password',
              onTap: () => _changePassword(context, ref),
            ),
            _S(
              icon: Icons.logout_rounded,
              color: AppColors.expense,
              title: 'Đăng xuất',
              subtitle: 'Đẩy dữ liệu lên máy chủ rồi xoá khỏi máy này',
              keywords: 'dang xuat',
              onTap: () async {
                if (await confirm(
                  context,
                  'Đăng xuất?',
                  message: 'Thay đổi chưa đồng bộ sẽ được đẩy lên trước khi xoá dữ liệu trên máy.',
                  ok: 'Đăng xuất',
                  danger: true,
                )) {
                  await ref.read(sessionProvider).logout();
                  if (context.mounted) showToast(context, 'Đã đăng xuất');
                }
              },
            ),
            _S(
              icon: Icons.delete_forever_rounded,
              color: AppColors.expense,
              title: 'Xoá tài khoản',
              subtitle: 'Xoá vĩnh viễn tài khoản và toàn bộ dữ liệu',
              keywords: 'xoa tai khoan delete',
              danger: true,
              onTap: () => context.push('/settings/delete-account'),
            ),
          ],
        ),
    ];

    final key = Fmt.fold(q.trim());
    final showLook = key.isEmpty || Fmt.fold('giao dien sang toi mau chu dao theme').contains(key);
    final visible = [
      for (final (title, items) in groups)
        if (items.where((s) => s.matches(key)).toList() case final list when list.isNotEmpty) (title, list),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _ProfileCard(onEdit: () => _editProfile(context, ref)),
          const SizedBox(height: 12),
          const LiveSyncBanner(),
          const SizedBox(height: 4),
          // Tìm nhanh một cài đặt
          TextField(
            controller: search,
            onChanged: (v) => setState(() => q = v),
            decoration: InputDecoration(
              hintText: 'Tìm cài đặt...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: q.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => setState(() {
                        search.clear();
                        q = '';
                      }),
                    ),
              isDense: true,
              filled: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showLook) ...[
                  const _GroupTitle('Giao diện'),
                  AppCard(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            for (final (i, (v, label)) in const [('system', 'Tự động'), ('light', 'Sáng'), ('dark', 'Tối')].indexed) ...[
                              if (i > 0) const SizedBox(width: 10),
                              Expanded(
                                child: _ThemeOption(mode: v, label: label, selected: settings.theme == v, accent: seed, onTap: () => update({'theme': v})),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Màu chủ đạo',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 8),
                        ColorPickerRow(value: seed, onChanged: (c) => update({'primaryColor': colorHex(c)})),
                      ],
                    ),
                  ),
                ],
                for (final (title, items) in visible) ...[
                  _GroupTitle(title),
                  AppCard(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        for (final (i, s) in items.indexed) ...[
                          if (i > 0) Divider(height: 1, indent: 62, color: scheme.outlineVariant.withValues(alpha: 0.35)),
                          _SettingRow(s),
                        ],
                      ],
                    ),
                  ),
                ],
                if (!showLook && visible.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: EmptyState(icon: Icons.search_off_rounded, title: 'Không tìm thấy cài đặt'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                Text(
                  AppConfig.appName,
                  style: TextStyle(fontWeight: FontWeight.w800, color: scheme.onSurfaceVariant),
                ),
                Text('Lưu trên máy · đồng bộ khi có mạng', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    final current = TextEditingController(), next = TextEditingController(), again = TextEditingController();
    String? error;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Đổi mật khẩu'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: current,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Mật khẩu hiện tại'),
              ),
              TextField(
                controller: next,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Mật khẩu mới (tối thiểu 6 ký tự)'),
              ),
              TextField(
                controller: again,
                obscureText: true,
                decoration: InputDecoration(labelText: 'Nhập lại mật khẩu mới', errorText: error),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
            FilledButton(
              onPressed: () {
                if (next.text != again.text) return set(() => error = 'Mật khẩu nhập lại không khớp');
                Navigator.pop(ctx, true);
              },
              child: const Text('Đổi'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      final api = ref.read(apiProvider);
      try {
        await api.post('/me/password', {'currentPassword': current.text, 'newPassword': next.text, 'refreshToken': api.refreshToken});
        if (context.mounted) showToast(context, 'Đã đổi mật khẩu');
      } on ApiException catch (e) {
        if (context.mounted) showToast(context, e.message, error: true);
      }
    }
    for (final c in [current, next, again]) {
      c.dispose();
    }
  }

  Future<void> _serverUrl(BuildContext context, WidgetRef ref) async {
    final api = ref.read(apiProvider);
    final c = TextEditingController(text: api.baseUrl);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Địa chỉ máy chủ'),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(hintText: AppConfig.prodApiUrl, helperText: 'Để trống = máy chủ mặc định'),
        ),
        actions: [
          TextButton(onPressed: () => c.text = '', child: const Text('Mặc định')),
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Lưu')),
        ],
      ),
    );
    if (ok == true) {
      if (c.text.trim().isEmpty) {
        ref.read(storeProvider).setMeta('apiUrl', null); // về địa chỉ mặc định của bản build
      } else {
        api.baseUrl = c.text;
      }
      final alive = await api.ping();
      if (context.mounted) showToast(context, alive ? 'Kết nối máy chủ thành công' : 'Không kết nối được máy chủ', error: !alive);
    }
  }

  Future<void> _editProfile(BuildContext context, WidgetRef ref) async {
    final session = ref.read(sessionProvider);
    final name = TextEditingController(text: session.user?['displayName'] as String?);
    final bio = TextEditingController(text: session.user?['bio'] as String?);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hồ sơ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Tên hiển thị'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: bio,
              decoration: const InputDecoration(labelText: 'Giới thiệu'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Lưu')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final u = await ref.read(apiProvider).put<Map<String, dynamic>>('/me', {
        'displayName': name.text,
        'bio': bio.text,
        'avatarFileId': session.user?['avatarFileId'],
      });
      session.updateUser(u);
    } on ApiException catch (e) {
      if (context.mounted) showToast(context, e.message, error: true);
    }
  }
}

/// Thẻ hồ sơ đầu trang: đã đăng nhập → tên, tài khoản, nút sửa; chưa → lời mời đăng nhập.
class _ProfileCard extends ConsumerWidget {
  const _ProfileCard({required this.onEdit});
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final scheme = Theme.of(context).colorScheme;
    final hero = heroOf(scheme.primary);
    final gradient = LinearGradient(colors: [hero, accentOf(hero, light: -0.08)], begin: Alignment.topLeft, end: Alignment.bottomRight);
    if (!session.isLoggedIn) {
      return AppCard(
        gradient: gradient,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.cloud_off_rounded, color: Colors.white),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Đang dùng offline',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      Text('Đăng nhập để sao lưu, đồng bộ nhiều máy và kết nối bạn bè', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                      minimumSize: const Size(64, 42),
                    ),
                    onPressed: () => context.push('/register'),
                    child: const Text('Tạo tài khoản', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: hero, minimumSize: const Size(64, 42)),
                    onPressed: () => context.push('/login'),
                    child: const Text('Đăng nhập', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
    final u = session.user ?? {};
    return AppCard(
      gradient: gradient,
      padding: const EdgeInsets.all(16),
      onTap: onEdit,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: UserAvatar(u, radius: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  u['displayName'] as String? ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                ),
                Text(
                  '@${u['username']} · ${u['email']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                if (session.roles.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final r in session.roles)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                          child: Text(
                            r,
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
          ),
        ],
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(6, 20, 6, 8),
    child: Text(
      title.toUpperCase(),
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
}

/// Dòng cài đặt: ô icon màu · tiêu đề (+ mô tả) · giá trị / công tắc / mũi tên.
class _SettingRow extends StatelessWidget {
  const _SettingRow(this.s);
  final _S s;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isSwitch = s.switchValue != null;
    final row = Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color.lerp(s.color, Colors.white, 0.1)!, Color.lerp(s.color, Colors.black, 0.15)!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(s.icon, size: 19, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.title,
                  style: TextStyle(fontSize: 15, fontWeight: s.danger ? FontWeight.w800 : FontWeight.w600, color: s.danger ? AppColors.expense : null),
                ),
                if (s.subtitle != null)
                  Text(
                    s.subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          if (s.value != null) ...[
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 130),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
                child: Text(
                  s.value!,
                  key: ValueKey(s.value),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: scheme.primary),
                ),
              ),
            ),
          ],
          if (isSwitch)
            Switch(value: s.switchValue!, onChanged: s.onSwitch)
          else
            Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant.withValues(alpha: 0.7)),
        ],
      ),
    );
    if (isSwitch) {
      return GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => s.onSwitch?.call(!s.switchValue!), child: row);
    }
    return Pressable(scale: 0.98, onTap: s.onTap, child: row);
  }
}

/// Thẻ chọn giao diện có hình xem trước (sáng / tối / tự động).
class _ThemeOption extends StatelessWidget {
  const _ThemeOption({required this.mode, required this.label, required this.selected, required this.accent, required this.onTap});
  final String mode;
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  Widget _mock(bool dark) {
    final bg = dark ? const Color(0xFF15181C) : const Color(0xFFF4F5F7);
    final card = dark ? const Color(0xFF262A30) : Colors.white;
    final line = dark ? const Color(0xFF3A3F46) : const Color(0xFFDDE0E4);
    return Container(
      color: bg,
      padding: const EdgeInsets.all(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 14,
            decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(height: 4),
          Container(
            height: 18,
            decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(3)),
            padding: const EdgeInsets.all(4),
            child: Container(color: line),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(color: line, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final preview = switch (mode) {
      'light' => _mock(false),
      'dark' => _mock(true),
      _ => Row(
        children: [
          Expanded(child: ClipRect(child: _mock(false))),
          Expanded(child: ClipRect(child: _mock(true))),
        ],
      ),
    };
    return Pressable(
      scale: 0.95,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: selected ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.5), width: selected ? 2.5 : 1),
              boxShadow: selected ? [BoxShadow(color: scheme.primary.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 3))] : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  preview,
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: AnimatedScale(
                      scale: selected ? 1 : 0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutBack,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
                        child: Icon(Icons.check_rounded, size: 13, color: scheme.onPrimary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                switch (mode) {
                  'light' => Icons.light_mode_rounded,
                  'dark' => Icons.dark_mode_rounded,
                  _ => Icons.brightness_auto_rounded,
                },
                size: 14,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w800 : FontWeight.w600, color: selected ? scheme.primary : null),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Đăng nhập / đăng ký.
class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key, this.startWithRegister = false});

  /// Mở thẳng vào form đăng ký (nút "Tạo tài khoản").
  final bool startWithRegister;

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  late bool register = widget.startWithRegister;
  bool busy = false;
  bool hide = true;
  bool agree = false;
  final login = TextEditingController();
  final email = TextEditingController();
  final username = TextEditingController();
  final name = TextEditingController();
  final password = TextEditingController();

  Future<void> _submit() async {
    setState(() => busy = true);
    try {
      final s = ref.read(sessionProvider);
      if (register) {
        await s.register(email.text.trim(), username.text.trim(), password.text, name.text.trim(), acceptTerms: agree);
      } else {
        await s.login(login.text.trim(), password.text);
      }
      if (mounted) {
        showToast(context, 'Xin chào ${s.user?['displayName']} 👋');
        context.go('/');
      }
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              Icon(Icons.account_balance_wallet_rounded, size: 64, color: scheme.primary).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
              const SizedBox(height: 12),
              Text(
                AppConfig.appName,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
              Text(register ? 'Tạo tài khoản mới' : 'Đăng nhập để đồng bộ dữ liệu', textAlign: TextAlign.center),
              const SizedBox(height: 24),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                child: Column(
                  children: [
                    if (register) ...[
                      TextField(
                        controller: name,
                        decoration: const InputDecoration(labelText: 'Tên hiển thị', prefixIcon: Icon(Icons.badge_rounded)),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_rounded)),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: username,
                        decoration: const InputDecoration(
                          labelText: 'Tên đăng nhập',
                          helperText: 'Chữ thường, số, dấu _ hoặc .',
                          prefixIcon: Icon(Icons.alternate_email_rounded),
                        ),
                      ),
                    ] else
                      TextField(
                        controller: login,
                        decoration: const InputDecoration(labelText: 'Email hoặc tên đăng nhập', prefixIcon: Icon(Icons.person_rounded)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: password,
                obscureText: hide,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Mật khẩu',
                  prefixIcon: const Icon(Icons.lock_rounded),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => hide = !hide),
                    icon: Icon(hide ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                  ),
                ),
              ),
              // Bắt buộc đồng ý điều khoản khi đăng ký (App Store 1.2: không dung thứ nội dung phản cảm)
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                child: !register
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(value: agree, onChanged: (v) => setState(() => agree = v ?? false)),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Wrap(
                                  children: [
                                    const Text('Tôi đồng ý '),
                                    GestureDetector(
                                      onTap: () => context.push('/legal/terms'),
                                      child: Text(
                                        'Điều khoản sử dụng',
                                        style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    const Text(' và '),
                                    GestureDetector(
                                      onTap: () => context.push('/legal/privacy'),
                                      child: Text(
                                        'Chính sách quyền riêng tư',
                                        style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    const Text('. Không đăng nội dung phản cảm hay lạm dụng người khác.'),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: busy || (register && !agree) ? null : _submit,
                child: busy
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                    : Text(register ? 'Đăng ký' : 'Đăng nhập'),
              ),
              TextButton(
                onPressed: () => setState(() => register = !register),
                child: Text(register ? 'Đã có tài khoản? Đăng nhập' : 'Chưa có tài khoản? Đăng ký'),
              ),
              const SizedBox(height: 8),
              Text(
                'Máy chủ: ${ref.read(apiProvider).baseUrl}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tuỳ chỉnh menu: tab dưới cùng (tối đa 4) và tiện ích trang chủ, kéo thả để sắp xếp.
class MenuConfigPage extends ConsumerStatefulWidget {
  const MenuConfigPage({super.key});

  @override
  ConsumerState<MenuConfigPage> createState() => _MenuConfigPageState();
}

class _MenuConfigPageState extends ConsumerState<MenuConfigPage> {
  late MenuLayout layout = MenuLayout.of(ref.read(storeProvider));
  late List<String> tabs = [...layout.tabs];
  late List<String> shortcuts = [...layout.shortcuts];

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final available = features.where((f) => f.visible(session)).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tuỳ chỉnh menu'),
        actions: [
          TextButton(
            onPressed: () {
              MenuLayout(tabs, shortcuts).save(ref.read(storeProvider));
              showToast(context, 'Đã lưu menu');
              Navigator.of(context).maybePop();
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionTitle('Thanh điều hướng (tối đa 4 + Menu)'),
          ReorderableListView(
            shrinkWrap: true,
            buildDefaultDragHandles: false,
            proxyDecorator: liftOnDrag,
            physics: const NeverScrollableScrollPhysics(),
            onReorder: (o, n) => setState(() {
              final x = tabs.removeAt(o);
              tabs.insert(n > o ? n - 1 : n, x);
            }),
            children: [
              for (final (i, id) in tabs.indexed)
                ListTile(
                  key: ValueKey('tab-$id'),
                  leading: Icon(featureById(id)?.icon),
                  title: Text(featureById(id)?.title ?? id),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(onPressed: () => setState(() => tabs.remove(id)), icon: const Icon(Icons.remove_circle_outline_rounded)),
                      DragHandle(index: i),
                    ],
                  ),
                ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in available.where((f) => !tabs.contains(f.id) && f.id != 'settings'))
                ActionChip(avatar: Icon(f.icon, size: 18), label: Text(f.title), onPressed: tabs.length >= 4 ? null : () => setState(() => tabs.add(f.id))),
            ],
          ),
          SectionTitle(
            'Tiện ích trang chủ',
            trailing: TextButton(
              onPressed: () => setState(() => shortcuts.addAll(available.where((f) => f.id != 'home' && !shortcuts.contains(f.id)).map((f) => f.id))),
              child: const Text('Thêm tất cả'),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child: shortcuts.isEmpty
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                    child: Text(
                      'Chưa ghim tiện ích nào — trang chủ sẽ tự hiện các chức năng chưa có trên thanh điều hướng. Mọi chức năng luôn mở được qua ô "Tất cả".',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          ReorderableListView(
            shrinkWrap: true,
            buildDefaultDragHandles: false,
            proxyDecorator: liftOnDrag,
            physics: const NeverScrollableScrollPhysics(),
            onReorder: (o, n) => setState(() {
              final x = shortcuts.removeAt(o);
              shortcuts.insert(n > o ? n - 1 : n, x);
            }),
            children: [
              for (final (i, id) in shortcuts.indexed)
                ListTile(
                  key: ValueKey('sc-$id'),
                  leading: Icon(featureById(id)?.icon),
                  title: Text(featureById(id)?.title ?? id),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(onPressed: () => setState(() => shortcuts.remove(id)), icon: const Icon(Icons.remove_circle_outline_rounded)),
                      DragHandle(index: i),
                    ],
                  ),
                ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in available.where((f) => !shortcuts.contains(f.id) && f.id != 'home'))
                ActionChip(avatar: Icon(f.icon, size: 18), label: Text(f.title), onPressed: () => setState(() => shortcuts.add(f.id))),
            ],
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() {
              tabs = [...MenuLayout.defaultTabs];
              shortcuts = [...MenuLayout.defaultShortcuts];
            }),
            child: const Text('Khôi phục mặc định'),
          ),
        ],
      ),
    );
  }
}

/// Trạng thái đồng bộ, hàng đợi offline, dọn bộ nhớ đệm.
class SyncStatusPage extends ConsumerWidget {
  const SyncStatusPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(syncProvider);
    final store = ref.watch(storeProvider);
    final rt = ref.watch(realtimeProvider);
    final dirty = store.dirtyRecords();
    final uploads = store.pendingUploads();
    final outbox = store.outbox();
    return Scaffold(
      appBar: AppBar(title: const Text('Đồng bộ')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SyncBanner(sync: sync),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: SwitchListTile(
              value: sync.autoSync,
              onChanged: (v) => sync.autoSync = v,
              secondary: Icon(sync.autoSync ? Icons.cloud_sync_rounded : Icons.phone_iphone_rounded, color: Theme.of(context).colorScheme.primary),
              title: const Text('Tự động đồng bộ', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(
                  sync.autoSync
                      ? 'Mọi thay đổi tự đẩy lên máy chủ và tải về từ các máy khác.'
                      : 'Dữ liệu và ảnh chỉ lưu trên máy này. Bấm "Đồng bộ ngay" khi muốn đồng bộ.',
                  key: ValueKey(sync.autoSync),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              children: [
                ListTile(leading: const Icon(Icons.edit_note_rounded), title: const Text('Bản ghi chờ đẩy lên'), trailing: Text('${dirty.length}')),
                ListTile(leading: const Icon(Icons.image_rounded), title: const Text('Ảnh chờ tải lên'), trailing: Text('${uploads.length}')),
                ListTile(leading: const Icon(Icons.photo_library_rounded), title: const Text('Ảnh lưu trên máy'), trailing: Text('${store.localFileCount}')),
                ListTile(leading: const Icon(Icons.outbox_rounded), title: const Text('Bài viết / tin nhắn chờ gửi'), trailing: Text('${outbox.length}')),
                ListTile(
                  leading: Icon(Icons.bolt_rounded, color: rt.connected ? AppColors.income : null),
                  title: const Text('Realtime (SignalR)'),
                  trailing: Text(rt.connected ? 'Đã kết nối' : 'Chưa kết nối'),
                ),
                ListTile(
                  leading: const Icon(Icons.history_rounded),
                  title: const Text('Lần đồng bộ gần nhất'),
                  trailing: Text(sync.lastSyncedAt == null ? '—' : Fmt.time(sync.lastSyncedAt!)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: sync.state == SyncState.syncing ? null : () => sync.sync(),
            icon: const Icon(Icons.sync_rounded),
            label: const Text('Đồng bộ ngay'),
          ),
          const SizedBox(height: 12),
          if (dirty.isNotEmpty) ...[
            const SectionTitle('Chi tiết chờ đồng bộ'),
            for (final d in dirty.take(50)) ListTile(dense: true, title: Text(d.entity), subtitle: Text(d.data['id'] as String)),
          ],
          const SizedBox(height: 12),
          Text(
            'Dữ liệu và ảnh luôn được lưu trong máy nên dùng được cả khi không có mạng. Khi đồng bộ, app đẩy thay đổi và ảnh mới lên máy chủ, '
            'đồng thời tải về dữ liệu và ảnh còn thiếu (vd ảnh thêm từ máy khác). Ảnh của bản ghi đã xoá sẽ được dọn khỏi máy.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Cấu hình mọi giá trị thời gian (không cố định trong code): mốc nhắc, nhắc mặc định, khung giờ timeline...
class TimeSettingsPage extends ConsumerWidget {
  const TimeSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watchTables(const [E.appSettings]);
    final cfg = TimeConfig.of(store);
    final scheme = Theme.of(context).colorScheme;
    void save(TimeConfig c) => c.save(store);

    Future<void> addRemind() async {
      final value = TextEditingController();
      var unit = 1; // 1 phút, 60 giờ, 1440 ngày
      final r = await showDialog<int>(
        context: context,
        builder: (c) => StatefulBuilder(
          builder: (c, set) => AlertDialog(
            title: const Text('Thêm mốc nhắc'),
            content: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: value,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Trước'),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: unit,
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('phút')),
                    DropdownMenuItem(value: 60, child: Text('giờ')),
                    DropdownMenuItem(value: 1440, child: Text('ngày')),
                  ],
                  onChanged: (v) => set(() => unit = v!),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c), child: const Text('Huỷ')),
              FilledButton(onPressed: () => Navigator.pop(c, (int.tryParse(value.text) ?? -1) * unit), child: const Text('Thêm')),
            ],
          ),
        ),
      );
      if (r != null && r >= 0 && !cfg.remindOptions.contains(r)) save(cfg.copyWith(remindOptions: [...cfg.remindOptions, r]..sort()));
    }

    Widget remindPicker(String label, int? value, ValueChanged<int?> onChanged) => ValueTile(
      icon: Icons.notifications_active_rounded,
      title: label,
      value: TimeConfig.remindLabel(value),
      onTap: () async {
        final v = await pickFromList<int>(
          context,
          title: label,
          selected: value ?? -1,
          items: [
            (-1, 'Không nhắc', Icons.notifications_off_rounded),
            for (final m in {...cfg.remindOptions, ?value}) (m, TimeConfig.remindLabel(m), Icons.alarm_rounded),
          ],
        );
        if (v != null) onChanged(v == -1 ? null : v);
      },
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Thời gian & nhắc nhở')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        children: [
          FormSection(
            title: 'Các mốc nhắc trước',
            padding: const EdgeInsets.all(14),
            children: [
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final m in cfg.remindOptions)
                      InputChip(
                        label: Text(TimeConfig.remindLabel(m)),
                        onDeleted: cfg.remindOptions.length <= 1
                            ? null
                            : () => save(cfg.copyWith(remindOptions: cfg.remindOptions.where((x) => x != m).toList())),
                      ),
                    ActionChip(avatar: const Icon(Icons.add_rounded, size: 18), label: const Text('Thêm mốc'), onPressed: addRemind),
                  ],
                ),
              ),
            ],
          ),
          FormSection(
            title: 'Nhắc nhở mặc định',
            children: [
              remindPicker('Lịch trình mới', cfg.defaultRemind, (v) => save(cfg.copyWith(defaultRemind: v))),
              remindPicker('Từng hoạt động theo giờ', cfg.itemRemindMinutes, (v) => save(cfg.copyWith(itemRemindMinutes: v))),
            ],
          ),
          FormSection(
            title: 'Timeline trong ngày',
            padding: const EdgeInsets.all(14),
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Khung giờ hiển thị: ${cfg.dayStartHour}:00 → ${cfg.dayEndHour}:00'),
                  RangeSlider(
                    values: RangeValues(cfg.dayStartHour.toDouble(), cfg.dayEndHour.toDouble()),
                    min: 0,
                    max: 24,
                    divisions: 24,
                    labels: RangeLabels('${cfg.dayStartHour}:00', '${cfg.dayEndHour}:00'),
                    onChanged: (v) {
                      if (v.end - v.start >= 3) save(cfg.copyWith(dayStartHour: v.start.round(), dayEndHour: v.end.round()));
                    },
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(padding: EdgeInsets.only(top: 8, bottom: 6), child: Text('Chạm vào trục giờ sẽ làm tròn theo')),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final m in [5, 10, 15, 30, 60])
                        ChoiceChip(
                          label: Text('$m phút'),
                          selected: cfg.snapMinutes == m,
                          onSelected: (_) => save(cfg.copyWith(snapMinutes: m)),
                        ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(padding: const EdgeInsets.only(top: 12), child: Text('Thời lượng mặc định của hoạt động mới: ${cfg.defaultActivityMinutes} phút')),
                  Slider(
                    value: cfg.defaultActivityMinutes.toDouble(),
                    min: 15,
                    max: 240,
                    divisions: 15,
                    label: '${cfg.defaultActivityMinutes} phút',
                    onChanged: (v) => save(cfg.copyWith(defaultActivityMinutes: v.round())),
                  ),
                ],
              ),
            ],
          ),
          const CalendarLookSection(),
          FormSection(
            title: 'Lịch',
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Ngày đầu tuần'), SizedBox(height: 10), FirstDayPicker()]),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Mọi thay đổi được lưu ngay và đồng bộ sang các máy khác của bạn.', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
          TextButton(onPressed: () => save(TimeConfig.defaults()), child: const Text('Khôi phục mặc định')),
        ],
      ),
    );
  }
}

/// Cấu hình giao diện ô lịch: màu viền ô thường / hôm nay / đang chọn, độ dày viền, màu Thứ 7 & Chủ nhật. Có xem trước.
class CalendarLookSection extends ConsumerWidget {
  const CalendarLookSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watchTables(const [E.appSettings]);
    final look = CalendarLook.of(store);
    final scheme = Theme.of(context).colorScheme;
    void save(CalendarLook l) => l.save(store);

    Widget colorRow(String label, String value, ValueChanged<String> onChanged, {bool allowNone = false}) {
      Widget dot({required bool selected, Color? color, required VoidCallback onTap, Widget? child}) => Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: selected ? 32 : 28,
          height: selected ? 32 : 28,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? scheme.onSurface : scheme.outlineVariant, width: selected ? 2.5 : 1),
          ),
          child: child,
        ),
      );
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  dot(
                    selected: value == 'auto',
                    onTap: () => onChanged('auto'),
                    child: const Center(
                      child: Text('A', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                    ),
                  ),
                  if (allowNone)
                    dot(
                      selected: value == 'none',
                      onTap: () => onChanged('none'),
                      child: Icon(Icons.block_rounded, size: 16, color: scheme.onSurfaceVariant),
                    ),
                  for (final c in AppColors.palette) dot(selected: value.toUpperCase() == colorHex(c), color: c, onTap: () => onChanged(colorHex(c))),
                  dot(selected: value.toUpperCase() == '#FFFFFF', color: Colors.white, onTap: () => onChanged('#FFFFFF')),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Xem trước 1 tuần
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final preview = Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: SizedBox(height: 28, child: calendarDow(context, monday.add(Duration(days: i)), look)),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Builder(
                    builder: (c) {
                      final d = monday.add(Duration(days: i));
                      final isToday = d.day == now.day;
                      final selected = i == (now.weekday % 7); // ô kế bên hôm nay làm ví dụ "đang chọn"
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.all(1.5),
                        decoration: BoxDecoration(
                          color: selected ? scheme.primary.withValues(alpha: 0.18) : scheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: selected
                                ? look.selectedBorderColor(scheme)
                                : isToday
                                ? look.todayBorderColor(scheme)
                                : (look.cellBorderColor(scheme) ?? Colors.transparent),
                            width: selected || isToday ? look.borderWidth + 0.6 : look.borderWidth,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${d.day}',
                          style: TextStyle(fontWeight: FontWeight.w700, color: look.weekdayColor(d.weekday, scheme) ?? scheme.onSurface),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ],
    );

    return FormSection(
      title: 'Giao diện lịch',
      padding: const EdgeInsets.all(14),
      children: [
        preview,
        colorRow('Viền ô ngày', look.cellBorder, (v) => save(look.copyWith(cellBorder: v)), allowNone: true),
        colorRow('Viền ô hôm nay', look.todayBorder, (v) => save(look.copyWith(todayBorder: v)), allowNone: true),
        colorRow('Viền ô đang chọn', look.selectedBorder, (v) => save(look.copyWith(selectedBorder: v)), allowNone: true),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Độ dày viền: ${look.borderWidth.toStringAsFixed(1)}', style: const TextStyle(fontWeight: FontWeight.w600)),
              Slider(
                value: look.borderWidth,
                min: 0.5,
                max: 3,
                divisions: 5,
                onChanged: (v) => save(look.copyWith(borderWidth: v)),
              ),
            ],
          ),
        ),
        colorRow('Màu chữ Thứ 7', look.saturdayColor, (v) => save(look.copyWith(saturdayColor: v)), allowNone: true),
        colorRow('Màu chữ Chủ nhật', look.sundayColor, (v) => save(look.copyWith(sundayColor: v)), allowNone: true),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('A = theo giao diện · ⦸ = không viền / màu chữ thường', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        ),
      ],
    );
  }
}
