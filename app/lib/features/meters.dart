import 'dart:convert';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../data/local_store.dart';
import '../data/logic.dart';
import '../data/models.dart';
import '../providers.dart';

const _bolt = Color(0xFFF5A524);

/// Nghiệp vụ công tơ: chỉ số cũ, hoá đơn theo kỳ, tạo/cập nhật giao dịch.
class MeterLogic {
  MeterLogic(this.store, this.f);
  final LocalStore store;
  final Finance f;

  static DateTime periodOf(DateTime d) => DateTime(d.year, d.month);
  static bool samePeriod(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;

  List<Meter> get meters => store.all(E.meters).map(Meter.new).toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  List<Meter> get active => meters.where((m) => !m.isArchived).toList();
  List<PriceTable> get tables => store.all(E.priceTables).map(PriceTable.new).toList();
  List<Bill> get bills => store.all(E.bills).map(Bill.new).toList();

  PriceTable? table(String? id) => tables.where((t) => t.id == id).firstOrNull;
  PriceTable? get defaultTable => tables.where((t) => t.isDefault).firstOrNull ?? tables.firstOrNull;
  List<Tier> tiers(String tableId) => store.all(E.tiers).map(Tier.new).where((t) => t.tableId == tableId).toList()..sort((a, b) => a.order.compareTo(b.order));

  /// Hoá đơn của công tơ (null = hoá đơn tổng EVN), mới nhất trước.
  List<Bill> billsOf(String? meterId) => bills.where((b) => b.meterId == meterId).toList()..sort((a, b) => b.period.compareTo(a.period));
  Bill? billAt(String? meterId, DateTime period) => billsOf(meterId).where((b) => samePeriod(b.period, period)).firstOrNull;

  /// Chỉ số cũ của kỳ: chỉ số mới của kỳ gần nhất trước đó, chưa có thì lấy chỉ số ban đầu.
  int oldIndex(Meter m, DateTime period) {
    final prev = billsOf(m.id).where((b) => b.period.isBefore(periodOf(period)) && b.newIndex != null).firstOrNull;
    return prev?.newIndex ?? m.initialIndex;
  }

  ElectricityResult? calc(Meter m, int kwh) {
    final t = table(m.tableId);
    if (t == null) return null;
    return Electricity.calc(kwh, tiers(t.id), t.vat, t.fixedFee);
  }

  Category? _catByName(int type, List<String> names) {
    final list = f.categories.where((c) => c.type == type).toList();
    for (final n in names) {
      final c = list.where((c) => c.name.toLowerCase() == n.toLowerCase()).firstOrNull;
      if (c != null) return c;
    }
    return list.where((c) => c.parentId == null).firstOrNull;
  }

  /// Danh mục cho giao dịch: theo công tơ nếu đã cấu hình, không thì đoán theo tên.
  String? categoryFor(Meter? m, int txType) {
    if (m?.categoryId != null && f.category(m!.categoryId) != null) return m.categoryId;
    return (txType == TxType.income ? _catByName(2, ['Tiền điện', 'Cho thuê', 'Thu khác']) : _catByName(1, ['Điện', 'Tiền điện', 'Nhà cửa', 'Khác']))?.id;
  }

  /// Tạo mới hoặc cập nhật giao dịch gắn với hoá đơn; trả về id (null nếu đã xoá).
  String? upsertTx({
    String? txId,
    required int type,
    required double amount,
    String? categoryId,
    String? accountId,
    required String note,
    required DateTime at,
  }) {
    final existing = txId == null ? null : store.all(E.transactions).where((t) => t['id'] == txId).firstOrNull;
    if (amount <= 0) {
      if (existing != null) store.remove(E.transactions, txId!);
      return null;
    }
    final acc = f.account(accountId) ?? f.defaultAccount();
    if (acc == null || categoryId == null) return null;
    final rec = store.put(E.transactions, {
      'id': ?existing?['id'],
      'type': type,
      'amount': amount,
      'currencyCode': acc.currencyCode,
      'accountId': acc.id,
      'accountName': acc.name,
      'categoryId': categoryId,
      'categoryName': f.category(categoryId)?.name,
      'occurredAt': toIso8601WithOffset(at),
      'note': note,
    });
    return rec['id'] as String;
  }

  /// Ngày ghi giao dịch cho kỳ: tháng hiện tại → bây giờ, tháng cũ → cuối tháng đó.
  static DateTime txDate(DateTime period) {
    final now = DateTime.now();
    if (samePeriod(now, period)) return now;
    return DateTime(period.year, period.month + 1, 0, 12);
  }
}

// ============================================================================ Tab Công tơ

/// Danh sách công tơ + tổng hợp theo kỳ.
class MetersView extends ConsumerStatefulWidget {
  const MetersView({super.key});

