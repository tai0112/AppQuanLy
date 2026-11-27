import 'dart:math';

import 'package:uuid/uuid.dart';

import '../core/format.dart';
import 'local_store.dart';
import 'models.dart';

// ============================================================ Tài chính

/// Truy vấn tài chính trên dữ liệu local (chạy offline).
/// Truy vấn tài chính trên dữ liệu local (chạy offline).
/// Hiệu năng: mỗi lần dữ liệu đổi, provider tạo Finance mới; mọi danh sách / bảng tra / số dư
/// chỉ tính MỘT LẦN rồi giữ lại (late final) → khung hình không phải sắp xếp/quét lại nhiều lần.
class Finance {
  Finance(this.store);
  final LocalStore store;

  /// Bộ nhớ đệm dùng chung giữa các lần tạo Finance: chỉ tính lại khi bảng liên quan thực sự đổi.
  static final _memo = <String, (String, Object?)>{};

  T _m<T>(String name, List<String> deps, T Function() build) {
    final key = store.versionKey(deps);
    final hit = _memo[name];
    if (hit != null && hit.$1 == key) return hit.$2 as T;
    final v = build();
    _memo[name] = (key, v);
    return v;
  }

  late final AppSettingsRec? settings = _m('settings', [E.appSettings], () {
    final all = store.all(E.appSettings);
    return all.isEmpty ? null : AppSettingsRec(all.first);
  });

  late final String baseCurrency = settings?.baseCurrency ?? 'VND';
  late final int monthStartDay = settings?.monthStartDay ?? 1;
  late final List<RecurringRule> recurringRules = _m('recurringRules', [
    E.recurringRules,
  ], () => store.all(E.recurringRules).map(RecurringRule.new).toList()..sort((a, b) => a.nextRunAt.compareTo(b.nextRunAt)));

  // ---------------------------------------------------- Tiền tệ
  late final List<Currency> currencies = _m('currencies', [
    E.currencies,
  ], () => store.all(E.currencies).map(Currency.new).toList()..sort((a, b) => a.code.compareTo(b.code)));
  late final Map<String, Currency> _curByCode = _m('curByCode', [E.currencies], () => {for (final c in currencies) c.code: c});
  Currency? currency(String code) => _curByCode[code];

  String money(num v, [String? code, bool sign = false]) {
    final c = currency(code ?? baseCurrency);
    return Fmt.money(v, symbol: c?.symbol ?? (code ?? baseCurrency), decimals: c?.decimals ?? 0, before: c?.symbolBefore ?? false, sign: sign);
  }

  late final List<ExchangeRate> _rates = _m('rates', [
    E.exchangeRates,
  ], () => store.all(E.exchangeRates).map(ExchangeRate.new).toList()..sort((a, b) => b.effectiveDate.compareTo(a.effectiveDate)));
  late final _ratePairs = _m('ratePairs', [E.exchangeRates], () => <String, List<ExchangeRate>>{});
  List<ExchangeRate> _pair(String f, String t) => _ratePairs.putIfAbsent('$f>$t', () => _rates.where((r) => r.from == f && r.to == t).toList());

  /// Quy đổi theo tỷ giá nhập tay gần nhất (trước hoặc bằng ngày giao dịch), hỗ trợ cả chiều ngược.
  double convert(double amount, String from, String to, [DateTime? at]) {
    if (from == to) return amount;
    final when = at ?? DateTime.now();
    ExchangeRate? pick(String f, String t) {
      final list = _pair(f, t);
      return list.where((r) => !r.effectiveDate.isAfter(when)).firstOrNull ?? list.firstOrNull;
    }

    final direct = pick(from, to);
    if (direct != null) return amount * direct.rate;
    final inverse = pick(to, from);
    if (inverse != null && inverse.rate != 0) return amount / inverse.rate;
    return amount; // chưa có tỷ giá
  }

  double toBase(Txn t) => t.currencyCode == baseCurrency ? t.amount : convert(t.amount, t.currencyCode, baseCurrency, at(t));

