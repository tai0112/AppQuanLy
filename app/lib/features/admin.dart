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
    final allOpIds = operations.map((o) => o['id'] as String).toList();
    await showModalBottomSheet(
      sheetAnimationStyle: kSheetAnim,
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          final scheme = Theme.of(ctx).colorScheme;
          final allSelected = allOpIds.isNotEmpty && selected.length == allOpIds.length;
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.88,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (ctx, scroll) => Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: scheme.outlineVariant, borderRadius: BorderRadius.circular(2)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                        child: Icon(Icons.admin_panel_settings_rounded, color: scheme.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Quyền của "${r['name']}"', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                            Text(
                              'Đã bật ${selected.length}/${allOpIds.length} chức năng',
                              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => set(() {
                          if (allSelected) {
                            selected.clear();
                          } else {
                            selected.addAll(allOpIds);
                          }
                        }),
                        child: Text(allSelected ? 'Bỏ hết' : 'Chọn hết', style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    controller: scroll,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    children: [
                      for (final m in modules)
                        Builder(
                          builder: (_) {
                            final modOps = operations.where((o) => o['moduleId'] == m['id']).toList();
                            final modIds = modOps.map((o) => o['id'] as String).toList();
                            final activeCount = modIds.where(selected.contains).length;
                            final groupState = activeCount == 0
                                ? false
                                : activeCount == modIds.length
                                ? true
                                : null;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: AppCard(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Column(
                                  children: [
                                    CheckboxListTile(
                                      tristate: true,
                                      value: groupState,
                                      onChanged: (v) => set(() {
                                        v == true ? selected.addAll(modIds) : selected.removeAll(modIds);
                                      }),
                                      secondary: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: scheme.primary.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(iconOf(m['icon'] as String?), size: 20, color: scheme.primary),
                                      ),
                                      title: Row(
                                        children: [
                                          Expanded(
                                            child: Text(m['name'] as String, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: activeCount > 0 ? scheme.primary.withValues(alpha: 0.12) : scheme.surfaceContainerHighest,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              '$activeCount/${modIds.length}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: activeCount > 0 ? scheme.primary : scheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (modOps.isNotEmpty) Divider(height: 1, indent: 16, endIndent: 16, color: scheme.outlineVariant.withValues(alpha: 0.4)),
                                    for (final (idx, o) in modOps.indexed) ...[
                                      if (idx > 0) Divider(height: 1, indent: 56, endIndent: 16, color: scheme.outlineVariant.withValues(alpha: 0.25)),
                                      SwitchListTile.adaptive(
                                        contentPadding: const EdgeInsets.only(left: 20, right: 12),
                                        value: selected.contains(o['id']),
                                        onChanged: (v) => set(() => v ? selected.add(o['id'] as String) : selected.remove(o['id'])),
                                        title: Text(o['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                        subtitle: Text(
                                          o['code'] as String,
                                          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant.withValues(alpha: 0.75)),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(ctx).padding.bottom + 16),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    border: Border(top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.35))),
                  ),
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _run(() => api.put('/admin/roles/${r['id']}/operations', {'ids': selected.toList()}), 'Đã cập nhật quyền');
                    },
                    child: Text('Lưu phân quyền (${selected.length} chức năng)', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _editUserRoles(Map<String, dynamic> u) async {
    final selected = (u['roleIds'] as List).cast<String>().toSet();
    final api = ref.read(apiProvider);
    await showModalBottomSheet(
      sheetAnimationStyle: kSheetAnim,
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          final scheme = Theme.of(ctx).colorScheme;
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: scheme.outlineVariant, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                      child: Icon(Icons.badge_rounded, color: scheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Phân vai trò', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                          Text(
                            '${u['displayName']} · @${u['username']}',
                            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded)),
                  ],
                ),
                const SizedBox(height: 16),
                for (final r in roles)
                  Builder(
                    builder: (_) {
                      final isSelected = selected.contains(r['id']);
                      final isAdmin = (r['code'] as String?)?.toUpperCase() == 'ADMIN';
                      final roleColor = isAdmin ? Colors.amber.shade700 : scheme.primary;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Pressable(
                          scale: 0.98,
                          onTap: () => set(() => isSelected ? selected.remove(r['id']) : selected.add(r['id'] as String)),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isSelected ? roleColor.withValues(alpha: 0.08) : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                              border: Border.all(color: isSelected ? roleColor : scheme.outlineVariant.withValues(alpha: 0.4), width: isSelected ? 1.5 : 1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: roleColor.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
                                  child: Icon(isAdmin ? Icons.shield_rounded : Icons.person_rounded, color: roleColor, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(r['name'] as String, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                      const SizedBox(height: 2),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: roleColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                                        child: Text(r['code'] as String, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: roleColor)),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                  color: isSelected ? roleColor : scheme.onSurfaceVariant,
                                  size: 26,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 10),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _run(() => api.put('/admin/users/${u['id']}/roles', {'ids': selected.toList()}), 'Đã cập nhật vai trò');
                  },
                  child: const Text('Lưu vai trò', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ],
            ),
          );
        },
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
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.access_time_rounded, size: 12, color: scheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                () {
                                  final raw = u['lastSeenAt'] as String?;
                                  final dt = raw == null ? null : DateTime.tryParse(raw)?.toLocal();
                                  return dt == null ? 'Chưa đăng nhập' : 'Đăng nhập cuối: ${Fmt.dateShort(dt)} ${Fmt.time(dt)}';
                                }(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
                              ),
                            ),
                          ],
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
    String? error;
    final ok = await showModalBottomSheet<bool>(
      sheetAnimationStyle: kSheetAnim,
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          final scheme = Theme.of(ctx).colorScheme;
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(color: scheme.outlineVariant, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                        child: Icon(Icons.person_add_alt_1_rounded, color: scheme.primary),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Thêm người dùng mới', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                            Text('Tạo tài khoản và phân quyền ban đầu', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                      IconButton(onPressed: () => Navigator.pop(ctx, false), icon: const Icon(Icons.close_rounded)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: name,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Tên hiển thị',
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: username,
                    decoration: InputDecoration(
                      labelText: 'Tên đăng nhập (chữ thường, số, _ .)',
                      prefixIcon: const Icon(Icons.alternate_email_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: password,
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu ban đầu',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      suffixIcon: IconButton(
                        tooltip: 'Tạo ngẫu nhiên',
                        onPressed: () => set(() => password.text = _randomPassword()),
                        icon: const Icon(Icons.casino_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Vai trò', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final r in roles)
                        Builder(
                          builder: (_) {
                            final isSelected = selected.contains(r['id']);
                            final isAdmin = (r['code'] as String?)?.toUpperCase() == 'ADMIN';
                            return FilterChip(
                              selected: isSelected,
                              avatar: Icon(isAdmin ? Icons.shield_rounded : Icons.person_rounded, size: 16),
                              label: Text('${r['name']} (${r['code']})'),
                              onSelected: (v) => set(() => v ? selected.add(r['id'] as String) : selected.remove(r['id'])),
                            );
                          },
                        ),
                    ],
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.expense.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                      child: Text(error!, style: const TextStyle(color: AppColors.expense, fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      if (name.text.trim().isEmpty) return set(() => error = 'Vui lòng nhập tên hiển thị');
                      if (username.text.trim().isEmpty) return set(() => error = 'Vui lòng nhập tên đăng nhập');
                      if (password.text.length < 6) return set(() => error = 'Mật khẩu tối thiểu 6 ký tự');
                      Navigator.pop(ctx, true);
                    },
                    child: const Text('Tạo người dùng', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                ],
              ),
            ),
          );
        },
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
