import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../core/ui.dart';
import '../data/notify_prefs.dart';
import '../data/local_store.dart';
import '../providers.dart';
import 'common.dart';

/// Cài đặt âm thanh thông báo: âm riêng cho từng nhóm, rung, âm lượng trong app, giờ yên lặng.
class NotifySettingsPage extends ConsumerWidget {
  const NotifySettingsPage({super.key});

  static const _kindIcons = {
    NotifyKind.chat: (Icons.chat_bubble_rounded, Color(0xFF12A594)),
    NotifyKind.social: (Icons.people_alt_rounded, Color(0xFF0090FF)),
    NotifyKind.reminder: (Icons.alarm_rounded, Color(0xFF8E4EC6)),
    NotifyKind.finance: (Icons.account_balance_wallet_rounded, Color(0xFFF76B15)),
  };

  static String _hm(int minutes) => '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watchTables(const [E.appSettings]);
    final p = NotifyPrefs.of(store);
    final notifier = ref.read(notifierProvider);
    final scheme = Theme.of(context).colorScheme;
    void save(NotifyPrefs n) => n.save(store);

    return Scaffold(
      appBar: AppBar(title: const Text('Âm thanh thông báo')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          AppCard(
            gradient: LinearGradient(colors: [scheme.primary.withValues(alpha: 0.22), scheme.primary.withValues(alpha: 0.05)]),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: p.enabled ? scheme.primary : scheme.surfaceContainerHighest, shape: BoxShape.circle),
                  child: Icon(p.enabled ? Icons.notifications_active_rounded : Icons.notifications_off_rounded, color: p.enabled ? scheme.onPrimary : null),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Cho phép thông báo', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      Text(
                        p.enabled ? 'Đang bật · chỉnh âm thanh từng loại bên dưới' : 'Đang tắt toàn bộ thông báo',
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Switch(value: p.enabled, onChanged: (v) => save(p.copyWith({'enabled': v}))),
              ],
            ),
          ),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: p.enabled ? 1 : 0.45,
            child: IgnorePointer(
              ignoring: !p.enabled,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionTitle('Theo loại thông báo'),
                  for (final (i, k) in NotifyKind.all.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _KindCard(
                        kind: k,
                        icon: _kindIcons[k.id]!.$1,
                        color: _kindIcons[k.id]!.$2,
                        prefs: p,
                        onChanged: save,
                        onTest: () => notifier.show('${k.label} · thử', 'Âm thanh: ${NotifySound.of(p.sound(k.id)).label}', kind: k.id),
                      ).stagger(i),
                    ),
                  const SectionTitle('Khi đang mở app'),
                  AppCard(
                    child: Column(
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          secondary: const Icon(Icons.volume_up_rounded),
                          title: const Text('Phát âm thanh trong app'),
                          subtitle: const Text('Khi có thông báo lúc đang dùng app'),
                          value: p.inAppSound,
                          onChanged: (v) => save(p.copyWith({'inAppSound': v})),
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 250),
                          child: !p.inAppSound
                              ? const SizedBox(width: double.infinity)
                              : Row(
                                  children: [
                                    const Icon(Icons.volume_down_rounded, size: 20),
                                    Expanded(
                                      child: Slider(
                                        value: p.volume,
                                        divisions: 10,
                                        label: '${(p.volume * 100).round()}%',
                                        onChanged: (v) => save(p.copyWith({'volume': v})),
                                        onChangeEnd: (v) => notifier.playSound('ting', volume: v),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 44,
                                      child: Text(
                                        '${(p.volume * 100).round()}%',
                                        textAlign: TextAlign.end,
                                        style: const TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SectionTitle('Giờ yên lặng'),
                  AppCard(
                    child: Column(
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          secondary: const Icon(Icons.bedtime_rounded, color: Color(0xFF6E56CF)),
                          title: const Text('Không phát âm thanh, không rung'),
                          subtitle: Text(p.quietEnabled ? 'Từ ${_hm(p.quietFrom)} đến ${_hm(p.quietTo)} · thông báo vẫn hiện nhưng im lặng' : 'Tắt'),
                          value: p.quietEnabled,
                          onChanged: (v) => save(p.copyWith({'quietEnabled': v})),
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 250),
                          child: !p.quietEnabled
                              ? const SizedBox(width: double.infinity)
                              : Row(
                                  children: [
                                    for (final (label, key, value) in [('Bắt đầu', 'quietFrom', p.quietFrom), ('Kết thúc', 'quietTo', p.quietTo)])
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.all(4),
                                          child: Pressable(
                                            onTap: () async {
                                              final t = await showModernTimePicker(
                                                context,
                                                initial: TimeOfDay(hour: value ~/ 60, minute: value % 60),
                                                title: 'Giờ yên lặng · $label',
                                              );
                                              if (t != null) save(p.copyWith({key: t.hour * 60 + t.minute}));
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(vertical: 10),
                                              decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(14)),
                                              child: Column(
                                                children: [
                                                  Text(label, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                                                  Text(_hm(value), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                  if (kIsWeb)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(
                        'Trên web chỉ phát âm thanh khi app đang mở. Âm riêng cho thông báo hệ thống và rung áp dụng trên app iOS/Android.',
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KindCard extends ConsumerWidget {
  const _KindCard({required this.kind, required this.icon, required this.color, required this.prefs, required this.onChanged, required this.onTest});
  final NotifyKind kind;
  final IconData icon;
  final Color color;
  final NotifyPrefs prefs;
  final ValueChanged<NotifyPrefs> onChanged;
  final VoidCallback onTest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final on = prefs.kindEnabled(kind.id);
    final sound = NotifySound.of(prefs.sound(kind.id));
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(kind.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    Text(kind.description, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Switch(value: on, onChanged: (v) => onChanged(prefs.withKind(kind.id, {'enabled': v}))),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child: !on
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 10, right: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Pressable(
                            onTap: () => _pickSound(context, ref),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(14)),
                              child: Row(
                                children: [
                                  Icon(sound.id == NotifySound.silent ? Icons.volume_off_rounded : Icons.music_note_rounded, size: 18, color: color),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(sound.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  ),
                                  Icon(Icons.expand_more_rounded, color: scheme.onSurfaceVariant),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Tooltip(
                          message: prefs.vibrate(kind.id) ? 'Đang rung' : 'Không rung',
                          child: IconButton.filledTonal(
                            isSelected: prefs.vibrate(kind.id),
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                              onChanged(prefs.withKind(kind.id, {'vibrate': !prefs.vibrate(kind.id)}));
                            },
                            icon: const Icon(Icons.mobile_off_rounded),
                            selectedIcon: const Icon(Icons.vibration_rounded),
                          ),
                        ),
                        IconButton(tooltip: 'Thử', onPressed: onTest, icon: const Icon(Icons.play_circle_rounded)),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// Bảng chọn âm: bấm để nghe thử ngay, dấu ✓ là âm đang dùng.
  Future<void> _pickSound(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(notifierProvider);
    var current = prefs.sound(kind.id);
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      sheetAnimationStyle: kSheetAnim,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          final scheme = Theme.of(ctx).colorScheme;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Âm thanh · ${kind.label}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('Bấm để nghe thử', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 10),
                  for (final s in NotifySound.all)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Pressable(
                        onTap: () {
                          set(() => current = s.id);
                          if (s.id != NotifySound.silent) notifier.playSound(s.id);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: current == s.id ? color.withValues(alpha: 0.15) : scheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: current == s.id ? color : Colors.transparent, width: 1.4),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                s.id == NotifySound.silent
                                    ? Icons.volume_off_rounded
                                    : (s.id == NotifySound.system ? Icons.phone_iphone_rounded : Icons.graphic_eq_rounded),
                                color: current == s.id ? color : scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(s.label, style: TextStyle(fontWeight: current == s.id ? FontWeight.w800 : FontWeight.w500)),
                              ),
                              AnimatedScale(
                                scale: current == s.id ? 1 : 0,
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOutBack,
                                child: Icon(Icons.check_circle_rounded, color: color),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48)),
                    onPressed: () => Navigator.pop(ctx, current),
                    child: const Text('Dùng âm này'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (picked != null) onChanged(prefs.withKind(kind.id, {'sound': picked}));
  }
}
