import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../core/icons.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../data/api.dart';
import '../data/session.dart';
import '../providers.dart';

/// Quản trị phân quyền động: vai trò ↔ chức năng, người dùng ↔ vai trò. Thay đổi có hiệu lực ngay.
class AdminPage extends ConsumerStatefulWidget {
  const AdminPage({super.key});

  @override
  ConsumerState<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends ConsumerState<AdminPage> {
  List<Map<String, dynamic>> roles = [], modules = [], operations = [], users = [];
  bool loading = true;
  String userQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ref.read(apiProvider);
    final s = ref.read(sessionProvider);
    try {
      final r = await Future.wait([
        api.get<List<dynamic>>('/admin/roles'),
        api.get<List<dynamic>>('/admin/modules'),
        api.get<List<dynamic>>('/admin/operations'),
        if (s.can(Perm.qtNguoiDung)) api.get<List<dynamic>>('/admin/users') else Future.value(<dynamic>[]),
      ]);
      if (!mounted) return;
      setState(() {
        roles = r[0].cast<Map<String, dynamic>>();
        modules = r[1].cast<Map<String, dynamic>>();
        operations = r[2].cast<Map<String, dynamic>>();
        users = r[3].cast<Map<String, dynamic>>();
        loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => loading = false);
        showToast(context, e.message, error: true);
      }
    }
  }

