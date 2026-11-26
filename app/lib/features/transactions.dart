import 'dart:async';
import 'dart:convert';

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';

import '../core/format.dart';
import '../core/icons.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../data/local_store.dart';
import '../data/location.dart';
import '../data/logic.dart';
import '../data/models.dart';
import '../data/ocr.dart';
import '../data/calendar_look.dart';
import '../data/time_config.dart';
import '../data/notify_prefs.dart';
import '../data/session.dart';
import '../providers.dart';
import 'common.dart';

Color txColor(int type) => switch (type) {
  TxType.income => AppColors.income,
  TxType.transfer => AppColors.transfer,
  _ => AppColors.expense,
};

/// Ngày mà nút "+" chung sẽ dùng khi thêm giao dịch (ngày đang chọn ở dạng lịch); null = bây giờ.
final txAddDate = ValueNotifier<DateTime?>(null);

/// Giữ giờ hiện tại nhưng đổi sang ngày [day].
DateTime atDay(DateTime? day) {
  final now = DateTime.now();
  if (day == null) return now;
  final l = day.toLocal();
  return DateTime(l.year, l.month, l.day, now.hour, now.minute);
}

/// Một dòng giao dịch.
/// Danh sách giao dịch gom nhóm theo từng ngày, có tổng thu/chi mỗi ngày và khoảng cách rõ ràng.
class GroupedTxDays extends ConsumerWidget {
  const GroupedTxDays({super.key, required this.items});
  final List<Txn> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.read(financeProvider);
    final scheme = Theme.of(context).colorScheme;
    final byDay = <DateTime, List<Txn>>{};
    for (final t in items) {
      byDay.putIfAbsent(dateOnly(t.occurredAt), () => []).add(t);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, day) in days.indexed)
          () {
            final dayItems = byDay[day]!;
            final dt = f.totals(dayItems);
            final card = Padding(
              padding: EdgeInsets.only(bottom: i == days.length - 1 ? 0 : 12),
              child: RepaintBoundary(
                child: AppCard(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(Fmt.dayHeader(day), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                            ),
                            if (dt.income > 0)
                              Text(
                                '+${Fmt.compact(dt.income)}  ',
                                style: const TextStyle(color: AppColors.income, fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                            if (dt.expense > 0)
                              Text(
                                '-${Fmt.compact(dt.expense)}',
                                style: const TextStyle(color: AppColors.expense, fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                          ],
                        ),
                      ),
                      Divider(height: 1, thickness: 1, indent: 14, endIndent: 14, color: scheme.outlineVariant.withValues(alpha: 0.35)),
                      const SizedBox(height: 4),
                      for (final (j, tx) in dayItems.indexed) ...[
                        if (j > 0) const SizedBox(height: 4),
                        TxTile(txn: tx),
                      ],
                    ],
                  ),
                ),
              ),
            );
            return i < 5 ? card.stagger(i) : card;
          }(),
      ],
    );
  }
}

class TxTile extends ConsumerWidget {
  const TxTile({super.key, required this.txn, this.showDate = false});
  final Txn txn;
  final bool showDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Chỉ theo dõi thứ dòng này hiển thị: thêm/sửa giao dịch KHÁC không làm dòng này dựng lại.
    ref.watch(financeProvider.select((f) => (f.categories, f.accounts, f.currencies, f.settings, f.photosOf(txn.id))));
    final f = ref.read(financeProvider);
    final cat = f.category(txn.categoryId);
    final acc = f.account(txn.accountId);
    final photos = f.photosOf(txn.id); // tra sẵn, không quét toàn bộ ảnh cho từng dòng
    final isTransfer = txn.type == TxType.transfer;
    final scheme = Theme.of(context).colorScheme;
    final catColor = isTransfer ? AppColors.transfer : hexColor(cat?.color, scheme.primary);
    final title = isTransfer ? 'Chuyển khoản' : (cat?.name ?? txn.categoryName ?? 'Không có danh mục');
    final accLabel = isTransfer ? '${acc?.name ?? '?'} → ${f.account(txn.toAccountId)?.name ?? '?'}' : (acc?.name ?? '');
    final extraMeta = [
      if (txn.location?.isNotEmpty == true) '📍 ${txn.location!}',
      if (showDate) Fmt.dateShort(txn.occurredAt),
    ].join(' · ');
    // Bấm vào giao dịch: thẻ "biến hình" thành màn sửa giao dịch
    return OpenCard(
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      page: TransactionEditPage(id: txn.id, type: txn.type),
      child: Row(
        children: [
          if (photos.isNotEmpty) ...[
            _StackedTxPhotos(photos: photos),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: _TxMetaColumn(
              title: title,
              catColor: catColor,
              note: txn.note,
              accLabel: accLabel,
              extraMeta: extraMeta,
              isRecurring: txn.recurringRuleId != null,
            ),
          ),
          const SizedBox(width: 8),
          CountText(
            values: [txn.amount],
            text: (cv) =>
                (txn.type == TxType.expense
                    ? '-'
                    : txn.type == TxType.income
                    ? '+'
                    : '') +
                f.money(cv[0], txn.currencyCode),
            style: TextStyle(fontWeight: FontWeight.w700, color: txColor(txn.type)),
          ),
        ],
      ),
    );
  }
}

