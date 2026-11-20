// Các yêu cầu bắt buộc của App Store:
//  - 1.2  Nội dung do người dùng tạo: báo cáo vi phạm, chặn người dùng, điều khoản không dung thứ nội dung phản cảm
//  - 5.1.1(v) Xoá tài khoản ngay trong app
//  - 5.1.1(i) Chính sách quyền riêng tư truy cập được trong app
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../data/api.dart';
import '../providers.dart';
import 'social.dart' show UserAvatar;

/// Loại nội dung bị báo cáo (khớp enum ReportTarget phía máy chủ).
abstract final class ReportTarget {
  static const post = 1, comment = 2, user = 3, message = 4;
}

/// Lý do báo cáo (khớp enum ReportReason phía máy chủ).
const reportReasons = <(int, String, IconData)>[
  (1, 'Spam / quảng cáo', Icons.campaign_rounded),
  (2, 'Quấy rối, bắt nạt', Icons.front_hand_rounded),
  (3, 'Khiêu dâm, nhạy cảm', Icons.no_adult_content_rounded),
  (4, 'Bạo lực, đe doạ', Icons.dangerous_rounded),
  (5, 'Thù ghét, phân biệt', Icons.do_not_disturb_on_rounded),
  (6, 'Lừa đảo, mạo danh', Icons.gpp_maybe_rounded),
  (99, 'Lý do khác', Icons.more_horiz_rounded),
];

String reportReasonLabel(int r) => reportReasons.firstWhere((x) => x.$1 == r, orElse: () => reportReasons.last).$2;

// ============================================================================ Báo cáo / chặn

/// Mở bảng báo cáo. Trả về true nếu đã gửi (nội dung nên được ẩn ngay với người báo cáo).
Future<bool> reportContent(BuildContext context, {required int type, required String id, String? userName}) async {
  final r = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    sheetAnimationStyle: kSheetAnim,
    builder: (_) => _ReportSheet(type: type, id: id, userName: userName),
  );
  return r == true;
}

/// Chặn người dùng (có hỏi xác nhận). Trả về true nếu đã chặn.
Future<bool> blockUser(BuildContext context, WidgetRef ref, {required String userId, required String name}) async {
  final ok = await confirm(
    context,
    'Chặn $name?',
    message:
        'Hai bạn sẽ không còn là bạn bè. Bạn sẽ không thấy bài viết, bình luận và không nhận tin nhắn từ người này. '
        'Có thể bỏ chặn trong Cài đặt → Người đã chặn.',
    ok: 'Chặn',
    danger: true,
  );
  if (!ok) return false;
  try {
    await ref.read(apiProvider).post('/blocks/$userId');
    if (context.mounted) showToast(context, 'Đã chặn $name');
    return true;
  } on ApiException catch (e) {
    if (context.mounted) showToast(context, e.message, error: true);
    return false;
  }
}