  // ---------------------------------------------------- Tài khoản, danh mục
  late final List<Account> accounts = _m('accounts', [
    E.accounts,
  ], () => store.all(E.accounts).map(Account.new).toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)));
  late final Map<String, Account> _accById = _m('accById', [E.accounts], () => {for (final a in accounts) a.id: a});
  late final List<Category> categories = _m('categories', [
    E.categories,
  ], () => store.all(E.categories).map(Category.new).toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)));
  late final Map<String, Category> _catById = _m('catById', [E.categories], () => {for (final c in categories) c.id: c});

  Category? category(String? id) => id == null ? null : _catById[id];
  Account? account(String? id) => id == null ? null : _accById[id];

  late final _rootCache = _m('rootCache', [E.categories], () => <String?, Category?>{});

  /// Danh mục gốc (cấp 1) của một danh mục.
  Category? rootCategory(String? id) => _rootCache.putIfAbsent(id, () {
    var c = category(id);
    var guard = 0;
    while (c?.parentId != null && guard++ < 10) {
      final p = category(c!.parentId);
      if (p == null) break;
      c = p;
    }
    return c;
  });

  // ---------------------------------------------------- Giao dịch
  late final _when = _m('when', [E.transactions], () => <String, DateTime>{});

  /// Thời điểm giao dịch (đã parse sẵn, không parse lại chuỗi mỗi lần so sánh).
  DateTime at(Txn t) => _when[t.id] ??= t.occurredAt;

  /// Giao dịch mới nhất trước — sắp xếp 1 lần.
  late final List<Txn> transactions = _m('transactions', [E.transactions], () {
    final list = store.all(E.transactions).map(Txn.new).toList();
    for (final t in list) {
      _when[t.id] = t.occurredAt;
    }
    list.sort((a, b) => _when[b.id]!.compareTo(_when[a.id]!));
    return list;
  });

  /// Danh sách fileId ảnh theo giao dịch (tra O(1) cho từng dòng).
  late final Map<String, List<String>> _photosByTxn = _m('photosByTxn', [E.attachments], () {
    final byOwner = <String, List<Attachment>>{};
    for (final raw in store.all(E.attachments)) {
      final a = Attachment(raw);
      (byOwner[a.ownerId] ??= []).add(a);
    }
    return {for (final e in byOwner.entries) e.key: (e.value..sort((a, b) => a.sortOrder.compareTo(b.sortOrder))).map((a) => a.fileId).toList()};
  });
  bool hasPhoto(String txnId) => _photosByTxn.containsKey(txnId);
  List<String> photosOf(String txnId) => _photosByTxn[txnId] ?? const [];

  /// Biến động số dư theo tài khoản — quét giao dịch MỘT lần cho mọi tài khoản.
  late final Map<String, double> _moves = _m('moves', [E.transactions, E.jarTransactions], () {
    final m = <String, double>{};
    for (final t in transactions) {
      m[t.accountId] = (m[t.accountId] ?? 0) + (t.type == TxType.income ? t.amount : -t.amount);
      if (t.type == TxType.transfer && t.toAccountId != null) {
        m[t.toAccountId!] = (m[t.toAccountId!] ?? 0) + (t.toAmount ?? t.amount);
      }
    }
    for (final j in store.all(E.jarTransactions).map(JarTxn.new)) {
      if (j.accountId != null) m[j.accountId!] = (m[j.accountId!] ?? 0) - j.amount; // nạp hũ trừ tiền tài khoản
    }
    return m;
  });

  double balance(Account a) => a.openingBalance + (_moves[a.id] ?? 0);

  late final double totalBalance = accounts
      .where((a) => a.includeInTotal && !a.isArchived)
      .fold(0.0, (s, a) => s + convert(balance(a), a.currencyCode, baseCurrency));

  /// Tài khoản chọn sẵn khi thêm giao dịch: theo cài đặt của từng người (mặc định cố định hoặc nhớ lần trước).
  Account? defaultAccount() {
    final active = accounts.where((a) => !a.isArchived).toList();
    final s = settings;
    final last = store.meta('lastAccountId');
    if (s?.rememberLastAccount == true && last != null) {
      final a = active.where((x) => x.id == last).firstOrNull;
      if (a != null) return a;
    }
    return active.where((x) => x.id == s?.defaultAccountId).firstOrNull ?? active.firstOrNull;
  }

  /// Tổng thu/chi theo nguồn tiền (tiền mặt / tài khoản).
  ({double income, double expense}) totalsBySource(List<Txn> list, MoneySource source) =>
      totals(list.where((t) => account(t.accountId)?.matches(source) ?? source == MoneySource.all).toList());

  /// Khoảng tháng tài chính chứa ngày [d] (tính theo ngày bắt đầu tháng cấu hình).
  (DateTime, DateTime) monthRange(DateTime d) {
    final sd = monthStartDay;
    var start = DateTime(d.year, d.month, sd);
    if (d.isBefore(start)) start = DateTime(d.year, d.month - 1, sd);
    return (start, DateTime(start.year, start.month + 1, sd));
  }

  late final _rangeCache = _m('ranges', [E.transactions], () => <String, List<Txn>>{});

  List<Txn> inRange(DateTime from, DateTime to) => _rangeCache.putIfAbsent(_rk(from, to), () {
    final out = <Txn>[];
    for (final t in transactions) {
      final w = at(t);
      if (w.isBefore(from)) break; // danh sách đã sắp mới → cũ: qua mốc là dừng
      if (w.isBefore(to)) out.add(t);
    }
    return out;
  });

  static String _rk(DateTime from, DateTime to) => '${from.millisecondsSinceEpoch}-${to.millisecondsSinceEpoch}';

  // Kết quả tổng hợp theo khoảng thời gian: nhớ lại cho tới khi giao dịch / tỷ giá / cài đặt / danh mục đổi.
  // Nhiều màn (Trang chủ, Giao dịch, Thống kê, thẻ So sánh) dùng chung → mỗi khoảng chỉ tính một lần.
  late final _totalsIn = _m('totalsIn', [E.transactions, E.exchangeRates, E.appSettings], () => <String, ({double income, double expense})>{});
  late final _byCatIn = _m('byCatIn', [
    E.transactions,
    E.exchangeRates,
    E.appSettings,
    E.categories,
  ], () => <String, List<({Category? category, double amount})>>{});

  /// Tổng thu/chi trong [from, to) — đã nhớ.
  ({double income, double expense}) totalsIn(DateTime from, DateTime to) => _totalsIn.putIfAbsent(_rk(from, to), () => totals(inRange(from, to)));

  /// Tổng theo danh mục trong [from, to) — đã nhớ. Không được sửa danh sách trả về.
  List<({Category? category, double amount})> byCategoryIn(DateTime from, DateTime to, int type, {String? parentId}) =>
      _byCatIn.putIfAbsent('${_rk(from, to)}|$type|$parentId', () => byCategory(inRange(from, to), type, parentId: parentId));

  ({double income, double expense}) totals(List<Txn> list) {
    var inc = 0.0, exp = 0.0;
    for (final t in list) {
      if (t.type == TxType.income) inc += toBase(t);
      if (t.type == TxType.expense) exp += toBase(t);
    }
    return (income: inc, expense: exp);
  }

  /// Tổng theo danh mục gốc (hoặc danh mục con nếu [parentId] được truyền).
  List<({Category? category, double amount})> byCategory(List<Txn> list, int type, {String? parentId}) {
    final map = <String?, double>{};
    for (final t in list) {
      if (t.type != type) continue;
      String? key;
      if (parentId == null) {
        key = rootCategory(t.categoryId)?.id;
      } else {
        if (rootCategory(t.categoryId)?.id != parentId) continue;
        key = t.categoryId;
      }
      map[key] = (map[key] ?? 0) + toBase(t);
    }
    return map.entries.map((e) => (category: category(e.key), amount: e.value)).toList()..sort((a, b) => b.amount.compareTo(a.amount));
  }

  // ---------------------------------------------------- Định mức

  (DateTime, DateTime) budgetRange(Budget b, DateTime now) {
    switch (b.period) {
      case 1:
        final d = dateOnly(now);
        return (d, d.add(const Duration(days: 1)));
      case 2:
        final d = dateOnly(now).subtract(Duration(days: now.weekday - 1));
        return (d, d.add(const Duration(days: 7)));
      case 4:
        return (DateTime(now.year), DateTime(now.year + 1));
      default:
        return monthRange(now);
    }
  }

  double budgetSpent(Budget b, [DateTime? when]) {
    final (from, to) = budgetRange(b, when ?? DateTime.now());
    var sum = 0.0;
    for (final t in inRange(from, to)) {
      if (t.type != TxType.expense) continue;
      if (b.scope == 2 && !(rootCategory(t.categoryId)?.id == b.refId || t.categoryId == b.refId)) continue;
      if (b.scope == 3 && t.accountId != b.refId) continue;
      sum += t.currencyCode == b.currencyCode ? t.amount : convert(t.amount, t.currencyCode, b.currencyCode, at(t));
    }
    return sum;
  }

  late final List<Budget> budgets = _m('budgets', [E.budgets], () => store.all(E.budgets).map(Budget.new).where((b) => b.isActive).toList());

  /// Các định mức bị ảnh hưởng bởi giao dịch, trả về cảnh báo nếu vượt ngưỡng.
  List<String> budgetWarnings(Txn t) {
    if (t.type != TxType.expense) return [];
    final out = <String>[];
    for (final b in budgets) {
      final related =
          b.scope == 1 || (b.scope == 2 && (rootCategory(t.categoryId)?.id == b.refId || t.categoryId == b.refId)) || (b.scope == 3 && t.accountId == b.refId);
      if (!related || b.limit <= 0) continue;
      final spent = budgetSpent(b, t.occurredAt);
      final pct = spent / b.limit * 100;
      if (pct >= 100) {
        out.add('Đã vượt định mức "${b.name}": ${money(spent, b.currencyCode)} / ${money(b.limit, b.currencyCode)}');
      } else if (pct >= b.warnPercent) {
        out.add('Sắp vượt định mức "${b.name}": đã dùng ${pct.toStringAsFixed(0)}%');
      }
    }
    return out;
  }

  // ---------------------------------------------------- Hũ

  late final Map<String, double> _jarSaved = _m('jarSaved', [E.jarTransactions], () {
    final m = <String, double>{};
    for (final j in store.all(E.jarTransactions).map(JarTxn.new)) {
      m[j.jarId] = (m[j.jarId] ?? 0) + j.amount;
    }
    return m;
  });

  double jarSaved(String jarId) => _jarSaved[jarId] ?? 0;
}

