import 'dart:async';
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../data/api.dart';
import '../data/local_store.dart';
import '../data/logic.dart';
import '../data/models.dart';
import '../providers.dart';
import 'common.dart';
import 'moderation.dart';

/// Màu đại diện cố định theo tên (để mỗi người một màu, lần nào cũng giống nhau).
Color avatarColor(String name) => AppColors.autoPalette[name.hashCode.abs() % AppColors.autoPalette.length];

/// Ảnh đại diện người dùng: nền gradient theo tên + chấm online.
class UserAvatar extends ConsumerWidget {
  const UserAvatar(this.user, {super.key, this.radius = 20, this.ring = false});
  final Map<String, dynamic> user;
  final double radius;

  /// Viền gradient quanh ảnh (dùng cho dải "đang hoạt động").
  final bool ring;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = user['isOnline'] == true || ref.watch(realtimeProvider).online.contains(user['id']);
    final name = (user['displayName'] as String?) ?? '?';
    final isPartner = user['id'] != null && user['id'] == myPartnerId(ref);
    final fid = user['avatarFileId'] as String?;
    final scheme = Theme.of(context).colorScheme;
    final c = avatarColor(name);
    Widget avatar = Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c, Color.lerp(c, Colors.black, 0.35)!]),
      ),
      alignment: Alignment.center,
      child: fid == null
          ? Text(
              name.characters.isEmpty ? '?' : name.characters.first.toUpperCase(),
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: radius * 0.85, color: Colors.white),
            )
          : ClipOval(
              child: SizedBox(width: radius * 2, height: radius * 2, child: FileImage2(fid, radius: 0)),
            ),
    );
    if (ring) {
      avatar = Container(
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: online ? [AppColors.income, scheme.primary] : [scheme.outlineVariant, scheme.outlineVariant]),
        ),
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(shape: BoxShape.circle, color: scheme.surface),
          child: avatar,
        ),
      );
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        if (isPartner)
          Positioned(
            right: ring ? 2 : -3,
            top: ring ? 2 : -3,
            child: Container(
              padding: EdgeInsets.all(radius * 0.08),
              decoration: BoxDecoration(color: scheme.surface, shape: BoxShape.circle),
              child: Icon(Icons.favorite_rounded, size: (radius * 0.55).clamp(10, 20), color: AppColors.love),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(begin: 0.9, end: 1.1, duration: 900.ms, curve: Curves.easeInOut),
          ),
        Positioned(
          right: ring ? 4 : 0,
          bottom: ring ? 4 : 0,
          child: AnimatedScale(
            scale: online ? 1 : 0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            child: Container(
              width: radius * 0.55,
              height: radius * 0.55,
              decoration: BoxDecoration(
                color: AppColors.income,
                shape: BoxShape.circle,
                border: Border.all(color: scheme.surface, width: 2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Ô tìm kiếm bo tròn dùng chung cho tin nhắn / bạn bè.
class PillSearchField extends StatelessWidget {
  const PillSearchField({super.key, required this.hint, required this.onChanged, this.controller});
  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none);
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        isDense: true,
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        contentPadding: const EdgeInsets.symmetric(vertical: 11),
        border: border,
        enabledBorder: border,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: scheme.primary, width: 1.2),
        ),
      ),
    );
  }
}

/// Thanh tab dạng viên thuốc (thay cho TabBar gạch chân).
PreferredSizeWidget pillTabBar(BuildContext context, List<Widget> tabs) {
  final scheme = Theme.of(context).colorScheme;
  return PreferredSize(
    preferredSize: const Size.fromHeight(56),
    child: Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(14)),
      child: TabBar(
        tabs: tabs,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(16)),
        labelColor: scheme.onPrimary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        splashBorderRadius: BorderRadius.circular(16),
        labelPadding: EdgeInsets.zero,
      ),
    ),
  );
}

Widget loginRequired(BuildContext context) => EmptyState(
  icon: Icons.lock_outline_rounded,
  title: 'Cần đăng nhập',
  subtitle: 'Đăng nhập để dùng bảng tin, bạn bè và tin nhắn',
  action: FilledButton(onPressed: () => context.push('/login'), child: const Text('Đăng nhập')),
);

/// Id tài khoản người yêu (đã xác nhận hai chiều), null nếu chưa có.
String? myPartnerId(WidgetRef ref) => ref.watch(coupleProvider).partnerId;

Future<void> _coupleCall(BuildContext context, Future<void> Function() f, String ok) async {
  try {
    await f();
    HapticFeedback.mediumImpact();
    if (context.mounted) showToast(context, ok);
  } on ApiException catch (e) {
    if (context.mounted) showToast(context, e.message, error: true);
  }
}

/// Mời một người bạn làm người yêu (cần người đó xác nhận), hoặc [user] = null để huỷ liên kết / huỷ lời mời hiện tại.
Future<void> setPartner(BuildContext context, WidgetRef ref, Map<String, dynamic>? user) async {
  final couple = ref.read(coupleProvider);
  if (user == null) {
    final other = couple.partner ?? (couple.outgoing?['user'] as Map?)?.cast<String, dynamic>();
    if (other == null) return;
    final isPartner = couple.partner != null;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        icon: Icon(isPartner ? Icons.heart_broken_rounded : Icons.close_rounded, color: AppColors.love, size: 36),
        title: Text(isPartner ? 'Huỷ liên kết với ${other['displayName']}?' : 'Huỷ lời mời gửi ${other['displayName']}?'),
        content: Text(isPartner ? 'Cả hai sẽ không còn thấy nhau là người yêu. Dữ liệu "Ngày yêu" vẫn được giữ.' : 'Người ấy sẽ không thấy lời mời nữa.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Không')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.expense, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(d, true),
            child: Text(isPartner ? 'Huỷ liên kết' : 'Huỷ lời mời'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted)
      await _coupleCall(context, () => couple.end(other['id'] as String), isPartner ? 'Đã huỷ liên kết người yêu' : 'Đã huỷ lời mời');
    return;
  }
  final name = user['displayName'] as String? ?? '';
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      icon: const Icon(Icons.favorite_rounded, color: AppColors.love, size: 36),
      title: Text('Mời $name làm người yêu?'),
      content: Text('$name sẽ nhận được lời mời. Khi $name đồng ý, cả hai sẽ thấy nhau là người yêu ❤️ và "Ngày yêu" được liên kết tự động.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Huỷ')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.love, foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(d, true),
          child: const Text('Gửi lời mời'),
        ),
      ],
    ),
  );
  if (ok == true && context.mounted) await _coupleCall(context, () => couple.request(user['id'] as String), 'Đã gửi lời mời, chờ $name xác nhận ❤️');
}

/// Chấp nhận / từ chối lời mời làm người yêu.
Future<void> answerCouple(BuildContext context, WidgetRef ref, Map<String, dynamic> user, bool accept) => _coupleCall(
  context,
  () => accept ? ref.read(coupleProvider).accept(user['id'] as String) : ref.read(coupleProvider).end(user['id'] as String),
  accept ? 'Hai bạn đã chính thức là một đôi ❤️' : 'Đã từ chối lời mời',
);

/// Thẻ lời mời làm người yêu (dùng ở tab Lời mời và màn Ngày yêu).
class CoupleInviteCard extends StatelessWidget {
  const CoupleInviteCard({super.key, required this.user, required this.onAnswer});
  final Map<String, dynamic> user;
  final void Function(bool accept) onAnswer;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(14),
    gradient: LinearGradient(colors: [AppColors.love.withValues(alpha: 0.25), AppColors.love.withValues(alpha: 0.06)]),
    child: Column(
      children: [
        Row(
          children: [
            UserAvatar(user, radius: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user['displayName'] as String, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  const Text('muốn xác nhận hai bạn là người yêu ❤️', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(onPressed: () => onAnswer(false), child: const Text('Từ chối')),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.love, foregroundColor: Colors.white),
                onPressed: () => onAnswer(true),
                icon: const Icon(Icons.favorite_rounded, size: 18),
                label: const Text('Đồng ý'),
              ),
            ),
          ],
        ),
      ],
    ),
  ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(0.97, 0.97));
}