/// Bảng thao tác nhanh trên nội dung của người khác (nhấn giữ bình luận / tin nhắn): Báo cáo · Chặn.
/// Trả về true nếu nội dung nên được ẩn đi.
Future<bool> showContentActions(
  BuildContext context,
  WidgetRef ref, {
  required int type,
  required String id,
  required String userId,
  required String userName,
}) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    sheetAnimationStyle: kSheetAnim,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.flag_rounded, color: AppColors.warning),
            title: Text(switch (type) {
              ReportTarget.comment => 'Báo cáo bình luận',
              ReportTarget.message => 'Báo cáo tin nhắn',
              ReportTarget.post => 'Báo cáo bài viết',
              _ => 'Báo cáo người dùng',
            }),
            onTap: () => Navigator.pop(c, 'report'),
          ),
          ListTile(
            leading: const Icon(Icons.block_rounded, color: AppColors.expense),
            title: Text('Chặn $userName'),
            onTap: () => Navigator.pop(c, 'block'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (!context.mounted || action == null) return false;
  return action == 'report' ? reportContent(context, type: type, id: id, userName: userName) : blockUser(context, ref, userId: userId, name: userName);
}

class _ReportSheet extends ConsumerStatefulWidget {
  const _ReportSheet({required this.type, required this.id, this.userName});
  final int type;
  final String id;
  final String? userName;

  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  int? reason;
  bool block = false;
  bool sending = false;
  final note = TextEditingController();

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (reason == null) return;
    setState(() => sending = true);
    try {
      await ref.read(apiProvider).post('/reports', {
        'targetType': widget.type,
        'targetId': widget.id,
        'reason': reason,
        'note': note.text.trim(),
        'block': block,
      });
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      showToast(context, 'Đã gửi báo cáo. Chúng tôi sẽ xem xét trong vòng 24 giờ.');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => sending = false);
        showToast(context, e.message, error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final what = switch (widget.type) {
      ReportTarget.post => 'bài viết',
      ReportTarget.comment => 'bình luận',
      ReportTarget.message => 'tin nhắn',
      _ => 'người dùng',
    };
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Báo cáo $what', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Báo cáo được gửi ẩn danh tới quản trị viên. Nội dung sẽ được ẩn ngay với bạn.', style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (v, label, icon) in reportReasons)
                ChoiceChip(
                  avatar: Icon(icon, size: 16),
                  label: Text(label),
                  selected: reason == v,
                  onSelected: (_) {
                    HapticFeedback.selectionClick();
                    setState(() => reason = v);
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: note,
            maxLines: 3,
            minLines: 1,
            maxLength: 1000,
            decoration: const InputDecoration(hintText: 'Mô tả thêm (không bắt buộc)', counterText: ''),
          ),
          if (widget.userName != null && widget.type != ReportTarget.user)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: block,
              onChanged: (v) => setState(() => block = v ?? false),
              title: Text('Chặn luôn ${widget.userName}'),
              subtitle: const Text('Không thấy nội dung và không nhận tin nhắn từ người này'),
            ),
          if (widget.type == ReportTarget.user)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: block,
              onChanged: (v) => setState(() => block = v ?? false),
              title: const Text('Chặn người dùng này'),
            ),
          const SizedBox(height: 8),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48), backgroundColor: AppColors.expense),
            onPressed: reason == null || sending ? null : _send,
            icon: sending
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.flag_rounded),
            label: const Text('Gửi báo cáo'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================ Người đã chặn

class BlockedUsersPage extends ConsumerStatefulWidget {
  const BlockedUsersPage({super.key});

  @override
  ConsumerState<BlockedUsersPage> createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends ConsumerState<BlockedUsersPage> {
  List<Map<String, dynamic>>? users;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ref.read(apiProvider).get<List<dynamic>>('/blocks');
      if (mounted) setState(() => users = r.cast<Map<String, dynamic>>());
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => users = []);
        showToast(context, e.message, error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Người đã chặn')),
    body: users == null
        ? const SkeletonList()
        : users!.isEmpty
        ? const EmptyState(
            icon: Icons.verified_user_rounded,
            title: 'Bạn chưa chặn ai',
            subtitle: 'Chặn từ menu ⋯ của bài viết, bình luận, tin nhắn hoặc bạn bè',
          )
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final (i, u) in users!.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        UserAvatar(u),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(u['displayName'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text('@${u['username']}', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        OutlinedButton(
                          onPressed: () async {
                            await ref.read(apiProvider).delete('/blocks/${u['id']}');
                            if (!context.mounted) return;
                            showToast(context, 'Đã bỏ chặn ${u['displayName']}');
                            setState(() => users!.remove(u));
                          },
                          child: const Text('Bỏ chặn'),
                        ),
                      ],
                    ),
                  ).stagger(i),
                ),
            ],
          ),
  );
}

// ============================================================================ Xoá tài khoản

class DeleteAccountPage extends ConsumerStatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  ConsumerState<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends ConsumerState<DeleteAccountPage> {
  final password = TextEditingController();
  bool understood = false;
  bool busy = false;
  bool hide = true;
  String? error;