extension LetX<T> on T {
  R let<R>(R Function(T) f) => f(this);
}

// ============================================================ Tiền điện bậc thang

class TierUse {
  TierUse(this.order, this.kwh, this.price);
  final int order;
  final int kwh;
  final double price;
  double get amount => kwh * price;
}

class ElectricityResult {
  ElectricityResult(this.kwh, this.uses, this.subtotal, this.vat, this.fixedFee);
  final int kwh;
  final List<TierUse> uses;
  final double subtotal;
  final double vat;
  final double fixedFee;
  double get total => subtotal + vat + fixedFee;
}

class Electricity {
  /// Số kWh → tiền (theo từng bậc, cộng VAT + phí cố định).
  static ElectricityResult calc(int kwh, List<Tier> tiers, double vatPercent, double fixedFee) {
    final sorted = [...tiers]..sort((a, b) => a.from.compareTo(b.from));
    var remaining = kwh;
    final uses = <TierUse>[];
    for (final t in sorted) {
      if (remaining <= 0) break;
      final cap = t.to == null ? remaining : (t.to! - t.from + (t.from == 0 ? 0 : 1));
      final used = min(remaining, max(0, cap));
      if (used > 0) uses.add(TierUse(t.order, used, t.price));
      remaining -= used;
    }
    final subtotal = uses.fold(0.0, (s, u) => s + u.amount);
    final vat = subtotal * vatPercent / 100;
    return ElectricityResult(kwh, uses, subtotal, vat, fixedFee);
  }

  /// Tiền → số kWh (tính ngược).
  static int reverse(double money, List<Tier> tiers, double vatPercent, double fixedFee) {
    var budget = (money - fixedFee) / (1 + vatPercent / 100);
    if (budget <= 0) return 0;
    final sorted = [...tiers]..sort((a, b) => a.from.compareTo(b.from));
    var kwh = 0.0;
    for (final t in sorted) {
      final cap = t.to == null ? double.infinity : (t.to! - t.from + (t.from == 0 ? 0 : 1)).toDouble();
      final cost = cap * t.price;
      if (budget <= cost || t.to == null) {
        kwh += budget / t.price;
        budget = 0;
        break;
      }
      kwh += cap;
      budget -= cost;
    }
    return kwh.floor();
  }
}

// ============================================================ Chu kỳ kinh nguyệt

class CyclePrediction {
  CyclePrediction({
    required this.avgCycle,
    required this.avgPeriod,
    required this.nextStart,
    required this.earliest,
    required this.latest,
    required this.ovulation,
    required this.fertileStart,
    required this.fertileEnd,
    required this.cycles,
    this.calendarFertile,
    this.standardDays,
    required this.warnings,
    this.extraBefore = 0,
    this.extraAfter = 0,
    this.irregular = false,
    this.safeEarly,
    this.safeLate,
  });
  final double avgCycle;
  final double avgPeriod;
  final DateTime nextStart;
  final DateTime earliest;
  final DateTime latest;
  final DateTime ovulation;
  final DateTime fertileStart;
  final DateTime fertileEnd;
  final List<int> cycles;
  final (int, int)? calendarFertile; // ngày thứ x..y của chu kỳ (Ogino–Knaus)
  final bool? standardDays; // áp dụng được Standard Days Method (26–32 ngày)
  final List<String> warnings;

  /// Số ngày nới thêm cho cửa sổ dễ thụ thai khi chu kỳ dao động (rụng trứng có thể sớm / muộn hơn trung bình).
  final int extraBefore, extraAfter;

  /// Chu kỳ không đều (chênh lệch > 7 ngày hoặc ngoài 21–35 ngày) → ngày an toàn kém tin cậy.
  final bool irregular;

