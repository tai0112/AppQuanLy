import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/format.dart';
import '../core/icons.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../data/local_store.dart';
import '../data/logic.dart';
import '../data/models.dart';
import '../providers.dart';
import 'common.dart';
import 'transactions.dart';

/// Màn hình quản lý Giao dịch tự động định kỳ (hằng ngày, hằng tuần, hằng tháng, hằng năm).
class RecurringPage extends ConsumerWidget {
  const RecurringPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(financeProvider);
    final rules = f.recurringRules;
    final scheme = Theme.of(context).colorScheme;

    var estExpense = 0.0;
    var estIncome = 0.0;
    for (final r in rules.where((x) => x.isActive)) {
      final freq = Recurrence.parse(r.rrule)['FREQ'];
      final mult = switch (freq) {
        'DAILY' => 30.0,
        'WEEKLY' => 4.0,
        'YEARLY' => 1 / 12.0,
        _ => 1.0,
      };
      final baseAmt = f.convert(r.amount, r.currencyCode, f.baseCurrency);
      if (r.type == TxType.expense) estExpense += baseAmt * mult;
      if (r.type == TxType.income) estIncome += baseAmt * mult;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Giao dịch định kỳ')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => editRecurringRule(context, ref, null),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm định kỳ'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        children: [
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.event_repeat_rounded, size: 18, color: scheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Ước tính mỗi tháng', style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant, fontSize: 13)),
                    ),
                    Text(
                      '${rules.where((r) => r.isActive).length}/${rules.length} đang bật',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.income.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Thu định kỳ', style: TextStyle(fontSize: 11, color: AppColors.income, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(f.money(estIncome), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.income)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.expense.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Chi định kỳ', style: TextStyle(fontSize: 11, color: AppColors.expense, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(f.money(estExpense), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.expense)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (rules.isEmpty)
            EmptyState(
              icon: Icons.event_repeat_rounded,
              title: 'Chưa có giao dịch định kỳ',
              subtitle: 'Tự động tạo tiền nhà, lương, hoá đơn hằng ngày, hằng tuần hoặc hằng tháng',
              action: FilledButton.icon(
                onPressed: () => editRecurringRule(context, ref, null),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Tạo quy tắc đầu tiên'),
              ),
            )
          else
            for (final (i, r) in rules.indexed)
              _RuleCard(rule: r, finance: f).stagger(i),
        ],
      ),
    );
  }
}