/// Bảng chọn người yêu trong danh sách bạn bè.
Future<Map<String, dynamic>?> pickFriend(BuildContext context, WidgetRef ref, {String title = 'Chọn người yêu trong bạn bè'}) async {
  List<Map<String, dynamic>> friends;
  try {
    friends = (await ref.read(apiProvider).get<List<dynamic>>('/friends')).cast<Map<String, dynamic>>();
  } on ApiException catch (e) {
    if (context.mounted) showToast(context, e.message, error: true);
    return null;
  }
  if (!context.mounted) return null;
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      maxChildSize: 0.9,
      builder: (ctx, sc) => ListView(
        controller: sc,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          if (friends.isEmpty) const EmptyState(icon: Icons.group_rounded, title: 'Chưa có bạn bè', subtitle: 'Kết bạn với người ấy trước nhé'),
          for (final (i, f) in friends.indexed)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: UserAvatar(f, radius: 22),
              title: Text(f['displayName'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('@${f['username']}'),
              trailing: const Icon(Icons.favorite_border_rounded, color: AppColors.love),
              onTap: () => Navigator.pop(ctx, f),
            ).stagger(i),
        ],
      ),
    ),
  );
}

const reactionEmoji = {1: '👍', 2: '❤️', 3: '😆', 4: '😮', 5: '😢', 6: '😡'};

// ========================================================================= Bảng tin

class FeedPage extends ConsumerStatefulWidget {
  const FeedPage({super.key});

  @override
  ConsumerState<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends ConsumerState<FeedPage> with PagedPosts<FeedPage> {
  StreamSubscription? _sub;
  StreamSubscription? _sentSub;

  @override
  String get postsPath => '/posts/feed';

  @override
  void initState() {
    super.initState();
    final cached = ref.read(storeProvider).meta('feedCache');
    if (cached != null) posts = (jsonDecode(cached) as List).cast<Map<String, dynamic>>();
    loadPosts(reset: true);
    _sub = ref.read(realtimeProvider).events.listen((e) {
      if (e.method == 'PostCreated' && mounted) prependPost(e.data as Map<String, dynamic>);
    });
    _sentSub = ref.read(syncProvider).outboxSent.listen((s) {
      if (s.kind == 'post' && mounted) prependPost(s.result as Map<String, dynamic>);
    });
  }

  @override
  void onFirstPage(List<Map<String, dynamic>> items) => ref.read(storeProvider).setMeta('feedCache', jsonEncode(items));

  @override
  void dispose() {
    _sub?.cancel();
    _sentSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    if (!session.isLoggedIn)
      return Scaffold(
        appBar: AppBar(title: const Text('Bảng tin')),
        body: loginRequired(context),
      );
    final pending = ref.watch(storeProvider).outbox().where((o) => o.kind == 'post').toList();
    // Danh sách dựng LƯỜI: chỉ bài đang thấy (± vùng đệm) mới được dựng → cuộn mượt dù có hàng trăm bài.
    final head = <Widget>[
      if (offline)
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text('⚠️ Đang offline — hiển thị bài viết đã lưu', textAlign: TextAlign.center),
        ),
      for (final p in pending)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppCard(
            child: Row(
              children: [
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 12),
                Expanded(child: Text('Đang chờ đăng: ${p.payload['content'] ?? '(ảnh)'}', maxLines: 2, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
        ),
      if (posts.isEmpty && !loading && loadedOnce)
        const EmptyState(icon: Icons.dynamic_feed_rounded, title: 'Chưa có bài viết', subtitle: 'Kết bạn và chia sẻ khoảnh khắc đầu tiên'),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bảng tin'),
        actions: [
          IconButton(onPressed: () => context.push('/friends'), icon: const Icon(Icons.group_add_rounded)),
          Padding(
            padding: const EdgeInsets.only(right: 12, left: 4),
            child: Pressable(onTap: () => openProfile(context, session.user ?? {}), child: UserAvatar(session.user ?? {}, radius: 17)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(onPressed: () => context.push('/feed/compose'), child: const Icon(Icons.edit_rounded)),
      body: RefreshIndicator(onRefresh: () => loadPosts(reset: true), child: postList(context, head)),
    );
  }
}

/// Danh sách bài viết tải theo trang: kéo gần cuối → tự tải trang tiếp. Dựng lười nên cuộn mượt.
mixin PagedPosts<W extends ConsumerStatefulWidget> on ConsumerState<W> {
  static const pageSize = 10;
  List<Map<String, dynamic>> posts = [];
  String? cursor;
  bool loading = false;
  bool offline = false;
  bool error = false;

  /// Đã tải ít nhất 1 trang từ server (phân biệt "đang hiện cache" với "hết bài").
  bool loadedOnce = false;

  String get postsPath;
  void onFirstPage(List<Map<String, dynamic>> items) {}
  bool get hasMore => cursor != null;

  void prependPost(Map<String, dynamic> p) {
    if (posts.any((x) => x['id'] == p['id'])) return;
    setState(() => posts.insert(0, p));
  }

  Future<void> loadPosts({bool reset = false}) async {
    if (!ref.read(sessionProvider).isLoggedIn || loading) return;
    if (!reset && !hasMore) return;
    setState(() {
      loading = true;
      error = false;
    });
    try {
      final r = await ref.read(apiProvider).get<Map<String, dynamic>>(postsPath, query: {if (!reset && cursor != null) 'before': cursor, 'limit': pageSize});
      final items = (r['items'] as List).cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() {
        if (reset) {
          posts = items;
        } else {
          final seen = {for (final p in posts) p['id']};
          posts = [...posts, ...items.where((p) => !seen.contains(p['id']))];
        }
        cursor = r['nextCursor'] as String?;
        offline = false;
        loadedOnce = true;
      });
      if (reset) onFirstPage(items);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          offline = e.offline;
          error = !e.offline;
        });
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  /// Gần tới cuối danh sách → tải trang tiếp (sau frame để không setState khi đang dựng).
  void _maybeLoadMore() {
    if (loading || !hasMore || error) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) loadPosts();
    });
  }

  Widget _footer(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (loading) {
      return Column(
        children: [for (var i = 0; i < (posts.isEmpty ? 3 : 1); i++) const Padding(padding: EdgeInsets.only(bottom: 12), child: _PostSkeleton())],
      );
    }
    if (error) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: FilledButton.tonalIcon(onPressed: loadPosts, icon: const Icon(Icons.refresh_rounded), label: const Text('Tải lại')),
        ),
      );
    }
    if (loadedOnce && !hasMore && posts.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Row(
          children: [
            Expanded(child: Divider(color: scheme.outlineVariant.withValues(alpha: 0.5))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded, size: 16, color: scheme.primary),
                  const SizedBox(width: 6),
                  Text('Đã xem hết bài viết', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            Expanded(child: Divider(color: scheme.outlineVariant.withValues(alpha: 0.5))),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  /// [head]: các khối phía trên danh sách bài (banner, thẻ hồ sơ...).
  Widget postList(BuildContext context, List<Widget> head) => ListView.builder(
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
    physics: const AlwaysScrollableScrollPhysics(),
    cacheExtent: 800,
    itemCount: head.length + posts.length + 1,
    itemBuilder: (context, i) {
      if (i < head.length) return head[i];
      final k = i - head.length;
      if (k == posts.length) return _footer(context);
      // Còn ~3 bài nữa là hết → tải trước trang sau, gần như không phải chờ.
      if (k >= posts.length - 3) _maybeLoadMore();
      final p = posts[k];
      return PostCard(
        key: ValueKey(p['id']),
        post: p,
        onChanged: (np) => setState(() {
          final at = posts.indexWhere((x) => x['id'] == np['id']);
          if (at >= 0) posts[at] = np;
        }),
        onDeleted: () => setState(() => posts.removeWhere((x) => x['id'] == p['id'])),
      ).stagger(k % pageSize);
    },
  );
}

void openProfile(BuildContext context, Map<String, dynamic> user) {
  if (user['id'] == null) return;
  HapticFeedback.selectionClick();
  context.push('/profile', extra: {'user': user});
}

/// Trang cá nhân: thông tin người dùng + các bài họ đã đăng (tải theo trang).
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key, required this.user});
  final Map<String, dynamic> user;

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> with PagedPosts<ProfilePage> {
  @override
  String get postsPath => '/posts/user/${widget.user['id']}';

  @override
  void initState() {
    super.initState();
    loadPosts(reset: true);
  }

  Future<void> _chat() async {
    try {
      final c = await ref.read(apiProvider).post<Map<String, dynamic>>('/conversations/direct', {'userId': widget.user['id']});
      if (mounted) context.push('/chat/room', extra: c);
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final scheme = Theme.of(context).colorScheme;
    final isMe = u['id'] == ref.watch(sessionProvider).userId;
    final isPartner = u['id'] == myPartnerId(ref);
    final online = u['isOnline'] == true || ref.watch(realtimeProvider).online.contains(u['id']);
    final name = u['displayName'] as String? ?? '';
    final base = isPartner ? AppColors.love : avatarColor(name);
    final photos = posts.fold(0, (s, p) => s + ((p['photoFileIds'] as List?)?.length ?? 0));
    final likes = posts.fold(0, (s, p) => s + ((p['reactionCount'] as num?)?.toInt() ?? 0));

    Widget stat(String value, String label) => Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
        ],
      ),
    );

    final header = Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [heroOf(base), heroOf(accentOf(base, hue: 30))]),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: [BoxShadow(color: base.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2.5),
              ),
              child: UserAvatar(u, radius: 44),
            ).animate().scaleXY(begin: 0.8, end: 1, duration: 450.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 10),
            Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                if (u['username'] != null) _ProfileChip(text: '@${u['username']}'),
                if (isPartner) const _ProfileChip(text: '❤️ Người yêu'),
                if (online) const _ProfileChip(text: '● Đang hoạt động', color: Color(0xFF7CF0B0)),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(AppRadius.md)),
              child: Row(
                children: [
                  stat('${posts.length}${hasMore ? '+' : ''}', 'Bài viết'),
                  stat('$photos${hasMore ? '+' : ''}', 'Ảnh'),
                  stat('$likes${hasMore ? '+' : ''}', 'Lượt thích'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: heroOf(base), minimumSize: const Size.fromHeight(46)),
                onPressed: isMe ? () => context.push('/feed/compose') : _chat,
                icon: Icon(isMe ? Icons.edit_rounded : Icons.chat_bubble_rounded, size: 18),
                label: Text(isMe ? 'Viết bài mới' : 'Nhắn tin', style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(isMe ? 'Trang của tôi' : name)),
      body: RefreshIndicator(
        onRefresh: () => loadPosts(reset: true),
        child: postList(context, [
          header,
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Text(
              'Bài viết',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: scheme.onSurface),
            ),
          ),
          if (offline)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('⚠️ Đang offline', textAlign: TextAlign.center),
            ),
          if (posts.isEmpty && !loading && loadedOnce)
            EmptyState(
              icon: Icons.article_outlined,
              title: 'Chưa có bài viết',
              subtitle: isMe ? 'Chia sẻ khoảnh khắc đầu tiên của bạn' : '$name chưa đăng bài nào bạn xem được',
            ),
        ]),
      ),
    );
  }
}