  /// Ngày an toàn của chu kỳ dự đoán gần nhất: tương đối (sau kỳ kinh → trước cửa sổ dễ thụ thai)
  /// và an toàn hơn (sau cửa sổ dễ thụ thai → trước kỳ sau). null = không có khoảng nào.
  final (DateTime, DateTime)? safeEarly, safeLate;
}

/// Đánh dấu một ngày trên lịch chu kỳ.
enum CycleMark { none, period, predicted, fertile, ovulation, safeRelative, safe }

class Cycle {
  /// Dự đoán theo công thức trong PLAN.md (mục 3.11). Nguồn: NHS, Cleveland Clinic, womenshealth.gov.
  static CyclePrediction? predict(List<CyclePeriod> periods, CycleSettings? s) {
    if (periods.isEmpty) return null;
    final sorted = [...periods]..sort((a, b) => a.start.compareTo(b.start));
    final all = <int>[];
    for (var i = 1; i < sorted.length; i++) {
      all.add(sorted[i].start.difference(sorted[i - 1].start).inDays);
    }
    final valid = all.where((c) => c >= 15 && c <= 90).toList();
    final recent = valid.length > 6 ? valid.sublist(valid.length - 6) : valid;
    final avgCycle = recent.isEmpty ? (s?.cycleDays ?? 28).toDouble() : recent.reduce((a, b) => a + b) / recent.length;
    final lens = sorted.where((p) => p.end != null).map((p) => p.end!.difference(p.start).inDays + 1).toList();
    final avgPeriod = lens.isEmpty ? (s?.periodDays ?? 5).toDouble() : lens.reduce((a, b) => a + b) / lens.length;

    final last = sorted.last.start;
    final next = last.add(Duration(days: avgCycle.round()));
    final earliest = recent.isEmpty ? next : last.add(Duration(days: recent.reduce(min)));
    final latest = recent.isEmpty ? next : last.add(Duration(days: recent.reduce(max)));
    final luteal = s?.lutealDays ?? 14;
    final ovulation = next.subtract(Duration(days: luteal));
    // Chu kỳ dao động → ngày rụng trứng có thể sớm (theo chu kỳ ngắn nhất) hoặc muộn (dài nhất) hơn trung bình:
    // nới cửa sổ dễ thụ thai tương ứng (tối đa 7 ngày mỗi phía) để không gắn nhầm "an toàn".
    final extraBefore = recent.isEmpty ? 0 : (avgCycle.round() - recent.reduce(min)).clamp(0, 7);
    final extraAfter = recent.isEmpty ? 0 : (recent.reduce(max) - avgCycle.round()).clamp(0, 7);
    final irregular = recent.isNotEmpty && (recent.reduce(max) - recent.reduce(min) > 7 || recent.any((c) => c < 21 || c > 35));
    final fertileStart = ovulation.subtract(Duration(days: (s?.fertileBefore ?? 5) + extraBefore));
    final fertileEnd = ovulation.add(Duration(days: (s?.fertileAfter ?? 1) + extraAfter));
    // Ngày an toàn của chu kỳ vừa bắt đầu (từ [last]): sau kỳ kinh → trước cửa sổ, và sau cửa sổ → trước kỳ sau
    final lastPeriodEnd = sorted.last.end ?? last.add(Duration(days: avgPeriod.round() - 1));
    final cycleOvu = last.add(Duration(days: avgCycle.round() - luteal));
    final cFertStart = cycleOvu.subtract(Duration(days: (s?.fertileBefore ?? 5) + extraBefore));
    final cFertEnd = cycleOvu.add(Duration(days: (s?.fertileAfter ?? 1) + extraAfter));
    final early = (dateOnly(lastPeriodEnd).add(const Duration(days: 1)), dateOnly(cFertStart).subtract(const Duration(days: 1)));
    final late = (dateOnly(cFertEnd).add(const Duration(days: 1)), dateOnly(next).subtract(const Duration(days: 1)));

    (int, int)? calendar;
    if (valid.length >= 6) calendar = (valid.reduce(min) - 18, valid.reduce(max) - 11);
    bool? sdm;
    if (recent.isNotEmpty) sdm = recent.every((c) => c >= 26 && c <= 32);

    final warnings = <String>[];
    if (recent.any((c) => c < 21 || c > 35)) warnings.add('Có chu kỳ ngoài khoảng 21–35 ngày (chu kỳ không đều). Nếu kéo dài, nên hỏi ý kiến bác sĩ.');
    final daysSince = DateTime.now().difference(last).inDays;
    if (daysSince >= 90) warnings.add('Đã $daysSince ngày chưa có kinh (≥ 90 ngày). Nên đi khám nếu không mang thai/cho con bú.');

    return CyclePrediction(
      avgCycle: avgCycle,
      avgPeriod: avgPeriod,
      nextStart: next,
      earliest: earliest,
      latest: latest,
      ovulation: ovulation,
      fertileStart: fertileStart,
      fertileEnd: fertileEnd,
      cycles: all,
      calendarFertile: calendar,
      standardDays: sdm,
      warnings: warnings,
      extraBefore: extraBefore,
      extraAfter: extraAfter,
      irregular: irregular,
      safeEarly: early.$1.isAfter(early.$2) ? null : early,
      safeLate: late.$1.isAfter(late.$2) ? null : late,
    );
  }