class _TxMetaColumn extends StatelessWidget {
  const _TxMetaColumn({
    required this.title,
    required this.catColor,
    required this.note,
    required this.accLabel,
    required this.extraMeta,
    this.isRecurring = false,
  });
  final String title;
  final Color catColor;
  final String? note;
  final String accLabel;
  final String extraMeta;
  final bool isRecurring;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3.5,
              height: 14,
              margin: const EdgeInsets.only(right: 7),
              decoration: BoxDecoration(color: catColor, borderRadius: BorderRadius.circular(2)),
            ),
            Flexible(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isRecurring) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.repeat_rounded, size: 14)),
          ],
        ),
        if (note?.isNotEmpty == true) ...[
          const SizedBox(height: 3),
          Row(
            children: [
              Icon(Icons.sticky_note_2_outlined, size: 12.5, color: catColor.withValues(alpha: 0.85)),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  note!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: scheme.onSurface.withValues(alpha: 0.88)),
                ),
              ),
            ],
          ),
        ],
        if (accLabel.isNotEmpty || extraMeta.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              if (accLabel.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: scheme.primary.withValues(alpha: 0.16), width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.account_balance_wallet_outlined, size: 10.5, color: scheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        accLabel,
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: scheme.primary),
                      ),
                    ],
                  ),
                ),
              if (accLabel.isNotEmpty && extraMeta.isNotEmpty) const SizedBox(width: 6),
              if (extraMeta.isNotEmpty)
                Expanded(
                  child: Text(
                    extraMeta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Hiển thị ảnh giao dịch dạng xếp đè lên nhau; nếu có nhiều hơn 2 ảnh thì hiện huy hiệu +1, +2...
class _StackedTxPhotos extends StatelessWidget {
  const _StackedTxPhotos({required this.photos});
  final List<String> photos;

  @override
  Widget build(BuildContext context) {
    final visible = photos.length > 2 ? 2 : photos.length;
    final extra = photos.length - visible;
    const size = 44.0;
    const step = 14.0;
    final totalW = size + (visible - 1) * step;
    final surface = Theme.of(context).colorScheme.surface;

    return SizedBox(
      width: totalW,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < visible; i++)
            Positioned(
              left: i * step,
              top: 0,
              width: size,
              height: size,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: surface, width: 1.5),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 1)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.5),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      FileImage2(photos[i], radius: 0),
                      if (i == visible - 1 && extra > 0)
                        Container(
                          color: Colors.black.withValues(alpha: 0.52),
                          alignment: Alignment.center,
                          child: Text(
                            '+$extra',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Danh sách giao dịch: dạng danh sách hoặc lịch, lọc theo tháng / loại / tìm kiếm.
class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key, this.showFab = false});
  final bool showFab;

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {
  bool calendar = true;
  DateTime month = DateTime.now();
  DateTime selectedDay = dateOnly(DateTime.now());
  int? type;
  MoneySource source = MoneySource.all;

  /// Danh mục đang lọc (chọn nhiều). Chọn danh mục cha thì gồm cả danh mục con.
  final Set<String> cats = {};
  String query = '';
  final search = TextEditingController();

  /// Ô ngày đã dựng: nếu dữ liệu của ô không đổi thì dùng lại đúng widget cũ → Flutter bỏ qua, không dựng lại.
  /// (Thêm 1 giao dịch chỉ làm 1 ô vẽ lại thay vì cả 42 ô.)
  final _cellCache = <DateTime, (String, Widget)>{};

  /// Dòng giao dịch đã dựng, dùng lại khi bản ghi không đổi (cùng đối tượng dữ liệu).
  final _rowCache = <String, (Object, Widget)>{};
  String _cellEnv = '';

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    txAddDate.value = calendar ? selectedDay : null; // nút + ở thanh dưới thêm vào ngày đang chọn
    final f = ref.watch(financeProvider);
    final (from, to) = f.monthRange(month);
    var list = f.inRange(from, to);
    if (source != MoneySource.all) list = list.where((t) => f.account(t.accountId)?.matches(source) ?? false).toList();
    if (cats.isNotEmpty) list = list.where((t) => _inCats(f, cats, t)).toList();
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      list = list
          .where(
            (t) =>
                (t.note ?? '').toLowerCase().contains(q) ||
                (t.location ?? '').toLowerCase().contains(q) ||
                (f.category(t.categoryId)?.name ?? '').toLowerCase().contains(q),
          )
          .toList();
    }
    // Tổng tính trước khi lọc theo loại để các ô Thu/Chi luôn có số.
    final totals = f.totals(list);
    if (type != null) list = list.where((t) => t.type == type).toList();

    final canAdd = ref.watch(sessionProvider).can(Perm.giaoDich);
    return Scaffold(
      floatingActionButton: widget.showFab && canAdd
          ? OpenContainer(
              transitionDuration: const Duration(milliseconds: 520),
              transitionType: ContainerTransitionType.fadeThrough,
              closedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              closedColor: Theme.of(context).colorScheme.primary,
              middleColor: Theme.of(context).colorScheme.primary,
              openColor: Theme.of(context).scaffoldBackgroundColor,
              closedElevation: 4,
              openElevation: 0,
              openBuilder: (_, _) => TransactionEditPage(type: 1, preset: {if (txAddDate.value != null) 'date': txAddDate.value!}),
              closedBuilder: (_, open) => SizedBox(
                width: 56,
                height: 56,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    open();
                  },
                  child: Icon(Icons.add_rounded, color: Theme.of(context).colorScheme.onPrimary, size: 28),
                ),
              ),
            )
          : null,
      appBar: AppBar(
        title: const Text('Giao dịch'),
        actions: [
          IconButton(
            tooltip: 'Giao dịch định kỳ',
            onPressed: () => context.push('/recurring'),
            icon: const Icon(Icons.event_repeat_rounded),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: PillToggle<bool>(
              value: calendar,
              values: const [false, true],
              icons: const [Icons.view_agenda_rounded, Icons.calendar_month_rounded],
              onChanged: (v) => setState(() => calendar = v),
            ),
          ),
        ],
      ),
      // Vuốt từ mép trái / phải màn hình để lùi / tiến một tháng.
      body: EdgeSwipe(
        onPrev: () => _goMonth(-1),
        onNext: () => _goMonth(1),
        child: Column(
          children: [
            // Khối đầu trang: tháng + kiểu xem + tổng (ô tổng = bộ lọc nhanh theo loại).
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: AppCard(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton.filledTonal(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _goMonth(-1),
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            transitionBuilder: (c, a) => FadeTransition(
                              opacity: a,
                              child: SlideTransition(
                                position: Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(a),
                                child: c,
                              ),
                            ),
                            child: Column(
                              key: ValueKey(from),
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.event_note_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        'Tháng ${Fmt.month(from)}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${Fmt.dateShort(from)} – ${Fmt.dateShort(to.subtract(const Duration(days: 1)))} · ${list.length} giao dịch',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        ),
                        IconButton.filledTonal(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _goMonth(1),
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        children: [
                          _Total(
                            'Thu',
                            Icons.south_west_rounded,
                            totals.income,
                            AppColors.income,
                            f.money,
                            selected: type == TxType.income,
                            onTap: () => _toggleType(TxType.income),
                          ),
                          const SizedBox(width: 8),
                          _Total(
                            'Chi',
                            Icons.north_east_rounded,
                            totals.expense,
                            AppColors.expense,
                            f.money,
                            selected: type == TxType.expense,
                            onTap: () => _toggleType(TxType.expense),
                          ),
                          const SizedBox(width: 8),
                          _Total(
                            'Còn lại',
                            Icons.account_balance_wallet_rounded,
                            totals.income - totals.expense,
                            Theme.of(context).colorScheme.primary,
                            f.money,
                            selected: type == null,
                            onTap: () => setState(() => type = null),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: search,
                      onChanged: (v) => setState(() => query = v.trim()),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Tìm ghi chú, danh mục...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        suffixIcon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                          child: query.isEmpty
                              ? const SizedBox.shrink(key: ValueKey('none'))
                              : IconButton(
                                  key: const ValueKey('clear'),
                                  icon: const Icon(Icons.close_rounded, size: 18),
                                  onPressed: () => setState(() {
                                    search.clear();
                                    query = '';
                                  }),
                                ),
                        ),
                        isDense: true,
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Badge(
                    isLabelVisible: _activeFilters > 0,
                    label: Text('$_activeFilters'),
                    child: IconButton.filledTonal(tooltip: 'Bộ lọc', onPressed: _openFilters, icon: const Icon(Icons.tune_rounded)),
                  ),
                ],
              ),
            ),
            // Bộ lọc đang bật, bấm × để bỏ.
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              child: _activeFilters == 0
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (type != null)
                              InputChip(visualDensity: VisualDensity.compact, label: Text(_typeLabel(type!)), onDeleted: () => setState(() => type = null)),
                            if (source != MoneySource.all)
                              InputChip(
                                visualDensity: VisualDensity.compact,
                                avatar: Icon(source == MoneySource.cash ? Icons.payments_rounded : Icons.account_balance_rounded, size: 16),
                                label: Text(source == MoneySource.cash ? 'Tiền mặt' : 'Tài khoản'),
                                onDeleted: () => setState(() => source = MoneySource.all),
                              ),
                            for (final id in cats)
                              if (ref.read(financeProvider).category(id) case final c?)
                                InputChip(
                                  key: ValueKey('cat-$id'),
                                  visualDensity: VisualDensity.compact,
                                  avatar: Icon(iconOf(c.icon), size: 16, color: hexColor(c.color)),
                                  label: Text(c.name),
                                  onDeleted: () => setState(() => cats.remove(id)),
                                ),
                          ],
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: calendar ? _calendarView(list, from) : _listView(list)),
            ),
          ],
        ),
      ),
    );
  }

  int get _activeFilters => (type != null ? 1 : 0) + (source != MoneySource.all ? 1 : 0) + cats.length;

  /// Giao dịch thuộc một trong [ids]: chính danh mục đó hoặc một danh mục cha của nó.
  static bool _inCats(Finance f, Set<String> ids, Txn t) {
    var c = f.category(t.categoryId);
    for (var guard = 0; c != null && guard < 10; guard++) {
      if (ids.contains(c.id)) return true;
      c = f.category(c.parentId);
    }
    return false;
  }

  String _typeLabel(int t) => switch (t) {
    TxType.expense => 'Khoản chi',
    TxType.income => 'Khoản thu',
    _ => 'Chuyển khoản',
  };

  void _toggleType(int t) => setState(() => type = type == t ? null : t);

  /// Bảng lọc: loại giao dịch + nguồn tiền + danh mục.
  void _openFilters() {
    final f = ref.read(financeProvider);
    final children = <String, List<Category>>{};
    for (final c in f.categories) {
      if (c.parentId != null) children.putIfAbsent(c.parentId!, () => []).add(c);
    }
    final roots = [
      for (final c in f.categories)
        if (c.parentId == null || f.category(c.parentId) == null) c,
    ];

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      sheetAnimationStyle: kSheetAnim,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          void apply(VoidCallback fn) {
            setState(fn);
            setSheet(() {});
          }

          Widget group(String title, List<Widget> chips) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: chips),
              ],
            ),
          );

          // Chip danh mục: chọn cha = cả nhánh; khi cha đang chọn thì hiện các con để thu hẹp.
          final scheme = Theme.of(ctx).colorScheme;
          Widget catChip(Category c, {bool partial = false, required VoidCallback onTap}) {
            final color = hexColor(c.color);
            final on = cats.contains(c.id) || partial;
            return FilterChip(
              showCheckmark: false,
              avatar: Icon(iconOf(c.icon), size: 16, color: on ? color : scheme.onSurfaceVariant),
              label: Text(c.name),
              selected: on,
              selectedColor: color.withValues(alpha: partial ? 0.10 : 0.20),
              side: BorderSide(color: on ? color.withValues(alpha: 0.6) : scheme.outlineVariant),
              onSelected: (_) => apply(onTap),
            );
          }

          List<Widget> catSection(int t) {
            final list = roots.where((c) => c.type == t).toList();
            if (list.isEmpty) return const [];
            final out = <Widget>[];
            if (type == null) {
              out.add(
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    t == TxType.expense ? 'Chi' : 'Thu',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
                  ),
                ),
              );
            }
            out.add(
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final r in list)
                    catChip(
                      r,
                      partial: !cats.contains(r.id) && (children[r.id] ?? const []).any((k) => cats.contains(k.id)),
                      onTap: () {
                        final kids = children[r.id] ?? const <Category>[];
                        if (cats.contains(r.id) || kids.any((k) => cats.contains(k.id))) {
                          cats.remove(r.id);
                          cats.removeAll(kids.map((k) => k.id));
                        } else {
                          cats.add(r.id);
                        }
                      },
                    ),
                ],
              ),
            );
            // Danh mục con của các mục cha đang chọn.
            for (final r in list) {
              final kids = children[r.id] ?? const <Category>[];
              final open = kids.isNotEmpty && (cats.contains(r.id) || kids.any((k) => cats.contains(k.id)));
              out.add(
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topLeft,
                  child: !open
                      ? const SizedBox(width: double.infinity)
                      : Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 10),
                          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                          decoration: BoxDecoration(color: hexColor(r.color).withValues(alpha: 0.06), borderRadius: BorderRadius.circular(14)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cats.contains(r.id) ? '${r.name}: tất cả — chọn mục con để thu hẹp' : r.name,
                                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  for (final k in kids)
                                    catChip(
                                      k,
                                      onTap: () {
                                        // Chọn con đầu tiên: bỏ "cả nhánh", chỉ giữ các con được chọn.
                                        cats.remove(r.id);
                                        if (!cats.remove(k.id)) cats.add(k.id);
                                      },
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                ),
              );
            }
            return out;
          }

          final showCats = type != TxType.transfer;
          final catTypes = type == null ? [TxType.expense, TxType.income] : [type!];

          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.85),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Bộ lọc', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        ),
                        TextButton(
                          onPressed: _activeFilters == 0
                              ? null
                              : () => apply(() {
                                  type = null;
                                  source = MoneySource.all;
                                  cats.clear();
                                }),
                          child: const Text('Đặt lại'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            group('Loại giao dịch', [
                              for (final (label, icon, v) in [
                                ('Tất cả', Icons.all_inclusive_rounded, null),
                                ('Khoản chi', Icons.arrow_upward_rounded, TxType.expense),
                                ('Khoản thu', Icons.arrow_downward_rounded, TxType.income),
                                ('Chuyển khoản', Icons.swap_horiz_rounded, TxType.transfer),
                              ])
                                ChoiceChip(
                                  avatar: Icon(icon, size: 16),
                                  label: Text(label),
                                  selected: type == v,
                                  onSelected: (_) => apply(() {
                                    type = v;
                                    // Bỏ các danh mục không thuộc loại vừa chọn.
                                    if (v != null) cats.removeWhere((id) => f.category(id)?.type != v);
                                  }),
                                ),
                            ]),
                            group('Nguồn tiền', [
                              for (final (label, icon, v) in [
                                ('Tất cả', Icons.all_inclusive_rounded, MoneySource.all),
                                ('Tiền mặt', Icons.payments_rounded, MoneySource.cash),
                                ('Tài khoản (NH, ví, thẻ)', Icons.account_balance_rounded, MoneySource.account),
                              ])
                                ChoiceChip(avatar: Icon(icon, size: 16), label: Text(label), selected: source == v, onSelected: (_) => apply(() => source = v)),
                            ]),
                            if (showCats && roots.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Expanded(
                                          child: Text('Danh mục', style: TextStyle(fontWeight: FontWeight.w700)),
                                        ),
                                        if (cats.isNotEmpty)
                                          TextButton(
                                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                            onPressed: () => apply(cats.clear),
                                            child: Text('Bỏ chọn (${cats.length})'),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    for (final t in catTypes) ...[...catSection(t), if (t != catTypes.last) const SizedBox(height: 12)],
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Xong')),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Đổi tháng; ngày đang chọn ở dạng lịch nhảy về hôm nay (nếu thuộc tháng) hoặc ngày đầu kỳ.
  void _goMonth(int delta) {
    final f = ref.read(financeProvider);
    setState(() {
      month = DateTime(month.year, month.month + delta, 15);
      final (from, to) = f.monthRange(month);
      final today = dateOnly(DateTime.now());
      selectedDay = !today.isBefore(from) && today.isBefore(to) ? today : from;
    });
  }

  Widget _listView(List<Txn> list) {
    if (list.isEmpty) return const EmptyState(key: ValueKey('empty'), icon: Icons.receipt_long_rounded, title: 'Không có giao dịch nào');
    final f = ref.read(financeProvider);
    final byDay = <DateTime, List<Txn>>{};
    for (final t in list) {
      byDay.putIfAbsent(dateOnly(t.occurredAt), () => []).add(t);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    return ListView.builder(
      key: const ValueKey('list'),
      cacheExtent: 600,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      itemCount: days.length,
      itemBuilder: (c, i) {
        final day = days[i];
        final items = byDay[day]!;
        final t = f.totals(items);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: RepaintBoundary(
            child: AppCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(Fmt.dayHeader(day), style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        if (t.income > 0)
                          Text(
                            '+${Fmt.compact(t.income)}  ',
                            style: const TextStyle(color: AppColors.income, fontWeight: FontWeight.w600),
                          ),
                        if (t.expense > 0)
                          Text(
                            '-${Fmt.compact(t.expense)}',
                            style: const TextStyle(color: AppColors.expense, fontWeight: FontWeight.w600),
                          ),
                      ],
                    ),
                  ),
                  for (final tx in items) _dismissible(tx),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _dismissible(Txn t) {
    final hit = _rowCache[t.id];
    if (hit != null && identical(hit.$1, t.m)) return hit.$2;
    if (_rowCache.length > 3000) _rowCache.clear();
    final w = _buildRow(t);
    _rowCache[t.id] = (t.m, w);
    return w;
  }

  Widget _buildRow(Txn t) => Dismissible(
    key: ValueKey(t.id),
    direction: DismissDirection.endToStart,
    background: Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      color: AppColors.expense.withValues(alpha: 0.15),
      child: const Icon(Icons.delete_rounded, color: AppColors.expense),
    ),
    onDismissed: (_) {
      HapticFeedback.mediumImpact();
      final store = ref.read(storeProvider);
      final backup = Map<String, dynamic>.from(t.m);
      store.remove(E.transactions, t.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: const Text('Đã xoá giao dịch'),
          action: SnackBarAction(label: 'Hoàn tác', onPressed: () => store.put(E.transactions, {...backup, 'deletedAt': null})),
        ),
      );
    },
    child: TxTile(txn: t),
  );

  /// Mở bảng giao dịch của [day] (giữ bộ lọc loại / nguồn tiền / tìm kiếm đang áp dụng).
  void _openDay(DateTime day) {
    final f = ref.read(financeProvider);
    final src = source, ty = type, q = query.toLowerCase(), cs = {...cats};
    bool keep(Txn t) =>
        (src == MoneySource.all || (f.account(t.accountId)?.matches(src) ?? false)) &&
        (cs.isEmpty || _inCats(f, cs, t)) &&
        (ty == null || t.type == ty) &&
        (q.isEmpty ||
            (t.note ?? '').toLowerCase().contains(q) ||
            (t.location ?? '').toLowerCase().contains(q) ||
            (f.category(t.categoryId)?.name ?? '').toLowerCase().contains(q));
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      sheetAnimationStyle: kSheetAnim,
      builder: (c) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 1,
        snap: true,
        snapSizes: const [0.75],
        builder: (c, scroll) => _DaySheet(day: day, filter: keep, scroll: scroll),
      ),
    );
  }

  Widget _calendarView(List<Txn> list, DateTime from) {
    final f = ref.read(financeProvider);
    final byDay = <DateTime, List<Txn>>{};
    for (final t in list) {
      byDay.putIfAbsent(dateOnly(t.occurredAt), () => []).add(t);
    }
    // Ảnh đầu tiên (theo thứ tự) của mỗi giao dịch, nếu có.
    final ids = {for (final t in list) t.id};
    final photoOf = <String, ({String file, int order})>{};
    for (final a in ref.read(storeProvider).all(E.attachments).map(Attachment.new)) {
      if (!ids.contains(a.ownerId)) continue;
      final cur = photoOf[a.ownerId];
      if (cur == null || a.sortOrder < cur.order) photoOf[a.ownerId] = (file: a.fileId, order: a.sortOrder);
    }
    final today = dateOnly(DateTime.now());

    final store = ref.read(storeProvider);
    final look = CalendarLook.of(store);
    final env = store.versionKey(const [E.appSettings, E.categories, E.currencies]);
    if (env != _cellEnv) {
      _cellCache.clear();
      _cellEnv = env;
    }
    Widget cell(DateTime d, {bool outside = false}) {
      final day = dateOnly(d);
      final items = outside ? const <Txn>[] : (byDay[day] ?? const <Txn>[]);
      final sig = StringBuffer('${day == selectedDay}|${day == today}|$outside');
      for (final t in items) {
        sig.write('|${t.id}:${t.amount}:${t.type}:${t.categoryId}:${t.currencyCode}:${photoOf[t.id]?.file}');
      }
      final key = sig.toString();
      final hit = _cellCache[day];
      if (hit != null && hit.$1 == key) return hit.$2;
      final w = _buildCell(day, items, outside, today, look, f, photoOf);
      _cellCache[day] = (key, w);
      return w;
    }

    return _calendarBody(cell, from, list);
  }

  Widget _buildCell(
    DateTime day,
    List<Txn> items,
    bool outside,
    DateTime today,
    CalendarLook look,
    Finance f,
    Map<String, ({String file, int order})> photoOf,
  ) {
    {
      return _DayCell(
        day: day,
        items: items,
        selected: day == selectedDay,
        isToday: day == today,
        outside: outside,
        look: look,
        totals: items.isEmpty ? null : f.totals(items),
        avatar: (t) {
          final photo = photoOf[t.id];
          if (photo != null) return FileImage2(photo.file, radius: 0);
          if (t.type == TxType.transfer) return const _IconDot(icon: null, color: AppColors.transfer, fallback: Icons.swap_horiz_rounded);
          final c = f.category(t.categoryId);
          return _IconDot(icon: c?.icon, color: hexColor(c?.color, t.type == TxType.income ? AppColors.income : AppColors.expense));
        },
      );
    }
  }

  Widget _calendarBody(Widget Function(DateTime, {bool outside}) cell, DateTime from, List<Txn> list) {
    final look = CalendarLook.of(ref.read(storeProvider));
    final scheme = Theme.of(context).colorScheme;
    final canAdd = ref.watch(sessionProvider).can(Perm.giaoDich);
    final recent = [...list]..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

    void openNew(int txType) {
      HapticFeedback.selectionClick();
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TransactionEditPage(type: txType, preset: {'date': atDay(selectedDay)})),
      );
    }

    return ListView(
      key: const ValueKey('cal'),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
      children: [
        AppCard(
          padding: const EdgeInsets.all(6),
          // Tháng 5 ↔ 6 tuần: co giãn chiều cao mượt thay vì nhảy.
          child: AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: LayoutBuilder(
              builder: (context, box) => TableCalendar<Txn>(
                locale: 'vi',
                // Chỉ nhận vuốt ngang (đổi tháng); vuốt dọc nhường cho cuộn màn hình — bắt đầu vuốt trên lịch vẫn cuộn được.
                availableGestures: AvailableGestures.horizontalSwipe,
                firstDay: DateTime(2000),
                lastDay: DateTime(2100),
                focusedDay: selectedDay.isBefore(from) ? from : selectedDay,
                startingDayOfWeek: StartingDayOfWeek.values[TimeConfig.of(ref.read(storeProvider)).firstDayOfWeek - 1],
                headerVisible: false,
                rowHeight: box.maxWidth / 7, // ô vuông
                daysOfWeekHeight: 30,
                selectedDayPredicate: (d) => isSameDay(d, selectedDay),
                onDaySelected: (d, _) {
                  setState(() => selectedDay = dateOnly(d));
                  _openDay(dateOnly(d));
                },
                onPageChanged: (d) {
                  final delta = (d.year - month.year) * 12 + d.month - month.month;
                  if (delta != 0) _goMonth(delta); // bấm ‹ › đã đổi tháng rồi → tránh dựng lại lần 2
                },
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (c, d, _) => cell(d),
                  todayBuilder: (c, d, _) => cell(d),
                  selectedBuilder: (c, d, _) => cell(d),
                  outsideBuilder: (c, d, _) => cell(d, outside: true),
                  dowBuilder: (c, d) => calendarDow(c, d, look),
                ),
              ),
            ),
          ),
        ),
        if (canAdd) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuickTxBtn(
                  label: 'Khoản chi',
                  icon: Icons.north_east_rounded,
                  color: AppColors.expense,
                  onTap: () => openNew(TxType.expense),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickTxBtn(
                  label: 'Khoản thu',
                  icon: Icons.south_west_rounded,
                  color: AppColors.income,
                  onTap: () => openNew(TxType.income),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickTxBtn(
                  label: 'Chuyển tiền',
                  icon: Icons.swap_horiz_rounded,
                  color: AppColors.transfer,
                  onTap: () => openNew(TxType.transfer),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        if (recent.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Text('Giao dịch gần đây', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
                const Spacer(),
                TextButton(
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  onPressed: () => setState(() => calendar = false),
                  child: Text('Xem tất cả (${recent.length})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          GroupedTxDays(items: recent.take(8).toList()),
        ] else
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.touch_app_rounded, color: scheme.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tháng ${Fmt.month(from)} chưa có giao dịch', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(
                        'Chạm vào một ngày trên lịch hoặc dùng nút ghi nhanh ở trên để thêm.',
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _QuickTxBtn extends StatelessWidget {
  const _QuickTxBtn({required this.label, required this.icon, required this.color, required this.onTap});
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: 0.96,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Một ô ngày trong lịch giao dịch: số ngày, chồng ảnh (tối đa 3 + "+N"), tổng tiền.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.items,
    required this.selected,
    required this.isToday,
    required this.outside,
    required this.look,
    required this.totals,
    required this.avatar,
  });
  final DateTime day;
  final List<Txn> items;
  final bool selected, isToday, outside;
  final CalendarLook look;
  final ({double income, double expense})? totals;
  final Widget Function(Txn) avatar;

  static const _size = 18.0, _step = 10.0, _max = 3;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shown = items.take(_max).toList();
    final more = items.length - shown.length;
    final slots = shown.length + (more > 0 ? 1 : 0);
    final t = totals;
    final numColor = outside
        ? scheme.onSurfaceVariant.withValues(alpha: 0.4)
        : selected || isToday
        ? scheme.primary
        : look.weekdayColor(day.weekday, scheme) ?? scheme.onSurface;

    final stack = slots == 0
        ? const SizedBox(height: _size)
        : SizedBox(
            width: _size + _step * (slots - 1),
            height: _size,
            child: Stack(
              children: [
                for (final (i, tx) in shown.indexed)
                  Positioned(
                    left: i * _step,
                    child: _ring(
                      context,
                      ClipOval(
                        child: SizedBox.square(dimension: _size, child: avatar(tx)),
                      ),
                    ),
                  ),
                if (more > 0)
                  Positioned(
                    left: shown.length * _step,
                    child: _ring(
                      context,
                      Container(
                        width: _size,
                        height: _size,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: scheme.secondaryContainer, shape: BoxShape.circle),
                        child: FittedBox(
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Text(
                              '+$more',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: scheme.onSecondaryContainer),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );

    // Ô vuông lấp đầy cả cột của lịch.
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        color: outside
            ? Colors.transparent
            : selected
            ? scheme.primary.withValues(alpha: 0.18)
            : scheme.surfaceContainerHighest.withValues(alpha: items.isNotEmpty ? 0.55 : 0.22),
        borderRadius: BorderRadius.circular(6),
        // Màu & độ dày viền do người dùng cấu hình (Cài đặt → Thời gian & nhắc nhở → Giao diện lịch)
        border: Border.all(
          color: selected
              ? look.selectedBorderColor(scheme)
              : isToday
              ? look.todayBorderColor(scheme)
              : outside
              ? Colors.transparent
              : (look.cellBorderColor(scheme) ?? Colors.transparent),
          width: selected || isToday ? look.borderWidth + 0.6 : look.borderWidth,
        ),
      ),
      child: SizedBox.expand(
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${day.day}',
                  style: TextStyle(fontSize: 12, fontWeight: isToday || selected ? FontWeight.w800 : FontWeight.w600, color: numColor),
                ),
                const SizedBox(height: 2),
                stack,
                const SizedBox(height: 2),
                CountText(
                  values: [t?.expense ?? 0, t?.income ?? 0],
                  text: (cv) => t == null ? ' ' : (t.expense > 0 ? Fmt.compact(cv[0]) : (t.income > 0 ? '+${Fmt.compact(cv[1])}' : ' ')),
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: t != null && t.expense > 0 ? AppColors.expense : AppColors.income),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Viền cùng màu nền để các ảnh chồng lên nhau tách bạch.
  Widget _ring(BuildContext context, Widget child) => Container(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: Theme.of(context).colorScheme.surfaceContainer, width: 1.2),
    ),
    child: child,
  );
}

/// Icon danh mục tròn nhỏ dùng khi giao dịch không có ảnh.
class _IconDot extends StatelessWidget {
  const _IconDot({required this.icon, required this.color, this.fallback});
  final String? icon;
  final Color color;
  final IconData? fallback;

  @override
  Widget build(BuildContext context) => Container(
    color: color,
    alignment: Alignment.center,
    child: Icon(icon == null && fallback != null ? fallback : iconOf(icon), size: 11, color: Colors.white),
  );
}

/// Thẻ giao dịch dạng lưới: ảnh (hoặc icon danh mục), số tiền, tên; bấm để mở/sửa.
class _TxGridCard extends ConsumerWidget {
  const _TxGridCard({required this.txn, this.photo, this.cols = 2});
  final Txn txn;
  final String? photo;

  /// Số ô mỗi hàng: 3–4 ô thì thu gọn chữ / khoảng cách.
  final int cols;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(financeProvider.select((f) => (f.categories, f.accounts, f.currencies, f.settings)));
    final f = ref.read(financeProvider);
    final scheme = Theme.of(context).colorScheme;
    final isTransfer = txn.type == TxType.transfer;
    final cat = f.category(txn.categoryId);
    final color = isTransfer ? AppColors.transfer : hexColor(cat?.color, txColor(txn.type));
    final title = isTransfer ? 'Chuyển khoản' : (cat?.name ?? txn.categoryName ?? 'Không có danh mục');
    final sign = switch (txn.type) {
      TxType.expense => '-',
      TxType.income => '+',
      _ => '',
    };
    final dense = cols >= 3, tiny = cols >= 4;
    return OpenCard(
      radius: dense ? 12 : 16,
      padding: EdgeInsets.zero,
      page: TransactionEditPage(id: txn.id, type: txn.type),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (photo != null)
                  FileImage2(photo!, radius: 0)
                else
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0.12)],
                      ),
                    ),
                    child: Icon(isTransfer ? Icons.swap_horiz_rounded : iconOf(cat?.icon), size: tiny ? 26 : (dense ? 32 : 44), color: color),
                  ),
                Positioned(
                  left: dense ? 4 : 8,
                  top: dense ? 4 : 8,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: dense ? 4 : 7, vertical: dense ? 1.5 : 3),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(dense ? 6 : 8)),
                    child: Text(
                      Fmt.time(txn.occurredAt),
                      style: TextStyle(color: Colors.white, fontSize: tiny ? 8.5 : (dense ? 9.5 : 11), fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: dense ? const EdgeInsets.fromLTRB(6, 5, 6, 6) : const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '$sign${f.money(txn.amount, txn.currencyCode)}',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: tiny ? 11.5 : (dense ? 13 : 15), color: txColor(txn.type)),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: tiny ? 9.5 : (dense ? 11 : 13)),
                ),
                if (!tiny && txn.note?.isNotEmpty == true)
                  Text(
                    txn.note!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: dense ? 10 : 11, color: scheme.onSurfaceVariant),
                  )
                else if (!dense)
                  Text(
                    txn.location?.isNotEmpty == true ? '📍 ${txn.location!}' : (f.account(txn.accountId)?.name ?? ''),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}



/// Kiểu xem trong bảng giao dịch của ngày (lưu trên máy).
const _dayViewKey = 'txDayView';

/// Bảng giao dịch của một ngày: ảnh + số tiền, xem dạng danh sách hoặc lưới 3 / 4 ô mỗi hàng.
class _DaySheet extends ConsumerStatefulWidget {
  const _DaySheet({required this.day, required this.filter, required this.scroll});
  final DateTime day;
  final bool Function(Txn) filter;
  final ScrollController scroll;

  @override
  ConsumerState<_DaySheet> createState() => _DaySheetState();
}

class _DaySheetState extends ConsumerState<_DaySheet> {
  late int view = int.tryParse(ref.read(storeProvider).meta(_dayViewKey) ?? '') ?? 3; // 1 = danh sách, 3 / 4 = số ô mỗi hàng

  void _setView(int v) {
    setState(() => view = v);
    ref.read(storeProvider).setMeta(_dayViewKey, '$v');
  }

  @override
  Widget build(BuildContext context) {
    final f = ref.watch(financeProvider);
    final store = ref.watchTables(const [E.attachments]);
    final scheme = Theme.of(context).colorScheme;
    final d = widget.day;
    final items = f.inRange(d, DateTime(d.year, d.month, d.day + 1)).where(widget.filter).toList()..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    final ids = {for (final t in items) t.id};
    final photoOf = <String, ({String file, int order})>{};
    for (final a in store.all(E.attachments).map(Attachment.new)) {
      if (!ids.contains(a.ownerId)) continue;
      final cur = photoOf[a.ownerId];
      if (cur == null || a.sortOrder < cur.order) photoOf[a.ownerId] = (file: a.fileId, order: a.sortOrder);
    }
    final t = f.totals(items);

    final Widget body;
    if (items.isEmpty) {
      body = Padding(
        key: const ValueKey('empty'),
        padding: const EdgeInsets.only(top: 24),
        child: Column(
          children: [
            Icon(Icons.receipt_long_rounded, size: 48, color: scheme.onSurfaceVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 8),
            Text('Chưa có giao dịch trong ngày', style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            SizedBox(width: 180, height: 150, child: _AddDayCard(day: d)),
          ],
        ),
      );
    } else if (view == 1) {
      body = Column(
        key: const ValueKey('list'),
        children: [
          for (final x in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RepaintBoundary(child: _DayRow(txn: x, photo: photoOf[x.id]?.file)),
            ),
          SizedBox(height: 64, child: _AddDayCard(day: d, row: true)),
        ],
      );
    } else {
      body = GridView.count(
        key: ValueKey('grid$view'),
        crossAxisCount: view,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: view == 4 ? 0.66 : 0.72,
        children: [
          for (final x in items) RepaintBoundary(child: _TxGridCard(txn: x, photo: photoOf[x.id]?.file, cols: view)),
          _AddDayCard(day: d, compact: true),
        ],
      );
    }

    return ListView(
      controller: widget.scroll,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Fmt.dayHeader(d),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    // Tiêu đề đã có thứ/ngày thì phụ đề chỉ ghi số giao dịch; "Hôm nay/Hôm qua/Ngày mai" thì kèm ngày cụ thể.
                    [
                      if ((dateOnly(DateTime.now()).difference(d).inDays).abs() <= 1) '${Fmt.weekdays[d.weekday - 1]}, ${Fmt.date(d)}',
                      '${items.length} giao dịch',
                    ].join(' · '),
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            PillToggle<int>(
              value: view,
              values: const [1, 3, 4],
              icons: const [Icons.view_agenda_rounded, Icons.view_module_rounded, Icons.view_comfy_rounded],
              tips: const ['Danh sách', '3 ô', '4 ô'],
              onChanged: _setView,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _DayTotal(label: 'Chi', value: '-${f.money(t.expense)}', color: AppColors.expense),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _DayTotal(label: 'Thu', value: '+${f.money(t.income)}', color: AppColors.income),
            ),
          ],
        ),
        const SizedBox(height: 12),
        body,
      ],
    );
  }
}

