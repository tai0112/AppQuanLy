import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../data/local_store.dart';
import '../data/models.dart';
import '../data/notify_prefs.dart';
import '../providers.dart';
import 'common.dart';

/// Hũ có sóng nước dâng lên theo % tiến độ.
class JarFill extends StatefulWidget {
  const JarFill({super.key, required this.progress, required this.color, this.size = 90});
  final double progress;
  final Color color;
  final double size;

  @override
  State<JarFill> createState() => _JarFillState();
}

class _JarFillState extends State<JarFill> with SingleTickerProviderStateMixin {
  late final wave = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();

  @override
  void dispose() {
    wave.dispose();
    super.dispose();
  }

  @override
  // RepaintBoundary: sóng nước chạy liên tục chỉ vẽ lại trong hũ, không làm cả lưới vẽ lại.
  Widget build(BuildContext context) => RepaintBoundary(child: _fill(context));

  Widget _fill(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: widget.progress.clamp(0, 1)),
    duration: const Duration(milliseconds: 1200),
    curve: Curves.easeOutCubic,
    builder: (_, level, __) => AnimatedBuilder(
      animation: wave,
      builder: (_, __) => CustomPaint(
        isComplex: true,
        size: Size(widget.size * 0.8, widget.size),
        painter: _JarPainter(level, wave.value, widget.color, Theme.of(context).colorScheme.outlineVariant),
      ),
    ),
  );
}

class _JarPainter extends CustomPainter {
  _JarPainter(this.level, this.phase, this.color, this.outline);
  final double level;
  final double phase;
  final Color color;
  final Color outline;

  @override
  void paint(Canvas canvas, Size s) {
    final body = RRect.fromRectAndRadius(Rect.fromLTWH(0, s.height * 0.14, s.width, s.height * 0.86), Radius.circular(s.width * 0.22));
    final lid = RRect.fromRectAndRadius(Rect.fromLTWH(s.width * 0.18, 0, s.width * 0.64, s.height * 0.12), const Radius.circular(6));
    canvas.drawRRect(lid, Paint()..color = color.withValues(alpha: 0.8));
    canvas.save();
    canvas.clipRRect(body);
    canvas.drawRRect(body, Paint()..color = color.withValues(alpha: 0.08));
    final top = body.top + body.height * (1 - level);
    final path = Path()..moveTo(0, s.height);
    for (double x = 0; x <= s.width; x++) {
      path.lineTo(x, top + sin((x / s.width * 2 * pi) + phase * 2 * pi) * (level > 0 && level < 1 ? 4 : 0));
    }
    path
      ..lineTo(s.width, s.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.75));
    canvas.restore();
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = outline,
    );
  }

  @override
  bool shouldRepaint(_JarPainter old) => old.level != level || old.phase != phase;
}

