import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../data/local_store.dart';
import '../data/models.dart';
import '../providers.dart';
import 'common.dart';
import 'transactions.dart';

/// Danh sách tài khoản / ví với số dư.
class AccountsPage extends ConsumerWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(financeProvider);
    final accounts = f.accounts.where((a) => !a.isArchived).toList();
    final archived = f.accounts.where((a) => a.isArchived).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tài khoản'),
        actions: [IconButton(tooltip: 'Tiền tệ & tỷ giá', onPressed: () => context.push('/currencies'), icon: const Icon(Icons.currency_exchange_rounded))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/accounts/edit'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm ví'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        children: [
          AppCard(
            gradient: LinearGradient(colors: [AppColors.income, AppColors.income.withValues(alpha: 0.7)]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tổng tài sản', style: TextStyle(color: Colors.white70)),
                AnimatedAmount(
                  value: f.totalBalance,
                  format: (v) => f.money(v),
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                ),
                Text('Quy đổi về ${f.baseCurrency}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (final (i, a) in accounts.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                onTap: () => _showDetail(context, ref, a),
                child: Row(
                  children: [
                    CircleIcon(icon: a.icon, color: hexColor(a.color)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(
                            '${AccType.names[a.type] ?? ''}${a.includeInTotal ? '' : ' · không tính vào tổng'}',
                            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    CountText(
                      values: [f.balance(a)],
                      text: (cv) => f.money(cv[0], a.currencyCode),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ).stagger(i),
            ),
          if (archived.isNotEmpty) ...[
            const SectionTitle('Đã lưu trữ'),
            for (final a in archived)
              ListTile(
                leading: CircleIcon(icon: a.icon, color: Colors.grey, size: 36),
                title: Text(a.name),
                onTap: () => context.push('/accounts/edit', extra: {'id': a.id}),
              ),
          ],
        ],
      ),
    );
  }

  void _showDetail(BuildContext context, WidgetRef ref, Account a) {
    showModalBottomSheet(
      sheetAnimationStyle: kSheetAnim,
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (c) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (c, scroll) => _AccountDetailSheet(scroll: scroll, account: a),
      ),
    );
  }
}

class _AccountDetailSheet extends ConsumerStatefulWidget {
  const _AccountDetailSheet({required this.scroll, required this.account});
  final ScrollController scroll;
  final Account account;

  @override
  ConsumerState<_AccountDetailSheet> createState() => _AccountDetailSheetState();
}

class _AccountDetailSheetState extends ConsumerState<_AccountDetailSheet> {
  int catType = TxType.expense;
  String? filterCatId;

  @override
  Widget build(BuildContext context) {
    final a = widget.account;
    final f = ref.watch(financeProvider);
    final scheme = Theme.of(context).colorScheme;

    final allTxs = f.transactions.where((t) => t.accountId == a.id || t.toAccountId == a.id).toList();
    final expenseTxs = allTxs.where((t) => t.type == TxType.expense && t.accountId == a.id).toList();
    final incomeTxs = allTxs.where((t) => t.type == TxType.income && (t.accountId == a.id || t.toAccountId == a.id)).toList();
    final totalExpense = expenseTxs.fold(0.0, (s, t) => s + f.toBase(t));
    final totalIncome = incomeTxs.fold(0.0, (s, t) => s + f.toBase(t));

    final currentTxs = catType == TxType.expense ? expenseTxs : incomeTxs;
    final currentTotal = catType == TxType.expense ? totalExpense : totalIncome;
    final catGroups = f.byCategory(currentTxs, catType);

    final shownTxs = filterCatId == null
        ? allTxs
        : allTxs.where((t) => f.rootCategory(t.categoryId)?.id == filterCatId || t.categoryId == filterCatId).toList();

    return ListView(
      controller: widget.scroll,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            CircleIcon(icon: a.icon, color: hexColor(a.color), size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                  Text(
                    '${AccType.names[a.type] ?? ''}${a.includeInTotal ? '' : ' · không tính vào tổng'}',
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Sửa tài khoản',
              icon: const Icon(Icons.edit_rounded),
              onPressed: () {
                Navigator.pop(context);
                context.push('/accounts/edit', extra: {'id': a.id});
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Số dư hiện tại', style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w500)),
                  CountText(
                    values: [f.balance(a)],
                    text: (cv) => f.money(cv[0], a.currencyCode),
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: scheme.primary),
                  ),
                ],
              ),
              const Divider(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Tổng thu', style: TextStyle(fontSize: 12, color: AppColors.income, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(f.money(totalIncome, a.currencyCode), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.income)),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 30, color: scheme.outlineVariant.withValues(alpha: 0.5)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Tổng chi', style: TextStyle(fontSize: 12, color: AppColors.expense, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(f.money(totalExpense, a.currencyCode), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.expense)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Expanded(
              child: Text('Số liệu theo danh mục', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
            PillToggle<int>(
              value: catType,
              values: const [TxType.expense, TxType.income],
              labels: const ['Chi', 'Thu'],
              icons: const [Icons.north_east_rounded, Icons.south_west_rounded],
              colors: const [AppColors.expense, AppColors.income],
              onChanged: (v) => setState(() {
                catType = v;
                filterCatId = null;
              }),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (catGroups.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'Chưa có dữ liệu ${catType == TxType.expense ? 'chi tiêu' : 'thu nhập'} theo danh mục',
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
              ),
            ),
          )
        else ...[
          for (final g in catGroups)
            Builder(
              builder: (_) {
                final isSelected = filterCatId == g.category?.id;
                final catColor = hexColor(g.category?.color, AppColors.autoPalette[0]);
                final pct = currentTotal == 0 ? 0.0 : g.amount / currentTotal * 100;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Pressable(
                    scale: 0.98,
                    onTap: () {
                      setState(() {
                        filterCatId = isSelected ? null : g.category?.id;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSelected ? catColor.withValues(alpha: 0.12) : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                        border: isSelected ? Border.all(color: catColor, width: 1.5) : null,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              CircleIcon(icon: g.category?.icon, color: catColor, size: 32),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  g.category?.name ?? 'Không có danh mục',
                                  style: TextStyle(fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600, fontSize: 14),
                                ),
                              ),
                              Text(
                                f.money(g.amount, a.currencyCode),
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: catColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${pct.toStringAsFixed(0)}%',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: catColor),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: currentTotal == 0 ? 0 : (g.amount / currentTotal).clamp(0.0, 1.0),
                              minHeight: 5,
                              color: catColor,
                              backgroundColor: catColor.withValues(alpha: 0.12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                filterCatId == null ? 'Lịch sử giao dịch (${shownTxs.length})' : 'Giao dịch: ${f.category(filterCatId)?.name} (${shownTxs.length})',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
            if (filterCatId != null)
              TextButton.icon(
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Xem tất cả', style: TextStyle(fontSize: 12)),
                onPressed: () => setState(() => filterCatId = null),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (shownTxs.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('Chưa có giao dịch')),
          )
        else
          GroupedTxDays(items: shownTxs.take(60).toList()),
      ],
    );
  }
}

class AccountEditPage extends ConsumerStatefulWidget {
  const AccountEditPage({super.key, this.id});
  final String? id;

  @override
  ConsumerState<AccountEditPage> createState() => _AccountEditPageState();
}

class _AccountEditPageState extends ConsumerState<AccountEditPage> {
  // Giải phóng tài nguyên khi đóng màn (tránh tích tụ khi mở/đóng nhiều lần)
  @override
  void dispose() {
    name.dispose();
    balance.dispose();
    super.dispose();
  }

  final name = TextEditingController();
  final balance = TextEditingController(text: '0');
  int type = AccType.cash;
  String icon = 'payments';
  Color color = AppColors.palette[3];
  String currency = 'VND';
  bool includeInTotal = true;
  bool archived = false;

  @override
  void initState() {
    super.initState();
    final rec = ref.read(storeProvider).get(E.accounts, widget.id);
    if (rec != null) {
      final a = Account(rec);
      name.text = a.name;
      balance.text = amountText(a.openingBalance);
      type = a.type;
      icon = a.icon ?? icon;
      color = hexColor(a.color, color);
      currency = a.currencyCode;
      includeInTotal = a.includeInTotal;
      archived = a.isArchived;
    } else {
      currency = ref.read(financeProvider).baseCurrency;
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = ref.watch(financeProvider);
    return Scaffold(
      appBar: AppBar(title: Text(widget.id == null ? 'Thêm tài khoản' : 'Sửa tài khoản')),
      bottomNavigationBar: KeyboardAvoidBottomBar(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.35))),
          ),
          child: Row(
            children: [
              if (widget.id != null) ...[
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.expense,
                    side: const BorderSide(color: AppColors.expense),
                    minimumSize: const Size(0, 50),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => _deleteAccount(context, ref, f),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Xoá', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    if (name.text.trim().isEmpty) return showToast(context, 'Nhập tên tài khoản', error: true);
                    ref.read(storeProvider).put(E.accounts, {
                      if (widget.id != null) 'id': widget.id,
                      'name': name.text.trim(),
                      'type': type,
                      'icon': icon,
                      'color': colorHex(color),
                      'currencyCode': currency,
                      'openingBalance': parseAmount(balance.text),
                      'includeInTotal': includeInTotal,
                      'isArchived': archived,
                      'sortOrder': widget.id == null ? f.accounts.length + 1 : Account(ref.read(storeProvider).get(E.accounts, widget.id)!).sortOrder,
                    });
                    Navigator.of(context).maybePop();
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Lưu', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Center(
            child: CircleIcon(icon: icon, color: color, size: 72),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Tên tài khoản'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final e in AccType.names.entries)
                ChoiceChip(
                  label: Text(e.value),
                  selected: type == e.key,
                  onSelected: (_) => setState(() {
                    type = e.key;
                    icon = AccType.icons[e.key]!;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: balance,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [ThousandsInputFormatter()],
                  decoration: const InputDecoration(labelText: 'Số dư ban đầu'),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: f.currencies.any((c) => c.code == currency) ? currency : null,
                items: [for (final c in f.currencies) DropdownMenuItem(value: c.code, child: Text(c.code))],
                onChanged: (v) => setState(() => currency = v ?? currency),
              ),
            ],
          ),
          SwitchListTile(value: includeInTotal, onChanged: (v) => setState(() => includeInTotal = v), title: const Text('Tính vào tổng tài sản')),
          if (widget.id != null)
            SwitchListTile(value: archived, onChanged: (v) => setState(() => archived = v), title: const Text('Lưu trữ (ẩn khỏi danh sách)')),
          const SizedBox(height: 8),
          const Text('Màu', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ColorPickerRow(value: color, onChanged: (c) => setState(() => color = c)),
          const SizedBox(height: 16),
          const Text('Biểu tượng', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          IconPickerGrid(value: icon, color: color, onChanged: (i) => setState(() => icon = i)),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref, dynamic f) async {
    final accId = widget.id;
    if (accId == null) return;
    final store = ref.read(storeProvider);
    final currentAcc = store.get(E.accounts, accId);
    if (currentAcc == null) return;
    final accName = currentAcc['name']?.toString() ?? 'Tài khoản';

    // 1. Kiểm tra số lượng tài khoản hoạt động
    final otherAccounts = (f.accounts as List<Account>).where((a) => a.id != accId).toList();
    if (otherAccounts.isEmpty) {
      showToast(context, 'Cần giữ lại ít nhất 1 tài khoản hoạt động', error: true);
      return;
    }

    // 2. Kiểm tra các giao dịch liên quan
    final relatedTxs = (f.transactions as List<Txn>).where((t) => t.accountId == accId || t.toAccountId == accId).toList();

    if (relatedTxs.isEmpty) {
      final ok = await confirm(
        context,
        'Xoá tài khoản "$accName"?',
        message: 'Tài khoản này sẽ bị xoá khỏi danh sách.',
        danger: true,
        ok: 'Xoá',
      );
      if (ok) {
        _performDelete(store, accId);
        if (context.mounted) Navigator.of(context).maybePop();
      }
      return;
    }

    // 3. Có giao dịch liên quan: mở BottomSheet lựa chọn
    if (!context.mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _DeleteAccountSheet(
        accName: accName,
        txCount: relatedTxs.length,
        otherAccounts: otherAccounts,
        onConfirm: (targetAccountId) {
          if (targetAccountId != null) {
            // Chuyển toàn bộ giao dịch sang tài khoản đích
            final targetAcc = store.get(E.accounts, targetAccountId);
            final targetName = targetAcc?['name']?.toString();
            for (final tx in relatedTxs) {
              final m = Map<String, dynamic>.from(tx.m);
              var changed = false;
              if (m['accountId'] == accId) {
                m['accountId'] = targetAccountId;
                if (targetName != null) m['accountName'] = targetName;
                changed = true;
              }
              if (m['toAccountId'] == accId) {
                m['toAccountId'] = targetAccountId;
                if (targetName != null) m['toAccountName'] = targetName;
                changed = true;
              }
              if (changed) {
                store.put(E.transactions, m, notify: false);
              }
            }
          }
          _performDelete(store, accId);
          Navigator.of(ctx).pop();
          if (context.mounted) Navigator.of(context).maybePop();
        },
      ),
    );
  }

  void _performDelete(LocalStore store, String accId) {
    store.remove(E.accounts, accId);
    // Nếu tài khoản xoá là defaultAccountId, xóa bỏ cài đặt này để hệ thống dùng tài khoản đầu tiên
    final settingsList = store.all(E.appSettings);
    if (settingsList.isNotEmpty) {
      final s = settingsList.first;
      if (s['defaultAccountId'] == accId) {
        store.put(E.appSettings, {...s, 'defaultAccountId': null});
      }
    }
  }
}

class _DeleteAccountSheet extends StatefulWidget {
  const _DeleteAccountSheet({
    required this.accName,
    required this.txCount,
    required this.otherAccounts,
    required this.onConfirm,
  });

  final String accName;
  final int txCount;
  final List<Account> otherAccounts;
  final void Function(String? targetAccountId) onConfirm;

  @override
  State<_DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends State<_DeleteAccountSheet> {
  int _mode = 0; // 0: Chuyển sang tài khoản khác rồi xoá, 1: Xoá và giữ nguyên lịch sử
  String? _targetAccountId;

  @override
  void initState() {
    super.initState();
    if (widget.otherAccounts.isNotEmpty) {
      _targetAccountId = widget.otherAccounts.first.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.expense, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Xoá tài khoản "${widget.accName}"?',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Tài khoản này đang có ${widget.txCount} giao dịch. Vui lòng chọn cách xử lý:',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          RadioListTile<int>(
            value: 0,
            groupValue: _mode,
            onChanged: (v) => setState(() => _mode = v!),
            title: const Text('Chuyển tất cả giao dịch sang tài khoản khác rồi xoá', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Khuyên dùng để số dư và lịch sử giao dịch không bị lệch.'),
            contentPadding: EdgeInsets.zero,
          ),
          if (_mode == 0 && widget.otherAccounts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 32, bottom: 8),
              child: DropdownButtonFormField<String>(
                value: _targetAccountId,
                decoration: const InputDecoration(
                  labelText: 'Tài khoản đích nhận giao dịch',
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final a in widget.otherAccounts)
                    DropdownMenuItem(
                      value: a.id,
                      child: Row(
                        children: [
                          CircleIcon(icon: a.icon, color: hexColor(a.color), size: 24),
                          const SizedBox(width: 8),
                          Text(a.name),
                        ],
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _targetAccountId = v),
              ),
            ),
          RadioListTile<int>(
            value: 1,
            groupValue: _mode,
            onChanged: (v) => setState(() => _mode = v!),
            title: const Text('Xoá tài khoản và giữ nguyên lịch sử', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Các giao dịch cũ vẫn lưu tên tài khoản nhưng tài khoản sẽ bị xoá khỏi danh mục.'),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Huỷ'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
                  onPressed: () {
                    if (_mode == 0 && _targetAccountId == null) {
                      return;
                    }
                    widget.onConfirm(_mode == 0 ? _targetAccountId : null);
                  },
                  child: const Text('Xác nhận xoá'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Cấu hình tiền tệ, tiền tệ chính, tỷ giá nhập tay.
class CurrenciesPage extends ConsumerWidget {
  const CurrenciesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(financeProvider);
    final store = ref.watchTables(const [E.exchangeRates, E.currencies]);
    final rates = store.all(E.exchangeRates).map(ExchangeRate.new).toList()..sort((a, b) => b.effectiveDate.compareTo(a.effectiveDate));
    return Scaffold(
      appBar: AppBar(title: const Text('Tiền tệ & tỷ giá')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionTitle(
            'Tiền tệ',
            trailing: TextButton.icon(onPressed: () => _editCurrency(context, ref, null), icon: const Icon(Icons.add), label: const Text('Thêm')),
          ),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final c in f.currencies)
                  ListTile(
                    leading: CircleAvatar(child: Text(c.symbol)),
                    title: Text('${c.code} · ${c.name}'),
                    subtitle: Text('Ví dụ: ${f.money(1234567.89, c.code)}'),
                    trailing: c.code == f.baseCurrency
                        ? const Chip(label: Text('Chính'))
                        : TextButton(
                            onPressed: () {
                              final s = store.all(E.appSettings).firstOrNull ?? {};
                              store.put(E.appSettings, {...s, 'baseCurrencyCode': c.code});
                            },
                            child: const Text('Đặt làm chính'),
                          ),
                    onTap: () => _editCurrency(context, ref, c),
                  ),
              ],
            ),
          ),
          SectionTitle(
            'Tỷ giá (nhập tay)',
            trailing: TextButton.icon(onPressed: () => _addRate(context, ref), icon: const Icon(Icons.add), label: const Text('Thêm')),
          ),
          if (rates.isEmpty) const Text('Chưa có tỷ giá. Thống kê sẽ cộng thẳng nếu khác tiền tệ.'),
          for (final r in rates)
            Card(
              child: ListTile(
                title: CountText(
                  values: [r.rate],
                  text: (cv) => '1 ${r.from} = ${Fmt.money(cv[0], symbol: r.to, decimals: 2)}',
                ),
                subtitle: Text('Áp dụng từ ${Fmt.date(r.effectiveDate)}'),
                trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => store.remove(E.exchangeRates, r.m['id'] as String)),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _editCurrency(BuildContext context, WidgetRef ref, Currency? c) async {
    final code = TextEditingController(text: c?.code);
    final name = TextEditingController(text: c?.name);
    final symbol = TextEditingController(text: c?.symbol);
    final decimals = TextEditingController(text: '${c?.decimals ?? 0}');
    var before = c?.symbolBefore ?? false;

    await showModalBottomSheet(
      sheetAnimationStyle: kSheetAnim,
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          final scheme = Theme.of(ctx).colorScheme;
          final sym = symbol.text.trim().isEmpty ? (code.text.trim().isEmpty ? '₫' : code.text.trim()) : symbol.text.trim();
          final dec = int.tryParse(decimals.text) ?? 0;
          final sampleNumber = dec > 0 ? '1.234.567,89' : '1.234.567';
          final preview = before ? '$sym $sampleNumber' : '$sampleNumber $sym';

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 8,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.currency_exchange_rounded, color: scheme.primary, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          c == null ? 'Thêm tiền tệ mới' : 'Sửa ${c.code}',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Live Preview Card
                  AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: scheme.primary.withValues(alpha: 0.15),
                          child: Text(sym, style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name.text.trim().isEmpty ? 'Tên tiền tệ' : name.text.trim(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                              Text('Định dạng hiển thị: $preview', style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: code,
                    enabled: c == null,
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (_) => set(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Mã tiền tệ (VD: JPY, USD, EUR)',
                      prefixIcon: Icon(Icons.code_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: name,
                    onChanged: (_) => set(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Tên tiền tệ (VD: Yên Nhật)',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: symbol,
                          onChanged: (_) => set(() {}),
                          decoration: const InputDecoration(
                            labelText: r'Ký hiệu (VD: ¥, $, €)',
                            prefixIcon: Icon(Icons.monetization_on_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: decimals,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => set(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Chữ số thập phân',
                            prefixIcon: Icon(Icons.pin_outlined),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      value: before,
                      onChanged: (v) => set(() => before = v),
                      title: const Text('Ký hiệu đứng trước số', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(before ? 'Ví dụ: \$ 100' : 'Ví dụ: 100 ₫'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      if (code.text.trim().isEmpty) return;
                      ref.read(storeProvider).put(E.currencies, {
                        if (c != null) 'id': c.id,
                        'code': code.text.trim().toUpperCase(),
                        'name': name.text.trim().isEmpty ? code.text.trim().toUpperCase() : name.text.trim(),
                        'symbol': symbol.text.trim().isEmpty ? code.text.trim().toUpperCase() : symbol.text.trim(),
                        'decimals': int.tryParse(decimals.text) ?? 0,
                        'symbolPosition': before ? 2 : 1,
                        'isBase': c?.isBase ?? false,
                      });
                      Navigator.pop(ctx);
                    },
                    child: const Text('Lưu tiền tệ', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _addRate(BuildContext context, WidgetRef ref) async {
    final f = ref.read(financeProvider);
    final codes = f.currencies.map((c) => c.code).toList();
    if (codes.length < 2) return showToast(context, 'Cần ít nhất 2 loại tiền tệ', error: true);
    var from = codes.firstWhere((c) => c != f.baseCurrency, orElse: () => codes.first);
    var to = f.baseCurrency;
    final rate = TextEditingController();
    var date = DateTime.now();

    await showModalBottomSheet(
      sheetAnimationStyle: kSheetAnim,
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          final scheme = Theme.of(ctx).colorScheme;
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 8,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.trending_up_rounded, color: scheme.primary, size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text(
                          'Thêm tỷ giá hối đoái',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('1 ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: from,
                              items: [for (final c in codes) DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontWeight: FontWeight.w700)))],
                              onChanged: (v) => set(() => from = v!),
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Icon(Icons.arrow_forward_rounded),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: to,
                              items: [for (final c in codes) DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontWeight: FontWeight.w700)))],
                              onChanged: (v) => set(() => to = v!),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: rate,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Tỷ giá (1 $from bằng bao nhiêu $to)',
                      prefixIcon: const Icon(Icons.calculate_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppCard(
                    onTap: () async {
                      final d = await pickDateTime(ctx, date, withTime: false);
                      if (d != null) set(() => date = d);
                    },
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        const Icon(Icons.today_rounded),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Áp dụng từ ngày', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                              Text(Fmt.date(date), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      final r = double.tryParse(rate.text.replaceAll(',', '.'));
                      if (r == null || r <= 0 || from == to) {
                        return showToast(ctx, 'Vui lòng nhập tỷ giá hợp lệ và 2 loại tiền khác nhau', error: true);
                      }
                      ref.read(storeProvider).put(E.exchangeRates, {'fromCode': from, 'toCode': to, 'rate': r, 'effectiveDate': Fmt.isoDate(date)});
                      Navigator.pop(ctx);
                    },
                    child: const Text('Lưu tỷ giá', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
