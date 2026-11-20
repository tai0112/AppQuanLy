import 'dart:async';

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
import '../data/realtime.dart';
import '../providers.dart';
import 'common.dart';
import 'moderation.dart';
import 'social.dart';

/// Danh sách cuộc trò chuyện (cập nhật realtime qua SignalR).
class ChatListPage extends ConsumerStatefulWidget {
  const ChatListPage({super.key});

  @override
  ConsumerState<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends ConsumerState<ChatListPage> {
  List<Map<String, dynamic>>? items;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _load();
    _loadFriends();
    _sub = ref.read(realtimeProvider).events.listen((e) {
      if (e.method == 'MessageReceived' || e.method == 'ConversationCreated' || e.method == 'MessageRead') _load();
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
      final r = await ref.read(apiProvider).get<List<dynamic>>('/conversations');
      if (mounted) setState(() => items = r.cast<Map<String, dynamic>>());
    } catch (_) {
      if (mounted) setState(() => items ??= []);
    }
  }

  Future<void> _newGroup() async {
    final api = ref.read(apiProvider);
    final friends = (await api.get<List<dynamic>>('/friends')).cast<Map<String, dynamic>>();
    if (!mounted) return;
    final name = TextEditingController();
    final selected = <String>{};
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('Tạo nhóm'),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Tên nhóm'),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final f in friends)
                        CheckboxListTile(
                          value: selected.contains(f['id']),
                          onChanged: (v) => set(() => v == true ? selected.add(f['id'] as String) : selected.remove(f['id'])),
                          title: Text(f['displayName'] as String),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Huỷ')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Tạo')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      final conv = await api.post<Map<String, dynamic>>('/conversations/group', {'name': name.text, 'memberIds': selected.toList()});
      if (mounted) context.push('/chat/room', extra: conv);
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  String filter = '';
  List<Map<String, dynamic>> friends = [];

  Future<void> _loadFriends() async {
    try {
      final r = await ref.read(apiProvider).get<List<dynamic>>('/friends');
      if (mounted) setState(() => friends = r.cast<Map<String, dynamic>>());
    } catch (_) {}
  }

  Future<void> _openDirect(Map<String, dynamic> user) async {
    HapticFeedback.selectionClick();
    try {
      final c = await ref.read(apiProvider).post<Map<String, dynamic>>('/conversations/direct', {'userId': user['id']});
      if (!mounted) return;
      await context.push('/chat/room', extra: c);
      _load();
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  /// Bảng chọn người để nhắn tin mới (hoặc tạo nhóm).
  Future<void> _newMessage() async {
    if (friends.isEmpty) await _loadFriends();
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (ctx, sc) => ListView(
          controller: sc,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            const Text('Tin nhắn mới', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            AppCard(
              padding: const EdgeInsets.all(12),
              onTap: () {
                Navigator.pop(ctx);
                _newGroup();
              },
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.15), shape: BoxShape.circle),
                    child: Icon(Icons.group_add_rounded, color: scheme.primary),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Tạo nhóm chat', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
            const SectionTitle('Bạn bè'),
            if (friends.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.push('/friends');
                    },
                    child: const Text('Chưa có bạn bè — tìm bạn'),
                  ),
                ),
              ),
            for (final (i, f) in friends.indexed)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: UserAvatar(f, radius: 22),
                title: Text(f['displayName'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('@${f['username']}'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openDirect(f);
                },
              ).stagger(i),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    if (!session.isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tin nhắn')),
        body: loginRequired(context),
      );
    }
    final rt = ref.watch(realtimeProvider);
    final me = session.userId;
    final online = friends.where((f) => f['isOnline'] == true || rt.online.contains(f['id'])).toList();
    final key = Fmt.fold(filter);
    final list = [
      for (final c in items ?? const <Map<String, dynamic>>[])
        if (key.isEmpty || Fmt.fold(_title(c, me)).contains(key)) c,
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tin nhắn'),
        actions: [
          IconButton(tooltip: 'Bạn bè', onPressed: () => context.push('/friends'), icon: const Icon(Icons.people_alt_rounded)),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-msg',
        onPressed: _newMessage,
        icon: const Icon(Icons.edit_rounded),
        label: const Text('Tin nhắn mới'),
      ),
      body: items == null
          ? const SkeletonList()
          : RefreshIndicator(
              onRefresh: () async {
                await Future.wait([_load(), _loadFriends()]);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                children: [
                  PillSearchField(hint: 'Tìm cuộc trò chuyện', onChanged: (v) => setState(() => filter = v)),
                  if (online.isNotEmpty && filter.isEmpty) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 88,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final (i, f) in online.indexed)
                            Padding(
                              padding: const EdgeInsets.only(right: 14),
                              child: Pressable(
                                onTap: () => _openDirect(f),
                                child: SizedBox(
                                  width: 62,
                                  child: Column(
                                    children: [
                                      UserAvatar(f, radius: 25, ring: true),
                                      const SizedBox(height: 5),
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
                  const SizedBox(height: 8),
                  if (list.isEmpty)
                    EmptyState(
                      icon: Icons.forum_rounded,
                      title: filter.isEmpty ? 'Chưa có cuộc trò chuyện' : 'Không tìm thấy',
                      subtitle: filter.isEmpty ? 'Bấm "Tin nhắn mới" để bắt đầu' : null,
                    ),
                  for (final (i, c) in list.indexed) _tile(c).stagger(i),
                ],
              ),
            ),
    );
  }

  String _title(Map<String, dynamic> c, String? me) {
    final others = (c['members'] as List).cast<Map<String, dynamic>>().where((m) => m['id'] != me);
    return c['type'] == 2 ? (c['name'] as String? ?? 'Nhóm') : (others.firstOrNull?['displayName'] as String? ?? '');
  }

  Widget _tile(Map<String, dynamic> c) {
    final me = ref.read(sessionProvider).userId;
    final scheme = Theme.of(context).colorScheme;
    final members = (c['members'] as List).cast<Map<String, dynamic>>();
    final others = members.where((m) => m['id'] != me).toList();
    final isGroup = c['type'] == 2;
    final title = _title(c, me);
    final last = c['lastMessage'] as Map<String, dynamic>?;
    final unread = c['unreadCount'] as int? ?? 0;
    final preview = last == null ? 'Bắt đầu trò chuyện 👋' : '${last['senderId'] == me ? 'Bạn: ' : ''}${last['type'] == 2 ? '📷 Hình ảnh' : last['content']}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Pressable(
        scale: 0.98,
        onTap: () async {
          await context.push('/chat/room', extra: c);
          _load();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(color: unread > 0 ? scheme.primary.withValues(alpha: 0.08) : Colors.transparent, borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              isGroup
                  ? Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [avatarColor(title), Color.lerp(avatarColor(title), Colors.black, 0.35)!]),
                      ),
                      child: const Icon(Icons.groups_rounded, color: Colors.white),
                    )
                  : UserAvatar(others.firstOrNull ?? {'displayName': '?'}, radius: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 15, fontWeight: unread > 0 ? FontWeight.w800 : FontWeight.w600),
                          ),
                        ),
                        if (!isGroup && others.isNotEmpty && others.first['id'] == myPartnerId(ref))
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.favorite_rounded, size: 14, color: AppColors.love),
                          ),
                        const Spacer(),
                        if (c['lastMessageAt'] != null)
                          Text(
                            _when(DateTime.parse(c['lastMessageAt'] as String).toLocal()),
                            style: TextStyle(
                              fontSize: 11,
                              color: unread > 0 ? scheme.primary : scheme.onSurfaceVariant,
                              fontWeight: unread > 0 ? FontWeight.w700 : null,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: unread > 0 ? scheme.onSurface : scheme.onSurfaceVariant,
                              fontWeight: unread > 0 ? FontWeight.w600 : null,
                            ),
                          ),
                        ),
                        AnimatedScale(
                          scale: unread > 0 ? 1 : 0,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutBack,
                          child: Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(16)),
                            child: Text(
                              '${unread > 99 ? '99+' : unread}',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: scheme.onPrimary),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Giờ ngắn gọn kiểu ứng dụng chat: 14:05 · Hôm qua · T3 · 12/11.
String _when(DateTime d) {
  final now = DateTime.now();
  final days = dateOnly(now).difference(dateOnly(d)).inDays;
  if (days == 0) return Fmt.time(d);
  if (days == 1) return 'Hôm qua';
  if (days < 7) return Fmt.weekdaysShort[d.weekday - 1];
  return Fmt.dateShort(d);
}

/// Phòng chat: realtime, đang nhập..., đã xem, gửi khi offline (tự gửi lại khi có mạng).
class ChatRoomPage extends ConsumerStatefulWidget {
  const ChatRoomPage({super.key, required this.conversation});
  final Map<String, dynamic> conversation;

  @override
  ConsumerState<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends ConsumerState<ChatRoomPage> {
  final text = TextEditingController();
  final scroll = ScrollController();
  List<Map<String, dynamic>> messages = [];
  String? cursor;
  final Set<String> typing = {};
  final Map<String, String> readBy = {}; // userId → messageId
  StreamSubscription? _sub;
  StreamSubscription? _sentSub;
  Timer? _typingTimer;
  late final Realtime _rt = ref.read(realtimeProvider);
  late final _unread = ref.read(unreadChatProvider);
  late final _notifier = ref.read(notifierProvider);
  bool _iAmTyping = false;

  String get id => widget.conversation['id'] as String;
  String? get me => ref.read(sessionProvider).userId;

  @override
  void initState() {
    super.initState();
    _load();
    final rt = _rt; // khởi tạo tham chiếu ngay lúc mở phòng
    rt.joinConversation(id);
    _notifier.activeConversation = id;
    _sub = rt.events.listen((e) {
      if (!mounted) return;
      if (e.method == 'MessageReceived' && e.data['conversationId'] == id) {
        setState(() {
          messages.removeWhere((m) => m['id'] == e.data['id']);
          messages.insert(0, e.data);
          typing.remove(e.data['senderId']);
        });
        if (e.data['senderId'] != me) _markRead(e.data['id'] as String);
      } else if (e.method == 'Typing' && e.data['conversationId'] == id) {
        setState(() => e.data['isTyping'] == true ? typing.add(e.data['userId'] as String) : typing.remove(e.data['userId']));
      } else if (e.method == 'MessageRead' && e.data['conversationId'] == id) {
        setState(() => readBy[e.data['userId'] as String] = e.data['messageId'] as String);
      }
    });
    _sentSub = ref.read(syncProvider).outboxSent.listen((s) {
      if (s.kind == 'message' && s.result['conversationId'] == id && mounted) {
        setState(() {
          final i = messages.indexWhere((m) => m['id'] == s.result['id']);
          if (i >= 0) messages[i] = s.result;
        });
      }
    });
    scroll.addListener(() {
      if (scroll.position.pixels > scroll.position.maxScrollExtent - 200 && cursor != null) _load(more: true);
    });
  }

  @override
  void dispose() {
    if (_notifier.activeConversation == id) _notifier.activeConversation = null;
    _rt.leaveConversation(id); // dùng tham chiếu giữ từ initState (không gọi ref sau khi màn bị huỷ)
    _sub?.cancel();
    _sentSub?.cancel();
    _typingTimer?.cancel();
    text.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    try {
      final r = await ref.read(apiProvider).get<Map<String, dynamic>>('/conversations/$id/messages', query: {if (more) 'before': cursor, 'limit': 30});
      final items = (r['items'] as List).cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() {
        messages = more ? [...messages, ...items] : items;
        cursor = r['nextCursor'] as String?;
      });
      final lastOther = items.where((m) => m['senderId'] != me).firstOrNull;
      if (!more && lastOther != null) _markRead(lastOther['id'] as String);
    } catch (_) {}
  }

  void _markRead(String messageId) =>
      ref.read(apiProvider).post('/conversations/$id/read', {'messageId': messageId}).then((_) => _unread.refresh()).catchError((_) => null);

  void _send() {
    final content = text.text.trim();
    if (content.isEmpty) return;
    HapticFeedback.lightImpact();
    final msg = {'id': newId(), 'type': 1, 'content': content, 'clientSentAt': DateTime.now().toUtc().toIso8601String()};
    ref.read(storeProvider).enqueue('message', {...msg, 'conversationId': id});
    ref.read(syncProvider).schedule(const Duration(milliseconds: 50));
    setState(() {
      messages.insert(0, {...msg, 'conversationId': id, 'senderId': me, '_pending': true});
      text.clear();
    });
    _setTyping(false);
  }

  Future<void> _sendPhoto() async {
    final ids = await pickPhotos(context, ref, multiple: false);
    if (ids.isEmpty) return;
    final msg = {'id': newId(), 'type': 2, 'content': ids.first, 'clientSentAt': DateTime.now().toUtc().toIso8601String()};
    ref.read(storeProvider).enqueue('message', {...msg, 'conversationId': id});
    ref.read(syncProvider).schedule(const Duration(milliseconds: 50));
    setState(() => messages.insert(0, {...msg, 'conversationId': id, 'senderId': me, '_pending': true}));
  }

  void _setTyping(bool v) {
    if (_iAmTyping == v) return;
    _iAmTyping = v;
    ref.read(realtimeProvider).typing(id, v);
  }

  static DateTime _at(Map<String, dynamic> m) => DateTime.tryParse((m['serverReceivedAt'] ?? m['clientSentAt'] ?? '') as String)?.toLocal() ?? DateTime.now();

  @override
  Widget build(BuildContext context) {
    final members = (widget.conversation['members'] as List).cast<Map<String, dynamic>>();
    final others = members.where((m) => m['id'] != me).toList();
    final isGroup = widget.conversation['type'] == 2;
    final title = isGroup ? widget.conversation['name'] as String? ?? 'Nhóm' : others.firstOrNull?['displayName'] as String? ?? '';
    final online = others.any((o) => ref.watch(realtimeProvider).online.contains(o['id']) || o['isOnline'] == true);
    final scheme = Theme.of(context).colorScheme;
    Map<String, dynamic> userOf(String uid) => members.firstWhere((m) => m['id'] == uid, orElse: () => {'displayName': '?'});
    String nameOf(String uid) => userOf(uid)['displayName'] as String;
    final lastMine = messages.where((m) => m['senderId'] == me && m['_pending'] != true).firstOrNull;
    final seen = lastMine != null && readBy.values.contains(lastMine['id']);
    final hasText = text.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            if (!isGroup && others.isNotEmpty)
              UserAvatar(others.first, radius: 19)
            else
              CircleAvatar(
                radius: 19,
                backgroundColor: avatarColor(title),
                child: const Icon(Icons.groups_rounded, color: Colors.white, size: 20),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      typing.isNotEmpty
                          ? '${typing.map(nameOf).join(', ')} đang nhập...'
                          : (isGroup ? '${members.length} thành viên' : (online ? 'Đang hoạt động' : 'Ngoại tuyến')),
                      key: ValueKey('${typing.length}$online'),
                      style: TextStyle(
                        fontSize: 12,
                        color: typing.isNotEmpty || online ? (typing.isNotEmpty ? scheme.primary : AppColors.income) : scheme.onSurfaceVariant,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (!isGroup && others.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'report',
                  child: Row(
                    children: [
                      Icon(Icons.flag_rounded, size: 20, color: AppColors.warning),
                      SizedBox(width: 10),
                      Text('Báo cáo người dùng'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'block',
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
                final o = others.first;
                if (v == 'report') {
                  await reportContent(context, type: ReportTarget.user, id: o['id'] as String, userName: o['displayName'] as String);
                } else if (await blockUser(context, ref, userId: o['id'] as String, name: o['displayName'] as String) && context.mounted) {
                  context.pop();
                }
              },
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [scheme.surface, Color.lerp(scheme.surface, scheme.primary, 0.05)!],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isGroup && others.isNotEmpty) UserAvatar(others.first, radius: 40),
                          const SizedBox(height: 12),
                          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text('Gửi lời chào để bắt đầu 👋', style: TextStyle(color: scheme.onSurfaceVariant)),
                        ],
                      ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(0.9, 0.9)),
                    )
                  : ListView.builder(
                      controller: scroll,
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(10, 12, 12, 8),
                      itemCount: messages.length + (typing.isNotEmpty ? 1 : 0),
                      itemBuilder: (c, idx) {
                        // Ô "đang nhập" nằm dưới cùng (index 0 của danh sách đảo ngược)
                        if (typing.isNotEmpty && idx == 0) return const _TypingBubble();
                        final i = typing.isNotEmpty ? idx - 1 : idx;
                        final m = messages[i];
                        final mine = m['senderId'] == me;
                        final pending = m['_pending'] == true;
                        final at = _at(m);
                        // Liền kề (cũ hơn = i+1, mới hơn = i-1): gom nhóm tin cùng người, cách nhau < 5 phút
                        bool sameGroup(Map<String, dynamic>? o) =>
                            o != null && o['senderId'] == m['senderId'] && _at(o).difference(at).inMinutes.abs() < 5 && dateOnly(_at(o)) == dateOnly(at);
                        final older = i + 1 < messages.length ? messages[i + 1] : null;
                        final newer = i > 0 ? messages[i - 1] : null;
                        final first = !sameGroup(older); // tin đầu của nhóm
                        final lastOfGroup = !sameGroup(newer); // tin cuối của nhóm
                        final newDay = older == null || dateOnly(_at(older)) != dateOnly(at);
                        const r = Radius.circular(20), rs = Radius.circular(6);
                        final radius = BorderRadius.only(
                          topLeft: !mine && !first ? rs : r,
                          bottomLeft: !mine && !lastOfGroup ? rs : (mine ? r : rs),
                          topRight: mine && !first ? rs : r,
                          bottomRight: mine && !lastOfGroup ? rs : (mine ? rs : r),
                        );
                        final bubbleBox = Container(
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                          padding: m['type'] == 2 ? const EdgeInsets.all(3) : const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            gradient: mine
                                ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [scheme.primary, accentOf(scheme.primary)])
                                : null,
                            color: mine ? null : scheme.surfaceContainerHighest,
                            borderRadius: radius,
                            boxShadow: mine ? [BoxShadow(color: scheme.primary.withValues(alpha: 0.18), blurRadius: 8, offset: const Offset(0, 3))] : null,
                          ),
                          child: m['type'] == 2
                              ? Pressable(
                                  onTap: () => openGallery(context, [m['content'] as String], 0),
                                  child: ClipRRect(
                                    borderRadius: radius,
                                    child: SizedBox(width: 210, height: 210, child: FileImage2(m['content'] as String, radius: 0)),
                                  ),
                                )
                              : Text(m['content'] as String? ?? '', style: TextStyle(color: mine ? scheme.onPrimary : null, fontSize: 15, height: 1.3)),
                        );
                        // Tin của người khác: nhấn giữ để báo cáo / chặn
                        final bubble = mine || pending
                            ? bubbleBox
                            : GestureDetector(
                                onLongPress: () async {
                                  HapticFeedback.mediumImpact();
                                  final hide = await showContentActions(
                                    context,
                                    ref,
                                    type: ReportTarget.message,
                                    id: m['id'] as String,
                                    userId: m['senderId'] as String,
                                    userName: nameOf(m['senderId'] as String),
                                  );
                                  if (hide && mounted) setState(() => messages.remove(m));
                                },
                                child: bubbleBox,
                              );
                        return Column(
                              children: [
                                if (newDay)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
                                      child: Text(
                                        Fmt.dayHeader(at),
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
                                      ),
                                    ),
                                  ),
                                Padding(
                                  padding: EdgeInsets.only(top: first ? 8 : 2),
                                  child: Column(
                                    crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                    children: [
                                      if (isGroup && !mine && first)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 44, bottom: 3),
                                          child: Text(
                                            nameOf(m['senderId'] as String),
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: avatarColor(nameOf(m['senderId'] as String))),
                                          ),
                                        ),
                                      Row(
                                        mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          if (!mine) SizedBox(width: 36, child: lastOfGroup ? UserAvatar(userOf(m['senderId'] as String), radius: 14) : null),
                                          if (mine && pending)
                                            Padding(
                                              padding: const EdgeInsets.only(right: 4, bottom: 4),
                                              child: Icon(Icons.schedule_rounded, size: 13, color: scheme.onSurfaceVariant),
                                            ),
                                          Flexible(child: bubble),
                                        ],
                                      ),
                                      if (lastOfGroup)
                                        Padding(
                                          padding: EdgeInsets.only(top: 3, left: mine ? 0 : 44, right: 4),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(Fmt.time(at), style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
                                              if (i == 0 && mine && !pending) ...[
                                                const SizedBox(width: 4),
                                                Icon(
                                                  seen ? Icons.done_all_rounded : Icons.done_rounded,
                                                  size: 14,
                                                  color: seen ? scheme.primary : scheme.onSurfaceVariant,
                                                ),
                                                const SizedBox(width: 2),
                                                Text(
                                                  seen ? 'Đã xem' : 'Đã gửi',
                                                  style: TextStyle(fontSize: 10, color: seen ? scheme.primary : scheme.onSurfaceVariant),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                            .animate(key: ValueKey(m['id']))
                            .fadeIn(duration: 220.ms)
                            .slideY(begin: 0.25, end: 0, duration: 260.ms, curve: Curves.easeOutCubic)
                            .scaleXY(begin: 0.96, end: 1, alignment: mine ? Alignment.bottomRight : Alignment.bottomLeft, duration: 260.ms);
                      },
                    ),
            ),
            // ------------------------------------------------ Ô soạn tin
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            IconButton(
                              tooltip: 'Gửi ảnh',
                              onPressed: _sendPhoto,
                              icon: Icon(Icons.add_photo_alternate_rounded, color: scheme.primary),
                            ),
                            Expanded(
                              child: TextField(
                                controller: text,
                                minLines: 1,
                                maxLines: 5,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _send(),
                                onChanged: (v) {
                                  setState(() {});
                                  _setTyping(v.isNotEmpty);
                                  _typingTimer?.cancel();
                                  _typingTimer = Timer(const Duration(seconds: 3), () => _setTyping(false));
                                },
                                decoration: const InputDecoration(
                                  hintText: 'Nhắn tin...',
                                  filled: false,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.fromLTRB(0, 12, 12, 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedScale(
                      scale: hasText ? 1 : 0.85,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutBack,
                      child: AnimatedOpacity(
                        opacity: hasText ? 1 : 0.5,
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: [scheme.primary, accentOf(scheme.primary)]),
                          ),
                          child: IconButton(
                            onPressed: hasText ? _send : null,
                            icon: Icon(Icons.send_rounded, color: scheme.onPrimary, size: 22),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bong bóng "đang nhập..." với 3 chấm nhấp nháy.
class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(left: 36, top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(18)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(color: scheme.onSurfaceVariant, shape: BoxShape.circle),
                  )
                  .animate(onPlay: (c) => c.repeat())
                  .fadeIn(delay: (i * 150).ms, duration: 300.ms)
                  .moveY(begin: 0, end: -4, duration: 300.ms, curve: Curves.easeOut)
                  .then()
                  .moveY(begin: 0, end: 4, duration: 300.ms, curve: Curves.easeIn),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 200.ms).scale(begin: const Offset(0.8, 0.8), alignment: Alignment.bottomLeft);
  }
}
