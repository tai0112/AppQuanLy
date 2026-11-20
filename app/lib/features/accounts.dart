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
      builder: (c) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        builder: (c, scroll) => Consumer(
          builder: (c, ref, _) {
            final f = ref.watch(financeProvider);
            final txs = f.transactions.where((t) => t.accountId == a.id || t.toAccountId == a.id).take(100).toList();
            return ListView(
              controller: scroll,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                ListTile(
                  leading: CircleIcon(icon: a.icon, color: hexColor(a.color)),
                  title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                  subtitle: CountText(values: [f.balance(a)], text: (cv) => 'Số dư: ${f.money(cv[0], a.currencyCode)}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_rounded),
                    onPressed: () {
                      Navigator.pop(c);
                      context.push('/accounts/edit', extra: {'id': a.id});
                    },
                  ),
                ),
                const Divider(),
                if (txs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('Chưa có giao dịch')),
                  ),
                for (final t in txs) TxTile(txn: t, showDate: true),
              ],
            );
          },
        ),
      ),
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
      body: ListView(
        padding: const EdgeInsets.all(16),
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
          const SizedBox(height: 24),
          FilledButton(
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
            child: const Text('Lưu'),
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
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text(c == null ? 'Thêm tiền tệ' : 'Sửa ${c.code}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: code,
                  enabled: c == null,
                  decoration: const InputDecoration(labelText: 'Mã (VD: JPY)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Tên'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: symbol,
                  decoration: const InputDecoration(labelText: 'Ký hiệu (VD: ¥)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: decimals,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Số chữ số thập phân'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: before,
                  onChanged: (v) => set(() => before = v),
                  title: const Text('Ký hiệu đứng trước số'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
            FilledButton(
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
              child: const Text('Lưu'),
            ),
          ],
        ),
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
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Thêm tỷ giá'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text('1 '),
                  DropdownButton<String>(
                    value: from,
                    items: [for (final c in codes) DropdownMenuItem(value: c, child: Text(c))],
                    onChanged: (v) => set(() => from = v!),
                  ),
                  const Text('  =  '),
                  DropdownButton<String>(
                    value: to,
                    items: [for (final c in codes) DropdownMenuItem(value: c, child: Text(c))],
                    onChanged: (v) => set(() => to = v!),
                  ),
                ],
              ),
              TextField(
                controller: rate,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Tỷ giá'),
              ),
              const SizedBox(height: 8),
              InfoTile(
                icon: Icons.today,
                label: 'Từ ngày',
                value: Fmt.date(date),
                onTap: () async {
                  final d = await pickDateTime(ctx, date, withTime: false);
                  if (d != null) set(() => date = d);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
            FilledButton(
              onPressed: () {
                final r = double.tryParse(rate.text.replaceAll(',', '.'));
                if (r == null || r <= 0 || from == to) return;
                ref.read(storeProvider).put(E.exchangeRates, {'fromCode': from, 'toCode': to, 'rate': r, 'effectiveDate': Fmt.isoDate(date)});
                Navigator.pop(ctx);
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }
}