  Future<void> _run(Future<void> Function() f, String ok) async {
    try {
      await f();
      if (mounted) showToast(context, ok);
      await _load();
      await ref.read(sessionProvider).refreshPermissions(); // quyền của chính mình có thể đổi
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);
    if (!s.isAdmin)
      return Scaffold(
        appBar: AppBar(title: const Text('Quản trị')),
        body: const EmptyState(icon: Icons.lock_rounded, title: 'Bạn không có quyền quản trị'),
      );
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Quản trị phân quyền'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Vai trò'),
              Tab(text: 'Người dùng'),
            ],
          ),
        ),
        // Nút thêm đổi theo tab đang mở: Vai trò / Người dùng
        floatingActionButton: Builder(
          builder: (context) {
            final tc = DefaultTabController.of(context);
            return AnimatedBuilder(
              animation: tc,
              builder: (context, _) => AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                child: tc.index == 0
                    ? FloatingActionButton.extended(
                        key: const ValueKey('role'),
                        onPressed: () => _editRole(null),
                        icon: const Icon(Icons.add),
                        label: const Text('Vai trò'),
                      )
                    : s.can(Perm.qtNguoiDung)
                    ? FloatingActionButton.extended(
                        key: const ValueKey('user'),
                        onPressed: _createUser,
                        icon: const Icon(Icons.person_add_rounded),
                        label: const Text('Người dùng'),
                      )
                    : const SizedBox.shrink(),
              ),
            );
          },
        ),
        body: loading
            ? const SkeletonList()
            : TabBarView(
                children: [
                  RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                      children: [
                        for (final (i, r) in roles.indexed)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: AppCard(
                              onTap: () => _editPermissions(r),
                              child: Row(
                                children: [
                                  CircleAvatar(child: Icon(r['isSystem'] == true ? Icons.shield_rounded : Icons.badge_rounded)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('${r['name']} (${r['code']})', style: const TextStyle(fontWeight: FontWeight.w700)),
                                        Text(
                                          '${(r['operationIds'] as List).length} chức năng · ${r['userCount']} người dùng'
                                          '${r['isDefault'] == true ? ' · mặc định khi đăng ký' : ''}${r['isActive'] == true ? '' : ' · ĐANG TẮT'}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(onPressed: () => _editRole(r), icon: const Icon(Icons.edit_rounded)),
                                ],
                              ),
                            ).stagger(i),
                          ),
                      ],
                    ),
                  ),
                  RefreshIndicator(
                    onRefresh: _load,
                    child: !s.can(Perm.qtNguoiDung)
                        ? ListView(
                            children: const [EmptyState(icon: Icons.lock_rounded, title: 'Không có quyền quản lý người dùng')],
                          )
                        : _usersTab(s),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _editRole(Map<String, dynamic>? r) async {
    final code = TextEditingController(text: r?['code'] as String?);
    final name = TextEditingController(text: r?['name'] as String?);
    final desc = TextEditingController(text: r?['description'] as String?);
    var active = r?['isActive'] as bool? ?? true;
    var isDefault = r?['isDefault'] as bool? ?? false;
    final api = ref.read(apiProvider);
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text(r == null ? 'Vai trò mới' : 'Sửa vai trò'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: code,
                  enabled: r?['isSystem'] != true,
                  decoration: const InputDecoration(labelText: 'Mã (VD: KE_TOAN)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Tên'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: desc,
                  decoration: const InputDecoration(labelText: 'Mô tả'),
                ),
                SwitchListTile(contentPadding: EdgeInsets.zero, value: active, onChanged: (v) => set(() => active = v), title: const Text('Đang bật')),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: isDefault,
                  onChanged: (v) => set(() => isDefault = v),
                  title: const Text('Gán khi đăng ký'),
                ),
              ],
            ),
          ),
          actions: [
            if (r != null && r['isSystem'] != true)
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _run(() => api.delete('/admin/roles/${r['id']}'), 'Đã xoá vai trò');
                },
                child: const Text('Xoá'),
              ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                final body = {'code': code.text, 'name': name.text, 'description': desc.text, 'isActive': active, 'isDefault': isDefault};
                _run(() => r == null ? api.post('/admin/roles', body) : api.put('/admin/roles/${r['id']}', body), 'Đã lưu vai trò');
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editPermissions(Map<String, dynamic> r) async {
    final selected = (r['operationIds'] as List).cast<String>().toSet();
    final api = ref.read(apiProvider);
    await showModalBottomSheet(
      sheetAnimationStyle: kSheetAnim,
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          builder: (ctx, scroll) => Column(
            children: [
              Text('Quyền của "${r['name']}"', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              Expanded(
                child: ListView(
                  controller: scroll,
                  children: [
                    for (final m in modules) ...[
                      CheckboxListTile(
                        tristate: true,
                        value: () {
                          final ops = operations.where((o) => o['moduleId'] == m['id']).map((o) => o['id'] as String);
                          final n = ops.where(selected.contains).length;
                          return n == 0
                              ? false
                              : n == ops.length
                              ? true
                              : null;
                        }(),
                        onChanged: (v) => set(() {
                          final ops = operations.where((o) => o['moduleId'] == m['id']).map((o) => o['id'] as String);
                          v == true ? selected.addAll(ops) : selected.removeAll(ops);
                        }),
                        secondary: Icon(iconOf(m['icon'] as String?)),
                        title: Text(m['name'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      for (final o in operations.where((o) => o['moduleId'] == m['id']))
                        CheckboxListTile(
                          contentPadding: const EdgeInsets.only(left: 56, right: 16),
                          value: selected.contains(o['id']),
                          onChanged: (v) => set(() => v == true ? selected.add(o['id'] as String) : selected.remove(o['id'])),
                          title: Text(o['name'] as String),
                          subtitle: Text(o['code'] as String, style: const TextStyle(fontSize: 11)),
                        ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _run(() => api.put('/admin/roles/${r['id']}/operations', {'ids': selected.toList()}), 'Đã cập nhật quyền');
                  },
                  child: Text('Lưu (${selected.length} chức năng)'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editUserRoles(Map<String, dynamic> u) async {
    final selected = (u['roleIds'] as List).cast<String>().toSet();
    final api = ref.read(apiProvider);
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text('Vai trò của ${u['displayName']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final r in roles)
                CheckboxListTile(
                  value: selected.contains(r['id']),
                  onChanged: (v) => set(() => v == true ? selected.add(r['id'] as String) : selected.remove(r['id'])),
                  title: Text(r['name'] as String),
                  subtitle: Text(r['code'] as String),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _run(() => api.put('/admin/users/${u['id']}/roles', {'ids': selected.toList()}), 'Đã cập nhật vai trò');
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================ Người dùng

  Widget _usersTab(Session s) {
    final scheme = Theme.of(context).colorScheme;
    final q = Fmt.fold(userQuery.trim());
    final list = users.where((u) => q.isEmpty || Fmt.fold('${u['displayName']} ${u['username']} ${u['email']}').contains(q)).toList();
    String roleCode(Object? id) => roles.firstWhere((r) => r['id'] == id, orElse: () => {'code': '?'})['code'] as String;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        TextField(
          onChanged: (v) => setState(() => userQuery = v),
          decoration: InputDecoration(
            hintText: 'Tìm theo tên, tài khoản, email...',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            isDense: true,
            filled: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
          child: Text(
            '${list.length} người dùng · ${users.where((u) => u['isLocked'] == true).length} bị khoá',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ),
        for (final (i, u) in list.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              padding: const EdgeInsets.all(12),
              onTap: () => _userActions(u),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: (u['isLocked'] == true ? AppColors.expense : scheme.primary).withValues(alpha: 0.15),
                    foregroundColor: u['isLocked'] == true ? AppColors.expense : scheme.primary,
                    child: u['isLocked'] == true
                        ? const Icon(Icons.lock_rounded, size: 20)
                        : Text((u['displayName'] as String).characters.first.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                u['displayName'] as String,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                            if (u['id'] == s.userId) ...[const SizedBox(width: 6), _badge('Bạn', scheme.primary)],
                            if (u['isLocked'] == true) ...[const SizedBox(width: 6), _badge('Đã khoá', AppColors.expense)],
                          ],
                        ),
                        Text(
                          '@${u['username']} · ${u['email']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            for (final rid in (u['roleIds'] as List))
                              _badge(roleCode(rid), roleCode(rid) == 'ADMIN' ? AppColors.warning : scheme.onSurfaceVariant),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.more_vert_rounded, color: scheme.onSurfaceVariant),
                ],
              ),
            ).stagger(i),
          ),
      ],
    );
  }

  Widget _badge(String text, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: c.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(6)),
    child: Text(
      text,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c),
    ),
  );

  /// Bảng thao tác trên một người dùng.
  Future<void> _userActions(Map<String, dynamic> u) async {
    final me = ref.read(sessionProvider).userId;
    final isMe = u['id'] == me;
    final locked = u['isLocked'] == true;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      sheetAnimationStyle: kSheetAnim,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('${u['displayName']} (@${u['username']})', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ),
            ListTile(leading: const Icon(Icons.badge_rounded), title: const Text('Phân vai trò'), onTap: () => Navigator.pop(c, 'roles')),
            ListTile(leading: const Icon(Icons.password_rounded), title: const Text('Đặt lại mật khẩu'), onTap: () => Navigator.pop(c, 'password')),
            if (!isMe)
              ListTile(
                leading: Icon(locked ? Icons.lock_open_rounded : Icons.lock_rounded, color: AppColors.warning),
                title: Text(locked ? 'Mở khoá tài khoản' : 'Khoá tài khoản'),
                subtitle: Text(locked ? 'Cho phép đăng nhập lại' : 'Đăng xuất mọi thiết bị, không đăng nhập được'),
                onTap: () => Navigator.pop(c, 'lock'),
              ),
            if (!isMe)
              ListTile(
                leading: const Icon(Icons.delete_forever_rounded, color: AppColors.expense),
                title: const Text(
                  'Xoá người dùng',
                  style: TextStyle(color: AppColors.expense, fontWeight: FontWeight.w700),
                ),
                subtitle: const Text('Xoá vĩnh viễn tài khoản và toàn bộ dữ liệu'),
                onTap: () => Navigator.pop(c, 'delete'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    final api = ref.read(apiProvider);
    switch (action) {
      case 'roles':
        await _editUserRoles(u);
      case 'password':
        final pw = await _askPassword('Mật khẩu mới cho ${u['displayName']}');
        if (pw != null)
          await _run(
            () => api.post('/admin/users/${u['id']}/password', {'newPassword': pw}),
            'Đã đặt lại mật khẩu · người dùng bị đăng xuất khỏi mọi thiết bị',
          );
      case 'lock':
        if (locked ||
            await confirm(
              context,
              'Khoá ${u['displayName']}?',
              message: 'Người này bị đăng xuất khỏi mọi thiết bị và không đăng nhập được cho tới khi mở khoá.',
              ok: 'Khoá',
              danger: true,
            )) {
          await _run(() => api.post('/admin/users/${u['id']}/lock', {'locked': !locked}), locked ? 'Đã mở khoá' : 'Đã khoá tài khoản');
        }
      case 'delete':
        if (await confirm(
          context,
          'Xoá vĩnh viễn ${u['displayName']}?',
          message: 'Toàn bộ dữ liệu của người này bị xoá khỏi máy chủ. Không thể khôi phục.',
          ok: 'Xoá vĩnh viễn',
          danger: true,
        )) {
          await _run(() => api.delete('/admin/users/${u['id']}'), 'Đã xoá người dùng');
        }
    }
  }

  /// Hộp nhập mật khẩu (có nút tạo ngẫu nhiên + sao chép).
  Future<String?> _askPassword(String title) async {
    final c = TextEditingController(text: _randomPassword());
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          decoration: InputDecoration(
            labelText: 'Mật khẩu (tối thiểu 6 ký tự)',
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(tooltip: 'Tạo ngẫu nhiên', onPressed: () => c.text = _randomPassword(), icon: const Icon(Icons.casino_rounded)),
                IconButton(
                  tooltip: 'Sao chép',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: c.text));
                    showToast(ctx, 'Đã sao chép mật khẩu');
                  },
                  icon: const Icon(Icons.copy_rounded),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Lưu')),
        ],
      ),
    );
    c.dispose();
    return r;
  }

  static String _randomPassword() {
    const chars = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    return List.generate(10, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  /// Quản trị viên tạo tài khoản mới.
  Future<void> _createUser() async {
    final name = TextEditingController(), username = TextEditingController(), email = TextEditingController();
    final password = TextEditingController(text: _randomPassword());
    final selected = <String>{
      for (final r in roles)
        if (r['isDefault'] == true) r['id'] as String,
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Thêm người dùng'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Tên hiển thị'),
                ),
                TextField(
                  controller: username,
                  decoration: const InputDecoration(labelText: 'Tên đăng nhập (chữ thường, số, _ .)'),
                ),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                TextField(
                  controller: password,
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu ban đầu',
                    suffixIcon: IconButton(
                      tooltip: 'Tạo ngẫu nhiên',
                      onPressed: () => password.text = _randomPassword(),
                      icon: const Icon(Icons.casino_rounded),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Vai trò', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                for (final r in roles)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: selected.contains(r['id']),
                    onChanged: (v) => set(() => v == true ? selected.add(r['id'] as String) : selected.remove(r['id'])),
                    title: Text(r['name'] as String),
                    subtitle: Text(r['code'] as String),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Tạo')),
          ],
        ),
      ),
    );
    if (ok == true) {
      final pw = password.text;
      await _run(
        () => ref.read(apiProvider).post('/admin/users', {
          'displayName': name.text.trim(),
          'username': username.text.trim(),
          'email': email.text.trim(),
          'password': pw,
          'roleIds': selected.toList(),
        }),
        'Đã tạo tài khoản @${username.text.trim()} · mật khẩu: $pw',
      );
    }
    for (final c in [name, username, email, password]) {
      c.dispose();
    }
  }
}
