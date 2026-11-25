import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../data/local_store.dart';
import '../data/logic.dart';
import '../data/models.dart';
import '../data/api.dart';
import '../providers.dart';
import 'common.dart';
import 'social.dart';

/// Đếm ngày yêu: số ngày, năm/tháng/ngày, mốc sắp tới, sinh nhật người ấy.
class LovePage extends ConsumerWidget {
  const LovePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watchTables(const [E.loveCounters]);
    final rec = store.all(E.loveCounters).firstOrNull;
    if (rec == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ngày yêu')),
        body: EmptyState(
          icon: Icons.favorite_rounded,
          title: 'Bắt đầu đếm ngày yêu',
          subtitle: 'Nhập ngày bắt đầu và tên người ấy',
          action: FilledButton(onPressed: () => _edit(context, ref, null), child: const Text('Thiết lập')),
        ),
      );
    }
    final l = LoveCounter(rec);
    final days = Love.days(l.startDate);
    final (y, m, d) = Love.ymd(l.startDate);
    final bd = Love.nextBirthday(l.partnerBirthday);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ngày yêu'),
        actions: [IconButton(onPressed: () => _edit(context, ref, l), icon: const Icon(Icons.edit_rounded))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            padding: const EdgeInsets.all(24),
            gradient: const LinearGradient(colors: [Color(0xFFFF8FAB), Color(0xFFE93D82)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Avatar(fileId: l.myPhoto, label: 'Tôi'),
                    const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Icon(Icons.favorite_rounded, color: Colors.white, size: 40),
                        )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scale(begin: const Offset(0.85, 0.85), end: const Offset(1.15, 1.15), duration: 800.ms, curve: Curves.easeInOut)
                        .isolated(),
                    _Avatar(fileId: l.partnerPhoto, label: l.partnerName),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('Đã bên nhau', style: TextStyle(color: Colors.white70)),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: days.toDouble()),
                  duration: const Duration(milliseconds: 1500),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => Text(
                    '${v.round()}',
                    style: const TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.w900, height: 1.1),
                  ),
                ),
                const Text('ngày', style: TextStyle(color: Colors.white, fontSize: 18)),
                const SizedBox(height: 8),
                Text('$y năm $m tháng $d ngày · từ ${Fmt.date(l.startDate)}', style: const TextStyle(color: Colors.white)),
              ],
            ),
          ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.05),
          if (ref.watch(sessionProvider).isLoggedIn) ...[const SizedBox(height: 12), _LinkCard(love: l)],
          const SectionTitle('Mốc sắp tới'),
          for (final (i, ms) in Love.milestones(l.startDate, count: 5).indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(Icons.celebration_rounded, color: AppColors.love),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ms.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(Fmt.dayHeader(ms.date), style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    Text(
                      ms.daysLeft == 0 ? 'Hôm nay 🎉' : 'còn ${ms.daysLeft} ngày',
                      style: const TextStyle(color: AppColors.love, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ).stagger(i),
            ),
          if (bd != null) ...[
            const SectionTitle('Sinh nhật'),
            AppCard(
              child: Row(
                children: [
                  const Icon(Icons.cake_rounded, color: AppColors.love),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Sinh nhật ${l.partnerName}: ${Fmt.date(bd)}')),
                  Text('còn ${bd.difference(dateOnly(DateTime.now())).inDays} ngày', style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Nhắc trước ${l.reminderDays} ngày cho mỗi mốc',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, LoveCounter? l) async {
    final name = TextEditingController(text: l?.partnerName);
    var start = l?.startDate ?? DateTime.now();
    DateTime? bd = l?.partnerBirthday;
    var reminder = (l?.reminderDays ?? 3).toDouble();
    String? myPhoto = l?.myPhoto, partnerPhoto = l?.partnerPhoto;
    await showModalBottomSheet(
      sheetAnimationStyle: kSheetAnim,
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Thiết lập ngày yêu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Pressable(
                      onTap: () async {
                        final ids = await pickPhotos(ctx, ref, multiple: false);
                        if (ids.isNotEmpty) set(() => myPhoto = ids.first);
                      },
                      child: _Avatar(fileId: myPhoto, label: 'Ảnh của tôi', dark: true),
                    ),
                    Pressable(
                      onTap: () async {
                        final ids = await pickPhotos(ctx, ref, multiple: false);
                        if (ids.isNotEmpty) set(() => partnerPhoto = ids.first);
                      },
                      child: _Avatar(fileId: partnerPhoto, label: 'Ảnh người ấy', dark: true),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Tên người ấy'),
                ),
                InfoTile(
                  icon: Icons.favorite,
                  label: 'Ngày bắt đầu',
                  value: Fmt.date(start),
                  color: AppColors.love,
                  onTap: () async {
                    final d = await pickDateTime(ctx, start, withTime: false);
                    if (d != null) set(() => start = d);
                  },
                ),
                InfoTile(
                  icon: Icons.cake,
                  label: 'Sinh nhật người ấy',
                  value: bd == null ? 'Chưa đặt' : Fmt.date(bd!),
                  color: AppColors.love,
                  onTap: () async {
                    final d = await pickDateTime(ctx, bd ?? DateTime(2000), withTime: false);
                    if (d != null) set(() => bd = d);
                  },
                ),
                Text('Nhắc trước ${reminder.round()} ngày'),
                Slider(value: reminder, min: 0, max: 14, divisions: 14, onChanged: (v) => set(() => reminder = v)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  if (name.text.trim().isEmpty) return;
                  ref.read(storeProvider).put(E.loveCounters, {
                    if (l != null) 'id': l.id,
                    'partnerName': name.text.trim(),
                    'startDate': Fmt.isoDate(start),
                    'partnerBirthday': bd == null ? null : Fmt.isoDate(bd!),
                    'myPhotoFileId': myPhoto,
                    'partnerPhotoFileId': partnerPhoto,
                    'milestoneReminderDays': reminder.round(),
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Lưu'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.fileId, required this.label, this.dark = false});
  final String? fileId;
  final String label;
  final bool dark;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          color: Colors.white24,
        ),
        child: ClipOval(child: fileId == null ? const Icon(Icons.person_rounded, color: Colors.white, size: 40) : FileImage2(fileId!, radius: 0)),
      ),
      const SizedBox(height: 6),
      Text(
        label,
        style: TextStyle(color: dark ? null : Colors.white, fontWeight: FontWeight.w600),
      ),
    ],
  );
}

/// Liên kết tài khoản người ấy (xác nhận hai chiều): mời / chờ xác nhận / đã là một đôi.
class _LinkCard extends ConsumerWidget {
  const _LinkCard({required this.love});
  final LoveCounter love;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final couple = ref.watch(coupleProvider);
    final scheme = Theme.of(context).colorScheme;
    final partner = couple.partner;
    final out = (couple.outgoing?['user'] as Map?)?.cast<String, dynamic>();

    Widget body;
    if (couple.incoming.isNotEmpty && partner == null) {
      final u = (couple.incoming.first['user'] as Map).cast<String, dynamic>();
      return CoupleInviteCard(user: u, onAnswer: (ok) => answerCouple(context, ref, u, ok));
    } else if (partner != null) {
      body = Row(
        key: const ValueKey('linked'),
        children: [
          UserAvatar(partner, radius: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(partner['displayName'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  '@${partner['username']} · đã xác nhận${couple.since == null ? '' : ' từ ${Fmt.date(couple.since!)}'} ❤️',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Nhắn tin',
            onPressed: () async {
              try {
                final c = await ref.read(apiProvider).post<Map<String, dynamic>>('/conversations/direct', {'userId': partner['id']});
                if (context.mounted) context.push('/chat/room', extra: c);
              } on ApiException catch (e) {
                if (context.mounted) showToast(context, e.message, error: true);
              }
            },
            icon: const Icon(Icons.chat_bubble_rounded, size: 20),
          ),
          PopupMenuButton(
            itemBuilder: (_) => [const PopupMenuItem(value: 1, child: Text('Huỷ liên kết người yêu'))],
            onSelected: (_) => setPartner(context, ref, null),
          ),
        ],
      );
    } else if (out != null) {
      body = Row(
        key: const ValueKey('pending'),
        children: [
          UserAvatar(out, radius: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Đang chờ ${out['displayName']} xác nhận', style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('Khi người ấy đồng ý, hai bạn sẽ thấy nhau là người yêu', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          TextButton(onPressed: () => setPartner(context, ref, null), child: const Text('Huỷ')),
        ],
      );
    } else {
      body = Row(
        key: const ValueKey('none'),
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.love.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: const Icon(Icons.link_rounded, color: AppColors.love),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Liên kết tài khoản người ấy', style: TextStyle(fontWeight: FontWeight.w700)),
                Text('Gửi lời mời, người ấy đồng ý thì hai bạn chính thức là một đôi', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
          FilledButton.tonal(
            onPressed: () async {
              final f = await pickFriend(context, ref, title: 'Mời ai làm người yêu?');
              if (f != null && context.mounted) await setPartner(context, ref, f);
            },
            child: const Text('Mời'),
          ),
        ],
      );
    }
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: body),
    );
  }
}
