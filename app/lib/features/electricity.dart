import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../data/local_store.dart';
import '../data/logic.dart';
import '../data/models.dart';
import '../providers.dart';
import 'meters.dart';

/// Tính tiền điện bậc thang: cấu hình số bậc / khoảng kWh / đơn giá, tính xuôi (kWh → tiền) và ngược (tiền → kWh).
class ElectricityPage extends ConsumerStatefulWidget {
  const ElectricityPage({super.key});

  @override
  ConsumerState<ElectricityPage> createState() => _ElectricityPageState();
}

class _ElectricityPageState extends ConsumerState<ElectricityPage> {
  String? tableId;
  bool reverse = false;
  final oldIdx = TextEditingController();
  final newIdx = TextEditingController();
  final kwh = TextEditingController();
  final money = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final store = ref.watchTables(const [E.priceTables, E.tiers, E.bills, E.meters]);
    final f = ref.watch(financeProvider);
    final tables = store.all(E.priceTables).map(PriceTable.new).toList();
    if (tables.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tiền điện')),
        body: EmptyState(
          icon: Icons.bolt_rounded,
          title: 'Chưa có bảng giá',
          action: FilledButton(onPressed: () => _editTable(null), child: const Text('Tạo bảng giá')),
        ),
      );
    }
    final table = tables.where((t) => t.id == tableId).firstOrNull ?? tables.firstWhere((t) => t.isDefault, orElse: () => tables.first);
    final tiers = store.all(E.tiers).map(Tier.new).where((t) => t.tableId == table.id).toList()..sort((a, b) => a.order.compareTo(b.order));

    int? usedKwh;
    if (!reverse) {
      final o = int.tryParse(oldIdx.text), n = int.tryParse(newIdx.text);
      usedKwh = (o != null && n != null && n >= o) ? n - o : int.tryParse(kwh.text);
    } else {
      final m = parseAmount(money.text);
      usedKwh = m > 0 ? Electricity.reverse(m, tiers, table.vat, table.fixedFee) : null;
    }
    final result = usedKwh == null ? null : Electricity.calc(usedKwh, tiers, table.vat, table.fixedFee);
    final bills = store.all(E.bills).map(Bill.new).where((b) => b.meterId == null).toList()..sort((a, b) => b.period.compareTo(a.period));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tiền điện'),
          actions: [IconButton(tooltip: 'Sửa bảng giá', onPressed: () => _editTable(table), icon: const Icon(Icons.tune_rounded))],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.electric_meter_rounded, size: 20), text: 'Công tơ', iconMargin: EdgeInsets.only(bottom: 2)),
              Tab(icon: Icon(Icons.calculate_rounded, size: 20), text: 'Tính nhanh', iconMargin: EdgeInsets.only(bottom: 2)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const MetersView(),
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final t in tables)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(label: Text(t.name), selected: t.id == table.id, onSelected: (_) => setState(() => tableId = t.id)),
                        ),
                      ActionChip(avatar: const Icon(Icons.add, size: 16), label: const Text('Bảng giá mới'), onPressed: () => _editTable(null)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Số điện → Tiền')),
                    ButtonSegment(value: true, label: Text('Tiền → Số điện')),
                  ],
                  selected: {reverse},
                  onSelectionChanged: (s) => setState(() => reverse = s.first),
                ),
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: reverse
                      ? TextField(
                          key: const ValueKey('m'),
                          controller: money,
                          keyboardType: TextInputType.number,
                          inputFormatters: const [ThousandsInputFormatter()],
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(labelText: 'Số tiền (đã gồm VAT)', suffixText: '₫'),
                        )
                      : Column(
                          key: const ValueKey('k'),
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: oldIdx,
                                    keyboardType: TextInputType.number,
                                    onChanged: (_) => setState(() {}),
                                    decoration: const InputDecoration(labelText: 'Chỉ số cũ'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: newIdx,
                                    keyboardType: TextInputType.number,
                                    onChanged: (_) => setState(() {}),
                                    decoration: const InputDecoration(labelText: 'Chỉ số mới'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: kwh,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(labelText: 'Hoặc nhập số kWh', suffixText: 'kWh'),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 16),
                if (result != null)
                  AppCard(
                    gradient: LinearGradient(colors: [const Color(0xFFFFB224).withValues(alpha: 0.25), const Color(0xFFFFB224).withValues(alpha: 0.08)]),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.bolt_rounded, color: Color(0xFFF5A524), size: 36),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${result.kwh} kWh', style: const TextStyle(fontWeight: FontWeight.w700)),
                                  AnimatedAmount(
                                    value: result.total,
                                    format: (v) => f.money(v),
                                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        for (final u in result.uses)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 60,
                                  child: Text('Bậc ${u.order}', style: const TextStyle(fontWeight: FontWeight.w600)),
                                ),
                                Expanded(
                                  child: CountText(
                                    values: [u.price],
                                    text: (cv) => '${u.kwh} kWh × ${Fmt.money(cv[0], symbol: '')}',
                                  ),
                                ),
                                CountText(values: [u.amount], text: (cv) => f.money(cv[0])),
                              ],
                            ),
                          ),
                        const Divider(height: 20),
                        _row('Cộng', result.subtotal, f.money),
                        _row('VAT ${table.vat.toStringAsFixed(0)}%', result.vat, f.money),
                        if (table.fixedFee > 0) _row('Phí cố định', table.fixedFee, f.money),
                        _row('Tổng cộng', result.total, f.money, bold: true),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => _saveBill(table, result),
                          icon: const Icon(Icons.save_rounded),
                          label: const Text('Lưu kỳ này + tạo khoản chi'),
                        ),
                      ],
                    ),
                  ),
                const SectionTitle('Bảng giá đang dùng'),
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
                  child: Column(
                    children: [
                      for (final t in tiers)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              SizedBox(width: 60, child: Text('Bậc ${t.order}')),
                              Expanded(child: Text(t.to == null ? 'Từ ${t.from} kWh trở lên' : '${t.from} – ${t.to} kWh')),
                              CountText(
                                values: [t.price],
                                text: (cv) => '${Fmt.money(cv[0], symbol: '')} đ/kWh',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                if (bills.isNotEmpty) ...[
                  const SectionTitle('Lịch sử'),
                  for (final b in bills)
                    ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.receipt_rounded)),
                      title: Text('Tháng ${Fmt.month(b.period)} · ${b.kwh} kWh'),
                      subtitle: b.oldIndex == null ? null : Text('Chỉ số ${b.oldIndex} → ${b.newIndex}'),
                      trailing: CountText(
                        values: [b.amount],
                        text: (cv) => f.money(cv[0]),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      onLongPress: () => store.remove(E.bills, b.id),
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String l, double v, String Function(double) fmt, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(
          child: Text(l, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.normal)),
        ),
        AnimatedAmount(
          value: v,
          format: fmt,
          style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600),
        ),
      ],
    ),
  );

  void _saveBill(PriceTable table, ElectricityResult r) {
    final store = ref.read(storeProvider);
    final now = DateTime.now();
    store.put(E.bills, {
      'priceTableId': table.id,
      'period': Fmt.isoDate(DateTime(now.year, now.month, 1)),
      'oldIndex': int.tryParse(oldIdx.text),
      'newIndex': int.tryParse(newIdx.text),
      'kwh': r.kwh,
      'amount': r.total.roundToDouble(),
      'breakdownJson': jsonEncode([
        for (final u in r.uses) {'tier': u.order, 'kwh': u.kwh, 'price': u.price},
      ]),
    });
    if (newIdx.text.isNotEmpty) {
      oldIdx.text = newIdx.text;
      newIdx.clear();
    }
    context.push('/tx/edit', extra: {'type': 1, 'amount': r.total.round(), 'note': 'Tiền điện ${r.kwh} kWh', 'categoryName': 'Điện'});
  }

  Future<void> _editTable(PriceTable? table) async {
    final store = ref.read(storeProvider);
    final name = TextEditingController(text: table?.name ?? 'Bảng giá mới');
    final vat = TextEditingController(text: table == null ? '8' : table.vat.toStringAsFixed(0));
    final fee = TextEditingController(text: table == null ? '0' : amountText(table.fixedFee));
    final rows = <({TextEditingController from, TextEditingController to, TextEditingController price, String? id})>[
      if (table != null)
        for (final t in store.all(E.tiers).map(Tier.new).where((t) => t.tableId == table.id).toList()..sort((a, b) => a.order.compareTo(b.order)))
          (
            from: TextEditingController(text: '${t.from}'),
            to: TextEditingController(text: t.to?.toString() ?? ''),
            price: TextEditingController(text: amountText(t.price)),
            id: t.id,
          ),
    ];
    if (rows.isEmpty) rows.add((from: TextEditingController(text: '0'), to: TextEditingController(), price: TextEditingController(), id: null));
    final removed = <String>[];

    await showModalBottomSheet(
      sheetAnimationStyle: kSheetAnim,
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => FormSheetBody(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          action: Row(
            children: [
              if (table != null && store.all(E.priceTables).length > 1)
                TextButton(
                  onPressed: () {
                    store.remove(E.priceTables, table.id);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Xoá bảng', style: TextStyle(color: AppColors.expense)),
                ),
              const Spacer(),
              FilledButton(
                onPressed: () {
                  final saved = store.put(E.priceTables, {
                    if (table != null) ...table.m,
                    'name': name.text.trim(),
                    'vatPercent': double.tryParse(vat.text) ?? 0,
                    'fixedFee': parseAmount(fee.text),
                    'isDefault': table?.isDefault ?? store.all(E.priceTables).isEmpty,
                  });
                  for (final id in removed) {
                    store.remove(E.tiers, id);
                  }
                  for (final (i, r) in rows.indexed) {
                    store.put(E.tiers, {
                      if (r.id != null) 'id': r.id,
                      'priceTableId': saved['id'],
                      'tierOrder': i + 1,
                      'fromKwh': int.tryParse(r.from.text) ?? 0,
                      'toKwh': int.tryParse(r.to.text),
                      'price': parseAmount(r.price.text),
                    });
                  }
                  setState(() => tableId = saved['id'] as String);
                  Navigator.pop(ctx);
                },
                child: const Text('Lưu'),
              ),
            ],
          ),
          children: [
            Text(table == null ? 'Bảng giá mới' : 'Sửa bảng giá', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Tên bảng giá'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: vat,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'VAT (%)'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: fee,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [ThousandsInputFormatter()],
                    decoration: const InputDecoration(labelText: 'Phí cố định'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Các bậc (để trống "Đến" ở bậc cuối = không giới hạn)', style: TextStyle(fontWeight: FontWeight.w600)),
            for (final (i, r) in rows.indexed)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    SizedBox(width: 48, child: Text('Bậc ${i + 1}')),
                    Expanded(
                      child: TextField(
                        controller: r.from,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Từ', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        controller: r.to,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Đến', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: r.price,
                        keyboardType: TextInputType.number,
                        inputFormatters: const [ThousandsInputFormatter()],
                        decoration: const InputDecoration(labelText: 'Đơn giá', isDense: true),
                      ),
                    ),
                    IconButton(
                      onPressed: rows.length == 1
                          ? null
                          : () => set(() {
                              if (r.id != null) removed.add(r.id!);
                              rows.removeAt(i);
                            }),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                  ],
                ),
              ),
            TextButton.icon(
              onPressed: () => set(() {
                final lastTo = int.tryParse(rows.last.to.text);
                rows.add((
                  from: TextEditingController(text: lastTo == null ? '' : '${lastTo + 1}'),
                  to: TextEditingController(),
                  price: TextEditingController(),
                  id: null,
                ));
              }),
              icon: const Icon(Icons.add),
              label: const Text('Thêm bậc'),
            ),
          ],
        ),
      ),
    );
  }
}
