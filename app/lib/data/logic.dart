import 'dart:math';

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

  /// Giao dịch có ảnh đính kèm (tra O(1) cho từng dòng).
  late final Set<String> _withPhotos = _m('withPhotos', [E.attachments], () => store.all(E.attachments).map((a) => a['ownerId'] as String).toSet());
  bool hasPhoto(String txnId) => _withPhotos.contains(txnId);

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

  List<Txn> inRange(DateTime from, DateTime to) => _rangeCache.putIfAbsent('${from.millisecondsSinceEpoch}-${to.millisecondsSinceEpoch}', () {
    final out = <Txn>[];
    for (final t in transactions) {
      final w = at(t);
      if (w.isBefore(from)) break; // danh sách đã sắp mới → cũ: qua mốc là dừng
      if (w.isBefore(to)) out.add(t);
    }
    return out;
  });

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
}

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
    final ovulation = next.subtract(Duration(days: s?.lutealDays ?? 14));

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
      fertileStart: ovulation.subtract(Duration(days: s?.fertileBefore ?? 5)),
      fertileEnd: ovulation.add(Duration(days: s?.fertileAfter ?? 1)),
      cycles: all,
      calendarFertile: calendar,
      standardDays: sdm,
      warnings: warnings,
    );
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
    final before = s?.fertileBefore ?? 5, after = s?.fertileAfter ?? 1;
    final who = partner ? 'người ấy' : 'bạn';
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
        partner
            ? 'Có thể dễ cáu, mệt hoặc đau ngực. Lắng nghe và thông cảm nhiều hơn.'
            : 'Có thể đau ngực, đầy hơi, dễ cáu. Ngủ đủ, giảm muối và caffeine, vận động nhẹ.',
        0,
      );
    }
    if (d.isBefore(ovu)) {
      return CycleDay(
        d,
        CyclePhase.follicular,
        cycleDay,
        'Ngày $cycleDay của chu kỳ · nang noãn',
        partner
            ? 'Giai đoạn người ấy thường nhiều năng lượng, vui vẻ: hợp để đi chơi cùng nhau.'
            : 'Năng lượng thường tăng dần: thời điểm tốt để tập luyện và làm việc lớn.',
        0,
      );
    }
    return CycleDay(
      d,
      CyclePhase.luteal,
      cycleDay,
      'Ngày $cycleDay của chu kỳ · hoàng thể',
      'Còn $until ngày đến kỳ kinh tiếp theo (${Fmt.dateShort(nextStart)}).',
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
