import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../data/local_store.dart';
import '../data/models.dart';
import '../providers.dart';
import 'common.dart';

const _periods = {1: 'Ngày', 2: 'Tuần', 3: 'Tháng', 4: 'Năm'};

/// Thẻ định mức: thanh tiến độ đổi màu xanh → vàng → đỏ.
class BudgetCard extends ConsumerWidget {
  const BudgetCard({super.key, required this.budget, this.onTap});
  final Budget budget;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(financeProvider);
    final spent = f.budgetSpent(budget);
    final pct = budget.limit <= 0 ? 0.0 : spent / budget.limit;
    final color = pct >= 1
        ? AppColors.expense
        : pct * 100 >= budget.warnPercent
        ? AppColors.warning
        : AppColors.income;
    final (from, to) = f.budgetRange(budget, DateTime.now());
    final daysLeft = to.difference(DateTime.now()).inDays + 1;
    final perDay = daysLeft > 0 ? (budget.limit - spent) / daysLeft : 0;
    final scope = switch (budget.scope) {
      2 => f.category(budget.refId)?.name ?? 'Danh mục',
      3 => f.account(budget.refId)?.name ?? 'Tài khoản',
      _ => 'Tất cả khoản chi',
    };
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(budget.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              Text(
                '${(pct * 100).toStringAsFixed(0)}%',
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          Text(
            '$scope · theo ${_periods[budget.period]!.toLowerCase()}',
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: pct.clamp(0, 1)),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => LinearProgressIndicator(value: v, minHeight: 10, color: color, backgroundColor: color.withValues(alpha: 0.15)),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: CountText(
                  values: [spent, budget.limit],
                  text: (cv) => '${f.money(cv[0], budget.currencyCode)} / ${f.money(cv[1], budget.currencyCode)}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              CountText(
                values: [(spent - budget.limit).toDouble(), perDay.toDouble()],
                text: (cv) => pct >= 1 ? 'Vượt ${f.money(cv[0], budget.currencyCode)}' : 'Còn ${f.money(cv[1], budget.currencyCode)}/ngày',
                style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Định mức chi tiêu + cảnh báo khi sắp vượt / đã vượt.
class BudgetsPage extends ConsumerWidget {
  const BudgetsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watchTables(const [E.budgets]);
    final all = store.all(E.budgets).map(Budget.new).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Định mức chi tiêu')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Thêm định mức'),
      ),
      body: all.isEmpty
          ? EmptyState(
              icon: Icons.speed_rounded,
              title: 'Chưa có định mức',
              subtitle: 'Đặt hạn mức chi tiêu theo tháng/tuần/ngày cho tổng hoặc từng danh mục. App sẽ cảnh báo khi sắp vượt.',
              action: FilledButton(onPressed: () => _edit(context, ref, null), child: const Text('Tạo định mức')),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                for (final (i, b) in all.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: BudgetCard(budget: b, onTap: () => _edit(context, ref, b)).stagger(i),
                  ),
              ],
            ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Budget? b) async {
    final f = ref.read(financeProvider);
    final name = TextEditingController(text: b?.name);
    final limit = TextEditingController(text: b == null ? '' : amountText(b.limit));
    var scope = b?.scope ?? 1;
    var refId = b?.refId;
    var period = b?.period ?? 3;
    var warn = (b?.warnPercent ?? 80).toDouble();
    var active = b?.isActive ?? true;
    await showModalBottomSheet(
      sheetAnimationStyle: kSheetAnim,
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => FormSheetBody(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          action: Row(
            children: [
              if (b != null)
                TextButton(
                  onPressed: () {
                    ref.read(storeProvider).remove(E.budgets, b.id);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Xoá', style: TextStyle(color: AppColors.expense)),
                ),
              const Spacer(),
              FilledButton(
                onPressed: () {
                  final v = parseAmount(limit.text);
                  if (v <= 0 || (scope != 1 && refId == null)) return showToast(ctx, 'Nhập đủ thông tin', error: true);
                  ref.read(storeProvider).put(E.budgets, {
                    if (b != null) 'id': b.id,
                    'name': name.text.trim().isEmpty ? 'Định mức' : name.text.trim(),
                    'scope': scope,
                    'refId': refId,
                    'period': period,
                    'limitAmount': v,
                    'currencyCode': f.baseCurrency,
                    'warnPercent': warn.round(),
                    'isActive': active,
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Lưu'),
              ),
            ],
          ),
          children: [
            Text(b == null ? 'Thêm định mức' : 'Sửa định mức', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Tên (VD: Ăn uống tháng)'),
            ),
            const SizedBox(height: 12),
            AmountField(controller: limit, label: 'Hạn mức', suffix: f.currency(f.baseCurrency)?.symbol),
            const SizedBox(height: 12),
            const Text('Áp dụng cho'),
            Wrap(
              spacing: 8,
              children: [
                for (final e in {1: 'Tổng chi', 2: 'Danh mục', 3: 'Tài khoản'}.entries)
                  ChoiceChip(
                    label: Text(e.value),
                    selected: scope == e.key,
                    onSelected: (_) => set(() {
                      scope = e.key;
                      refId = null;
                    }),
                  ),
              ],
            ),
            if (scope == 2)
              InfoTile(
                icon: Icons.category,
                label: 'Danh mục',
                value: f.category(refId)?.name ?? 'Chọn',
                onTap: () async {
                  final c = await pickCategory(ctx, ref, 1);
                  if (c != null) set(() => refId = c.id);
                },
              ),
            if (scope == 3)
              InfoTile(
                icon: Icons.account_balance_wallet,
                label: 'Tài khoản',
                value: f.account(refId)?.name ?? 'Chọn',
                onTap: () async {
                  final a = await pickAccount(ctx, ref);
                  if (a != null) set(() => refId = a.id);
                },
              ),
            const SizedBox(height: 8),
            const Text('Chu kỳ'),
            Wrap(
              spacing: 8,
              children: [
                for (final e in _periods.entries) ChoiceChip(label: Text(e.value), selected: period == e.key, onSelected: (_) => set(() => period = e.key)),
              ],
            ),
            const SizedBox(height: 8),
            Text('Cảnh báo khi đạt ${warn.toStringAsFixed(0)}%'),
            Slider(value: warn, min: 50, max: 100, divisions: 10, label: '${warn.toStringAsFixed(0)}%', onChanged: (v) => set(() => warn = v)),
            SwitchListTile(contentPadding: EdgeInsets.zero, value: active, onChanged: (v) => set(() => active = v), title: const Text('Đang bật')),
          ],
        ),
      ),
    );
  }
}