  /// Đánh dấu ngày [day] cho lịch: kỳ đã ghi, kỳ dự đoán, dễ thụ thai, rụng trứng, an toàn tương đối / an toàn hơn.
  /// Dùng chung một cách chiếu chu kỳ với [CycleDays.of] (thẻ "Hôm nay", 7 ngày tới, thông báo) → mọi nơi khớp nhau.
  /// - Trước kỳ gần nhất: dùng đúng các kỳ đã ghi (độ dài chu kỳ thật).
  /// - Từ kỳ gần nhất trở đi: chiếu theo chu kỳ trung bình.
  static CycleMark markOf(CyclePrediction p, List<CyclePeriod> periods, CycleSettings? s, DateTime day) {
    if (periods.isEmpty) return CycleMark.none;
    final d = dateOnly(day);
    final periodDays = s?.periodDays ?? p.avgPeriod.round();
    for (final x in periods) {
      final end = dateOnly(x.end ?? x.start.add(Duration(days: periodDays - 1)));
      if (!d.isBefore(dateOnly(x.start)) && !d.isAfter(end)) return CycleMark.period;
    }
    final starts = [for (final x in periods) dateOnly(x.start)]..sort();
    final avg = p.avgCycle.round();
    final luteal = s?.lutealDays ?? 14;
    final before = (s?.fertileBefore ?? 5) + p.extraBefore, after = (s?.fertileAfter ?? 1) + p.extraAfter;

    DateTime cycleStart, cycleNext;
    var projected = false;
    if (d.isBefore(starts.first)) return CycleMark.none;
    final i = starts.lastIndexWhere((x) => !x.isAfter(d));
    if (i < starts.length - 1) {
      cycleStart = starts[i];
      cycleNext = starts[i + 1];
    } else {
      final k = d.difference(starts.last).inDays ~/ avg;
      cycleStart = starts.last.add(Duration(days: k * avg));
      cycleNext = cycleStart.add(Duration(days: avg));
      projected = k >= 1;
    }
    // Chu kỳ ghi thật bất thường (quá dài / quá ngắn) → không đoán ngày cho chu kỳ đó
    final len = cycleNext.difference(cycleStart).inDays;
    if (len < 15 || len > 90) return CycleMark.none;
    if (projected && d.difference(cycleStart).inDays < p.avgPeriod.round()) return CycleMark.predicted;
    final ovu = cycleNext.subtract(Duration(days: luteal));
    if (d == ovu) return CycleMark.ovulation;
    if (!d.isBefore(ovu.subtract(Duration(days: before))) && !d.isAfter(ovu.add(Duration(days: after)))) return CycleMark.fertile;
    return d.isBefore(ovu) ? CycleMark.safeRelative : CycleMark.safe;
  }
}

/// Giai đoạn của một ngày trong chu kỳ.
enum CyclePhase { period, late, soon, pms, fertile, ovulation, follicular, luteal }

/// Trạng thái + lời nhắc của một ngày (dùng cho thẻ "Hôm nay", dải 7 ngày và thông báo mỗi ngày).
class CycleDay {
  CycleDay(this.date, this.phase, this.cycleDay, this.title, this.body, this.level);
  final DateTime date;
  final CyclePhase phase;

  /// Ngày thứ mấy của chu kỳ (1 = ngày đầu hành kinh).
  final int cycleDay;
  final String title;
  final String body;

  /// 0 = thông tin, 1 = lưu ý, 2 = cảnh báo.
  final int level;
}