class _ProfileChip extends StatelessWidget {
  const _ProfileChip({required this.text, this.color = Colors.white});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(99)),
    child: Text(
      text,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
    ),
  );
}

/// Khung xương của một bài viết khi đang tải trang (nhấp nháy nhẹ).
class _PostSkeleton extends StatelessWidget {
  const _PostSkeleton();

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08);
    Widget bar(double w, double h) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(8)),
    );
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [bar(140, 12), const SizedBox(height: 6), bar(90, 10)]),
            ],
          ),
          const SizedBox(height: 14),
          bar(double.infinity, 12),
          const SizedBox(height: 8),
          bar(220, 12),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    ).animate(onPlay: (a) => a.repeat(reverse: true)).fade(begin: 0.55, end: 1, duration: 800.ms);
  }
}

class PostCard extends ConsumerWidget {
  const PostCard({super.key, required this.post, required this.onChanged, required this.onDeleted});
  final Map<String, dynamic> post;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final VoidCallback onDeleted;

  Future<void> _react(BuildContext context, WidgetRef ref, int? kind) async {
    HapticFeedback.lightImpact();
    final api = ref.read(apiProvider);
    try {
      final r = kind == null
          ? await api.delete<Map<String, dynamic>>('/posts/${post['id']}/reactions')
          : await api.post<Map<String, dynamic>>('/posts/${post['id']}/reactions', {'kind': kind});
      onChanged(r);
    } on ApiException catch (e) {
      if (context.mounted) showToast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final author = (post['author'] as Map).cast<String, dynamic>();
    final photos = (post['photoFileIds'] as List).cast<String>();
    final event = post['event'] as Map<String, dynamic>?;
    final mine = post['myReaction'] as int?;
    final isMe = author['id'] == ref.read(sessionProvider).userId;
    final tagged = (post['tagged'] as List).cast<Map<String, dynamic>>();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Pressable(onTap: () => openProfile(context, author), child: UserAvatar(author)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: author['displayName'] as String,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                              recognizer: TapGestureRecognizer()..onTap = () => openProfile(context, author),
                            ),
                            if (post['feeling'] != null) TextSpan(text: ' đang cảm thấy ${post['feeling']}'),
                            if (tagged.isNotEmpty) TextSpan(text: ' cùng ${tagged.map((t) => t['displayName']).join(', ')}'),
                          ],
                        ),
                      ),
                      Text(
                        '${Fmt.relative(DateTime.parse(post['createdAt'] as String).toLocal())}'
                        '${post['location'] != null ? ' · 📍 ${post['location']}' : ''} · ${switch (post['visibility']) {
                          2 => '🔒',
                          3 => '👥',
                          _ => '🌐',
                        }}',
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (isMe)
                  PopupMenuButton(
                    itemBuilder: (_) => [const PopupMenuItem(value: 'del', child: Text('Xoá bài viết'))],
                    onSelected: (_) async {
                      if (await confirm(context, 'Xoá bài viết?', danger: true, ok: 'Xoá')) {
                        await ref.read(apiProvider).delete('/posts/${post['id']}');
                        onDeleted();
                      }
                    },
                  )
                else
                  // Bài của người khác: báo cáo / chặn (ẩn ngay khỏi bảng tin của mình)
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_horiz_rounded, color: scheme.onSurfaceVariant),
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'report',
                        child: Row(
                          children: [
                            Icon(Icons.flag_rounded, size: 20, color: AppColors.warning),
                            SizedBox(width: 10),
                            Text('Báo cáo bài viết'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'block',
                        child: Row(
                          children: [
                            const Icon(Icons.block_rounded, size: 20, color: AppColors.expense),
                            const SizedBox(width: 10),
                            Text('Chặn ${author['displayName']}'),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (v) async {
                      final hide = v == 'report'
                          ? await reportContent(context, type: ReportTarget.post, id: post['id'] as String, userName: author['displayName'] as String)
                          : await blockUser(context, ref, userId: author['id'] as String, name: author['displayName'] as String);
                      if (hide) onDeleted();
                    },
                  ),
              ],
            ),
            if ((post['content'] as String?)?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(post['content'] as String, style: const TextStyle(fontSize: 15)),
              ),
            if (photos.isNotEmpty) ...[const SizedBox(height: 10), _PhotoMosaic(ids: photos)],
            if (event != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: scheme.primaryContainer.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Icon(Icons.event_rounded),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${event['title']} · ${Fmt.date(DateTime.parse(event['startAt'] as String).toLocal())}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                if ((post['reactionCount'] as int) > 0) Text('${reactionEmoji[mine] ?? '👍'} ${post['reactionCount']}', style: const TextStyle(fontSize: 13)),
                const Spacer(),
                if ((post['commentCount'] as int) > 0) Text('${post['commentCount']} bình luận', style: const TextStyle(fontSize: 13)),
              ],
            ),
            const Divider(height: 12),
            Row(
              children: [
                Expanded(
                  child: Pressable(
                    onTap: () => _react(context, ref, mine == null ? 1 : null),
                    onLongPress: () async {
                      final k = await showModalBottomSheet<int>(
                        sheetAnimationStyle: kSheetAnim,
                        context: context,
                        builder: (c) => SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                for (final e in reactionEmoji.entries)
                                  Pressable(
                                    onTap: () => Navigator.pop(c, e.key),
                                    child: Text(e.value, style: const TextStyle(fontSize: 34)),
                                  ).animate().scale(delay: (40 * e.key).ms, duration: 250.ms, curve: Curves.easeOutBack),
                              ],
                            ),
                          ),
                        ),
                      );
                      if (k != null && context.mounted) _react(context, ref, k);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                            child: mine == null
                                ? const Icon(Icons.thumb_up_outlined, key: ValueKey('none'), size: 20)
                                : Text(reactionEmoji[mine]!, key: ValueKey(mine), style: const TextStyle(fontSize: 18)),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            mine == null ? 'Thích' : 'Đã bày tỏ',
                            style: TextStyle(fontWeight: FontWeight.w600, color: mine == null ? null : scheme.primary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Pressable(
                    onTap: () => _comments(context, ref),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded, size: 20),
                          SizedBox(width: 6),
                          Text('Bình luận', style: TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void openComments(BuildContext context, WidgetRef ref) => _comments(context, ref);

  void _comments(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      sheetAnimationStyle: kSheetAnim,
      context: context,
      isScrollControlled: true,
      builder: (c) => _CommentsSheet(postId: post['id'] as String, onAdded: () => onChanged({...post, 'commentCount': (post['commentCount'] as int) + 1})),
    );
  }
}

class _PhotoMosaic extends StatelessWidget {
  const _PhotoMosaic({required this.ids});
  final List<String> ids;

  @override
  Widget build(BuildContext context) {
    Widget tile(int i, {double? h}) => Pressable(
      onTap: () => openGallery(context, ids, i),
      child: SizedBox(
        height: h,
        child: Hero(tag: 'photo-${ids[i]}', child: FileImage2(ids[i], radius: 10)),
      ),
    );
    if (ids.length == 1) return AspectRatio(aspectRatio: 4 / 3, child: tile(0));
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      children: [
        for (var i = 0; i < ids.length && i < 4; i++)
          i == 3 && ids.length > 4
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    tile(i),
                    IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(12)),
                        alignment: Alignment.center,
                        child: Text(
                          '+${ids.length - 4}',
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                )
              : tile(i),
      ],
    );
  }
}