  @override
  void dispose() {
    password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      'Xoá vĩnh viễn tài khoản?',
      message: 'Toàn bộ dữ liệu sẽ bị xoá khỏi máy chủ và thiết bị này. Không thể khôi phục.',
      ok: 'Xoá vĩnh viễn',
      danger: true,
    );
    if (!ok || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.read(sessionProvider).deleteAccount(password.text);
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      showToast(context, 'Đã xoá tài khoản và toàn bộ dữ liệu');
      context.go('/');
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = e.message.contains('Mật khẩu') || e.code == 'VALIDATION_ERROR' ? 'Mật khẩu không đúng' : e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = ref.watch(sessionProvider).user;
    Widget item(IconData icon, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.expense),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Xoá tài khoản')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            gradient: LinearGradient(colors: [AppColors.expense.withValues(alpha: 0.18), AppColors.expense.withValues(alpha: 0.05)]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: AppColors.expense, size: 28),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text('Thao tác không thể hoàn tác', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text('Tài khoản ${user?['displayName'] ?? ''} (@${user?['username'] ?? ''}) và những dữ liệu sau sẽ bị xoá vĩnh viễn:'),
                const SizedBox(height: 6),
                item(Icons.account_balance_wallet_rounded, 'Giao dịch, tài khoản tiền, danh mục, định mức, hũ tiết kiệm'),
                item(Icons.event_rounded, 'Lịch trình, hoạt động, ảnh lịch trình'),
                item(Icons.favorite_rounded, 'Ngày yêu, chu kỳ, tiền điện, cài đặt'),
                item(Icons.dynamic_feed_rounded, 'Bài viết, bạn bè; nội dung bình luận và tin nhắn bạn đã gửi'),
                item(Icons.photo_library_rounded, 'Mọi ảnh bạn đã tải lên'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: password,
            obscureText: hide,
            autofillHints: const [AutofillHints.password],
            onChanged: (_) => setState(() => error = null),
            decoration: InputDecoration(
              labelText: 'Nhập mật khẩu để xác nhận',
              prefixIcon: const Icon(Icons.lock_rounded),
              errorText: error,
              suffixIcon: IconButton(onPressed: () => setState(() => hide = !hide), icon: Icon(hide ? Icons.visibility_rounded : Icons.visibility_off_rounded)),
            ),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: understood,
            onChanged: (v) => setState(() => understood = v ?? false),
            title: const Text('Tôi hiểu dữ liệu sẽ bị xoá vĩnh viễn và không thể khôi phục'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: AppColors.expense, foregroundColor: Colors.white),
            onPressed: understood && password.text.isNotEmpty && !busy ? _delete : null,
            icon: busy
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.delete_forever_rounded),
            label: const Text('Xoá vĩnh viễn tài khoản'),
          ),
          const SizedBox(height: 12),
          Text(
            'Chỉ muốn ngừng đồng bộ? Hãy dùng "Đăng xuất" — dữ liệu trên máy chủ vẫn được giữ.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ============================================================================ Chính sách / điều khoản

/// Trang Chính sách quyền riêng tư / Điều khoản sử dụng (cùng nội dung với trang web /privacy.html, /terms.html).
class LegalPage extends StatelessWidget {
  const LegalPage({super.key, required this.doc});

  /// 'privacy' hoặc 'terms'
  final String doc;

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
    future: rootBundle.loadString('assets/legal/legal.json'),
    builder: (context, snap) {
      if (!snap.hasData) return Scaffold(appBar: AppBar(), body: const SkeletonList());
      final all = jsonDecode(snap.data!) as Map<String, dynamic>;
      final d = all[doc] as Map<String, dynamic>;
      String fill(String s) => s.replaceAll('{contact}', all['contact'] as String);
      final scheme = Theme.of(context).colorScheme;
      return Scaffold(
        appBar: AppBar(title: Text(d['title'] as String)),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            Text('${all['appName']} · Cập nhật ${all['updated']}', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 10),
            AppCard(child: Text(fill(d['intro'] as String), style: const TextStyle(height: 1.45))),
            for (final (i, s) in (d['sections'] as List).cast<Map<String, dynamic>>().indexed)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s['title'] as String,
                        style: TextStyle(fontWeight: FontWeight.w800, color: scheme.primary),
                      ),
                      const SizedBox(height: 6),
                      Text(fill(s['body'] as String), style: const TextStyle(height: 1.45)),
                    ],
                  ),
                ).stagger(i),
              ),
          ],
        ),
      );
    },
  );
}