class JarsPage extends ConsumerWidget {
  const JarsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(financeProvider);
    final jars = ref.watchTables(const [E.savingsJars]).all(E.savingsJars).map(Jar.new).toList();
    final total = jars.fold(0.0, (s, j) => s + f.convert(f.jarSaved(j.id), j.currencyCode, f.baseCurrency));
    return Scaffold(
      appBar: AppBar(title: const Text('Hũ tiết kiệm')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Tạo hũ',
        onPressed: () => editJar(context, ref, null),
        child: const Icon(Icons.add_rounded, size: 30),
      ),
      body: jars.isEmpty
          ? EmptyState(
              icon: Icons.savings_rounded,
              title: 'Chưa có hũ nào',
              subtitle: 'Tạo hũ cho từng mục tiêu: du lịch, mua xe, quỹ khẩn cấp...',
              action: FilledButton(onPressed: () => editJar(context, ref, null), child: const Text('Tạo hũ đầu tiên')),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                AppCard(
                  gradient: LinearGradient(colors: [AppColors.warning, AppColors.warning.withValues(alpha: 0.7)]),
                  child: Row(
                    children: [
                      const Icon(Icons.savings_rounded, color: Colors.white, size: 40),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Đã tiết kiệm', style: TextStyle(color: Colors.white70)),
                          AnimatedAmount(
                            value: total,
                            format: (v) => f.money(v),
                            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.78,
                  children: [
                    for (final (i, j) in jars.indexed)
                      OpenCard(
                        page: JarDetailPage(id: j.id),
                        child: Column(
                          children: [
                            Hero(
                              tag: 'jar-${j.id}',
                              child: JarFill(progress: j.target <= 0 ? 0 : f.jarSaved(j.id) / j.target, color: hexColor(j.color, AppColors.warning)),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              j.name,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            CountText(
                              values: [f.jarSaved(j.id)],
                              text: (cv) => f.money(cv[0], j.currencyCode),
                              style: TextStyle(color: hexColor(j.color, AppColors.warning), fontWeight: FontWeight.w700),
                            ),
                            CountText(values: [j.target], text: (cv) => '/ ${f.money(cv[0], j.currencyCode)}', style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ).stagger(i),
                  ],
                ),
              ],
            ),
    );
  }
}

Future<void> editJar(BuildContext context, WidgetRef ref, Jar? j) async {
  final f = ref.read(financeProvider);
  final name = TextEditingController(text: j?.name);
  final target = TextEditingController(text: j == null ? '' : amountText(j.target));
  var color = hexColor(j?.color, AppColors.palette[2]);
  var icon = j?.icon ?? 'savings';
  DateTime? deadline = j?.deadline;
  await showModalBottomSheet(
    sheetAnimationStyle: kSheetAnim,
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => FormSheetBody(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        action: FilledButton(
          onPressed: () {
            if (name.text.trim().isEmpty) return;
            ref.read(storeProvider).put(E.savingsJars, {
              if (j != null) ...j.m,
              'name': name.text.trim(),
              'targetAmount': parseAmount(target.text),
              'currencyCode': j?.currencyCode ?? f.baseCurrency,
              'deadline': deadline == null ? null : Fmt.isoDate(deadline!),
              'color': colorHex(color),
              'icon': icon,
            });
            Navigator.pop(ctx);
          },
          child: const Text('Lưu'),
        ),
        children: [
          Text(j == null ? 'Tạo hũ tiết kiệm' : 'Sửa hũ', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Tên hũ (VD: Du lịch Nhật)'),
          ),
          const SizedBox(height: 12),
          AmountField(controller: target, label: 'Mục tiêu', suffix: f.currency(f.baseCurrency)?.symbol),
          InfoTile(
            icon: Icons.flag_rounded,
            label: 'Hạn hoàn thành',
            value: deadline == null ? 'Không đặt' : Fmt.date(deadline!),
            onTap: () async {
              final d = await pickDateTime(ctx, deadline ?? DateTime.now().add(const Duration(days: 180)), withTime: false);
              set(() => deadline = d);
            },
          ),
          const SizedBox(height: 8),
          ColorPickerRow(value: color, onChanged: (c) => set(() => color = c)),
        ],
      ),
    ),
  );
}

class JarDetailPage extends ConsumerWidget {
  const JarDetailPage({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(financeProvider);
    final store = ref.watchTables(const [E.savingsJars]);
    final rec = store.get(E.savingsJars, id);
    if (rec == null) return const Scaffold(body: Center(child: Text('Hũ đã bị xoá')));
    final j = Jar(rec);
    final saved = f.jarSaved(id);
    final color = hexColor(j.color, AppColors.warning);
    final history = store.all(E.jarTransactions).map(JarTxn.new).where((x) => x.jarId == id).toList()..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final pct = j.target <= 0 ? 0.0 : saved / j.target;
    final daysLeft = j.deadline?.difference(DateTime.now()).inDays;
    final session = ref.watch(sessionProvider);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(j.name),
        actions: [
          if (session.isLoggedIn)
            IconButton(
              tooltip: 'Khoe lên bảng tin',
              onPressed: () => context.push('/feed/compose', extra: {'jarId': id}),
              icon: const Icon(Icons.share_rounded),
            ),
          IconButton(onPressed: () => editJar(context, ref, j), icon: const Icon(Icons.edit_rounded)),
          IconButton(
            onPressed: () async {
              if (await confirm(context, 'Xoá hũ "${j.name}"?', danger: true, ok: 'Xoá')) {
                store.remove(E.savingsJars, id);
                if (context.mounted) context.pop();
              }
            },
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          // Thẻ hũ: nút − / + hai bên, số tiền và tiến độ bên dưới
          Container(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0.04)],
              ),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _RoundAction(icon: Icons.remove_rounded, label: 'Rút', color: AppColors.expense, onTap: () => _move(context, ref, j, false)),
                    ),
                    Hero(
                      tag: 'jar-$id',
                      child: JarFill(progress: pct, color: color, size: 170),
                    ),
                    Expanded(
                      child: _RoundAction(icon: Icons.add_rounded, label: 'Nạp', color: color, filled: true, onTap: () => _move(context, ref, j, true)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                AnimatedAmount(
                  value: saved,
                  format: (v) => f.money(v, j.currencyCode),
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: color),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: pct.clamp(0.0, 1.0)),
                    duration: const Duration(milliseconds: 1000),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 10, color: color, backgroundColor: color.withValues(alpha: 0.15)),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    CountText(
                      values: [pct * 100],
                      text: (cv) => '${cv[0].toStringAsFixed(1)}%',
                      style: TextStyle(fontWeight: FontWeight.w800, color: color),
                    ),
                    const Spacer(),
                    CountText(
                      values: [j.target],
                      text: (cv) => 'Mục tiêu ${f.money(cv[0], j.currencyCode)}',
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Stat(
                icon: Icons.flag_rounded,
                label: saved >= j.target && j.target > 0 ? 'Đã đạt' : 'Còn thiếu',
                value: saved >= j.target && j.target > 0 ? '🎉' : f.money(max(0, j.target - saved), j.currencyCode),
                color: color,
              ),
              const SizedBox(width: 8),
              _Stat(
                icon: Icons.event_rounded,
                label: 'Hạn',
                value: daysLeft == null ? 'Không đặt' : (daysLeft > 0 ? 'Còn $daysLeft ngày' : 'Quá hạn'),
                color: daysLeft != null && daysLeft <= 0 ? AppColors.expense : color,
              ),
              if (daysLeft != null && daysLeft > 0 && saved < j.target) ...[
                const SizedBox(width: 8),
                _Stat(
                  icon: Icons.trending_up_rounded,
                  label: 'Cần mỗi tháng',
                  value: f.money((j.target - saved) / max(1, daysLeft / 30), j.currencyCode),
                  color: color,
                ),
              ],
            ],
          ),
          SectionTitle(
            'Lịch sử',
            trailing: history.isEmpty ? null : Text('${history.length} lần', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          ),
          if (history.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text('Chưa có lần nạp/rút nào', style: TextStyle(color: scheme.onSurfaceVariant)),
              ),
            ),
          for (final (i, h) in history.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Dismissible(
                key: ValueKey(h.id),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) => confirm(context, 'Xoá lần ${h.amount >= 0 ? 'nạp' : 'rút'} này?', danger: true, ok: 'Xoá'),
                onDismissed: (_) => store.remove(E.jarTransactions, h.id),
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(color: AppColors.expense.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(AppRadius.lg)),
                  child: const Icon(Icons.delete_outline_rounded, color: AppColors.expense),
                ),
                child: AppCard(
                  padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: (h.amount >= 0 ? AppColors.income : AppColors.expense).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          h.amount >= 0 ? Icons.south_west_rounded : Icons.north_east_rounded,
                          color: h.amount >= 0 ? AppColors.income : AppColors.expense,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              h.note?.isNotEmpty == true ? h.note! : (h.amount >= 0 ? 'Nạp vào hũ' : 'Rút khỏi hũ'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              [Fmt.dateTime(h.occurredAt), f.account(h.accountId)?.name].whereType<String>().join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      CountText(
                        values: [h.amount],
                        text: (cv) => f.money(cv[0], j.currencyCode, true),
                        style: TextStyle(fontWeight: FontWeight.w800, color: h.amount >= 0 ? AppColors.income : AppColors.expense),
                      ),
                    ],
                  ),
                ),
              ),
            ).stagger(i),
        ],
      ),
    );
  }

  Future<void> _move(BuildContext context, WidgetRef ref, Jar j, bool deposit) async {
    final f = ref.read(financeProvider);
    final amount = TextEditingController();
    final note = TextEditingController();
    Account? acc = f.accounts.where((a) => !a.isArchived).firstOrNull;
    await showModalBottomSheet(
      sheetAnimationStyle: kSheetAnim,
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => FormSheetBody(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          action: FilledButton(
            onPressed: () {
              final v = parseAmount(amount.text);
              if (v <= 0) return;
              ref.read(storeProvider).put(E.jarTransactions, {
                'jarId': j.id,
                'accountId': acc?.id,
                'amount': deposit ? v : -v,
                'note': note.text.trim().isEmpty ? null : note.text.trim(),
                'occurredAt': toIso8601WithOffset(DateTime.now()),
              });
              Navigator.pop(ctx);
              if (deposit && f.jarSaved(j.id) + v >= j.target && j.target > 0) {
                ref.read(notifierProvider).show('Chúc mừng! 🎉', 'Hũ "${j.name}" đã đạt mục tiêu', kind: NotifyKind.finance);
              }
            },
            child: Text(deposit ? 'Nạp' : 'Rút'),
          ),
          children: [
            Text(deposit ? 'Nạp vào hũ' : 'Rút từ hũ', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            AmountField(controller: amount, autofocus: true, suffix: f.currency(j.currencyCode)?.symbol),
            InfoTile(
              icon: Icons.account_balance_wallet,
              label: deposit ? 'Lấy từ' : 'Chuyển về',
              value: acc?.name ?? 'Không chọn',
              onTap: () async {
                final a = await pickAccount(ctx, ref);
                set(() => acc = a);
              },
            ),
            TextField(
              controller: note,
              decoration: const InputDecoration(labelText: 'Ghi chú'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nút tròn lớn (Nạp / Rút) cạnh hũ.
class _RoundAction extends StatelessWidget {
  const _RoundAction({required this.icon, required this.label, required this.color, required this.onTap, this.filled = false});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Pressable(
        onTap: onTap,
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: filled ? LinearGradient(colors: [color, accentOf(color, hue: 15)]) : null,
            color: filled ? null : color.withValues(alpha: 0.14),
            border: filled ? null : Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
            boxShadow: filled ? [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 14, offset: const Offset(0, 5))] : null,
          ),
          child: Icon(icon, size: 30, color: filled ? Colors.white : color),
        ),
      ),
      const SizedBox(height: 6),
      Text(
        label,
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: filled ? color : null),
      ),
    ],
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, required this.value, required this.color});
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          ),
        ],
      ),
    ),
  );
}