class _DayTotal extends StatelessWidget {
  const _DayTotal({required this.label, required this.value, required this.color});
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
    child: Row(
      children: [
        Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Một dòng trong bảng ngày (kiểu danh sách): ảnh to bên trái, số tiền nổi bật.
class _DayRow extends ConsumerWidget {
  const _DayRow({required this.txn, this.photo});
  final Txn txn;
  final String? photo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.read(financeProvider);
    final isTransfer = txn.type == TxType.transfer;
    final cat = f.category(txn.categoryId);
    final color = isTransfer ? AppColors.transfer : hexColor(cat?.color, txColor(txn.type));
    final sign = switch (txn.type) {
      TxType.expense => '-',
      TxType.income => '+',
      _ => '',
    };
    final acc = f.account(txn.accountId);
    final accLabel = isTransfer ? '${acc?.name ?? '?'} → ${f.account(txn.toAccountId)?.name ?? '?'}' : (acc?.name ?? '');
    final extraMeta = [
      Fmt.time(txn.occurredAt),
      if (txn.location?.isNotEmpty == true) '📍 ${txn.location!}',
    ].join(' · ');
    return AppCard(
      padding: const EdgeInsets.all(10),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TransactionEditPage(id: txn.id, type: txn.type))),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox.square(
              dimension: 60,
              child: photo != null
                  ? FileImage2(photo!, radius: 0)
                  : Container(
                      color: color.withValues(alpha: 0.16),
                      child: Icon(isTransfer ? Icons.swap_horiz_rounded : iconOf(cat?.icon), color: color, size: 28),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _TxMetaColumn(
              title: isTransfer ? 'Chuyển khoản' : (cat?.name ?? 'Không có danh mục'),
              catColor: color,
              note: txn.note,
              accLabel: accLabel,
              extraMeta: extraMeta,
              isRecurring: txn.recurringRuleId != null,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$sign${f.money(txn.amount, txn.currencyCode)}',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: txColor(txn.type)),
          ),
        ],
      ),
    );
  }
}