class _CommentsSheet extends ConsumerStatefulWidget {
  const _CommentsSheet({required this.postId, required this.onAdded});
  final String postId;
  final VoidCallback onAdded;

  @override
  ConsumerState<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<_CommentsSheet> {
  // Giải phóng tài nguyên khi đóng màn (tránh tích tụ khi mở/đóng nhiều lần)
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>>? items;
  final text = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await ref.read(apiProvider).get<List<dynamic>>('/posts/${widget.postId}/comments');
    if (mounted) setState(() => items = r.cast<Map<String, dynamic>>());
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
    child: SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          const Text('Bình luận', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
          Expanded(
            child: items == null
                ? const SkeletonList()
                : ListView(
                    children: [
                      for (final (i, c) in items!.indexed)
                        ListTile(
                          onLongPress: (c['author'] as Map)['id'] == ref.read(sessionProvider).userId
                              ? null
                              : () async {
                                  final a = (c['author'] as Map).cast<String, dynamic>();
                                  final hide = await showContentActions(
                                    context,
                                    ref,
                                    type: ReportTarget.comment,
                                    id: c['id'] as String,
                                    userId: a['id'] as String,
                                    userName: a['displayName'] as String,
                                  );
                                  if (hide && mounted) setState(() => items!.remove(c));
                                },
                          leading: UserAvatar((c['author'] as Map).cast<String, dynamic>(), radius: 16),
                          title: Text((c['author'] as Map)['displayName'] as String, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          subtitle: Text(c['content'] as String),
                          trailing: Text(Fmt.relative(DateTime.parse(c['createdAt'] as String).toLocal()), style: const TextStyle(fontSize: 11)),
                        ).stagger(i),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: text,
                    decoration: const InputDecoration(hintText: 'Viết bình luận...'),
                  ),
                ),
                IconButton.filled(
                  onPressed: () async {
                    if (text.text.trim().isEmpty) return;
                    final r = await ref.read(apiProvider).post<Map<String, dynamic>>('/posts/${widget.postId}/comments', {'content': text.text.trim()});
                    text.clear();
                    widget.onAdded();
                    setState(() => items = [...?items, r]);
                  },
                  icon: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Soạn bài viết: chữ + ảnh, quyền xem, gắn lịch trình / hũ, tag bạn. Offline → xếp hàng đăng sau.
class ComposePostPage extends ConsumerStatefulWidget {
  const ComposePostPage({super.key, this.eventId, this.jarId});
  final String? eventId;
  final String? jarId;

  @override
  ConsumerState<ComposePostPage> createState() => _ComposePostPageState();
}

class _ComposePostPageState extends ConsumerState<ComposePostPage> {
  // Giải phóng tài nguyên khi đóng màn (tránh tích tụ khi mở/đóng nhiều lần)
  @override
  void dispose() {
    content.dispose();
    location.dispose();
    super.dispose();
  }

  final content = TextEditingController();
  final location = TextEditingController();
  String? feeling;
  int visibility = 1;
  List<String> photos = [];
  Set<String> audience = {};
  Set<String> tags = {};
  List<Map<String, dynamic>> friends = [];

  @override
  void initState() {
    super.initState();
    final store = ref.read(storeProvider);
    final ev = store.get(E.events, widget.eventId);
    if (ev != null) {
      final e = EventRec(ev);
      content.text = '${e.title} ✨';
      location.text = e.location ?? '';
      photos = store.all(E.eventPhotos).map(EventPhoto.new).where((p) => p.eventId == e.id).map((p) => p.fileId).take(10).toList();
    }
    final jar = store.get(E.savingsJars, widget.jarId);
    if (jar != null) {
      final f = ref.read(financeProvider);
      final j = Jar(jar);
      content.text = 'Hũ "${j.name}" đã được ${f.money(f.jarSaved(j.id), j.currencyCode)} / ${f.money(j.target, j.currencyCode)} 💪';
    }
    ref
        .read(apiProvider)
        .get<List<dynamic>>('/friends')
        .then((r) {
          if (mounted) setState(() => friends = r.cast<Map<String, dynamic>>());
        })
        .catchError((_) {});
  }

  static const _feelings = [
    ('😄', 'vui vẻ'),
    ('🥰', 'hạnh phúc'),
    ('🤩', 'hào hứng'),
    ('😌', 'thư giãn'),
    ('🙏', 'biết ơn'),
    ('😋', 'ngon miệng'),
    ('😪', 'mệt mỏi'),
    ('😢', 'buồn'),
  ];
  static const _audiences = [
    (1, Icons.public_rounded, 'Bạn bè', 'Tất cả bạn bè của bạn'),
    (2, Icons.lock_rounded, 'Chỉ mình tôi', 'Không ai khác thấy bài này'),
    (3, Icons.group_rounded, 'Chọn người', 'Chỉ những người bạn chọn'),
  ];

  /// Khối đang mở trong phần "Thêm vào bài viết": 'feel' / 'place' / null.
  String? panel;

  bool get _canPost => content.text.trim().isNotEmpty || photos.isNotEmpty;

  Future<Set<String>> _pickFriends(String title, Set<String> initial) async {
    final selected = {...initial};
    await showModalBottomSheet(
      sheetAnimationStyle: kSheetAnim,
      context: context,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          maxChildSize: 0.9,
          builder: (c, sc) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    ),
                    FilledButton(onPressed: () => Navigator.pop(c), child: Text(selected.isEmpty ? 'Xong' : 'Xong · ${selected.length}')),
                  ],
                ),
              ),
              Expanded(
                child: friends.isEmpty
                    ? const EmptyState(icon: Icons.group_off_rounded, title: 'Chưa có bạn bè', subtitle: 'Hoặc đang offline')
                    : ListView(
                        controller: sc,
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                        children: [
                          for (final (i, f) in friends.indexed)
                            Pressable(
                              scale: 0.98,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                set(() => selected.contains(f['id']) ? selected.remove(f['id']) : selected.add(f['id'] as String));
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOutCubic,
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: selected.contains(f['id']) ? Theme.of(c).colorScheme.primary.withValues(alpha: 0.12) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                ),
                                child: Row(
                                  children: [
                                    UserAvatar(f),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(f['displayName'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                                    ),
                                    AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 200),
                                      transitionBuilder: (w, a) => ScaleTransition(scale: a, child: w),
                                      child: Icon(
                                        selected.contains(f['id']) ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                        key: ValueKey(selected.contains(f['id'])),
                                        color: selected.contains(f['id']) ? Theme.of(c).colorScheme.primary : Theme.of(c).colorScheme.outline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ).stagger(i),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
    return selected;
  }

  Future<void> _pickAudience() async {
    final v = await showModalBottomSheet<int>(
      sheetAnimationStyle: kSheetAnim,
      context: context,
      builder: (c) {
        final scheme = Theme.of(c).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Ai có thể xem bài viết?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                for (final (val, icon, title, sub) in _audiences)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Pressable(
                      scale: 0.98,
                      onTap: () => Navigator.pop(c, val),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: visibility == val ? scheme.primary.withValues(alpha: 0.12) : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: visibility == val ? scheme.primary : Colors.transparent, width: 1.5),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(14)),
                              child: Icon(icon, color: scheme.primary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                                  Text(sub, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                                ],
                              ),
                            ),
                            if (visibility == val) Icon(Icons.check_circle_rounded, color: scheme.primary),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (v == null) return;
    if (v == 3) {
      final sel = await _pickFriends('Ai được xem?', audience);
      if (sel.isEmpty) return;
      setState(() => audience = sel);
    }
    setState(() => visibility = v);
  }

  void _submit() {
    if (!_canPost) return showToast(context, 'Viết gì đó hoặc thêm ảnh', error: true);
    ref.read(storeProvider).enqueue('post', {
      'id': newId(),
      'content': content.text.trim(),
      'visibility': visibility,
      'audienceIds': audience.toList(),
      'tagIds': tags.toList(),
      'photoFileIds': photos,
      'eventId': widget.eventId,
      'jarId': widget.jarId,
      'location': location.text.trim().isEmpty ? null : location.text.trim(),
      'feeling': feeling,
    });
    ref.read(syncProvider).schedule(const Duration(milliseconds: 100));
    HapticFeedback.lightImpact();
    showToast(context, 'Đang đăng bài...');
    Navigator.of(context).maybePop();
  }

  Future<void> _addPhotos() async {
    final ids = await pickPhotos(context, ref);
    if (ids.isNotEmpty) setState(() => photos = [...photos, ...ids]);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider).user ?? {};
    final scheme = Theme.of(context).colorScheme;
    final aud = _audiences.firstWhere((a) => a.$1 == visibility);
    final tagged = friends.where((f) => tags.contains(f['id'])).toList();
    final place = location.text.trim();

    // Dòng phụ dưới tên: "đang cảm thấy 😄 vui vẻ · tại Hồ Tây · cùng Minh"
    final extras = <InlineSpan>[
      if (feeling != null) ...[
        const TextSpan(text: 'đang cảm thấy '),
        TextSpan(
          text: feeling,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ],
      if (place.isNotEmpty) ...[
        TextSpan(text: feeling != null ? ' · tại ' : 'tại '),
        TextSpan(
          text: place,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ],
      if (tagged.isNotEmpty) ...[
        TextSpan(text: feeling != null || place.isNotEmpty ? ' · cùng ' : 'cùng '),
        TextSpan(
          text: tagged.length == 1 ? tagged.first['displayName'] as String? : '${tagged.first['displayName']} và ${tagged.length - 1} người khác',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ],
    ];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close_rounded)),
        title: const Text('Tạo bài viết'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Pressable(
              onTap: _submit,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  gradient: _canPost ? LinearGradient(colors: [scheme.primary, accentOf(scheme.primary, hue: 24)]) : null,
                  color: _canPost ? null : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: _canPost ? [BoxShadow(color: scheme.primary.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))] : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.send_rounded, size: 16, color: _canPost ? scheme.onPrimary : scheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text(
                      'Đăng',
                      style: TextStyle(fontWeight: FontWeight.w800, color: _canPost ? scheme.onPrimary : scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          AppCard(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UserAvatar(user, radius: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user['displayName'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutCubic,
                            alignment: Alignment.topLeft,
                            child: extras.isEmpty
                                ? const SizedBox(width: double.infinity)
                                : Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text.rich(
                                      TextSpan(children: extras),
                                      style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant, height: 1.3),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 6),
                          Pressable(
                            onTap: _pickAudience,
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
                              decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(99)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(aud.$2, size: 14, color: scheme.primary),
                                  const SizedBox(width: 5),
                                  Text(
                                    visibility == 3 ? '${aud.$3} · ${audience.length}' : aud.$3,
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: scheme.primary),
                                  ),
                                  Icon(Icons.expand_more_rounded, size: 18, color: scheme.primary),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                TextField(
                  controller: content,
                  maxLines: null,
                  minLines: 5,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(fontSize: content.text.length < 80 && photos.isEmpty ? 21 : 16, height: 1.4, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: 'Bạn đang nghĩ gì?',
                    hintStyle: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.6)),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: photos.isEmpty
                      ? const SizedBox(width: double.infinity)
                      : LayoutBuilder(
                          builder: (context, box) =>
                              PhotoGrid(size: (box.maxWidth - 16) / 3, fileIds: photos, onAdd: _addPhotos, onRemove: (id) => setState(() => photos.remove(id))),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Thêm vào bài viết',
                  style: TextStyle(fontWeight: FontWeight.w800, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _ComposeAction(
                      icon: Icons.photo_library_rounded,
                      label: 'Ảnh',
                      color: const Color(0xFF34C77B),
                      active: photos.isNotEmpty,
                      onTap: _addPhotos,
                    ),
                    _ComposeAction(
                      icon: Icons.emoji_emotions_rounded,
                      label: 'Cảm xúc',
                      color: const Color(0xFFF5B83D),
                      active: feeling != null || panel == 'feel',
                      onTap: () => setState(() => panel = panel == 'feel' ? null : 'feel'),
                    ),
                    _ComposeAction(
                      icon: Icons.place_rounded,
                      label: 'Địa điểm',
                      color: const Color(0xFFF0605D),
                      active: place.isNotEmpty || panel == 'place',
                      onTap: () => setState(() => panel = panel == 'place' ? null : 'place'),
                    ),
                    _ComposeAction(
                      icon: Icons.sell_rounded,
                      label: tags.isEmpty ? 'Gắn thẻ' : 'Thẻ · ${tags.length}',
                      color: const Color(0xFF4C8DF6),
                      active: tags.isNotEmpty,
                      onTap: () async {
                        final sel = await _pickFriends('Gắn thẻ bạn bè', tags);
                        setState(() => tags = sel);
                      },
                    ),
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: switch (panel) {
                      'feel' => Padding(
                        key: const ValueKey('feel'),
                        padding: const EdgeInsets.only(top: 14),
                        child: GridView.count(
                          crossAxisCount: 4,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 0.95,
                          children: [
                            for (final (i, (emo, name)) in _feelings.indexed)
                              (() {
                                final v = '$name $emo';
                                final on = feeling == v;
                                return Pressable(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() => feeling = on ? null : v);
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeOutCubic,
                                    decoration: BoxDecoration(
                                      color: on ? const Color(0xFFF5B83D).withValues(alpha: 0.2) : scheme.surfaceContainerHighest.withValues(alpha: 0.45),
                                      borderRadius: BorderRadius.circular(AppRadius.md),
                                      border: Border.all(color: on ? const Color(0xFFF5B83D) : Colors.transparent, width: 1.5),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        AnimatedScale(
                                          scale: on ? 1.2 : 1,
                                          duration: const Duration(milliseconds: 220),
                                          child: Text(emo, style: const TextStyle(fontSize: 26)),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(name, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                                      ],
                                    ),
                                  ),
                                ).stagger(i);
                              })(),
                          ],
                        ),
                      ),
                      'place' => Padding(
                        key: const ValueKey('place'),
                        padding: const EdgeInsets.only(top: 14),
                        child: TextField(
                          controller: location,
                          autofocus: true,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Bạn đang ở đâu?',
                            prefixIcon: const Icon(Icons.place_rounded, color: Color(0xFFF0605D)),
                            suffixIcon: place.isEmpty
                                ? null
                                : IconButton(onPressed: () => setState(() => location.clear()), icon: const Icon(Icons.close_rounded)),
                          ),
                        ),
                      ),
                      _ => const SizedBox(key: ValueKey('none'), width: double.infinity),
                    },
                  ),
                ),
                if (tagged.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final f in tagged)
                        Container(
                          padding: const EdgeInsets.fromLTRB(4, 4, 6, 4),
                          decoration: BoxDecoration(color: const Color(0xFF4C8DF6).withValues(alpha: 0.14), borderRadius: BorderRadius.circular(99)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              UserAvatar(f, radius: 11),
                              const SizedBox(width: 6),
                              Text(f['displayName'] as String? ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                              const SizedBox(width: 2),
                              Pressable(onTap: () => setState(() => tags.remove(f['id'])), child: const Icon(Icons.close_rounded, size: 16)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposeAction extends StatelessWidget {
  const _ComposeAction({required this.icon, required this.label, required this.color, required this.active, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Pressable(
        onTap: onTap,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: active ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color, accentOf(color, hue: 18)]) : null,
                color: active ? null : color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(17),
                boxShadow: active ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))] : null,
              ),
              child: Icon(icon, color: active ? Colors.white : color),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

// ========================================================================= Bạn bè

class FriendsPage extends ConsumerStatefulWidget {
  const FriendsPage({super.key, this.tab = 0});

  /// Tab mở sẵn: 0 bạn bè, 1 lời mời, 2 tìm bạn.
  final int tab;

  @override
  ConsumerState<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends ConsumerState<FriendsPage> {
  // Giải phóng tài nguyên khi đóng màn (tránh tích tụ khi mở/đóng nhiều lần)
  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  List<Map<String, dynamic>> friends = [], requests = [], results = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!ref.read(sessionProvider).isLoggedIn) return;
    final api = ref.read(apiProvider);
    try {
      final f = await api.get<List<dynamic>>('/friends');
      final r = await api.get<List<dynamic>>('/friends/requests');
      if (mounted) {
        setState(() {
          friends = f.cast<Map<String, dynamic>>();
          requests = r.cast<Map<String, dynamic>>();
        });
      }
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  void _search(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      if (q.trim().length < 2) return setState(() => results = []);
      final r = await ref.read(apiProvider).get<List<dynamic>>('/friends/search', query: {'q': q});
      if (mounted) setState(() => results = r.cast<Map<String, dynamic>>());
    });
  }

  Future<void> _act(Future<void> Function() f, String ok) async {
    try {
      await f();
      HapticFeedback.lightImpact();
      if (mounted) showToast(context, ok);
      await _load();
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  String filter = '';

  Future<void> _openChat(Map<String, dynamic> user) async {
    HapticFeedback.selectionClick();
    try {
      final c = await ref.read(apiProvider).post<Map<String, dynamic>>('/conversations/direct', {'userId': user['id']});
      if (mounted) context.push('/chat/room', extra: c);
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(sessionProvider).isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('Bạn bè')),
        body: loginRequired(context),
      );
    }
    final api = ref.read(apiProvider);
    final rt = ref.watch(realtimeProvider);
    final scheme = Theme.of(context).colorScheme;
    bool isOnline(Map<String, dynamic> u) => u['isOnline'] == true || rt.online.contains(u['id']);
    final incoming = requests.where((r) => r['isIncoming'] == true).toList();
    final outgoing = requests.where((r) => r['isIncoming'] != true).toList();
    final partnerId = myPartnerId(ref);
    final couple = ref.watch(coupleProvider);
    final pendingId = couple.outgoingUserId;
    final key = Fmt.fold(filter);
    final shown =
        [
          for (final f in friends)
            if (key.isEmpty || Fmt.fold('${f['displayName']} ${f['username']}').contains(key)) f,
        ]..sort((a, b) {
          int rank(Map<String, dynamic> u) => (u['id'] == partnerId ? 2 : 0) + (isOnline(u) ? 1 : 0);
          return rank(b) - rank(a);
        });
    final partner = friends.where((f) => f['id'] == partnerId).firstOrNull;
    final online = friends.where(isOnline).toList();

    Widget tabLabel(String text, int count, {bool alert = false}) => Tab(
      height: 36,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: alert ? AppColors.expense : scheme.onSurface.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
              child: Text(
                '$count',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: alert ? Colors.white : null),
              ),
            ),
          ],
        ],
      ),
    );

    return DefaultTabController(
      length: 3,
      initialIndex: widget.tab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bạn bè'),
          bottom: pillTabBar(context, [
            tabLabel('Bạn bè', friends.length),
            tabLabel('Lời mời', incoming.length + couple.incoming.length, alert: true),
            const Tab(height: 36, text: 'Tìm bạn'),
          ]),
        ),
        body: TabBarView(
          children: [
            // ---------------- Bạn bè
            RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                children: [
                  if (friends.isEmpty)
                    const EmptyState(icon: Icons.group_rounded, title: 'Chưa có bạn bè', subtitle: 'Tìm theo tên đăng nhập ở tab "Tìm bạn"')
                  else ...[
                    PillSearchField(hint: 'Tìm trong ${friends.length} bạn bè', onChanged: (v) => setState(() => filter = v)),
                    if (partner != null && filter.isEmpty) ...[
                      const SizedBox(height: 14),
                      _PartnerCard(user: partner, online: isOnline(partner), onChat: () => _openChat(partner)),
                    ],
                    if (partner == null && couple.outgoing != null && filter.isEmpty) ...[
                      const SizedBox(height: 14),
                      AppCard(
                        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                        color: AppColors.love.withValues(alpha: 0.10),
                        child: Row(
                          children: [
                            UserAvatar((couple.outgoing!['user'] as Map).cast<String, dynamic>(), radius: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '⏳ Đang chờ ${(couple.outgoing!['user'] as Map)['displayName']} xác nhận làm người yêu',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                            TextButton(onPressed: () => setPartner(context, ref, null), child: const Text('Huỷ')),
                          ],
                        ),
                      ).animate().fadeIn(duration: 300.ms),
                    ],
                    if (online.isNotEmpty && filter.isEmpty) ...[
                      const SectionTitle('Đang hoạt động'),
                      SizedBox(
                        height: 92,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            for (final (i, f) in online.indexed)
                              Padding(
                                padding: const EdgeInsets.only(right: 14),
                                child: Pressable(
                                  onTap: () => openProfile(context, f),
                                  child: SizedBox(
                                    width: 64,
                                    child: Column(
                                      children: [
                                        UserAvatar(f, radius: 26, ring: true),
                                        const SizedBox(height: 6),
                                        Text(
                                          (f['displayName'] as String).split(' ').first,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ).stagger(i),
                          ],
                        ),
                      ),
                    ],
                    SectionTitle(filter.isEmpty ? 'Tất cả bạn bè' : 'Kết quả (${shown.length})'),
                    for (final (i, f) in shown.indexed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AppCard(
                          padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                          onTap: () => openProfile(context, f),
                          child: Row(
                            children: [
                              UserAvatar(f, radius: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(f['displayName'] as String, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                    const SizedBox(height: 2),
                                    Text(
                                      [
                                        if (f['id'] == partnerId) '❤️ Người yêu',
                                        if (f['id'] == pendingId) '⏳ Đã mời làm người yêu',
                                        isOnline(f) ? '● Đang hoạt động' : '@${f['username']}',
                                      ].join(' · '),
                                      style: TextStyle(fontSize: 12, color: isOnline(f) ? AppColors.income : scheme.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton.filledTonal(tooltip: 'Nhắn tin', onPressed: () => _openChat(f), icon: const Icon(Icons.chat_bubble_rounded, size: 20)),
                              PopupMenuButton(
                                icon: Icon(Icons.more_horiz_rounded, color: scheme.onSurfaceVariant),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                    value: 2,
                                    child: Row(
                                      children: [
                                        Icon(
                                          f['id'] == partnerId || f['id'] == pendingId ? Icons.heart_broken_rounded : Icons.favorite_rounded,
                                          size: 20,
                                          color: AppColors.love,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          f['id'] == partnerId
                                              ? 'Huỷ liên kết người yêu'
                                              : f['id'] == pendingId
                                              ? 'Huỷ lời mời người yêu'
                                              : 'Mời làm người yêu',
                                        ),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 1,
                                    child: Row(
                                      children: [
                                        Icon(Icons.person_remove_rounded, size: 20, color: AppColors.expense),
                                        SizedBox(width: 10),
                                        Text('Huỷ kết bạn'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 3,
                                    child: Row(
                                      children: [
                                        Icon(Icons.flag_rounded, size: 20, color: AppColors.warning),
                                        SizedBox(width: 10),
                                        Text('Báo cáo'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 4,
                                    child: Row(
                                      children: [
                                        Icon(Icons.block_rounded, size: 20, color: AppColors.expense),
                                        SizedBox(width: 10),
                                        Text('Chặn'),
                                      ],
                                    ),
                                  ),
                                ],
                                onSelected: (v) async {
                                  switch (v) {
                                    case 2:
                                      setPartner(context, ref, f['id'] == partnerId || f['id'] == pendingId ? null : f);
                                    case 3:
                                      await reportContent(context, type: ReportTarget.user, id: f['id'] as String, userName: f['displayName'] as String);
                                    case 4:
                                      if (await blockUser(context, ref, userId: f['id'] as String, name: f['displayName'] as String)) await _load();
                                    default:
                                      _act(() => api.delete('/friends/${f['id']}'), 'Đã huỷ kết bạn');
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ).stagger(i),
                  ],
                ],
              ),
            ),
            // ---------------- Lời mời
            RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                children: [
                  if (couple.incoming.isNotEmpty) const SectionTitle('Lời mời làm người yêu'),
                  for (final c in couple.incoming)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: CoupleInviteCard(
                        user: (c['user'] as Map).cast<String, dynamic>(),
                        onAnswer: (ok) => answerCouple(context, ref, (c['user'] as Map).cast<String, dynamic>(), ok),
                      ),
                    ),
                  if (incoming.isEmpty && outgoing.isEmpty && couple.incoming.isEmpty)
                    const EmptyState(icon: Icons.mark_email_read_rounded, title: 'Không có lời mời nào'),
                  if (incoming.isNotEmpty) const SectionTitle('Muốn kết bạn với bạn'),
                  for (final (i, r) in incoming.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppCard(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                UserAvatar((r['user'] as Map).cast<String, dynamic>(), radius: 26),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text((r['user'] as Map)['displayName'] as String, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                      Text(
                                        '@${(r['user'] as Map)['username']} · ${Fmt.relative(DateTime.parse(r['createdAt'] as String).toLocal())}',
                                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                                      ),
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
                                    onPressed: () => _act(() => api.delete('/friends/requests/${r['id']}'), 'Đã từ chối'),
                                    child: const Text('Xoá'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () => _act(() => api.post('/friends/requests/${r['id']}/accept'), 'Đã trở thành bạn bè 🎉'),
                                    icon: const Icon(Icons.check_rounded, size: 18),
                                    label: const Text('Chấp nhận'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ).stagger(i),
                  if (outgoing.isNotEmpty) const SectionTitle('Đã gửi lời mời'),
                  for (final (i, r) in outgoing.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                        child: Row(
                          children: [
                            UserAvatar((r['user'] as Map).cast<String, dynamic>(), radius: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text((r['user'] as Map)['displayName'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  Text('Đang chờ chấp nhận', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                                ],
                              ),
                            ),
                            TextButton(onPressed: () => _act(() => api.delete('/friends/requests/${r['id']}'), 'Đã huỷ lời mời'), child: const Text('Thu hồi')),
                          ],
                        ),
                      ),
                    ).stagger(i),
                ],
              ),
            ),
            // ---------------- Tìm bạn
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                PillSearchField(hint: 'Tên đăng nhập, tên hiển thị hoặc email', onChanged: _search),
                const SizedBox(height: 12),
                if (results.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Column(
                      children: [
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
                          child: Icon(Icons.person_search_rounded, size: 40, color: scheme.primary),
                        ),
                        const SizedBox(height: 12),
                        const Text('Tìm bạn bè', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text('Nhập ít nhất 2 ký tự để tìm', style: TextStyle(color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ).animate().fadeIn(duration: 300.ms),
                for (final (i, r) in results.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                      child: Row(
                        children: [
                          UserAvatar((r['user'] as Map).cast<String, dynamic>(), radius: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text((r['user'] as Map)['displayName'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                                Text('@${(r['user'] as Map)['username']}', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                              ],
                            ),
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                            child: switch (r['relation']) {
                              'friend' => IconButton.filledTonal(
                                key: const ValueKey('f'),
                                tooltip: 'Nhắn tin',
                                onPressed: () => _openChat((r['user'] as Map).cast<String, dynamic>()),
                                icon: const Icon(Icons.chat_bubble_rounded, size: 20),
                              ),
                              'outgoing' => Chip(
                                key: const ValueKey('o'),
                                avatar: const Icon(Icons.schedule_rounded, size: 16),
                                label: const Text('Đã mời'),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              'incoming' => FilledButton(
                                key: const ValueKey('i'),
                                onPressed: () => _act(() => api.post('/friends/requests/${r['friendshipId']}/accept'), 'Đã trở thành bạn bè'),
                                child: const Text('Chấp nhận'),
                              ),
                              _ => FilledButton.tonalIcon(
                                key: const ValueKey('n'),
                                onPressed: () => _act(() async {
                                  await api.post('/friends/requests', {'userId': (r['user'] as Map)['id']});
                                  setState(() => results[i] = {...r, 'relation': 'outgoing'});
                                }, 'Đã gửi lời mời'),
                                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                                label: const Text('Kết bạn'),
                              ),
                            },
                          ),
                        ],
                      ),
                    ),
                  ).stagger(i),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Thẻ nổi bật "Người yêu" ở đầu danh sách bạn bè.
class _PartnerCard extends ConsumerWidget {
  const _PartnerCard({required this.user, required this.online, required this.onChat});
  final Map<String, dynamic> user;
  final bool online;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final love = ref.watchTables(const [E.loveCounters]).all(E.loveCounters).map(LoveCounter.new).firstOrNull;
    final days = love == null ? null : Love.days(love.startDate);
    return AppCard(
      onTap: () => context.push('/love'),
      padding: const EdgeInsets.all(14),
      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFF8FAB), Color(0xFFE93D82)]),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
            child: UserAvatar(user, radius: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '❤️ Người yêu của bạn',
                  style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                Text(
                  user['displayName'] as String,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                ),
                Text(
                  [if (days != null) 'Bên nhau $days ngày', online ? 'Đang hoạt động' : '@${user['username']}'].join(' · '),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton.filled(
            style: IconButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.love),
            tooltip: 'Nhắn tin',
            onPressed: onChat,
            icon: const Icon(Icons.chat_bubble_rounded, size: 20),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.08, curve: Curves.easeOutCubic);
  }
}

// ========================================================================= Thông báo

/// Bấm thông báo → mở đúng nơi liên quan (bài viết, lời mời, trang cá nhân, lịch trình, tin nhắn).
Future<void> openNotification(BuildContext context, WidgetRef ref, Map<String, dynamic> n) async {
  HapticFeedback.selectionClick();
  Map<String, dynamic> payload = const {};
  final raw = n['payloadJson'];
  if (raw is String && raw.isNotEmpty) {
    try {
      payload = (jsonDecode(raw) as Map).cast<String, dynamic>();
    } catch (_) {}
  }
  final actor = (n['actor'] as Map?)?.cast<String, dynamic>();
  final t = n['type'] as int?;
  final router = GoRouter.of(context);
  switch (t) {
    case 1: // lời mời kết bạn
    case 10: // lời mời làm người yêu
      router.push('/friends', extra: {'tab': 1});
    case 2: // đã chấp nhận kết bạn
    case 12: // huỷ / từ chối người yêu
      if (actor != null) {
        router.push('/profile', extra: {'user': actor});
      } else {
        router.push('/friends');
      }
    case 11: // đã thành đôi
      router.push('/love');
    case 3: // tin nhắn
      router.push('/chat');
    case 4: // mời tham gia lịch trình
    case 5: // thay đổi lịch trình
      final id = payload['eventId'] as String?;
      if (id == null) {
        router.push('/schedule');
        return;
      }
      // Lịch trình được mời có thể chưa về máy → đồng bộ trước khi mở.
      if (ref.read(storeProvider).get(E.events, id) == null) {
        showToast(context, 'Đang tải lịch trình...');
        try {
          await ref.read(syncProvider).sync().timeout(const Duration(seconds: 8));
        } catch (_) {}
      }
      if (ref.read(storeProvider).get(E.events, id) == null) {
        router.push('/schedule');
      } else {
        router.push('/schedule/detail', extra: {'id': id});
      }
    case 6:
    case 7:
    case 8:
    case 9: // bài viết / bình luận / cảm xúc / gắn thẻ
      final id = payload['postId'] as String?;
      if (id == null) {
        router.push('/feed');
      } else {
        router.push('/post', extra: {'id': id, 'comments': t == 7});
      }
    default:
      break;
  }
}

/// Một bài viết riêng lẻ (mở từ thông báo). [comments] = mở luôn phần bình luận.
class PostDetailPage extends ConsumerStatefulWidget {
  const PostDetailPage({super.key, required this.id, this.comments = false});
  final String id;
  final bool comments;

  @override
  ConsumerState<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends ConsumerState<PostDetailPage> {
  Map<String, dynamic>? post;
  String? error;
  final _cardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await ref.read(apiProvider).get<Map<String, dynamic>>('/posts/${widget.id}');
      if (!mounted) return;
      setState(() => post = p);
      if (widget.comments) {
        await Future<void>.delayed(const Duration(milliseconds: 350));
        if (mounted) PostCard(post: p, onChanged: _changed, onDeleted: _deleted).openComments(context, ref);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.offline ? 'Đang offline, thử lại sau' : e.message);
    }
  }

  void _changed(Map<String, dynamic> p) => setState(() => post = p);
  void _deleted() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bài viết')),
      body: error != null
          ? EmptyState(icon: Icons.article_outlined, title: error!, subtitle: 'Bài có thể đã bị xoá hoặc bạn không có quyền xem')
          : post == null
          ? const Padding(padding: EdgeInsets.all(12), child: _PostSkeleton())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 40),
                children: [
                  PostCard(key: _cardKey, post: post!, onChanged: _changed, onDeleted: _deleted).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0),
                ],
              ),
            ),
    );
  }
}

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  List<Map<String, dynamic>>? items;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _load();
    _sub = ref.read(realtimeProvider).events.listen((e) {
      if (e.method == 'Notification' && mounted) setState(() => items = [e.data, ...?items]);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (!ref.read(sessionProvider).isLoggedIn) return;
    try {
      final r = await ref.read(apiProvider).get<List<dynamic>>('/notifications');
      if (mounted) setState(() => items = r.cast<Map<String, dynamic>>());
      await ref.read(apiProvider).post('/notifications/read-all');
      if (mounted) ref.read(unreadNotificationsProvider).set(0);
    } catch (_) {
      if (mounted) setState(() => items ??= []);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(sessionProvider).isLoggedIn)
      return Scaffold(
        appBar: AppBar(title: const Text('Thông báo')),
        body: loginRequired(context),
      );
    const icons = {
      1: Icons.person_add_rounded,
      2: Icons.how_to_reg_rounded,
      3: Icons.chat_rounded,
      4: Icons.event_rounded,
      5: Icons.event_note_rounded,
      6: Icons.dynamic_feed_rounded,
      7: Icons.mode_comment_rounded,
      8: Icons.favorite_rounded,
      9: Icons.sell_rounded,
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Thông báo')),
      body: items == null
          ? const SkeletonList()
          : items!.isEmpty
          ? const EmptyState(icon: Icons.notifications_none_rounded, title: 'Chưa có thông báo')
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                children: [
                  for (final (i, n) in items!.indexed)
                    ListTile(
                      leading: CircleAvatar(child: Icon(icons[n['type']] ?? Icons.notifications_rounded)),
                      title: Text(n['title'] as String? ?? '', style: TextStyle(fontWeight: n['readAt'] == null ? FontWeight.w700 : FontWeight.normal)),
                      subtitle: Text(n['body'] as String? ?? ''),
                      trailing: Text(Fmt.relative(DateTime.parse(n['createdAt'] as String).toLocal()), style: const TextStyle(fontSize: 11)),
                      onTap: () => openNotification(context, ref, n),
                    ).stagger(i),
                ],
              ),
            ),
    );
  }
}