class _RuleCard extends ConsumerWidget {
  const _RuleCard({required this.rule, required this.finance});
  final RecurringRule rule;
  final Finance finance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final cat = finance.category(rule.categoryId);
    final acc = finance.account(rule.accountId);
    final color = rule.type == TxType.transfer ? AppColors.transfer : hexColor(cat?.color, txColor(rule.type));
    final freqLabel = Recurrence.describe(rule.rrule);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: () => editRecurringRule(context, ref, rule),
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Opacity(
          opacity: rule.isActive ? 1.0 : 0.55,
          child: Column(
            children: [
              Row(
                children: [
                  CircleIcon(
                    icon: rule.type == TxType.transfer ? 'swap_horiz' : cat?.icon,
                    color: color,
                    size: 42,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(rule.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(
                          [freqLabel, if (acc != null) acc.name].join(' · '),
                          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${rule.type == TxType.income ? '+' : (rule.type == TxType.expense ? '-' : '')}${finance.money(rule.amount, rule.currencyCode)}',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: txColor(rule.type)),
                      ),
                      Text(
                        'Tới: ${Fmt.dateShort(rule.nextRunAt.toLocal())}',
                        style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8)),
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('Chạy ngay', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    onPressed: () {
                      final store = ref.read(storeProvider);
                      final now = DateTime.now();
                      final txId = const Uuid().v5(Namespace.oid.value, 'recurring:${rule.id}:${Fmt.isoDate(now)}');
                      if (store.get(E.transactions, txId) != null) {
                        showToast(context, 'Hôm nay đã chạy quy tắc này rồi');
                        return;
                      }
                      store.put(E.transactions, {
                        'id': txId,
                        'type': rule.type,
                        'amount': rule.amount,
                        'currencyCode': rule.currencyCode,
                        'accountId': rule.accountId,
                        if (rule.type == TxType.transfer && rule.toAccountId != null) 'toAccountId': rule.toAccountId,
                        if (rule.type != TxType.transfer && rule.categoryId != null) 'categoryId': rule.categoryId,
                        if (cat != null) 'categoryName': cat.name,
                        if (acc != null) 'accountName': acc.name,
                        'occurredAt': toIso8601WithOffset(now),
                        'note': (rule.note?.isNotEmpty == true) ? rule.note : rule.name,
                        'recurringRuleId': rule.id,
                      });
                      final next = Recurrence.nextOccurrence(rule.rrule, rule.nextRunAt.toLocal());
                      store.put(E.recurringRules, {...rule.m, 'nextRunAt': toIso8601WithOffset(next)});
                      HapticFeedback.lightImpact();
                      showToast(context, 'Đã ghi "${rule.name}"');
                    },
                  ),
                  const Spacer(),
                  Text(rule.isActive ? 'Đang bật' : 'Tạm dừng', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  const SizedBox(width: 6),
                  Switch.adaptive(
                    value: rule.isActive,
                    onChanged: (v) => ref.read(storeProvider).put(E.recurringRules, {...rule.m, 'isActive': v}),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hộp thoại tạo / sửa quy tắc giao dịch tự động định kỳ (nút lưu cố định ở đáy).
Future<void> editRecurringRule(BuildContext context, WidgetRef ref, RecurringRule? existing) async {
  final f = ref.read(financeProvider);
  final store = ref.read(storeProvider);

  var type = existing?.type ?? TxType.expense;
  final name = TextEditingController(text: existing?.name ?? '');
  final amount = TextEditingController(text: existing != null && existing.amount > 0 ? amountText(existing.amount) : '');
  final note = TextEditingController(text: existing?.note ?? '');

  var account = f.account(existing?.accountId) ?? f.defaultAccount();
  var toAccount = f.account(existing?.toAccountId);
  var category = f.category(existing?.categoryId);

  final parsed = Recurrence.parse(existing?.rrule);
  var freq = parsed['FREQ'] ?? 'MONTHLY';
  var interval = int.tryParse(parsed['INTERVAL'] ?? '1') ?? 1;
  var weekdays = parsed['BYDAY']?.split(',').map((x) => ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'].indexOf(x) + 1).where((w) => w >= 1).toSet() ?? {DateTime.now().weekday};
  var nextRun = existing?.nextRunAt.toLocal() ?? DateTime.now();
  var isActive = existing?.isActive ?? true;

  await showModalBottomSheet(
    sheetAnimationStyle: kSheetAnim,
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) {
        final scheme = Theme.of(ctx).colorScheme;
        final color = txColor(type);
        final sym = f.currency(account?.currencyCode ?? f.baseCurrency)?.symbol ?? '';
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(existing == null ? 'Thêm giao dịch định kỳ' : 'Sửa giao dịch định kỳ', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 12),
                      PillToggle<int>(
                        value: type,
                        values: const [TxType.expense, TxType.income, TxType.transfer],
                        labels: const ['Khoản chi', 'Khoản thu', 'Chuyển tiền'],
                        icons: const [Icons.north_east_rounded, Icons.south_west_rounded, Icons.swap_horiz_rounded],
                        colors: const [AppColors.expense, AppColors.income, AppColors.transfer],
                        onChanged: (v) => set(() {
                          type = v;
                          if (category != null && category!.type != type) category = null;
                        }),
                      ),
                      const SizedBox(height: 14),
                      AmountField(controller: amount, label: 'Số tiền', suffix: sym),
                      const SizedBox(height: 12),
                      TextField(
                        controller: name,
                        decoration: InputDecoration(
                          labelText: 'Tên quy tắc (VD: Tiền nhà, Lương)',
                          prefixIcon: const Icon(Icons.label_outline_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      AccountChips(
                        label: type == TxType.transfer ? 'Từ tài khoản' : (type == TxType.income ? 'Nhận vào' : 'Trả bằng'),
                        selected: account?.id,
                        onChanged: (a) => set(() {
                          account = a;
                          if (toAccount?.id == a.id) toAccount = null;
                        }),
                      ),
                      if (type == TxType.transfer) ...[
                        const SizedBox(height: 8),
                        AccountChips(label: 'Đến tài khoản', selected: toAccount?.id, exclude: account?.id, onChanged: (a) => set(() => toAccount = a)),
                      ] else
                        InfoTile(
                          icon: iconOf(category?.icon),
                          color: hexColor(category?.color, color),
                          label: 'Danh mục',
                          value: category?.name ?? 'Chọn danh mục',
                          onTap: () async {
                            final c = await pickCategory(ctx, ref, type);
                            if (c != null) {
                              set(() {
                                category = c;
                                if (name.text.trim().isEmpty) name.text = c.name;
                              });
                            }
                          },
                        ),
                      const SizedBox(height: 10),
                      const Text('Tần suất lặp', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          for (final (code, label) in [
                            ('DAILY', 'Hằng ngày'),
                            ('WEEKLY', 'Hằng tuần'),
                            ('MONTHLY', 'Hằng tháng'),
                            ('YEARLY', 'Hằng năm'),
                          ])
                            ChoiceChip(
                              label: Text(label),
                              selected: freq == code,
                              onSelected: (_) => set(() => freq = code),
                            ),
                        ],
                      ),
                      if (freq == 'WEEKLY') ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          children: [
                            for (var d = 1; d <= 7; d++)
                              FilterChip(
                                label: Text(Fmt.weekdaysShort[d - 1]),
                                selected: weekdays.contains(d),
                                visualDensity: VisualDensity.compact,
                                onSelected: (on) => set(() {
                                  if (on) {
                                    weekdays.add(d);
                                  } else if (weekdays.length > 1) {
                                    weekdays.remove(d);
                                  }
                                }),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text('Mỗi $interval ${switch (freq) {
                            'DAILY' => 'ngày',
                            'WEEKLY' => 'tuần',
                            'YEARLY' => 'năm',
                            _ => 'tháng',
                          }}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          const Spacer(),
                          IconButton.filledTonal(
                            visualDensity: VisualDensity.compact,
                            onPressed: interval > 1 ? () => set(() => interval--) : null,
                            icon: const Icon(Icons.remove_rounded, size: 18),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            visualDensity: VisualDensity.compact,
                            onPressed: interval < 30 ? () => set(() => interval++) : null,
                            icon: const Icon(Icons.add_rounded, size: 18),
                          ),
                        ],
                      ),
                      InfoTile(
                        icon: Icons.event_rounded,
                        color: scheme.primary,
                        label: 'Lần chạy kế tiếp',
                        value: '${Fmt.time(nextRun)} · ${Fmt.date(nextRun)}',
                        onTap: () async {
                          final d = await pickDateTime(ctx, nextRun, title: 'Chọn ngày bắt đầu / lần tới');
                          if (d != null) set(() => nextRun = d);
                        },
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: note,
                        decoration: InputDecoration(
                          labelText: 'Ghi chú (tuỳ chọn)',
                          prefixIcon: const Icon(Icons.notes_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      if (existing != null)
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Đang bật tự động'),
                          value: isActive,
                          onChanged: (v) => set(() => isActive = v),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (existing != null) ...[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.expense,
                        side: const BorderSide(color: AppColors.expense),
                        minimumSize: const Size(0, 50),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Xoá'),
                      onPressed: () {
                        store.remove(E.recurringRules, existing.id);
                        Navigator.pop(ctx);
                      },
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        final amt = parseAmount(amount.text);
                        if (amt <= 0) return showToast(ctx, 'Nhập số tiền hợp lệ', error: true);
                        if (account == null) return showToast(ctx, 'Chọn tài khoản', error: true);
                        if (type == TxType.transfer && toAccount == null) return showToast(ctx, 'Chọn tài khoản nhận', error: true);
                        final ruleName = name.text.trim().isNotEmpty ? name.text.trim() : (category?.name ?? 'Giao dịch định kỳ');
                        final rrule = Recurrence.build(freq, weekdays: weekdays.toList()..sort(), interval: interval) ?? 'FREQ=MONTHLY';
                        final tpl = jsonEncode({
                          'type': type,
                          'amount': amt,
                          'currencyCode': account!.currencyCode,
                          'accountId': account!.id,
                          if (type == TxType.transfer && toAccount != null) 'toAccountId': toAccount!.id,
                          if (type != TxType.transfer && category != null) 'categoryId': category!.id,
                          if (note.text.trim().isNotEmpty) 'note': note.text.trim(),
                        });
                        store.put(E.recurringRules, {
                          if (existing != null) 'id': existing.id,
                          'name': ruleName,
                          'templateJson': tpl,
                          'rRule': rrule,
                          'nextRunAt': toIso8601WithOffset(nextRun),
                          'isActive': isActive,
                        });
                        runDueRecurringRules(store);
                        HapticFeedback.lightImpact();
                        Navigator.pop(ctx);
                      },
                      child: const Text('Lưu quy tắc', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ),
  );

  name.dispose();
  amount.dispose();
  note.dispose();
}