// ============================================================================ Quản trị: xử lý báo cáo

class AdminReportsPage extends ConsumerStatefulWidget {
  const AdminReportsPage({super.key});

  @override
  ConsumerState<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends ConsumerState<AdminReportsPage> {
  List<Map<String, dynamic>>? items;
  bool open = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ref.read(apiProvider).get<List<dynamic>>('/admin/reports', query: open ? {'status': 1} : null);
      final list = r.cast<Map<String, dynamic>>();
      if (mounted) setState(() => items = open ? list : list.where((x) => x['status'] != 1).toList());
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => items = []);
        showToast(context, e.message, error: true);
      }
    }
  }

  Future<void> _resolve(Map<String, dynamic> r, bool remove) async {
    try {
      await ref.read(apiProvider).post('/admin/reports/${r['id']}/resolve', {'remove': remove});
      if (!mounted) return;
      showToast(context, remove ? 'Đã gỡ nội dung' : 'Đã bỏ qua báo cáo');
      await _load();
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Báo cáo vi phạm'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: PillToggle<bool>(
              value: open,
              values: const [true, false],
              icons: const [Icons.pending_actions_rounded, Icons.task_alt_rounded],
              labels: const ['Chờ', 'Đã xử lý'],
              onChanged: (v) {
                setState(() {
                  open = v;
                  items = null;
                });
                _load();
              },
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: items == null
            ? const SkeletonList()
            : items!.isEmpty
            ? ListView(
                children: [EmptyState(icon: Icons.verified_rounded, title: open ? 'Không có báo cáo nào chờ xử lý' : 'Chưa có báo cáo đã xử lý')],
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final (i, r) in items!.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: AppColors.expense.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                                  child: Text(
                                    reportReasonLabel(r['reason'] as int),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.expense),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(switch (r['targetType']) {
                                  1 => 'Bài viết',
                                  2 => 'Bình luận',
                                  4 => 'Tin nhắn',
                                  _ => 'Người dùng',
                                }, style: const TextStyle(fontWeight: FontWeight.w700)),
                                const Spacer(),
                                Text(
                                  Fmt.relative(DateTime.parse(r['createdAt'] as String).toLocal()),
                                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                            if (r['preview'] != null && (r['preview'] as String).isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: scheme.surfaceContainerHighest.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(8)),
                                child: Text(r['preview'] as String, maxLines: 4, overflow: TextOverflow.ellipsis),
                              ),
                            ],
                            if (r['note'] != null) ...[
                              const SizedBox(height: 6),
                              Text('Ghi chú: ${r['note']}', style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
                            ],
                            const SizedBox(height: 6),
                            Text(
                              '${(r['reporter'] as Map)['displayName']} báo cáo ${(r['targetUser'] as Map?)?['displayName'] ?? '?'}'
                              '${r['status'] == 2
                                  ? ' · đã gỡ'
                                  : r['status'] == 3
                                  ? ' · đã bỏ qua'
                                  : ''}',
                              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                            ),
                            if (r['status'] == 1) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(onPressed: () => _resolve(r, false), child: const Text('Bỏ qua')),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: FilledButton(
                                      style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
                                      onPressed: () => _resolve(r, true),
                                      child: Text(r['targetType'] == ReportTarget.user ? 'Đã xử lý' : 'Gỡ nội dung'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ).stagger(i),
                    ),
                ],
              ),
      ),
    );
  }
}
