import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../core/format.dart';
import '../core/icons.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../data/local_store.dart';
import '../data/logic.dart';
import '../data/models.dart';
import '../data/calendar_look.dart';
import '../data/time_config.dart';
import '../data/notify_prefs.dart';
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
  return day == null ? now : DateTime(day.year, day.month, day.day, now.hour, now.minute);
}

/// Một dòng giao dịch.
class TxTile extends ConsumerWidget {
  const TxTile({super.key, required this.txn, this.showDate = false});
  final Txn txn;
  final bool showDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Chỉ theo dõi thứ dòng này hiển thị: thêm/sửa giao dịch KHÁC không làm dòng này dựng lại.
    ref.watch(financeProvider.select((f) => (f.categories, f.accounts, f.currencies, f.settings, f.hasPhoto(txn.id))));
    final f = ref.read(financeProvider);
    final cat = f.category(txn.categoryId);
    final acc = f.account(txn.accountId);
    final hasPhoto = f.hasPhoto(txn.id); // tra sẵn, không quét toàn bộ ảnh cho từng dòng
    final isTransfer = txn.type == TxType.transfer;
    final title = isTransfer ? 'Chuyển khoản' : (cat?.name ?? 'Không có danh mục');
    final sub = [
      if (isTransfer) '${acc?.name ?? '?'} → ${f.account(txn.toAccountId)?.name ?? '?'}' else acc?.name ?? '',
      if (txn.note?.isNotEmpty == true) txn.note!,
      if (showDate) Fmt.dateShort(txn.occurredAt),
    ].where((s) => s.isNotEmpty).join(' · ');
    // Bấm vào giao dịch: thẻ "biến hình" thành màn sửa giao dịch
    return OpenCard(
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      page: TransactionEditPage(id: txn.id, type: txn.type),
      child: Row(
        children: [
          CircleIcon(icon: isTransfer ? 'sync_alt' : cat?.icon, color: isTransfer ? AppColors.transfer : hexColor(cat?.color)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (hasPhoto) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.photo_rounded, size: 14)),
                  ],
                ),
                if (sub.isNotEmpty)
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
              ],
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

