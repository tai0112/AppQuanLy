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
    // Chỉ dựng lại khi số đã chi / tên phạm vi / tiền tệ gốc của định mức này đổi, không phải mỗi lần dữ liệu tài chính đổi.
    ref.watch(financeProvider.select((f) => (f.budgetSpent(budget), f.category(budget.refId)?.name, f.account(budget.refId)?.name, f.baseCurrency)));
    final f = ref.read(financeProvider);
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
                (pct * 100).round() > 999 ? '>999%' : '${(pct * 100).round()}%',
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
    final scopeSearch = TextEditingController();
    var scopeQuery = '';
    var scope = b?.scope ?? 1;
    var refId = b?.refId;
    var period = b?.period ?? 3;
    var warn = (b?.warnPercent ?? 80).toDouble();
    var active = b?.isActive ?? true;
    final rootCats = f.categories.where((c) => c.type == 1 && c.parentId == null).toList();
    final accounts = f.accounts.where((a) => !a.isArchived).toList();
    String? expandedParentId = scope == 2 && refId != null
        ? (f.category(refId)?.parentId ?? (f.categories.any((x) => x.parentId == refId) ? refId : null))
        : null;
    await showModalBottomSheet(
      sheetAnimationStyle: kSheetAnim,
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          final scheme = Theme.of(ctx).colorScheme;
          final pickedCat = scope == 2 ? f.category(refId) : null;
          final parentCat = expandedParentId == null ? null : f.category(expandedParentId);
          final subCats = parentCat == null ? const <Category>[] : f.categories.where((x) => x.parentId == parentCat.id).toList();
          return FormSheetBody(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            action: Row(
              children: [
                if (b != null)
                  OutlinedButton.icon(
                    onPressed: () {
                      ref.read(storeProvider).remove(E.budgets, b.id);
                      Navigator.pop(ctx);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.expense,
                      side: BorderSide(color: AppColors.expense.withValues(alpha: 0.4)),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Xoá'),
                  ),
                if (b != null) const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
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
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Lưu định mức'),
                  ),
                ),
              ],
            ),
            children: [
              Text(b == null ? 'Thêm định mức' : 'Sửa định mức', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              TextField(
                controller: name,
                decoration: const InputDecoration(
                  hintText: 'Tên định mức (VD: Ăn uống tháng)',
                  prefixIcon: Icon(Icons.label_outline_rounded),
                ),
              ),
              const SizedBox(height: 10),
              AmountField(controller: limit, label: 'Hạn mức', suffix: f.currency(f.baseCurrency)?.symbol),
              const SizedBox(height: 8),
              SizedBox(
                height: 30,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final add in const [100000.0, 500000.0, 1000000.0, 2000000.0, 5000000.0])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Pressable(
                          onTap: () => set(() => limit.text = amountText(parseAmount(limit.text) + add)),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999)),
                            child: Text('+${Fmt.compact(add)}', style: TextStyle(color: scheme.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text('Áp dụng cho', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    for (final e in const {1: 'Tổng chi', 2: 'Danh mục', 3: 'Tài khoản'}.entries)
                      Expanded(
                        child: Pressable(
                          onTap: () => set(() {
                            if (scope == e.key) return;
                            scope = e.key;
                            refId = null;
                            expandedParentId = null;
                            scopeSearch.clear();
                            scopeQuery = '';
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: scope == e.key ? scheme.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              e.value,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: scope == e.key ? FontWeight.w700 : FontWeight.w600,
                                color: scope == e.key ? scheme.onPrimary : scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topLeft,
                child: scope == 2
                    ? Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: scopeSearch,
                              onChanged: (v) => set(() => scopeQuery = v.trim()),
                              decoration: InputDecoration(
                                hintText: 'Tìm danh mục...',
                                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                                suffixIcon: scopeQuery.isEmpty
                                    ? null
                                    : IconButton(
                                        icon: const Icon(Icons.close_rounded, size: 18),
                                        onPressed: () => set(() {
                                          scopeSearch.clear();
                                          scopeQuery = '';
                                        }),
                                      ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Builder(
                              builder: (_) {
                                final q = scopeQuery.toLowerCase();
                                final visibleCats = q.isEmpty
                                    ? rootCats
                                    : f.categories.where((c) => c.type == 1 && c.name.toLowerCase().contains(q)).toList();
                                if (visibleCats.isEmpty) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Text('Không tìm thấy danh mục "$scopeQuery"', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                                  );
                                }
                                return SizedBox(
                                  height: 38,
                                  child: ListView(
                                    scrollDirection: Axis.horizontal,
                                    children: [
                                      for (final c in visibleCats)
                                        (() {
                                          final on = q.isEmpty ? (refId == c.id || pickedCat?.parentId == c.id) : refId == c.id;
                                          final cc = hexColor(c.color, scheme.primary);
                                          final hasSub = q.isEmpty && f.categories.any((x) => x.parentId == c.id);
                                          return Padding(
                                            padding: const EdgeInsets.only(right: 6),
                                            child: Pressable(
                                              onTap: () => set(() {
                                                if (q.isNotEmpty) {
                                                  refId = c.id;
                                                  expandedParentId = c.parentId ?? (f.categories.any((x) => x.parentId == c.id) ? c.id : null);
                                                } else if (expandedParentId == c.id && refId == c.id) {
                                                  expandedParentId = null;
                                                } else {
                                                  refId = c.id;
                                                  expandedParentId = hasSub ? c.id : null;
                                                }
                                              }),
                                              child: AnimatedContainer(
                                                duration: const Duration(milliseconds: 180),
                                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                  color: on ? cc.withValues(alpha: 0.16) : scheme.surfaceContainerHigh,
                                                  borderRadius: BorderRadius.circular(999),
                                                  border: Border.all(color: on ? cc : Colors.transparent, width: 1.5),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    CircleIcon(icon: c.icon, color: cc, size: 22),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      c.name,
                                                      style: TextStyle(fontSize: 12.5, fontWeight: on ? FontWeight.w700 : FontWeight.w500, color: on ? cc : scheme.onSurface),
                                                    ),
                                                    if (hasSub) ...[
                                                      const SizedBox(width: 2),
                                                      Icon(
                                                        expandedParentId == c.id ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                                                        size: 16,
                                                        color: on ? cc : scheme.onSurfaceVariant,
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        })(),
                                      if (q.isEmpty)
                                        Pressable(
                                          onTap: () async {
                                            final c = await pickCategory(ctx, ref, 1);
                                            if (c != null) {
                                              set(() {
                                                refId = c.id;
                                                expandedParentId = c.parentId ?? (f.categories.any((x) => x.parentId == c.id) ? c.id : null);
                                              });
                                            }
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10),
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(999),
                                              border: Border.all(color: scheme.outlineVariant),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.apps_rounded, size: 15, color: scheme.onSurfaceVariant),
                                                const SizedBox(width: 5),
                                                Text('Tất cả', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              child: scopeQuery.isNotEmpty || subCats.isEmpty
                                  ? const SizedBox.shrink()
                                  : Container(
                                      margin: const EdgeInsets.only(top: 8),
                                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                                      decoration: BoxDecoration(
                                        color: scheme.surfaceContainerLow,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.55)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                width: 7,
                                                height: 7,
                                                margin: const EdgeInsets.only(right: 6),
                                                decoration: BoxDecoration(color: hexColor(parentCat?.color, scheme.primary), shape: BoxShape.circle),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  parentCat!.name,
                                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: hexColor(parentCat.color, scheme.primary)),
                                                ),
                                              ),
                                              if (pickedCat?.parentId == parentCat.id)
                                                GestureDetector(
                                                  onTap: () => set(() => refId = parentCat.id),
                                                  child: Text('Chọn cả mục cha', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: scheme.primary)),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            children: [
                                              for (final sub in subCats)
                                                (() {
                                                  final subOn = refId == sub.id;
                                                  final sc = hexColor(sub.color ?? parentCat.color, scheme.primary);
                                                  return Pressable(
                                                    onTap: () => set(() => refId = subOn ? parentCat.id : sub.id),
                                                    child: AnimatedContainer(
                                                      duration: const Duration(milliseconds: 180),
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                      decoration: BoxDecoration(
                                                        color: subOn ? sc.withValues(alpha: 0.16) : scheme.surfaceContainerLowest,
                                                        borderRadius: BorderRadius.circular(999),
                                                        border: Border.all(color: subOn ? sc : scheme.outlineVariant.withValues(alpha: 0.6), width: subOn ? 1.5 : 1),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          CircleIcon(icon: sub.icon, color: sc, size: 18),
                                                          const SizedBox(width: 5),
                                                          Text(
                                                            sub.name,
                                                            style: TextStyle(fontSize: 12, fontWeight: subOn ? FontWeight.w700 : FontWeight.w500, color: subOn ? sc : scheme.onSurface),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                })(),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      )
                    : scope == 3
                    ? Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: scopeSearch,
                              onChanged: (v) => set(() => scopeQuery = v.trim()),
                              decoration: InputDecoration(
                                hintText: 'Tìm tài khoản...',
                                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                                suffixIcon: scopeQuery.isEmpty
                                    ? null
                                    : IconButton(
                                        icon: const Icon(Icons.close_rounded, size: 18),
                                        onPressed: () => set(() {
                                          scopeSearch.clear();
                                          scopeQuery = '';
                                        }),
                                      ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Builder(
                              builder: (_) {
                                final q = scopeQuery.toLowerCase();
                                final visibleAccs = q.isEmpty
                                    ? accounts
                                    : accounts.where((a) => a.name.toLowerCase().contains(q)).toList();
                                if (visibleAccs.isEmpty) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Text('Không tìm thấy tài khoản "$scopeQuery"', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                                  );
                                }
                                return SizedBox(
                                  height: 38,
                                  child: ListView(
                                    scrollDirection: Axis.horizontal,
                                    children: [
                                      for (final a in visibleAccs)
                                        (() {
                                          final on = refId == a.id;
                                          final ac = hexColor(a.color, scheme.primary);
                                          return Padding(
                                            padding: const EdgeInsets.only(right: 6),
                                            child: Pressable(
                                              onTap: () => set(() => refId = a.id),
                                              child: AnimatedContainer(
                                                duration: const Duration(milliseconds: 180),
                                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                  color: on ? ac.withValues(alpha: 0.16) : scheme.surfaceContainerHigh,
                                                  borderRadius: BorderRadius.circular(999),
                                                  border: Border.all(color: on ? ac : Colors.transparent, width: 1.5),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    CircleIcon(icon: a.icon, color: ac, size: 22),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      a.name,
                                                      style: TextStyle(fontSize: 12.5, fontWeight: on ? FontWeight.w700 : FontWeight.w500, color: on ? ac : scheme.onSurface),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        })(),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
              const SizedBox(height: 14),
              const Text('Chu kỳ', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    for (final e in _periods.entries)
                      Expanded(
                        child: Pressable(
                          onTap: () => set(() => period = e.key),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: period == e.key ? scheme.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              e.value,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: period == e.key ? FontWeight.w700 : FontWeight.w600,
                                color: period == e.key ? scheme.onPrimary : scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Cảnh báo khi đạt', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(999)),
                    child: Text('${warn.toStringAsFixed(0)}%', style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.w800, fontSize: 12)),
                  ),
                ],
              ),
              Slider(value: warn, min: 50, max: 100, divisions: 10, label: '${warn.toStringAsFixed(0)}%', onChanged: (v) => set(() => warn = v)),
              SwitchListTile(contentPadding: EdgeInsets.zero, value: active, onChanged: (v) => set(() => active = v), title: const Text('Đang bật')),
            ],
          );
        },
      ),
    );
  }
}