  @override
  ConsumerState<MetersView> createState() => _MetersViewState();
}

class _MetersViewState extends ConsumerState<MetersView> {
  DateTime period = MeterLogic.periodOf(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final store = ref.watchTables(const [E.priceTables, E.tiers, E.bills, E.meters]);
    final f = ref.watch(financeProvider);
    final lg = MeterLogic(store, f);
    final scheme = Theme.of(context).colorScheme;
    final meters = lg.meters;
    final active = meters.where((m) => !m.isArchived).toList();

    if (lg.tables.isEmpty) {
      return const EmptyState(icon: Icons.bolt_rounded, title: 'Chưa có bảng giá', subtitle: 'Tạo bảng giá ở tab "Tính nhanh" trước');
    }
    if (meters.isEmpty) {
      return EmptyState(
        icon: Icons.electric_meter_rounded,
        title: 'Chưa có công tơ',
        subtitle: 'Thêm mỗi tầng/phòng một công tơ để chốt số và tính tiền riêng',
        action: FilledButton.icon(onPressed: () => editMeter(context, ref, null), icon: const Icon(Icons.add_rounded), label: const Text('Thêm công tơ')),
      );
    }

    // Tổng hợp kỳ đang xem
    var rentIncome = 0.0, selfCost = 0.0, recorded = 0;
    for (final m in active) {
      final b = lg.billAt(m.id, period);
      if (b == null) continue;
      recorded++;
      if (m.isRented) {
        rentIncome += b.amount;
      } else {
        selfCost += b.amount;
      }
    }
    final evn = lg.billAt(null, period);
    final netCost = (evn?.amount ?? (selfCost + rentIncome)) - rentIncome;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        AppCard(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 14),
          gradient: LinearGradient(colors: [_bolt.withValues(alpha: 0.22), _bolt.withValues(alpha: 0.06)]),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton.filledTonal(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => period = DateTime(period.year, period.month - 1)),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Column(
                        key: ValueKey(period),
                        children: [
                          Text('Kỳ tháng ${Fmt.month(period)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                          Text('Đã chốt $recorded/${active.length} công tơ', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: 140,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(end: active.isEmpty ? 0 : recorded / active.length),
                                duration: const Duration(milliseconds: 450),
                                curve: Curves.easeOutCubic,
                                builder: (_, v, _) =>
                                    LinearProgressIndicator(value: v, minHeight: 5, color: _bolt, backgroundColor: _bolt.withValues(alpha: 0.18)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => period = DateTime(period.year, period.month + 1)),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  children: [
                    _Sum('Thu người thuê', rentIncome, AppColors.income, Icons.south_west_rounded, f),
                    const SizedBox(width: 8),
                    _Sum(evn != null ? 'Hoá đơn EVN' : 'Nhà dùng', evn?.amount ?? selfCost, AppColors.expense, Icons.north_east_rounded, f),
                    const SizedBox(width: 8),
                    _Sum('Nhà thực chi', netCost, scheme.primary, Icons.home_rounded, f),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: active.isEmpty ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MeterReadingPage(period: period))),
                    icon: Icon(recorded == 0 ? Icons.edit_note_rounded : Icons.edit_rounded),
                    label: Text(recorded == 0 ? 'Chốt số tháng ${Fmt.month(period)}' : 'Sửa số đã chốt'),
                  ),
                ),
              ),
            ],
          ),
        ),
        SectionTitle(
          'Công tơ',
          trailing: TextButton.icon(onPressed: () => editMeter(context, ref, null), icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Thêm')),
        ),
        for (final (i, m) in meters.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _MeterCard(meter: m, period: period, lg: lg).stagger(i),
          ),
      ],
    );
  }
}