/// Ô "Thêm giao dịch" vào đúng ngày đang xem.
class _AddDayCard extends StatelessWidget {
  const _AddDayCard({required this.day, this.compact = false, this.row = false});
  final DateTime day;
  final bool compact, row;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (compact || row) {
      return OpenCard(
        radius: 12,
        padding: EdgeInsets.zero,
        color: scheme.primary.withValues(alpha: 0.08),
        page: TransactionEditPage(type: TxType.expense, preset: {'date': day}),
        child: Center(
          child: Flex(
            direction: row ? Axis.horizontal : Axis.vertical,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_circle_rounded, color: scheme.primary, size: row ? 24 : 30),
              const SizedBox(width: 8, height: 4),
              Text(
                'Thêm',
                style: TextStyle(fontWeight: FontWeight.w700, color: scheme.primary),
              ),
            ],
          ),
        ),
      );
    }
    return OpenCard(
      radius: 16,
      padding: EdgeInsets.zero,
      color: scheme.primary.withValues(alpha: 0.08),
      page: TransactionEditPage(type: TxType.expense, preset: {'date': day}),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.18), shape: BoxShape.circle),
              child: Icon(Icons.add_rounded, color: scheme.primary, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              'Thêm giao dịch',
              style: TextStyle(fontWeight: FontWeight.w700, color: scheme.primary),
            ),
            Text('ngày ${Fmt.dateShort(day)}', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total(this.label, this.icon, this.value, this.color, this.fmt, {required this.selected, required this.onTap});
  final String label;
  final IconData icon;
  final double value;
  final Color color;
  final String Function(num, [String?, bool]) fmt;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Pressable(
      scale: 0.96,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: selected ? 0.18 : 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? color.withValues(alpha: 0.8) : Colors.transparent, width: 1.4),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: selected ? 1 : 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 12, color: selected ? Colors.white : color),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: selected ? color : Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 22,
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: AnimatedAmount(
                  value: value,
                  format: (v) => fmt(v),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Thêm / sửa giao dịch (chi, thu, chuyển khoản) + ảnh đính kèm.
class TransactionEditPage extends ConsumerStatefulWidget {
  const TransactionEditPage({super.key, this.id, this.type = 1, this.preset = const {}});
  final String? id;
  final int type;
  final Map<String, dynamic> preset;

  @override
  ConsumerState<TransactionEditPage> createState() => _TransactionEditPageState();
}

class _TransactionEditPageState extends ConsumerState<TransactionEditPage> {
  // Giải phóng tài nguyên khi đóng màn (tránh tích tụ khi mở/đóng nhiều lần)
  @override
  void dispose() {
    _amountFocus.removeListener(_syncKeyboardCalc);
    _amountFocus.dispose();
    if (keyboardCalcNotifier.value != null) keyboardCalcNotifier.value = null;
    amount.dispose();
    toAmount.dispose();
    note.dispose();
    location.dispose();
    super.dispose();
  }

  late int type = widget.type;
  final amount = TextEditingController();
  final _amountFocus = FocusNode();
  final toAmount = TextEditingController();
  final note = TextEditingController();
  final location = TextEditingController();
  double? latitude;
  double? longitude;
  Category? category;
  Account? account;
  Account? toAccount;
  DateTime at = DateTime.now();
  String? eventId;
  String repeatFreq = 'NONE';
  List<String> photos = [];
  List<String> removedAttachments = [];
  List<double> ocrCandidates = [];
  final Map<String, double> photoOcrAmounts = {};
  bool ocrBusy = false;
  double? _calcLeft;
  String? _calcOp;
  String? _expandedParentId;

  @override
  void initState() {
    super.initState();
    _amountFocus.addListener(_syncKeyboardCalc);
    final store = ref.read(storeProvider);
    final f = ref.read(financeProvider);
    final rec = store.get(E.transactions, widget.id);
    if (rec != null) {
      final t = Txn(rec);
      type = t.type;
      amount.text = Fmt.money(t.amount, symbol: '', decimals: f.currency(t.currencyCode)?.decimals ?? 0).trim();
      if (t.toAmount != null) toAmount.text = amountText(t.toAmount!.round());
      note.text = t.note ?? '';
      location.text = t.location ?? '';
      latitude = t.latitude;
      longitude = t.longitude;
      category = f.category(t.categoryId);
      _expandedParentId = category?.parentId ?? (f.categories.any((x) => x.parentId == category?.id) ? category?.id : null);
      account = f.account(t.accountId);
      toAccount = f.account(t.toAccountId);
      at = t.occurredAt;
      eventId = t.eventId;
      photos = store.all(E.attachments).map(Attachment.new).where((a) => a.ownerId == t.id).map((a) => a.fileId).toList();
    } else {
      account = f.defaultAccount();
      eventId = widget.preset['eventId'] as String?;
      if (widget.preset['date'] is DateTime) at = atDay(widget.preset['date'] as DateTime);
      if (widget.preset['amount'] != null) amount.text = amountText(widget.preset['amount'] as num);
      if (widget.preset['note'] != null) note.text = widget.preset['note'] as String;
      if (widget.preset['location'] != null) location.text = widget.preset['location'] as String;
      if (widget.preset['latitude'] is num) latitude = (widget.preset['latitude'] as num).toDouble();
      if (widget.preset['longitude'] is num) longitude = (widget.preset['longitude'] as num).toDouble();
      if (widget.preset['categoryName'] != null) {
        category = f.categories.where((c) => c.name == widget.preset['categoryName']).firstOrNull;
      }
    }
  }

  void _save() {
    if (_calcOp != null && _calcLeft != null) {
      _evalCalc();
    }
    final f = ref.read(financeProvider);
    final store = ref.read(storeProvider);
    final value = parseAmount(amount.text);
    if (value <= 0) return showToast(context, 'Nhập số tiền', error: true);
    if (account == null) return showToast(context, 'Chọn tài khoản', error: true);
    if (type != TxType.transfer && category == null) return showToast(context, 'Chọn danh mục', error: true);
    if (type == TxType.transfer && (toAccount == null || toAccount!.id == account!.id)) {
      return showToast(context, 'Chọn tài khoản nhận khác tài khoản nguồn', error: true);
    }
    final crossCurrency = type == TxType.transfer && toAccount!.currencyCode != account!.currencyCode;
    final saved = store.put(E.transactions, {
      if (widget.id != null) 'id': widget.id,
      'type': type,
      'amount': value,
      'currencyCode': account!.currencyCode,
      'accountId': account!.id,
      'accountName': account!.name,
      'toAccountId': type == TxType.transfer ? toAccount!.id : null,
      'toAccountName': type == TxType.transfer ? toAccount?.name : null,
      'toAmount': crossCurrency
          ? (parseAmount(toAmount.text) > 0 ? parseAmount(toAmount.text) : f.convert(value, account!.currencyCode, toAccount!.currencyCode))
          : null,
      'categoryId': type == TxType.transfer ? null : category!.id,
      'categoryName': type == TxType.transfer ? null : category?.name,
      'occurredAt': toIso8601WithOffset(at),
      'note': note.text.trim().isEmpty ? null : note.text.trim(),
      'location': location.text.trim().isEmpty ? null : location.text.trim(),
      'latitude': location.text.trim().isEmpty ? null : latitude,
      'longitude': location.text.trim().isEmpty ? null : longitude,
      'eventId': eventId,
    });

    // Ảnh đính kèm
    final existing = store.all(E.attachments).map(Attachment.new).where((a) => a.ownerId == saved['id']).toList();
    for (final a in existing.where((a) => !photos.contains(a.fileId))) {
      store.remove(E.attachments, a.id);
    }
    for (final (i, fid) in photos.indexed) {
      if (existing.any((a) => a.fileId == fid)) continue;
      store.put(E.attachments, {'ownerType': 1, 'ownerId': saved['id'], 'fileId': fid, 'sortOrder': i});
    }

    store.setMeta('lastAccountId', account!.id); // nhớ nguồn tiền vừa dùng
    if (widget.id == null && repeatFreq != 'NONE') {
      final rrule = Recurrence.build(repeatFreq) ?? 'FREQ=MONTHLY';
      final nextAt = Recurrence.nextOccurrence(rrule, at);
      final tpl = jsonEncode({
        'type': type,
        'amount': value,
        'currencyCode': account!.currencyCode,
        'accountId': account!.id,
        if (type == TxType.transfer && toAccount != null) 'toAccountId': toAccount!.id,
        if (type != TxType.transfer && category != null) 'categoryId': category!.id,
        if (note.text.trim().isNotEmpty) 'note': note.text.trim(),
        if (location.text.trim().isNotEmpty) 'location': location.text.trim(),
        if (location.text.trim().isNotEmpty && latitude != null) 'latitude': latitude,
        if (location.text.trim().isNotEmpty && longitude != null) 'longitude': longitude,
      });
      store.put(E.recurringRules, {
        'name': note.text.trim().isNotEmpty ? note.text.trim() : (category?.name ?? 'Giao dịch định kỳ'),
        'templateJson': tpl,
        'rRule': rrule,
        'nextRunAt': toIso8601WithOffset(nextAt),
        'isActive': true,
      });
    }
    HapticFeedback.lightImpact();
    for (final w in ref.read(financeProvider).budgetWarnings(Txn(saved))) {
      ref.read(notifierProvider).show('Cảnh báo định mức', w, inApp: false, kind: NotifyKind.finance);
      showToast(context, w, error: w.startsWith('Đã vượt'));
    }
    Navigator.of(context).maybePop();
  }

  /// Danh mục cha hay dùng nhất của loại hiện tại (đếm theo cả giao dịch của các danh mục con), tối đa [n].
  List<Category> _frequent(Finance f, int n) {
    final all = f.categories.where((c) => c.type == type).toList();
    final byId = {for (final c in all) c.id: c};
    final count = <String, int>{};
    for (final t in f.transactions) {
      if (t.type != type || t.categoryId == null) continue;
      final c = byId[t.categoryId!];
      final rootId = c?.parentId ?? t.categoryId!;
      count[rootId] = (count[rootId] ?? 0) + 1;
    }
    final roots = all.where((c) => c.parentId == null).toList();
    roots.sort((a, b) => (count[b.id] ?? 0).compareTo(count[a.id] ?? 0));
    final list = roots.take(n).toList();
    final activeRoot = category?.parentId != null ? byId[category!.parentId!] : category;
    if (activeRoot != null && list.isNotEmpty && !list.any((c) => c.id == activeRoot.id)) {
      list[list.length - 1] = activeRoot;
    }
    return list;
  }

  void _addAmount(double v) {
    HapticFeedback.selectionClick();
    final cur = parseAmount(amount.text);
    setState(() => amount.text = amountText(cur + v));
  }

  void _syncKeyboardCalc() {
    if (_amountFocus.hasFocus) {
      keyboardCalcNotifier.value = KeyboardCalcBar(
        onOp: _pressOp,
        onEval: _evalCalc,
        activeOp: _calcOp,
        canEval: _calcOp != null,
      );
    } else if (keyboardCalcNotifier.value != null) {
      keyboardCalcNotifier.value = null;
    }
  }

  double _computeCalc(double left, String op, double right) => switch (op) {
    '+' => left + right,
    '-' => (left - right) < 0 ? 0 : (left - right),
    '×' => left * right,
    '÷' => right == 0 ? left : (left / right),
    _ => right,
  };

  void _pressOp(String op) {
    HapticFeedback.selectionClick();
    final cur = parseAmount(amount.text);
    setState(() {
      if (_calcOp != null && _calcLeft != null && amount.text.trim().isNotEmpty) {
        if (_calcOp == '÷' && cur == 0) {
          showToast(context, 'Không thể chia cho 0', error: true);
          return;
        }
        _calcLeft = _computeCalc(_calcLeft!, _calcOp!, cur);
      } else if (_calcOp == null) {
        _calcLeft = cur;
      }
      _calcOp = op;
      amount.clear();
    });
    _syncKeyboardCalc();
  }

  void _evalCalc() {
    if (_calcOp == null || _calcLeft == null) return;
    HapticFeedback.lightImpact();
    final cur = parseAmount(amount.text);
    if (_calcOp == '÷' && cur == 0) {
      showToast(context, 'Không thể chia cho 0', error: true);
      return;
    }
    final res = amount.text.trim().isEmpty ? _calcLeft! : _computeCalc(_calcLeft!, _calcOp!, cur);
    setState(() {
      amount.text = amountText(res);
      _calcLeft = null;
      _calcOp = null;
    });
    _syncKeyboardCalc();
  }

  Future<void> _scanPhotos(List<String> ids, List<String> paths, {bool forceFill = false}) async {
    if (paths.isEmpty) return;
    if (!OcrService.isSupported) {
      if (forceFill && mounted) showToast(context, 'Quét số từ ảnh hỗ trợ trên Android / iOS');
      return;
    }
    setState(() => ocrBusy = true);
    try {
      final store = ref.read(storeProvider);
      final allCandidates = <double>{};

      // Nếu đang có ảnh cũ chưa quét (vd vừa mở "Sửa giao dịch" rồi thêm ảnh thứ 2) -> quét luôn để cộng dồn chính xác
      for (var i = 0; i < photos.length; i++) {
        final fid = photos[i];
        if (ids.contains(fid) || photoOcrAmounts.containsKey(fid)) continue;
        final bytes = await store.readFile(fid);
        if (bytes == null) continue;
        final prevRes = await OcrService.scanImageBytes(bytes);
        if (prevRes != null && prevRes.bestAmount != null) {
          photoOcrAmounts[fid] = prevRes.bestAmount!;
          allCandidates.addAll(prevRes.candidates);
        }
      }

      var newScannedCount = 0;
      double? lastNewBest;
      OcrResult? lastRes;
      for (var i = 0; i < paths.length; i++) {
        final res = await OcrService.scanImagePath(paths[i]);
        lastRes = res;
        if (res != null && res.bestAmount != null) {
          if (i < ids.length) {
            photoOcrAmounts[ids[i]] = res.bestAmount!;
          }
          lastNewBest = res.bestAmount!;
          newScannedCount++;
          allCandidates.addAll(res.candidates);
        }
      }

      if (!mounted) return;
      setState(() => ocrBusy = false);

      if (newScannedCount > 0) {
        final sum = photoOcrAmounts.values.fold<double>(0, (s, v) => s + v);
        final hasMultiple = photoOcrAmounts.length > 1;
        final targetValue = hasMultiple ? sum : (lastNewBest ?? sum);
        setState(() {
          ocrCandidates = {if (hasMultiple) sum, ...allCandidates}.toList();
          if (hasMultiple || forceFill || parseAmount(amount.text) <= 0) {
            amount.text = amountText(targetValue);
          }
        });
        final f = ref.read(financeProvider);
        showToast(
          context,
          hasMultiple
              ? 'Đã cộng ${photoOcrAmounts.length} ảnh: ${f.money(sum, account?.currencyCode)}'
              : 'Đã đọc số ${f.money(targetValue, account?.currencyCode)} từ ảnh',
        );
      } else if (forceFill) {
        final msg = (lastRes == null || lastRes.rawText.trim().isEmpty)
            ? 'Không nhận diện được chữ/số trong ảnh'
            : 'Không tìm thấy số tiền phù hợp trong ảnh';
        showToast(context, msg, error: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => ocrBusy = false);
        showToast(context, 'Lỗi đọc ảnh: $e', error: true);
      }
    }
  }

  void _removePhoto(String id) {
    setState(() {
      photos = photos.where((p) => p != id).toList();
      final hadOcr = photoOcrAmounts.remove(id) != null;
      if (hadOcr && photoOcrAmounts.isNotEmpty) {
        final sum = photoOcrAmounts.values.fold<double>(0, (s, v) => s + v);
        amount.text = amountText(sum);
        ocrCandidates = {sum, ...photoOcrAmounts.values}.toList();
      } else if (photoOcrAmounts.isEmpty && hadOcr) {
        ocrCandidates = [];
      }
    });
  }

  Future<void> _pickAndScanReceipt() async {
    final paths = <String>[];
    final ids = await pickPhotos(context, ref, multiple: true, outPaths: paths);
    if (!mounted || ids.isEmpty) return;
    setState(() => photos = [...photos, ...ids]);
    await _scanPhotos(ids, paths, forceFill: true);
  }

  @override
  Widget build(BuildContext context) {
    final f = ref.watch(financeProvider);
    final scheme = Theme.of(context).colorScheme;
    final color = txColor(type);
    final event = ref.watchTables(const [E.events]).get(E.events, eventId);
    final symbol = f.currency(account?.currencyCode ?? 'VND')?.symbol ?? '₫';
    final value = parseAmount(amount.text);
    final today = dateOnly(DateTime.now());
    final hue = type == TxType.expense ? -16.0 : 20.0; // đỏ ngả hồng, xanh ngả ngọc
    final typeName = switch (type) {
      TxType.income => 'khoản thu',
      TxType.transfer => 'chuyển khoản',
      _ => 'khoản chi',
    };

    Widget section(String title, Widget child, {Widget? trailing}) => Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.id == null ? 'Thêm giao dịch' : 'Sửa giao dịch'),
        actions: [
          if (widget.id != null)
            IconButton(
              tooltip: 'Xoá',
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.expense),
              onPressed: () async {
                if (await confirm(context, 'Xoá giao dịch này?', danger: true, ok: 'Xoá')) {
                  ref.read(storeProvider).remove(E.transactions, widget.id!);
                  if (context.mounted) Navigator.of(context).maybePop();
                }
              },
            ),
        ],
      ),
      // Nút lưu cố định dưới cùng, màu theo loại giao dịch (tự nổi lên trên bàn phím)
      bottomNavigationBar: KeyboardAvoidBottomBar(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Pressable(
          onTap: _save,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  heroOf(color),
                  accentOf(heroOf(color), hue: hue),
                ],
              ),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  value > 0 ? 'Lưu $typeName · ${f.money(value, account?.currencyCode)}' : 'Lưu $typeName',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _TypeSwitch(
            value: type,
            onChanged: (v) => setState(() {
              type = v;
              if (category != null && category!.type != type) {
                category = null;
                _expandedParentId = null;
              }
            }),
          ),
          const SizedBox(height: 14),
          // Thẻ số tiền
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  heroOf(color),
                  accentOf(heroOf(color), hue: hue),
                ],
              ),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Text('Số tiền $typeName', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
                          if (_calcOp != null && _calcLeft != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                              child: Text(
                                '${f.money(_calcLeft!, account?.currencyCode)} $_calcOp',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (OcrService.isSupported)
                      Pressable(
                        onTap: ocrBusy ? null : _pickAndScanReceipt,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(14)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (ocrBusy)
                                const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              else
                                const Icon(Icons.document_scanner_rounded, size: 14, color: Colors.white),
                              const SizedBox(width: 5),
                              Text(ocrBusy ? 'Đang đọc...' : 'Quét ảnh', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: amount,
                        focusNode: _amountFocus,
                        autofocus: widget.id == null,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: const [ThousandsInputFormatter()],
                        onChanged: (_) => setState(() {}),
                        cursorColor: Colors.white,
                        style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
                        decoration: InputDecoration(
                          hintText: '0',
                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 38, fontWeight: FontWeight.w900),
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                        ),
                      ),
                    ),
                    Text(
                      symbol,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 24, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 32,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final v in const [10000.0, 50000.0, 100000.0, 200000.0, 500000.0])
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Pressable(
                            onTap: () => _addAmount(v),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(16)),
                              child: Text(
                                '+${Fmt.compact(v)}',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                            ),
                          ),
                        ),
                      if (value > 0 || _calcOp != null)
                        Pressable(
                          onTap: () {
                            setState(() {
                              amount.clear();
                              _calcLeft = null;
                              _calcOp = null;
                            });
                            _syncKeyboardCalc();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)),
                            child: const Icon(Icons.backspace_rounded, color: Colors.white, size: 16),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (ocrCandidates.isNotEmpty) ...[
            Text('Số đọc được từ ảnh (chạm để chọn):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.primary)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final v in ocrCandidates)
                  ChoiceChip(
                    avatar: const Icon(Icons.document_scanner_rounded, size: 15),
                    label: Text(f.money(v, account?.currencyCode)),
                    selected: parseAmount(amount.text) == v,
                    onSelected: (_) => setState(() => amount.text = amountText(v)),
                  ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          // Danh mục: đặt ngay dưới Số tiền để không bị quên, kèm nhãn nhắc khi chưa chọn
          if (type != TxType.transfer)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Danh mục', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      const SizedBox(width: 8),
                      if (category == null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text('Chưa chọn', style: TextStyle(color: AppColors.warning, fontSize: 11, fontWeight: FontWeight.w700)),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: hexColor(category!.color, color).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            category!.name,
                            style: TextStyle(color: hexColor(category!.color, color), fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ),
                      const Spacer(),
                      TextButton(
                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                        onPressed: () async {
                          final c = await pickCategory(context, ref, type);
                          if (c != null) setState(() => category = c);
                        },
                        child: const Text('Tất cả'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Builder(
                    builder: (_) {
                      final cats = _frequent(f, 7);
                      final parentIdForSub = _expandedParentId;
                      final parentCat = parentIdForSub == null ? null : f.category(parentIdForSub);
                      final subCats = parentCat == null
                          ? const <Category>[]
                          : (f.categories.where((x) => x.parentId == parentCat.id).toList());
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          GridView.count(
                            crossAxisCount: 4,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 0.98,
                            children: [
                              for (final (i, c) in cats.indexed)
                                Builder(
                                  builder: (_) {
                                    final on = category?.id == c.id || category?.parentId == c.id;
                                    final cc = hexColor(c.color, color);
                                    final hasSub = f.categories.any((x) => x.parentId == c.id);
                                    return Pressable(
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        setState(() {
                                          // Nếu đang mở danh mục con của chính cha này và đang chọn cha -> thu gọn; nếu đang chọn con -> quay về cha
                                          if (_expandedParentId == c.id && category?.id == c.id) {
                                            _expandedParentId = null;
                                          } else {
                                            category = c;
                                            _expandedParentId = hasSub ? c.id : null;
                                          }
                                        });
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 220),
                                        decoration: BoxDecoration(
                                          color: on ? cc.withValues(alpha: 0.18) : scheme.surfaceContainerHigh,
                                          borderRadius: BorderRadius.circular(18),
                                          border: Border.all(
                                            color: on ? cc : (category == null ? AppColors.warning.withValues(alpha: 0.35) : Colors.transparent),
                                            width: on ? 1.8 : 1.0,
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            AnimatedScale(
                                              scale: on ? 1.1 : 1,
                                              duration: const Duration(milliseconds: 220),
                                              curve: Curves.easeOutBack,
                                              child: CircleIcon(icon: c.icon, color: cc, size: 36),
                                            ),
                                            const SizedBox(height: 5),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 4),
                                              child: Text(
                                                c.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(fontSize: 11.5, fontWeight: on ? FontWeight.w800 : FontWeight.w500),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ).stagger(i);
                                  },
                                ),
                              Pressable(
                                onTap: () async {
                                  final c = await pickCategory(context, ref, type);
                                  if (c != null) {
                                    setState(() {
                                      category = c;
                                      _expandedParentId = c.parentId ?? (f.categories.any((x) => x.parentId == c.id) ? c.id : null);
                                    });
                                  }
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: scheme.outlineVariant),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.apps_rounded, color: scheme.onSurfaceVariant),
                                      const SizedBox(height: 5),
                                      Text('Xem thêm', style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOutCubic,
                            child: subCats.isEmpty
                                ? const SizedBox.shrink()
                                : Container(
                                    margin: const EdgeInsets.only(top: 10),
                                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                                    decoration: BoxDecoration(
                                      color: scheme.surfaceContainerLow,
                                      borderRadius: BorderRadius.circular(16),
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
                                              decoration: BoxDecoration(color: hexColor(parentCat?.color, color), shape: BoxShape.circle),
                                            ),
                                            Expanded(
                                              child: Text(
                                                parentCat!.name,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: hexColor(parentCat.color, color),
                                                ),
                                              ),
                                            ),
                                            if (category?.parentId == parentCat.id)
                                              GestureDetector(
                                                onTap: () {
                                                  HapticFeedback.selectionClick();
                                                  setState(() => category = parentCat);
                                                },
                                                child: Padding(
                                                  padding: const EdgeInsets.only(right: 8),
                                                  child: Text(
                                                    'Bỏ chọn con',
                                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: scheme.primary),
                                                  ),
                                                ),
                                              ),
                                            GestureDetector(
                                              onTap: () => setState(() => _expandedParentId = null),
                                              child: Icon(Icons.close_rounded, size: 16, color: scheme.onSurfaceVariant),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            for (final sub in subCats)
                                              (() {
                                                final subOn = category?.id == sub.id;
                                                final sc = hexColor(sub.color, hexColor(parentCat.color, color));
                                                return Pressable(
                                                  onTap: () {
                                                    HapticFeedback.selectionClick();
                                                    setState(() => category = subOn ? parentCat : sub);
                                                  },
                                                  child: AnimatedContainer(
                                                    duration: const Duration(milliseconds: 180),
                                                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                                                    decoration: BoxDecoration(
                                                      color: subOn ? sc.withValues(alpha: 0.16) : scheme.surfaceContainerLowest,
                                                      borderRadius: BorderRadius.circular(999),
                                                      border: Border.all(
                                                        color: subOn ? sc : scheme.outlineVariant.withValues(alpha: 0.6),
                                                        width: subOn ? 1.5 : 1,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(iconOf(sub.icon), size: 15, color: sc),
                                                        const SizedBox(width: 6),
                                                        Text(
                                                          sub.name,
                                                          style: TextStyle(
                                                            fontSize: 12.5,
                                                            fontWeight: subOn ? FontWeight.w700 : FontWeight.w500,
                                                            color: subOn ? sc : scheme.onSurface,
                                                          ),
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
                      );
                    },
                  ),
                ],
              ),
            ),
          section(
            'Ảnh hoá đơn / kỷ niệm',
            PhotoGrid(
              fileIds: photos,
              onAdd: () async {
                final paths = <String>[];
                final ids = await pickPhotos(context, ref, outPaths: paths);
                if (!mounted || ids.isEmpty) return;
                setState(() => photos = [...photos, ...ids]);
                if (paths.isNotEmpty) unawaited(_scanPhotos(ids, paths));
              },
              onRemove: _removePhoto,
            ),
          ),
          section(
            'Ghi chú',
            TextField(
              controller: note,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(hintText: 'Ăn gì, mua gì, với ai…', prefixIcon: Icon(Icons.edit_note_rounded)),
            ),
          ),
          const SizedBox(height: 14),
          AccountChips(
            label: type == TxType.transfer ? 'Từ tài khoản' : (type == TxType.income ? 'Nhận vào' : 'Trả bằng'),
            selected: account?.id,
            onChanged: (a) => setState(() {
              account = a;
              if (toAccount?.id == a.id) toAccount = null;
            }),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: type == TxType.transfer
                ? Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(
                      children: [
                        AccountChips(label: 'Đến tài khoản', selected: toAccount?.id, exclude: account?.id, onChanged: (a) => setState(() => toAccount = a)),
                        if (toAccount != null && account != null && toAccount!.currencyCode != account!.currencyCode)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: TextField(
                              controller: toAmount,
                              keyboardType: TextInputType.number,
                              inputFormatters: const [ThousandsInputFormatter()],
                              decoration: InputDecoration(
                                labelText: 'Số tiền nhận (${toAccount!.currencyCode})',
                                helperText: 'Để trống sẽ tự quy đổi theo tỷ giá',
                                prefixIcon: const Icon(Icons.currency_exchange_rounded),
                              ),
                            ),
                          ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          // Thời gian: chọn nhanh + chọn cụ thể
          section(
            'Thời gian',
            Row(
              children: [
                for (final (label, d) in [('Hôm nay', today), ('Hôm qua', today.subtract(const Duration(days: 1)))])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: dateOnly(at) == d,
                      onSelected: (_) => setState(() => at = DateTime(d.year, d.month, d.day, at.hour, at.minute)),
                    ),
                  ),
                Expanded(
                  child: Pressable(
                    onTap: () async {
                      final d = await pickDateTime(context, at);
                      if (d != null) setState(() => at = d);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        children: [
                          Icon(Icons.event_rounded, size: 18, color: scheme.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${Fmt.time(at)} · ${at.year == today.year ? Fmt.dateShort(at) : Fmt.date(at)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (event != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: AppCard(
                padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                child: Row(
                  children: [
                    const Icon(Icons.event_rounded, color: Color(0xFF0090FF)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('Lịch trình: ${event['title']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    IconButton(tooltip: 'Bỏ liên kết', onPressed: () => setState(() => eventId = null), icon: const Icon(Icons.close_rounded)),
                  ],
                ),
              ),
            ),
          section(
            'Vị trí',
            trailing: GpsIconButton(
              tooltip: 'Lấy vị trí hiện tại',
              onPickedResult: (res) => setState(() {
                location.text = res.address;
                latitude = res.latitude;
                longitude = res.longitude;
              }),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: location,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Quán ăn, cửa hàng, địa chỉ…',
                    prefixIcon: const Icon(Icons.place_rounded),
                    suffixIcon: location.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Xoá vị trí',
                            onPressed: () => setState(() {
                              location.clear();
                              latitude = null;
                              longitude = null;
                            }),
                            icon: const Icon(Icons.close_rounded, size: 18),
                          ),
                  ),
                ),
                if (latitude != null && longitude != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 4),
                    child: Row(
                      children: [
                        Icon(Icons.gps_fixed_rounded, size: 13, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'GPS: ${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}',
                            style: TextStyle(fontSize: 11.5, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() {
                            latitude = null;
                            longitude = null;
                          }),
                          child: Text(
                            'Bỏ tọa độ',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (widget.id == null)
            section(
              'Lặp lại định kỳ',
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final (code, label) in const [
                      ('NONE', 'Không lặp'),
                      ('DAILY', 'Hằng ngày'),
                      ('WEEKLY', 'Hằng tuần'),
                      ('MONTHLY', 'Hằng tháng'),
                      ('YEARLY', 'Hằng năm'),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(label),
                          selected: repeatFreq == code,
                          onSelected: (_) => setState(() => repeatFreq = code),
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

/// Chọn loại giao dịch: 3 ô, nền trượt đổi màu theo loại.
class _TypeSwitch extends StatelessWidget {
  const _TypeSwitch({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  static const _items = [
    (TxType.expense, 'Chi', Icons.north_east_rounded),
    (TxType.income, 'Thu', Icons.south_west_rounded),
    (TxType.transfer, 'Chuyển', Icons.sync_alt_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final idx = _items.indexWhere((e) => e.$1 == value);
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(18)),
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth / _items.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutBack,
                left: idx * w,
                top: 0,
                bottom: 0,
                width: w,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 320),
                  decoration: BoxDecoration(
                    color: txColor(value),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: txColor(value).withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 3))],
                  ),
                ),
              ),
              Positioned.fill(
                child: Row(
                  children: [
                    for (final (t, label, icon) in _items)
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            onChanged(t);
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(icon, size: 18, color: t == value ? Colors.white : scheme.onSurfaceVariant),
                              const SizedBox(width: 6),
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: t == value ? FontWeight.w800 : FontWeight.w600,
                                  color: t == value ? Colors.white : scheme.onSurfaceVariant,
                                ),
                                child: Text(label),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