extension CycleDays on Cycle {
  static CycleDay? of(CyclePrediction? p, List<CyclePeriod> periods, CycleSettings? s, DateTime day, {bool partner = false}) {
    if (p == null || periods.isEmpty) return null;
    final d = dateOnly(day);
    final today = dateOnly(DateTime.now());
    final avg = p.avgCycle.round();
    final periodLen = p.avgPeriod.round();
    final luteal = s?.lutealDays ?? 14;
    final before = (s?.fertileBefore ?? 5) + p.extraBefore, after = (s?.fertileAfter ?? 1) + p.extraAfter;
    final who = partner ? 'người ấy' : 'bạn';
    final safeNote = p.irregular
        ? 'Chu kỳ chưa đều nên ngày an toàn KHÔNG đáng tin; vẫn nên dùng biện pháp bảo vệ.'
        : 'Tính theo lịch, chỉ mang tính tham khảo (thất bại khoảng 1/4 trường hợp mỗi năm); muốn chắc chắn hãy dùng biện pháp bảo vệ.';
    final fertileNote = partner ? 'Nếu chưa muốn có em bé, hai bạn nhớ dùng biện pháp an toàn.' : 'Nếu chưa muốn có em bé, hãy dùng biện pháp an toàn.';

    // Kỳ kinh đã ghi chứa ngày này
    final logged = periods.where((x) {
      final end = x.end ?? x.start.add(Duration(days: (s?.periodDays ?? periodLen) - 1));
      return !d.isBefore(dateOnly(x.start)) && !d.isAfter(dateOnly(end));
    }).firstOrNull;
    if (logged != null) {
      final n = d.difference(dateOnly(logged.start)).inDays + 1;
      return CycleDay(
        d,
        CyclePhase.period,
        n,
        partner ? 'Người ấy đang ở ngày $n của kỳ kinh' : 'Ngày $n của kỳ kinh',
        n <= 2
            ? (partner
                  ? 'Những ngày đầu thường đau nhất: một túi chườm ấm và chút đồ ngọt sẽ rất ý nghĩa 💕'
                  : 'Ngày đầu thường đau nhiều: chườm ấm bụng, uống nước ấm, nghỉ ngơi nhiều hơn.')
            : (partner ? 'Nhẹ nhàng, kiên nhẫn và hỏi thăm người ấy nhiều hơn nhé.' : 'Thay băng vệ sinh 4–6 tiếng/lần, ăn đồ giàu sắt, hạn chế đồ lạnh.'),
        n <= 2 ? 1 : 0,
      );
    }

    // Trễ kinh: hôm nay đã qua ngày dự kiến mà chưa ghi kỳ mới
    final next = dateOnly(p.nextStart);
    if (d == today && !d.isBefore(next)) {
      final late = d.difference(next).inDays;
      if (late == 0) {
        return CycleDay(
          d,
          CyclePhase.soon,
          avg,
          partner ? 'Hôm nay người ấy có thể bắt đầu kỳ kinh' : 'Hôm nay có thể bắt đầu kỳ kinh',
          partner ? 'Chuẩn bị sẵn đồ ấm, đồ ngọt và sự quan tâm nhé 💕' : 'Mang theo băng vệ sinh, mặc đồ tối màu. Nhớ bấm "Ghi kỳ kinh" khi bắt đầu.',
          2,
        );
      }
      return CycleDay(
        d,
        CyclePhase.late,
        avg + late,
        partner ? 'Người ấy trễ kinh $late ngày' : 'Trễ kinh $late ngày',
        late >= 7
            ? 'Trễ từ 7 ngày trở lên: nên thử thai hoặc hỏi ý kiến bác sĩ nếu có khả năng mang thai.'
            : 'Căng thẳng, thức khuya, thay đổi cân nặng đều có thể làm trễ kinh. Nhớ ghi lại khi $who bắt đầu kỳ kinh.',
        late >= 7 ? 2 : 1,
      );
    }

    // Chiếu chu kỳ ra tương lai: tìm ngày bắt đầu chu kỳ chứa d
    var start = dateOnly(periods.map((x) => x.start).reduce((a, b) => a.isAfter(b) ? a : b));
    while (!d.isBefore(start.add(Duration(days: avg)))) {
      start = start.add(Duration(days: avg));
    }
    final cycleDay = d.difference(start).inDays + 1;
    final nextStart = start.add(Duration(days: avg));
    final until = nextStart.difference(d).inDays;
    final ovu = nextStart.subtract(Duration(days: luteal));

    if (d.isAfter(today) && cycleDay <= periodLen && !start.isBefore(next)) {
      return CycleDay(
        d,
        CyclePhase.period,
        cycleDay,
        partner ? 'Dự kiến ngày $cycleDay kỳ kinh của người ấy' : 'Dự kiến ngày $cycleDay của kỳ kinh',
        'Dự đoán theo chu kỳ trung bình ${p.avgCycle.toStringAsFixed(0)} ngày.',
        1,
      );
    }
    if (d == dateOnly(ovu)) {
      return CycleDay(
        d,
        CyclePhase.ovulation,
        cycleDay,
        partner ? 'Hôm nay người ấy dự kiến rụng trứng' : 'Hôm nay dự kiến rụng trứng',
        'Khả năng thụ thai cao nhất trong chu kỳ. $fertileNote',
        2,
      );
    }
    if (!d.isBefore(ovu.subtract(Duration(days: before))) && !d.isAfter(ovu.add(Duration(days: after)))) {
      final k = dateOnly(ovu).difference(d).inDays;
      return CycleDay(
        d,
        CyclePhase.fertile,
        cycleDay,
        k > 0 ? (partner ? 'Người ấy đang trong ngày dễ thụ thai' : 'Đang trong ngày dễ thụ thai') : 'Cuối cửa sổ dễ thụ thai',
        k > 0 ? 'Còn $k ngày đến ngày rụng trứng. $fertileNote' : fertileNote,
        1,
      );
    }
    if (until >= 1 && until <= 3) {
      return CycleDay(
        d,
        CyclePhase.soon,
        cycleDay,
        partner ? 'Còn $until ngày đến kỳ của người ấy' : 'Còn $until ngày đến kỳ kinh',
        partner
            ? 'Người ấy có thể mệt và nhạy cảm hơn. Chuẩn bị chút đồ ngọt, nhẹ nhàng hơn nhé 💕'
            : 'Chuẩn bị băng vệ sinh, giữ ấm bụng, hạn chế đồ cay và lạnh.',
        1,
      );
    }
    if (until >= 4 && until <= 7) {
      return CycleDay(
        d,
        CyclePhase.pms,
        cycleDay,
        partner ? 'Người ấy sắp vào giai đoạn tiền kinh nguyệt' : 'Giai đoạn tiền kinh nguyệt',
        '${partner ? 'Có thể dễ cáu, mệt hoặc đau ngực. Lắng nghe và thông cảm nhiều hơn.' : 'Có thể đau ngực, đầy hơi, dễ cáu. Ngủ đủ, giảm muối và caffeine, vận động nhẹ.'} '
        'Vẫn trong nhóm ngày an toàn. $safeNote',
        0,
      );
    }
    if (d.isBefore(ovu)) {
      return CycleDay(
        d,
        CyclePhase.follicular,
        cycleDay,
        'Ngày $cycleDay · an toàn tương đối',
        '${partner ? 'Giai đoạn người ấy thường nhiều năng lượng, vui vẻ.' : 'Năng lượng thường tăng dần, hợp để tập luyện.'} '
            'Ngày an toàn tương đối (trước cửa sổ dễ thụ thai). $safeNote',
        0,
      );
    }
    return CycleDay(
      d,
      CyclePhase.luteal,
      cycleDay,
      'Ngày $cycleDay · ngày an toàn',
      'Đã qua cửa sổ dễ thụ thai: ngày an toàn (giai đoạn hoàng thể). Còn $until ngày đến kỳ kinh (${Fmt.dateShort(nextStart)}). $safeNote',
      0,
    );
  }
}

// ============================================================ Lịch lặp