class _Sum extends StatelessWidget {
  const _Sum(this.label, this.value, this.color, this.icon, this.f);
  final String label;
  final double value;
  final Color color;
  final IconData icon;
  final Finance f;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          SizedBox(
            height: 22,
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: AnimatedAmount(
                value: value,
                format: (v) => f.money(v),
                style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _MeterCard extends ConsumerWidget {
  const _MeterCard({required this.meter, required this.period, required this.lg});
  final Meter meter;
  final DateTime period;
  final MeterLogic lg;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(financeProvider);
    final scheme = Theme.of(context).colorScheme;
    final bill = lg.billAt(meter.id, period);
    final prev = lg.billAt(meter.id, DateTime(period.year, period.month - 1));
    final color = meter.isRented ? AppColors.income : _bolt;
    final trend = bill != null && prev != null && prev.kwh > 0 ? (bill.kwh - prev.kwh) / prev.kwh * 100 : null;
    return Opacity(
      opacity: meter.isArchived ? 0.5 : 1,
      child: OpenCard(
        radius: 18,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        page: MeterDetailPage(meterId: meter.id),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0.10)]),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(meter.isRented ? Icons.key_rounded : Icons.home_rounded, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          meter.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8)),
                          child: Text(
                            meter.isArchived ? 'Ngừng' : (meter.isRented ? 'Cho thuê' : 'Nhà dùng'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.speed_rounded, size: 14, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          bill == null ? '${lg.oldIndex(meter, DateTime(period.year, period.month + 1))}' : '${bill.oldIndex} → ${bill.newIndex}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant, fontFeatures: const [FontFeature.tabularFigures()]),
                        ),
                      ),
                      if (meter.isRented && (meter.tenantName ?? '').isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.person_rounded, size: 14, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            meter.tenantName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: bill == null
                      ? Container(
                          key: const ValueKey('n'),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.warning.withValues(alpha: 0.45)),
                          ),
                          child: const Text(
                            'Chưa chốt',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.warning),
                          ),
                        )
                      : Column(
                          key: ValueKey(bill.id),
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            AnimatedAmount(
                              value: bill.amount,
                              format: (v) => '${meter.isRented ? '+' : '−'}${f.money(v)}',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: meter.isRented ? AppColors.income : AppColors.expense),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${bill.kwh} kWh',
                                  style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                                ),
                                if (trend != null) ...[const SizedBox(width: 4), _Trend(trend)],
                              ],
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ▲ / ▼ phần trăm kWh so với tháng trước (dùng nhiều hơn = cam, ít hơn = xanh).
class _Trend extends StatelessWidget {
  const _Trend(this.pct);
  final double pct;

  @override
  Widget build(BuildContext context) {
    final up = pct > 0;
    final c = pct.abs() < 0.5 ? Theme.of(context).colorScheme.onSurfaceVariant : (up ? AppColors.warning : AppColors.income);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
      child: Text(
        '${pct.abs() < 0.5 ? '=' : (up ? '▲' : '▼')} ${pct.abs().toStringAsFixed(0)}%',
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: c),
      ),
    );
  }
}

// ============================================================================ Thêm / sửa công tơ