/// Danh sách giao dịch: dạng danh sách hoặc lịch, lọc theo tháng / loại / tìm kiếm.
class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key});

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {
  bool calendar = true;
  DateTime month = DateTime.now();
  DateTime selectedDay = dateOnly(DateTime.now());
  int? type;
  MoneySource source = MoneySource.all;
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
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      list = list.where((t) => (t.note ?? '').toLowerCase().contains(q) || (f.category(t.categoryId)?.name ?? '').toLowerCase().contains(q)).toList();
    }
    // Tổng tính trước khi lọc theo loại để các ô Thu/Chi luôn có số.
    final totals = f.totals(list);
    if (type != null) list = list.where((t) => t.type == type).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Giao dịch'),
        actions: [
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
      body: Column(
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
                      IconButton.filledTonal(visualDensity: VisualDensity.compact, onPressed: () => _goMonth(-1), icon: const Icon(Icons.chevron_left_rounded)),
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
                                  Text('Tháng ${Fmt.month(from)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                ],
                              ),
                              Text(
                                '${Fmt.dateShort(from)} – ${Fmt.dateShort(to.subtract(const Duration(days: 1)))} · ${list.length} giao dịch',
                                style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton.filledTonal(visualDensity: VisualDensity.compact, onPressed: () => _goMonth(1), icon: const Icon(Icons.chevron_right_rounded)),
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
    );
  }

  int get _activeFilters => (type != null ? 1 : 0) + (source != MoneySource.all ? 1 : 0);

  String _typeLabel(int t) => switch (t) {
    TxType.expense => 'Khoản chi',
    TxType.income => 'Khoản thu',
    _ => 'Chuyển khoản',
  };

  void _toggleType(int t) => setState(() => type = type == t ? null : t);

  /// Bảng lọc: loại giao dịch + nguồn tiền.
  void _openFilters() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
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

          return SafeArea(
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
                              }),
                        child: const Text('Đặt lại'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  group('Loại giao dịch', [
                    for (final (label, icon, v) in [
                      ('Tất cả', Icons.all_inclusive_rounded, null),
                      ('Khoản chi', Icons.arrow_upward_rounded, TxType.expense),
                      ('Khoản thu', Icons.arrow_downward_rounded, TxType.income),
                      ('Chuyển khoản', Icons.swap_horiz_rounded, TxType.transfer),
                    ])
                      ChoiceChip(avatar: Icon(icon, size: 16), label: Text(label), selected: type == v, onSelected: (_) => apply(() => type = v)),
                  ]),
                  group('Nguồn tiền', [
                    for (final (label, icon, v) in [
                      ('Tất cả', Icons.all_inclusive_rounded, MoneySource.all),
                      ('Tiền mặt', Icons.payments_rounded, MoneySource.cash),
                      ('Tài khoản (NH, ví, thẻ)', Icons.account_balance_rounded, MoneySource.account),
                    ])
                      ChoiceChip(avatar: Icon(icon, size: 16), label: Text(label), selected: source == v, onSelected: (_) => apply(() => source = v)),
                  ]),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Xong')),
                  ),
                ],
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
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      itemCount: days.length,
      itemBuilder: (c, i) {
        final day = days[i];
        final items = byDay[day]!;
        final t = f.totals(items);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
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
                        CountText(
                          values: [t.income],
                          text: (cv) => '+${Fmt.compact(cv[0])}  ',
                          style: const TextStyle(color: AppColors.income, fontWeight: FontWeight.w600),
                        ),
                      if (t.expense > 0)
                        CountText(
                          values: [t.expense],
                          text: (cv) => '-${Fmt.compact(cv[0])}',
                          style: const TextStyle(color: AppColors.expense, fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                ),
                for (final tx in items) _dismissible(tx),
              ],
            ),
          ).stagger(i),
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
    final dayItems = byDay[selectedDay] ?? [];
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

    return _calendarBody(cell, from, dayItems, photoOf);
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

  Widget _calendarBody(Widget Function(DateTime, {bool outside}) cell, DateTime from, List<Txn> dayItems, Map<String, ({String file, int order})> photoOf) {
    final look = CalendarLook.of(ref.read(storeProvider));
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
                firstDay: DateTime(2000),
                lastDay: DateTime(2100),
                focusedDay: selectedDay.isBefore(from) ? from : selectedDay,
                startingDayOfWeek: TimeConfig.of(ref.read(storeProvider)).firstDayOfWeek == 7 ? StartingDayOfWeek.sunday : StartingDayOfWeek.monday,
                headerVisible: false,
                rowHeight: box.maxWidth / 7, // ô vuông
                daysOfWeekHeight: 30,
                selectedDayPredicate: (d) => isSameDay(d, selectedDay),
                onDaySelected: (d, _) => setState(() => selectedDay = dateOnly(d)),
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
        SectionTitle(
          Fmt.dayHeader(selectedDay),
          trailing: dayItems.isEmpty
              ? null
              : Text('${dayItems.length} giao dịch', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
        // Lưới giao dịch của ngày đang chọn + ô "Thêm" vào đúng ngày đó.
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (c, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(a),
              child: c,
            ),
          ),
          child: GridView.count(
            key: ValueKey(selectedDay),
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.82,
            children: [
              for (final (i, t) in dayItems.indexed) _TxGridCard(txn: t, photo: photoOf[t.id]?.file).stagger(i),
              _AddDayCard(day: selectedDay).stagger(dayItems.length),
            ],
          ),
        ),
      ],
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
  const _TxGridCard({required this.txn, this.photo});
  final Txn txn;
  final String? photo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(financeProvider.select((f) => (f.categories, f.accounts, f.currencies, f.settings)));
    final f = ref.read(financeProvider);
    final scheme = Theme.of(context).colorScheme;
    final isTransfer = txn.type == TxType.transfer;
    final cat = f.category(txn.categoryId);
    final color = isTransfer ? AppColors.transfer : hexColor(cat?.color, txColor(txn.type));
    final title = isTransfer ? 'Chuyển khoản' : (cat?.name ?? 'Không có danh mục');
    final sign = switch (txn.type) {
      TxType.expense => '-',
      TxType.income => '+',
      _ => '',
    };
    return OpenCard(
      radius: 16,
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
                    child: Icon(isTransfer ? Icons.swap_horiz_rounded : iconOf(cat?.icon), size: 44, color: color),
                  ),
                Positioned(
                  left: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      Fmt.time(txn.occurredAt),
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: CountText(
                    values: [txn.amount],
                    text: (cv) => '$sign${f.money(cv[0], txn.currencyCode)}',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: txColor(txn.type)),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Text(
                  txn.note?.isNotEmpty == true ? txn.note! : (f.account(txn.accountId)?.name ?? ''),
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

/// Ô "Thêm giao dịch" vào đúng ngày đang xem.
class _AddDayCard extends StatelessWidget {
  const _AddDayCard({required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: selected ? color : Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: AnimatedAmount(
                value: value,
                format: (v) => fmt(v),
                style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 15),
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
    amount.dispose();
    toAmount.dispose();
    note.dispose();
    super.dispose();
  }

  late int type = widget.type;
  final amount = TextEditingController();
  final toAmount = TextEditingController();
  final note = TextEditingController();
  Category? category;
  Account? account;
  Account? toAccount;
  DateTime at = DateTime.now();
  String? eventId;
  List<String> photos = [];
  List<String> removedAttachments = [];

  @override
  void initState() {
    super.initState();
    final store = ref.read(storeProvider);
    final f = ref.read(financeProvider);
    final rec = store.get(E.transactions, widget.id);
    if (rec != null) {
      final t = Txn(rec);
      type = t.type;
      amount.text = Fmt.money(t.amount, symbol: '', decimals: f.currency(t.currencyCode)?.decimals ?? 0).trim();
      if (t.toAmount != null) toAmount.text = amountText(t.toAmount!.round());
      note.text = t.note ?? '';
      category = f.category(t.categoryId);
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
      if (widget.preset['categoryName'] != null) {
        category = f.categories.where((c) => c.name == widget.preset['categoryName']).firstOrNull;
      }
    }
  }

  void _save() {
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
      'toAccountId': type == TxType.transfer ? toAccount!.id : null,
      'toAmount': crossCurrency
          ? (parseAmount(toAmount.text) > 0 ? parseAmount(toAmount.text) : f.convert(value, account!.currencyCode, toAccount!.currencyCode))
          : null,
      'categoryId': type == TxType.transfer ? null : category!.id,
      'occurredAt': at.toUtc().toIso8601String(),
      'note': note.text.trim().isEmpty ? null : note.text.trim(),
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
    HapticFeedback.lightImpact();
    for (final w in ref.read(financeProvider).budgetWarnings(Txn(saved))) {
      ref.read(notifierProvider).show('Cảnh báo định mức', w, inApp: false, kind: NotifyKind.finance);
      showToast(context, w, error: w.startsWith('Đã vượt'));
    }
    Navigator.of(context).maybePop();
  }

  /// Danh mục hay dùng nhất của loại hiện tại (đếm theo giao dịch đã ghi), tối đa [n].
  List<Category> _frequent(Finance f, int n) {
    final count = <String, int>{};
    for (final t in f.transactions) {
      if (t.type == type && t.categoryId != null) count[t.categoryId!] = (count[t.categoryId!] ?? 0) + 1;
    }
    final cats = f.categories.where((c) => c.type == type).toList();
    cats.sort((a, b) {
      final d = (count[b.id] ?? 0) - (count[a.id] ?? 0);
      return d != 0 ? d : (a.parentId == null ? 0 : 1) - (b.parentId == null ? 0 : 1);
    });
    final list = cats.take(n).toList();
    if (category != null && !list.any((c) => c.id == category!.id)) list[list.length - 1] = category!;
    return list;
  }

  void _addAmount(double v) {
    HapticFeedback.selectionClick();
    final cur = parseAmount(amount.text);
    setState(() => amount.text = amountText(cur + v));
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
      // Nút lưu cố định dưới cùng, màu theo loại giao dịch
      bottomNavigationBar: SafeArea(
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
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _TypeSwitch(
            value: type,
            onChanged: (v) => setState(() {
              type = v;
              if (category != null && category!.type != type) category = null;
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
                Text('Số tiền $typeName', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: amount,
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
                      if (value > 0)
                        Pressable(
                          onTap: () => setState(amount.clear),
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
          // Danh mục: lưới danh mục hay dùng + "Tất cả"
          if (type != TxType.transfer)
            section(
              'Danh mục',
              trailing: TextButton(
                onPressed: () async {
                  final c = await pickCategory(context, ref, type);
                  if (c != null) setState(() => category = c);
                },
                child: const Text('Tất cả'),
              ),
              Builder(
                builder: (_) {
                  final cats = _frequent(f, 7);
                  return GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.95,
                    children: [
                      for (final (i, c) in cats.indexed)
                        Builder(
                          builder: (_) {
                            final on = category?.id == c.id;
                            final cc = hexColor(c.color, color);
                            return Pressable(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => category = c);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                decoration: BoxDecoration(
                                  color: on ? cc.withValues(alpha: 0.18) : scheme.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: on ? cc : Colors.transparent, width: 1.6),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    AnimatedScale(
                                      scale: on ? 1.1 : 1,
                                      duration: const Duration(milliseconds: 220),
                                      curve: Curves.easeOutBack,
                                      child: CircleIcon(icon: c.icon, color: cc, size: 38),
                                    ),
                                    const SizedBox(height: 6),
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
                          if (c != null) setState(() => category = c);
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
                              const SizedBox(height: 6),
                              Text('Khác', style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
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
            'Ghi chú',
            TextField(
              controller: note,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(hintText: 'Ăn gì, mua gì, với ai…', prefixIcon: Icon(Icons.edit_note_rounded)),
            ),
          ),
          section(
            'Ảnh hoá đơn / kỷ niệm',
            PhotoGrid(
              fileIds: photos,
              onAdd: () async {
                final ids = await pickPhotos(context, ref);
                setState(() => photos = [...photos, ...ids]);
              },
              onRemove: (id) => setState(() => photos = photos.where((p) => p != id).toList()),
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