/// Quy tắc lặp đơn giản (tập con RRULE): FREQ=DAILY|WEEKLY|MONTHLY|YEARLY[;BYDAY=MO,TU][;INTERVAL=n]
class Recurrence {
  static const _days = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];

  static String? build(String freq, {List<int> weekdays = const [], int interval = 1}) {
    if (freq == 'NONE') return null;
    final parts = ['FREQ=$freq'];
    if (interval > 1) parts.add('INTERVAL=$interval');
    if (freq == 'WEEKLY' && weekdays.isNotEmpty) parts.add('BYDAY=${weekdays.map((d) => _days[d - 1]).join(',')}');
    return parts.join(';');
  }

  static final _ruleCache = <String, Map<String, String>>{};

  /// Đọc quy tắc lặp (có bộ đệm: cùng chuỗi RRULE chỉ phân tích 1 lần).
  static Map<String, String> parse(String? rrule) {
    if (rrule == null || rrule.isEmpty) return const {};
    return _ruleCache.putIfAbsent(rrule, () => _parseRaw(rrule));
  }

  static Map<String, String> _parseRaw(String? rrule) {
    if (rrule == null || rrule.isEmpty) return {};
    return {
      for (final p in rrule.split(';'))
        if (p.contains('=')) p.split('=')[0]: p.split('=')[1],
    };
  }

  static String describe(String? rrule) {
    final r = parse(rrule);
    switch (r['FREQ']) {
      case 'DAILY':
        return 'Hằng ngày';
      case 'WEEKLY':
        final days = r['BYDAY']?.split(',').map((d) => Fmt.weekdaysShort[_days.indexOf(d)]).join(', ');
        return days == null ? 'Hằng tuần' : 'Hằng tuần ($days)';
      case 'MONTHLY':
        return 'Hằng tháng';
      case 'YEARLY':
        return 'Hằng năm';
      default:
        return 'Không lặp';
    }
  }

  /// Các lần diễn ra trong [from, to).
  static List<DateTime> occurrences(EventRec e, DateTime from, DateTime to) {
    final start = e.startAt;
    final r = parse(e.rrule);
    final until = e.repeatUntil?.add(const Duration(days: 1));
    final end = until != null && until.isBefore(to) ? until : to;
    if (r.isEmpty) return (!start.isBefore(from) && start.isBefore(to)) || _spans(e, start, from) ? [start] : [];

    final interval = int.tryParse(r['INTERVAL'] ?? '1') ?? 1;
    final out = <DateTime>[];
    var guard = 0;
    switch (r['FREQ']) {
      case 'DAILY':
      case 'WEEKLY':
        final byDay = r['BYDAY']?.split(',').map((d) => _days.indexOf(d) + 1).toSet();
        var d = DateTime(start.year, start.month, start.day, start.hour, start.minute);
        if (d.isBefore(from)) {
          final skip = from.difference(d).inDays;
          d = d.add(Duration(days: skip - skip % (r['FREQ'] == 'DAILY' ? interval : 1)));
        }
        while (d.isBefore(end) && guard++ < 1000) {
          final ok = r['FREQ'] == 'DAILY'
              ? dateOnly(d).difference(dateOnly(start)).inDays % interval == 0
              : (byDay ?? {start.weekday}).contains(d.weekday) && (dateOnly(d).difference(dateOnly(start)).inDays ~/ 7) % interval == 0;
          if (ok && !d.isBefore(from) && !d.isBefore(start)) out.add(d);
          d = d.add(const Duration(days: 1));
        }
      case 'MONTHLY':
        var i = 0;
        while (guard++ < 600) {
          final d = DateTime(start.year, start.month + i * interval, start.day, start.hour, start.minute);
          if (!d.isBefore(end)) break;
          if (!d.isBefore(from) && d.day == start.day) out.add(d);
          i++;
        }
      case 'YEARLY':
        for (var y = max(start.year, from.year); y <= to.year; y++) {
          final d = DateTime(y, start.month, start.day, start.hour, start.minute);
          if (!d.isBefore(from) && d.isBefore(end) && !d.isBefore(start)) out.add(d);
        }
    }
    return out;
  }

  /// Sự kiện nhiều ngày (không lặp) có phủ qua ngày [from] không.
  static bool _spans(EventRec e, DateTime start, DateTime from) {
    final end = e.endAt;
    return end != null && start.isBefore(from) && end.isAfter(from);
  }

  /// Tính lần chạy kế tiếp sau [from] theo quy tắc [rrule].
  static DateTime nextOccurrence(String? rrule, DateTime from) {
    final r = parse(rrule);
    final interval = (int.tryParse(r['INTERVAL'] ?? '1') ?? 1).clamp(1, 365);
    switch (r['FREQ']) {
      case 'DAILY':
        return DateTime(from.year, from.month, from.day + interval, from.hour, from.minute);
      case 'WEEKLY':
        final byDay = r['BYDAY']?.split(',').map((d) => _days.indexOf(d) + 1).where((w) => w >= 1 && w <= 7).toSet();
        if (byDay == null || byDay.isEmpty) {
          return DateTime(from.year, from.month, from.day + 7 * interval, from.hour, from.minute);
        }
        // Tìm ngày kế tiếp trong tuần hiện tại; nếu hết tuần thì nhảy sang tuần +interval
        for (var offset = 1; offset <= 7; offset++) {
          final cand = DateTime(from.year, from.month, from.day + offset, from.hour, from.minute);
          if (cand.weekday > from.weekday && byDay.contains(cand.weekday)) return cand;
          if (cand.weekday <= from.weekday) {
            // Đã bước sang tuần mới -> nhảy thêm (interval - 1) tuần
            final jump = cand.add(Duration(days: 7 * (interval - 1)));
            for (var d = 0; d < 7; d++) {
              final next = jump.add(Duration(days: d));
              if (byDay.contains(next.weekday)) return next;
            }
          }
        }
        return DateTime(from.year, from.month, from.day + 7 * interval, from.hour, from.minute);
      case 'MONTHLY':
        final targetMonth = from.month + interval;
        final year = from.year + (targetMonth - 1) ~/ 12;
        final month = ((targetMonth - 1) % 12) + 1;
        final lastDay = DateTime(year, month + 1, 0).day;
        return DateTime(year, month, min(from.day, lastDay), from.hour, from.minute);
      case 'YEARLY':
        final year = from.year + interval;
        final lastDay = DateTime(year, from.month + 1, 0).day;
        return DateTime(year, from.month, min(from.day, lastDay), from.hour, from.minute);
      default:
        return DateTime(from.year, from.month + 1, from.day, from.hour, from.minute);
    }
  }
}