Future<void> editMeter(BuildContext context, WidgetRef ref, Meter? meter) async {
  final store = ref.read(storeProvider);
  final f = ref.read(financeProvider);
  final lg = MeterLogic(store, f);
  final name = TextEditingController(text: meter?.name ?? 'Tầng ${lg.meters.length + 1}');
  final tenant = TextEditingController(text: meter?.tenantName ?? '');
  final initial = TextEditingController(text: '${meter?.initialIndex ?? 0}');
  final note = TextEditingController(text: meter?.note ?? '');
  var kind = meter?.kind ?? Meter.selfUse;
  var tableId = meter?.tableId ?? lg.defaultTable?.id;
  var categoryId = meter?.categoryId;
  var accountId = meter?.accountId;
  var archived = meter?.isArchived ?? false;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    sheetAnimationStyle: kSheetAnim,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) {
        final scheme = Theme.of(ctx).colorScheme;
        final txType = kind == Meter.rented ? TxType.income : TxType.expense;
        final cats = f.categories.where((c) => c.type == txType).toList();
        if (categoryId != null && !cats.any((c) => c.id == categoryId)) categoryId = null;
        InputDecoration dec(String label, IconData icon, {String? helper, String? suffix}) => InputDecoration(
          labelText: label,
          helperText: helper,
          suffixText: suffix,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        );
        return FormSheetBody(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          action: Row(
            children: [
              if (meter != null) ...[
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.expense,
                    side: const BorderSide(color: AppColors.expense),
                    minimumSize: const Size(0, 52),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Xoá', style: TextStyle(fontWeight: FontWeight.w700)),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: ctx,
                      builder: (d) => AlertDialog(
                        title: const Text('Xoá công tơ?'),
                        content: const Text('Lịch sử chốt số của công tơ này cũng bị xoá. Giao dịch đã tạo vẫn giữ nguyên.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Huỷ')),
                          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Xoá')),
                        ],
                      ),
                    );
                    if (ok != true) return;
                    for (final b in lg.billsOf(meter.id)) {
                      store.remove(E.bills, b.id);
                    }
                    store.remove(E.meters, meter.id);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: tableId == null || name.text.trim().isEmpty
                      ? null
                      : () {
                          store.put(E.meters, {
                            'id': ?meter?.id,
                            'name': name.text.trim(),
                            'kind': kind,
                            'tenantName': kind == Meter.rented && tenant.text.trim().isNotEmpty ? tenant.text.trim() : null,
                            'priceTableId': tableId,
                            'initialIndex': int.tryParse(initial.text) ?? 0,
                            'categoryId': categoryId,
                            'accountId': accountId,
                            'note': note.text.trim().isEmpty ? null : note.text.trim(),
                            'isArchived': archived,
                            'sortOrder': meter?.sortOrder ?? lg.meters.length,
                          });
                          Navigator.pop(ctx);
                        },
                  child: Text(meter == null ? 'Thêm công tơ' : 'Lưu thay đổi', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),
            ],
          ),
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: _bolt.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.electric_meter_rounded, color: _bolt),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(meter == null ? 'Thêm công tơ' : 'Sửa công tơ', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      Text(
                        kind == Meter.rented ? 'Theo dõi tiền điện thu hộ' : 'Theo dõi điện tiêu thụ',
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                PillToggle<int>(
                  value: kind,
                  values: const [Meter.selfUse, Meter.rented],
                  icons: const [Icons.home_rounded, Icons.key_rounded],
                  labels: const ['Nhà', 'Thuê'],
                  colors: const [_bolt, AppColors.income],
                  onChanged: (v) => set(() => kind = v),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextField(controller: name, onChanged: (_) => set(() {}), decoration: dec('Tên công tơ (VD: Tầng 3)', Icons.label_outline_rounded)),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              child: kind == Meter.rented
                  ? Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: TextField(controller: tenant, decoration: dec('Người thuê (tuỳ chọn)', Icons.person_outline_rounded)),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    initialValue: tableId,
                    isExpanded: true,
                    decoration: dec('Bảng giá', Icons.receipt_long_rounded),
                    items: [
                      for (final t in lg.tables)
                        DropdownMenuItem(
                          value: t.id,
                          child: Text(t.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) => set(() => tableId = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: initial,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: dec('Số ban đầu', Icons.speed_rounded, suffix: 'kWh'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String?>(
              initialValue: categoryId,
              isExpanded: true,
              decoration: dec(kind == Meter.rented ? 'Danh mục khoản thu' : 'Danh mục khoản chi', Icons.category_outlined),
              items: [
                const DropdownMenuItem(value: null, child: Text('Tự chọn')),
                for (final c in cats)
                  DropdownMenuItem(
                    value: c.id,
                    child: Text(c.parentId == null ? c.name : '   ${c.name}', overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => set(() => categoryId = v),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String?>(
              initialValue: accountId,
              isExpanded: true,
              decoration: dec('Tài khoản thanh toán', Icons.account_balance_wallet_outlined),
              items: [
                const DropdownMenuItem(value: null, child: Text('Tài khoản mặc định')),
                for (final a in f.accounts.where((a) => !a.isArchived))
                  DropdownMenuItem(
                    value: a.id,
                    child: Text(a.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => set(() => accountId = v),
            ),
            const SizedBox(height: 14),
            TextField(controller: note, decoration: dec('Ghi chú (tuỳ chọn)', Icons.notes_rounded)),
            if (meter != null) ...[
              const SizedBox(height: 12),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: SwitchListTile(
                  title: const Text('Ngừng theo dõi', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('Ẩn khỏi màn chốt số, vẫn giữ lịch sử', style: TextStyle(fontSize: 12)),
                  value: archived,
                  onChanged: (v) => set(() => archived = v),
                ),
              ),
            ],
          ],
        );
      },
    ),
  );
}

// ============================================================================ Chốt số theo kỳ

/// Nhập chỉ số mới cho tất cả công tơ trong một kỳ; tự tính tiền và tạo khoản thu/chi.
class MeterReadingPage extends ConsumerStatefulWidget {
  const MeterReadingPage({super.key, required this.period});
  final DateTime period;

  @override
  ConsumerState<MeterReadingPage> createState() => _MeterReadingPageState();
}

class _MeterReadingPageState extends ConsumerState<MeterReadingPage> {
  late final MeterLogic lg = MeterLogic(ref.read(storeProvider), ref.read(financeProvider));
  late final List<Meter> meters = lg.active;
  final newIdx = <String, TextEditingController>{};
  final oldIdx = <String, int>{};

  /// Ô nhập chỉ số mới của từng công tơ (bấm "Tiếp" trên bàn phím → sang công tơ sau).
  final focus = <String, FocusNode>{};

  /// Công tơ đang mở bảng chi tiết bậc giá.
  final expanded = <String>{};
  final evnAmount = TextEditingController();
  final evnKwh = TextEditingController();
  bool useEvn = false;

  @override
  void initState() {
    super.initState();
    for (final m in meters) {
      final b = lg.billAt(m.id, widget.period);
      oldIdx[m.id] = b?.oldIndex ?? lg.oldIndex(m, widget.period);
      newIdx[m.id] = TextEditingController(text: b?.newIndex?.toString() ?? '');
      focus[m.id] = FocusNode();
    }
    final evn = lg.billAt(null, widget.period);
    if (evn != null) {
      useEvn = true;
      evnAmount.text = amountText(evn.amount);
      evnKwh.text = evn.kwh == 0 ? '' : '${evn.kwh}';
    }
  }

  @override
  void dispose() {
    for (final c in newIdx.values) {
      c.dispose();
    }
    for (final n in focus.values) {
      n.dispose();
    }
    evnAmount.dispose();
    evnKwh.dispose();
    super.dispose();
  }

  int? _kwh(Meter m) {
    final n = int.tryParse(newIdx[m.id]!.text);
    if (n == null) return null;
    return n - oldIdx[m.id]!;
  }

  @override
  Widget build(BuildContext context) {
    final f = ref.watch(financeProvider);
    final scheme = Theme.of(context).colorScheme;
    var rent = 0.0, self = 0.0, kwhSum = 0, filled = 0;
    var invalid = false;
    for (final m in meters) {
      final k = _kwh(m);
      if (k == null) continue;
      if (k < 0) {
        invalid = true;
        continue;
      }
      filled++;
      kwhSum += k;
      final r = lg.calc(m, k);
      if (r == null) continue;
      if (m.isRented) {
        rent += r.total.roundToDouble();
      } else {
        self += r.total.roundToDouble();
      }
    }
    final evn = useEvn ? parseAmount(evnAmount.text) : 0.0;
    final evnK = int.tryParse(evnKwh.text);
    final net = (useEvn ? evn : self + rent) - rent;

    final progress = meters.isEmpty ? 0.0 : filled / meters.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Chốt số điện')),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        children: [
          // Đầu trang: kỳ + tiến độ nhập
          AppCard(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_bolt.withValues(alpha: 0.24), _bolt.withValues(alpha: 0.06)],
            ),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: _bolt, borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.bolt_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tháng ${Fmt.month(widget.period)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                          Text('Nhập chỉ số mới trên mặt công tơ', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$filled/${meters.length}',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _bolt, fontFeatures: [FontFeature.tabularFigures()]),
                        ),
                        Text('công tơ', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: progress),
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 8, color: _bolt, backgroundColor: _bolt.withValues(alpha: 0.15)),
                  ),
                ),
                if (kwhSum > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Tổng đã nhập: $kwhSum kWh',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (final (i, m) in meters.indexed) _row(m, f, scheme, i).stagger(i),
          const SizedBox(height: 8),
          // Đối chiếu hoá đơn EVN tổng (tuỳ chọn)
          AppCard(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.receipt_long_rounded, color: _bolt),
                  title: const Text('Hoá đơn EVN cả nhà', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Nhập số tiền EVN báo để biết nhà mình thực chi bao nhiêu'),
                  value: useEvn,
                  onChanged: (v) => setState(() => useEvn = v),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  child: !useEvn
                      ? const SizedBox(width: double.infinity)
                      : Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextField(
                                    controller: evnAmount,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: const [ThousandsInputFormatter()],
                                    onChanged: (_) => setState(() {}),
                                    decoration: const InputDecoration(labelText: 'Số tiền EVN', suffixText: '₫'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: TextField(
                                    controller: evnKwh,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    onChanged: (_) => setState(() {}),
                                    decoration: const InputDecoration(labelText: 'Số kWh', suffixText: 'kWh'),
                                  ),
                                ),
                              ],
                            ),
                            if (evnK != null && filled == meters.length && evnK != kwhSum)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.warning),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Tổng các công tơ $kwhSum kWh, EVN $evnK kWh → chênh ${evnK - kwhSum} kWh (hao hụt / dùng chung)',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: KeyboardAvoidBottomBar(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _Sum('Thu người thuê', rent, AppColors.income, Icons.south_west_rounded, f),
                  const SizedBox(width: 8),
                  _Sum(useEvn ? 'EVN' : 'Nhà dùng', useEvn ? evn : self, AppColors.expense, Icons.north_east_rounded, f),
                  const SizedBox(width: 8),
                  _Sum('Nhà thực chi', net, scheme.primary, Icons.home_rounded, f),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: invalid || (filled == 0 && !useEvn) ? null : _save,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(invalid ? 'Có chỉ số mới nhỏ hơn chỉ số cũ' : 'Lưu $filled công tơ + tạo thu/chi'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(Meter m, Finance f, ColorScheme scheme, int index) {
    final k = _kwh(m);
    final r = k == null || k < 0 ? null : lg.calc(m, k);
    final color = m.isRented ? AppColors.income : _bolt;
    final done = r != null;
    final bad = k != null && k < 0;
    final last = index == meters.length - 1;
    const digits = TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 1.2, fontFeatures: [FontFeature.tabularFigures()]);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: bad
                ? AppColors.expense.withValues(alpha: 0.6)
                : done
                ? color.withValues(alpha: 0.45)
                : scheme.outlineVariant.withValues(alpha: 0.4),
            width: done || bad ? 1.4 : 1,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tên công tơ
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                  child: Icon(m.isRented ? Icons.key_rounded : Icons.home_rounded, color: color, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                      Text(
                        [
                          m.isRented ? 'Cho thuê' : 'Nhà dùng',
                          if (m.isRented && (m.tenantName ?? '').isNotEmpty) m.tenantName!,
                          lg.table(m.tableId)?.name ?? '',
                        ].where((x) => x.isNotEmpty).join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                  child: done
                      ? const Icon(Icons.check_circle_rounded, key: ValueKey('ok'), color: AppColors.income, size: 24)
                      : Container(
                          key: const ValueKey('n'),
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: scheme.outlineVariant, width: 1.5),
                          ),
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant),
                          ),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Chỉ số cũ → chỉ số mới (chữ số lớn, đều hàng)
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              decoration: BoxDecoration(color: scheme.surfaceContainerHighest.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(16)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Số cũ',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 2),
                      Text('${oldIdx[m.id]}', style: digits.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                    child: Icon(Icons.arrow_forward_rounded, color: scheme.onSurfaceVariant, size: 20),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Số mới',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
                        ),
                        TextField(
                          controller: newIdx[m.id],
                          focusNode: focus[m.id],
                          keyboardType: TextInputType.number,
                          textInputAction: last ? TextInputAction.done : TextInputAction.next,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => last ? FocusManager.instance.primaryFocus?.unfocus() : focus[meters[index + 1].id]!.requestFocus(),
                          style: digits.copyWith(color: bad ? AppColors.expense : null),
                          cursorColor: color,
                          decoration: InputDecoration(
                            hintText: '${oldIdx[m.id]}',
                            hintStyle: digits.copyWith(color: scheme.onSurfaceVariant.withValues(alpha: 0.25)),
                            isDense: true,
                            filled: false,
                            contentPadding: const EdgeInsets.only(top: 2),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Lỗi: chỉ số mới nhỏ hơn
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: !bad
                  ? const SizedBox(width: double.infinity)
                  : Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: AppColors.expense.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 18, color: AppColors.expense),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Số mới nhỏ hơn số cũ (${oldIdx[m.id]}). Kiểm tra lại mặt công tơ.',
                              style: const TextStyle(fontSize: 12, color: AppColors.expense, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            // Kết quả: kWh + tiền, chi tiết bậc giá
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: r == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(color: _bolt.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.bolt_rounded, size: 16, color: _bolt),
                                    const SizedBox(width: 2),
                                    Text(
                                      '${r.kwh} kWh',
                                      style: const TextStyle(fontWeight: FontWeight.w800, color: _bolt, fontFeatures: [FontFeature.tabularFigures()]),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: AnimatedAmount(
                                    value: r.total.roundToDouble(),
                                    format: (v) => '${m.isRented ? '+' : '−'}${f.money(v)}',
                                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: m.isRented ? AppColors.income : AppColors.expense),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 6)),
                              onPressed: () => setState(() => expanded.contains(m.id) ? expanded.remove(m.id) : expanded.add(m.id)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('Chi tiết bậc giá', style: TextStyle(fontSize: 12)),
                                  AnimatedRotation(
                                    turns: expanded.contains(m.id) ? 0.5 : 0,
                                    duration: const Duration(milliseconds: 220),
                                    child: const Icon(Icons.expand_more_rounded, size: 18),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOutCubic,
                            alignment: Alignment.topCenter,
                            child: !expanded.contains(m.id) ? const SizedBox(width: double.infinity) : _breakdown(r, f, scheme),
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

  /// Bảng chi tiết: từng bậc (kWh × đơn giá), VAT, phí cố định.
  Widget _breakdown(ElectricityResult r, Finance f, ColorScheme scheme) {
    Widget line(String a, String b, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              a,
              style: TextStyle(fontSize: 12.5, color: bold ? null : scheme.onSurfaceVariant, fontWeight: bold ? FontWeight.w800 : null),
            ),
          ),
          Text(
            b,
            style: TextStyle(fontSize: 12.5, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ],
      ),
    );
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(color: scheme.surfaceContainerHighest.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          for (final u in r.uses)
            if (u.kwh > 0) line('Bậc ${u.order} · ${u.kwh} kWh × ${f.money(u.price)}', f.money(u.amount)),
          if (r.vat > 0) line('Thuế VAT', f.money(r.vat)),
          if (r.fixedFee > 0) line('Phí cố định', f.money(r.fixedFee)),
          const Divider(height: 12),
          line('Tổng', f.money(r.total.roundToDouble()), bold: true),
        ],
      ),
    );
  }

  void _save() {
    final store = ref.read(storeProvider);
    final p = widget.period;
    final at = MeterLogic.txDate(p);
    final periodStr = Fmt.isoDate(p);
    var saved = 0;
    for (final m in meters) {
      final k = _kwh(m);
      final existing = lg.billAt(m.id, p);
      if (k == null || k < 0) continue;
      final r = lg.calc(m, k);
      if (r == null) continue;
      final amount = r.total.roundToDouble();
      // Nhà dùng: nếu có hoá đơn EVN thì EVN là khoản chi thật → không tạo chi riêng cho từng tầng.
      final txType = m.isRented ? TxType.income : TxType.expense;
      final wantTx = m.isRented || !useEvn;
      final txId = lg.upsertTx(
        txId: existing?.transactionId,
        type: txType,
        amount: wantTx ? amount : 0,
        categoryId: lg.categoryFor(m, txType),
        accountId: m.accountId,
        note: m.isRented
            ? 'Tiền điện ${m.name}${(m.tenantName ?? '').isNotEmpty ? ' (${m.tenantName})' : ''} · ${r.kwh} kWh · T${Fmt.month(p)}'
            : 'Tiền điện ${m.name} · ${r.kwh} kWh · T${Fmt.month(p)}',
        at: at,
      );
      store.put(E.bills, {
        'id': ?existing?.id,
        'meterId': m.id,
        'priceTableId': m.tableId,
        'period': periodStr,
        'oldIndex': oldIdx[m.id],
        'newIndex': int.parse(newIdx[m.id]!.text),
        'kwh': r.kwh,
        'amount': amount,
        'breakdownJson': jsonEncode([
          for (final u in r.uses) {'tier': u.order, 'kwh': u.kwh, 'price': u.price},
        ]),
        'transactionId': txId,
      });
      saved++;
    }
    // Hoá đơn EVN tổng
    final evnBill = lg.billAt(null, p);
    final evn = parseAmount(evnAmount.text);
    if (useEvn && evn > 0) {
      final txId = lg.upsertTx(
        txId: evnBill?.transactionId,
        type: TxType.expense,
        amount: evn,
        categoryId: lg.categoryFor(null, TxType.expense),
        accountId: null,
        note: 'Hoá đơn điện EVN · T${Fmt.month(p)}',
        at: at,
      );
      store.put(E.bills, {
        'id': ?evnBill?.id,
        'meterId': null,
        'priceTableId': evnBill?.tableId ?? lg.defaultTable!.id,
        'period': periodStr,
        'kwh': int.tryParse(evnKwh.text) ?? 0,
        'amount': evn,
        'transactionId': txId,
      });
    } else if (evnBill != null) {
      lg.upsertTx(txId: evnBill.transactionId, type: TxType.expense, amount: 0, note: '', at: at);
      store.remove(E.bills, evnBill.id);
    }
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã chốt $saved công tơ tháng ${Fmt.month(p)}')));
    Navigator.pop(context);
  }
}

// ============================================================================ Chi tiết một công tơ

class MeterDetailPage extends ConsumerWidget {
  const MeterDetailPage({super.key, required this.meterId});
  final String meterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watchTables(const [E.priceTables, E.tiers, E.bills, E.meters]);
    final f = ref.watch(financeProvider);
    final lg = MeterLogic(store, f);
    final m = lg.meters.where((x) => x.id == meterId).firstOrNull;
    final scheme = Theme.of(context).colorScheme;
    if (m == null)
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(icon: Icons.electric_meter_rounded, title: 'Công tơ đã bị xoá'),
      );
    final bills = lg.billsOf(m.id);
    final recent = bills.take(12).toList().reversed.toList();
    final color = m.isRented ? AppColors.income : _bolt;
    final maxKwh = recent.fold(0, (s, b) => max(s, b.kwh));
    final total = bills.fold(0.0, (s, b) => s + b.amount);
    final avgKwh = bills.isEmpty ? 0.0 : bills.fold(0, (s, b) => s + b.kwh) / bills.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(m.name),
        actions: [IconButton(tooltip: 'Sửa', onPressed: () => editMeter(context, ref, m), icon: const Icon(Icons.edit_rounded))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          AppCard(
            gradient: LinearGradient(colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0.05)]),
            child: Row(
              children: [
                Icon(m.isRented ? Icons.key_rounded : Icons.home_rounded, color: color, size: 34),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.isRented ? 'Cho thuê${(m.tenantName ?? '').isNotEmpty ? ' · ${m.tenantName}' : ''}' : 'Nhà dùng',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Chỉ số hiện tại ${lg.oldIndex(m, DateTime(DateTime.now().year, DateTime.now().month + 1))} · ${lg.table(m.tableId)?.name ?? ''}',
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _Sum(m.isRented ? 'Tổng đã thu' : 'Tổng đã dùng', total, m.isRented ? AppColors.income : AppColors.expense, Icons.payments_rounded, f),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(color: _bolt.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    children: [
                      const Text(
                        'TB mỗi tháng',
                        style: TextStyle(fontSize: 11, color: _bolt, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 3),
                      CountText(
                        values: [avgKwh],
                        text: (v) => '${v[0].round()} kWh',
                        style: const TextStyle(color: _bolt, fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (recent.isNotEmpty) ...[
            const SectionTitle('kWh theo tháng'),
            AppCard(
              child: SizedBox(
                height: 180,
                child: BarChart(
                  BarChartData(
                    maxY: maxKwh == 0 ? 1 : maxKwh * 1.2,
                    borderData: FlBorderData(show: false),
                    gridData: const FlGridData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(),
                      topTitles: const AxisTitles(),
                      rightTitles: const AxisTitles(),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 22,
                          getTitlesWidget: (v, _) => Text('T${recent[v.toInt()].period.month}', style: const TextStyle(fontSize: 10)),
                        ),
                      ),
                    ),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (g, _, r, _) =>
                            BarTooltipItem('${r.toY.round()} kWh\n${f.money(recent[g.x].amount)}', const TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                    ),
                    barGroups: [
                      for (final (i, b) in recent.indexed)
                        BarChartGroupData(
                          x: i,
                          barRods: [BarChartRodData(toY: b.kwh.toDouble(), color: color, width: 14, borderRadius: BorderRadius.circular(4))],
                        ),
                    ],
                  ),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                ),
              ),
            ),
          ],
          const SectionTitle('Lịch sử chốt số'),
          if (bills.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('Chưa chốt kỳ nào')),
            )
          else
            for (final (i, b) in bills.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MeterReadingPage(period: b.period))),
                  padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(14)),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'T${b.period.month}',
                              style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 15, height: 1.1),
                            ),
                            Text(
                              '${b.period.year}',
                              style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('${b.kwh} kWh', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                                if (i + 1 < bills.length && bills[i + 1].kwh > 0) ...[
                                  const SizedBox(width: 6),
                                  _Trend((b.kwh - bills[i + 1].kwh) / bills[i + 1].kwh * 100),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Chỉ số ${b.oldIndex} → ${b.newIndex}',
                              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, fontFeatures: const [FontFeature.tabularFigures()]),
                            ),
                          ],
                        ),
                      ),
                      AnimatedAmount(
                        value: b.amount,
                        format: (v) => '${m.isRented ? '+' : '−'}${f.money(v)}',
                        style: TextStyle(fontWeight: FontWeight.w900, color: m.isRented ? AppColors.income : AppColors.expense),
                      ),
                    ],
                  ),
                ),
              ).stagger(i),
        ],
      ),
    );
  }
}