/// Tự động sinh các giao dịch định kỳ đã đến hạn; trả về số giao dịch vừa tạo.
/// Dùng UUID v5 tất định theo `(rule.id, ngày đến hạn)` nên an toàn tuyệt đối khi chạy nhiều lần hoặc nhiều thiết bị.
int runDueRecurringRules(LocalStore store, {DateTime? now}) {
  final current = now ?? DateTime.now();
  const uuid = Uuid();
  var created = 0;

  final accs = {for (final a in store.all(E.accounts)) a['id'] as String: a};
  final cats = {for (final c in store.all(E.categories)) c['id'] as String: c};

  for (final raw in store.all(E.recurringRules)) {
    final rule = RecurringRule(raw);
    if (!rule.isActive || rule.rrule.isEmpty) continue;

    var due = rule.nextRunAt.toLocal();
    if (due.isAfter(current)) continue;

    final tpl = rule.template;
    final txType = rule.type;
    final amount = rule.amount;
    final accountId = rule.accountId;
    if (amount <= 0 || accountId == null || !accs.containsKey(accountId)) continue;

    final acc = accs[accountId]!;
    final cat = rule.categoryId != null ? cats[rule.categoryId] : null;
    var guard = 0;

    while (!due.isAfter(current) && guard++ < 60) {
      final txId = uuid.v5(Namespace.oid.value, 'recurring:${rule.id}:${Fmt.isoDate(due)}');
      if (store.get(E.transactions, txId) == null) {
        store.put(E.transactions, {
          'id': txId,
          'type': txType,
          'amount': amount,
          'currencyCode': tpl['currencyCode'] ?? acc['currencyCode'] ?? 'VND',
          'accountId': accountId,
          if (txType == TxType.transfer && tpl['toAccountId'] != null) 'toAccountId': tpl['toAccountId'],
          if (txType != TxType.transfer && rule.categoryId != null) 'categoryId': rule.categoryId,
          if (cat != null) 'categoryName': cat['name'],
          'accountName': acc['name'],
          'occurredAt': toIso8601WithOffset(due),
          'note': (rule.note?.isNotEmpty == true) ? rule.note : rule.name,
          'recurringRuleId': rule.id,
        }, notify: false);
        created++;
      }
      due = Recurrence.nextOccurrence(rule.rrule, due);
    }

    store.put(E.recurringRules, {...raw, 'nextRunAt': toIso8601WithOffset(due)}, notify: false);
  }

  if (created > 0) {
    // Thông báo thay đổi sau khi sinh hàng loạt
    store.notifyListeners();
  }
  return created;
}

// ============================================================ Ngày yêu

class Love {
  static int days(DateTime start) => dateOnly(DateTime.now()).difference(dateOnly(start)).inDays + 1;

  static (int y, int m, int d) ymd(DateTime start) {
    final now = dateOnly(DateTime.now());
    var y = now.year - start.year, m = now.month - start.month, d = now.day - start.day;
    if (d < 0) {
      m -= 1;
      d += DateTime(now.year, now.month, 0).day;
    }
    if (m < 0) {
      y -= 1;
      m += 12;
    }
    return (y, m, d);
  }

  /// Các mốc sắp tới: 100, 200... ngày, 365×n, 1000 ngày, kỷ niệm năm.
  static List<({String label, DateTime date, int daysLeft})> milestones(DateTime start, {int count = 4}) {
    final today = dateOnly(DateTime.now());
    final cur = days(start);
    final list = <({String label, DateTime date, int daysLeft})>[];
    final marks = <int>{for (var i = 1; i <= 100; i++) i * 100};
    for (final n in marks.where((n) => n >= cur).take(6)) {
      final date = dateOnly(start).add(Duration(days: n - 1));
      list.add((label: '$n ngày', date: date, daysLeft: date.difference(today).inDays));
    }
    for (var y = 1; y <= 60; y++) {
      final date = DateTime(start.year + y, start.month, start.day);
      if (!date.isBefore(today)) {
        list.add((label: 'Kỷ niệm $y năm', date: date, daysLeft: date.difference(today).inDays));
        if (list.where((x) => x.label.startsWith('Kỷ niệm')).length >= 2) break;
      }
    }
    list.sort((a, b) => a.date.compareTo(b.date));
    return list.take(count).toList();
  }

  static DateTime? nextBirthday(DateTime? bd) {
    if (bd == null) return null;
    final today = dateOnly(DateTime.now());
    var d = DateTime(today.year, bd.month, bd.day);
    if (d.isBefore(today)) d = DateTime(today.year + 1, bd.month, bd.day);
    return d;
  }
}

/// Tính các lần nhắc của [Reminder].
class Reminders {
  /// Các thời điểm nhắc trong [from, to), tăng dần.
  static List<DateTime> occurrences(Reminder r, DateTime from, DateTime to) {
    final times = r.times;
    if (!r.isActive || times.isEmpty || !to.isAfter(from)) return const [];
    final out = <DateTime>[];
    void addDay(DateTime d) {
      for (final t in times) {
        final at = DateTime(d.year, d.month, d.day, t.$1, t.$2);
        if (!at.isBefore(from) && at.isBefore(to)) out.add(at);
      }
    }

    if (r.repeatMode == ReminderRepeat.dates) {
      for (final s in r.dates) {
        final d = DateTime.tryParse(s);
        if (d != null) addDay(d);
      }
      return out..sort();
    }
    final days = r.repeatMode == ReminderRepeat.weekdays ? r.weekdays : null;
    if (days != null && days.isEmpty) return const [];
    for (var d = dateOnly(from); d.isBefore(to); d = DateTime(d.year, d.month, d.day + 1)) {
      if (days == null || days.contains(d.weekday)) addDay(d);
    }
    return out;
  }

  /// Lần nhắc kế tiếp (tìm trong 1 năm tới), null nếu không còn.
  static DateTime? next(Reminder r, DateTime now) {
    if (r.repeatMode == ReminderRepeat.dates) return occurrences(r, now, DateTime(now.year + 5)).firstOrNull;
    return occurrences(r, now, now.add(const Duration(days: 8))).firstOrNull;
  }

  /// "Hằng ngày" / "Thứ 2 – Thứ 6" / "T3, T5, CN" / "25/11, 28/11 +2 ngày"
  static String describe(Reminder r) {
    switch (r.repeatMode) {
      case ReminderRepeat.weekdays:
        final d = r.weekdays.toList()..sort();
        if (d.length == 7) return 'Hằng ngày';
        if (d.isEmpty) return 'Chưa chọn thứ';
        if (d.length == 5 && d.last == 5) return 'Thứ 2 – Thứ 6';
        if (d.length == 2 && d.first == 6) return 'Cuối tuần';
        return d.map((x) => Fmt.weekdaysShort[x - 1]).join(', ');
      case ReminderRepeat.dates:
        final ds = r.dates.map(DateTime.tryParse).whereType<DateTime>().toList();
        if (ds.isEmpty) return 'Chưa chọn ngày';
        final shown = ds.take(3).map(Fmt.dateShort).join(', ');
        return ds.length > 3 ? '$shown +${ds.length - 3} ngày' : shown;
      default:
        return 'Hằng ngày';
    }
  }
}
