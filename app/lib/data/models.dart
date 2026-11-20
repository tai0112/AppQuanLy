import 'dart:convert';

// Mô hình dữ liệu dạng "extension type" bọc Map JSON: không tốn chi phí, dễ đồng bộ nguyên bản với server.
// Enum lưu số nguyên giống server (LHT.Domain.Enums).

// Bộ đệm đọc ngày giờ: cùng một chuỗi ISO chỉ parse 1 lần cho cả app (DateTime bất biến nên dùng chung an toàn).
// Màn Lịch trình / Giao dịch đọc lại ngày giờ rất nhiều lần mỗi khung hình → tiết kiệm đáng kể.
final _dtCache = <String, DateTime>{};
final _dCache = <String, DateTime>{};

DateTime? _cached(Map<String, DateTime> cache, String s, DateTime? Function(String) parse) {
  final hit = cache[s];
  if (hit != null) return hit;
  final p = parse(s);
  if (p != null) {
    if (cache.length > 50000) cache.clear();
    cache[s] = p;
  }
  return p;
}

DateTime? _dt(Object? v) => v == null ? null : _cached(_dtCache, v as String, (s) => DateTime.tryParse(s)?.toLocal());
DateTime? _d(Object? v) => v == null ? null : _cached(_dCache, v as String, DateTime.tryParse);
double _num(Object? v) => v == null ? 0 : (v as num).toDouble();

class TxType {
  static const expense = 1, income = 2, transfer = 3;
}

class AccType {
  static const cash = 1, bank = 2, ewallet = 3, credit = 4, other = 99;
  static const names = {cash: 'Tiền mặt', bank: 'Ngân hàng', ewallet: 'Ví điện tử', credit: 'Thẻ tín dụng', other: 'Khác'};
  static const icons = {cash: 'payments', bank: 'account_balance', ewallet: 'phone_iphone', credit: 'credit_card', other: 'account_balance_wallet'};
}

extension type Currency(Map<String, dynamic> m) {
  String get id => m['id'];
  String get code => m['code'];
  String get name => m['name'] ?? code;
  String get symbol => m['symbol'] ?? code;
  int get decimals => (m['decimals'] as num?)?.toInt() ?? 0;
  bool get symbolBefore => m['symbolPosition'] == 2;
  bool get isBase => m['isBase'] == true;
}

extension type ExchangeRate(Map<String, dynamic> m) {
  String get from => m['fromCode'];
  String get to => m['toCode'];
  double get rate => _num(m['rate']);
  DateTime get effectiveDate => _d(m['effectiveDate']) ?? DateTime(2000);
}

extension type Account(Map<String, dynamic> m) {
  String get id => m['id'];
  String get name => m['name'] ?? '';
  int get type => (m['type'] as num?)?.toInt() ?? 1;
  String? get icon => m['icon'];
  String? get color => m['color'];
  String get currencyCode => m['currencyCode'] ?? 'VND';
  double get openingBalance => _num(m['openingBalance']);
  bool get includeInTotal => m['includeInTotal'] != false;
  int get sortOrder => (m['sortOrder'] as num?)?.toInt() ?? 0;
  bool get isArchived => m['isArchived'] == true;
}

extension type Category(Map<String, dynamic> m) {
  String get id => m['id'];
  String get name => m['name'] ?? '';
  int get type => (m['type'] as num?)?.toInt() ?? 1;
  String? get parentId => m['parentId'];
  String? get icon => m['icon'];
  String? get color => m['color'];
  int get sortOrder => (m['sortOrder'] as num?)?.toInt() ?? 0;
}

extension type Txn(Map<String, dynamic> m) {
  String get id => m['id'];
  int get type => (m['type'] as num?)?.toInt() ?? 1;
  double get amount => _num(m['amount']);
  String get currencyCode => m['currencyCode'] ?? 'VND';
  String get accountId => m['accountId'];
  String? get toAccountId => m['toAccountId'];
  double? get toAmount => m['toAmount'] == null ? null : _num(m['toAmount']);
  String? get categoryId => m['categoryId'];
  DateTime get occurredAt => _dt(m['occurredAt']) ?? DateTime.now();
  String? get note => m['note'];
  String? get eventId => m['eventId'];
  String? get jarId => m['jarId'];
}

extension type Attachment(Map<String, dynamic> m) {
  String get id => m['id'];
  int get ownerType => (m['ownerType'] as num?)?.toInt() ?? 1;
  String get ownerId => m['ownerId'];
  String get fileId => m['fileId'];
  int get sortOrder => (m['sortOrder'] as num?)?.toInt() ?? 0;
}

extension type Budget(Map<String, dynamic> m) {
  String get id => m['id'];
  String get name => m['name'] ?? '';
  int get scope => (m['scope'] as num?)?.toInt() ?? 1; // 1 tổng, 2 danh mục, 3 tài khoản
  String? get refId => m['refId'];
  int get period => (m['period'] as num?)?.toInt() ?? 3; // 1 ngày, 2 tuần, 3 tháng, 4 năm
  double get limit => _num(m['limitAmount']);
  String get currencyCode => m['currencyCode'] ?? 'VND';
  int get warnPercent => (m['warnPercent'] as num?)?.toInt() ?? 80;
  bool get isActive => m['isActive'] != false;
}

extension type Jar(Map<String, dynamic> m) {
  String get id => m['id'];
  String get name => m['name'] ?? '';
  String? get icon => m['icon'];
  String? get color => m['color'];
  double get target => _num(m['targetAmount']);
  String get currencyCode => m['currencyCode'] ?? 'VND';
  DateTime? get deadline => _d(m['deadline']);
  bool get isClosed => m['isClosed'] == true;
}

extension type JarTxn(Map<String, dynamic> m) {
  String get id => m['id'];
  String get jarId => m['jarId'];
  String? get accountId => m['accountId'];
  double get amount => _num(m['amount']);
  String? get note => m['note'];
  DateTime get occurredAt => _dt(m['occurredAt']) ?? DateTime.now();
}

extension type PriceTable(Map<String, dynamic> m) {
  String get id => m['id'];
  String get name => m['name'] ?? '';
  double get vat => _num(m['vatPercent']);
  double get fixedFee => _num(m['fixedFee']);
  bool get isDefault => m['isDefault'] == true;
}

extension type Tier(Map<String, dynamic> m) {
  String get id => m['id'];
  String get tableId => m['priceTableId'];
  int get order => (m['tierOrder'] as num?)?.toInt() ?? 0;
  int get from => (m['fromKwh'] as num?)?.toInt() ?? 0;
  int? get to => (m['toKwh'] as num?)?.toInt();
  double get price => _num(m['price']);
}

/// Công tơ điện của một tầng/phòng. kind: 1 = nhà dùng (khoản chi), 2 = cho thuê (khoản thu).
extension type Meter(Map<String, dynamic> m) {
  static const selfUse = 1, rented = 2;
  String get id => m['id'];
  String get name => m['name'] ?? '';
  int get kind => (m['kind'] as num?)?.toInt() ?? selfUse;
  bool get isRented => kind == rented;
  String? get tenantName => m['tenantName'];
  String get tableId => m['priceTableId'];
  int get initialIndex => (m['initialIndex'] as num?)?.toInt() ?? 0;
  String? get categoryId => m['categoryId'];
  String? get accountId => m['accountId'];
  int get sortOrder => (m['sortOrder'] as num?)?.toInt() ?? 0;
  bool get isArchived => m['isArchived'] == true;
  String? get note => m['note'];
}

extension type Bill(Map<String, dynamic> m) {
  String get id => m['id'];
  String? get meterId => m['meterId'];
  String get tableId => m['priceTableId'];
  DateTime get period => _d(m['period']) ?? DateTime.now();
  int? get oldIndex => (m['oldIndex'] as num?)?.toInt();
  int? get newIndex => (m['newIndex'] as num?)?.toInt();
  int get kwh => (m['kwh'] as num?)?.toInt() ?? 0;
  double get amount => _num(m['amount']);
  String? get transactionId => m['transactionId'];
}

extension type LoveCounter(Map<String, dynamic> m) {
  String get id => m['id'];
  DateTime get startDate => _d(m['startDate']) ?? DateTime.now();
  String get partnerName => m['partnerName'] ?? '';
  DateTime? get partnerBirthday => _d(m['partnerBirthday']);
  String? get myPhoto => m['myPhotoFileId'];
  String? get partnerPhoto => m['partnerPhotoFileId'];

  /// Tài khoản (trong bạn bè) của người ấy, nếu đã liên kết.
  String? get partnerUserId => m['partnerUserId'];
  int get reminderDays => (m['milestoneReminderDays'] as num?)?.toInt() ?? 3;
}

extension type CyclePeriod(Map<String, dynamic> m) {
  String get id => m['id'];
  int get subject => (m['subject'] as num?)?.toInt() ?? 1;
  DateTime get start => _d(m['startDate'])!;
  DateTime? get end => _d(m['endDate']);
  int? get flow => (m['flow'] as num?)?.toInt();
  String? get note => m['note'];
}

extension type CycleSettings(Map<String, dynamic> m) {
  String get id => m['id'];
  int get subject => (m['subject'] as num?)?.toInt() ?? 1;
  int get cycleDays => (m['defaultCycleDays'] as num?)?.toInt() ?? 28;
  int get periodDays => (m['defaultPeriodDays'] as num?)?.toInt() ?? 5;
  int get lutealDays => (m['lutealDays'] as num?)?.toInt() ?? 14;
  int get fertileBefore => (m['fertileDaysBefore'] as num?)?.toInt() ?? 5;
  int get fertileAfter => (m['fertileDaysAfter'] as num?)?.toInt() ?? 1;
  bool get syncEnabled => m['syncEnabled'] == true;

  Map<String, dynamic> get _rem {
    try {
      return (jsonDecode(m['remindersJson'] as String? ?? '{}') as Map).cast<String, dynamic>();
    } catch (_) {
      return {};
    }
  }

  /// Thông báo chu kỳ mỗi ngày (mặc định bật) lúc [remindHour]:[remindMinute].
  bool get dailyRemind => _rem['daily'] != false;
  int get remindHour => (_rem['hour'] as num?)?.toInt() ?? 8;
  int get remindMinute => (_rem['minute'] as num?)?.toInt() ?? 0;
}

extension type AppSettingsRec(Map<String, dynamic> m) {
  String get id => m['id'];
  String get theme => m['theme'] ?? 'system';
  String? get primaryColor => m['primaryColor'];
  String get baseCurrency => m['baseCurrencyCode'] ?? 'VND';
  int get monthStartDay => (m['financeMonthStartDay'] as num?)?.toInt() ?? 1;
  String? get menuLayoutJson => m['menuLayoutJson'];
  String? get defaultAccountId => m['defaultAccountId'];
  bool get rememberLastAccount => m['rememberLastAccount'] == true;
}

/// Nguồn tiền: tiền mặt hoặc tài khoản (ngân hàng / ví điện tử / thẻ / khác).
enum MoneySource { all, cash, account }

extension AccountSourceX on Account {
  bool get isCash => type == AccType.cash;
  bool matches(MoneySource s) => s == MoneySource.all || (s == MoneySource.cash) == isCash;
}

extension type EventRec(Map<String, dynamic> m) {
  String get id => m['id'];
  String get userId => m['userId'] ?? '';
  String get title => m['title'] ?? '';
  DateTime get startAt => _dt(m['startAt']) ?? DateTime.now();
  DateTime? get endAt => _dt(m['endAt']);
  bool get isAllDay => m['isAllDay'] == true;
  String? get location => m['location'];
  String? get note => m['note'];
  int get kind => (m['kind'] as num?)?.toInt() ?? 99; // cũ: 1 đi chơi, 2 công việc, 99 khác
  String? get categoryId => m['categoryId'];
  String? get color => m['color'];
  String? get rrule => m['rRule'];
  DateTime? get repeatUntil => _d(m['repeatUntil']);
  int? get remindBefore => (m['remindBeforeMinutes'] as num?)?.toInt();
  String? get coverFileId => m['coverFileId'];
  double? get estimatedCost => m['estimatedCost'] == null ? null : _num(m['estimatedCost']);
}

extension type EventPhoto(Map<String, dynamic> m) {
  String get id => m['id'];
  String get eventId => m['eventId'];
  DateTime? get occurrenceDate => _d(m['occurrenceDate']);
  String? get eventItemId => m['eventItemId'];
  String get fileId => m['fileId'];
  String? get caption => m['caption'];
}

extension type EventParticipant(Map<String, dynamic> m) {
  String get eventId => m['eventId'];
  String get userId => m['participantUserId'];
  int get status => (m['status'] as num?)?.toInt() ?? 1; // 1 mời, 2 đồng ý, 3 từ chối
  int get role => (m['role'] as num?)?.toInt() ?? 2;
}

/// Hoạt động theo giờ trong lịch trình (VD 07:00 Ăn sáng).
extension type EventItemRec(Map<String, dynamic> m) {
  String get id => m['id'];
  String get eventId => m['eventId'];
  String? get occurrenceDate => m['occurrenceDate'];
  String get title => m['title'] ?? '';
  String? get location => m['location'];
  String? get note => m['note'];
  String? get icon => m['icon'];
  double? get cost => m['cost'] == null ? null : _num(m['cost']);
  bool get isDone => m['isDone'] == true;

  /// "07:30:00" → (7, 30)
  (int, int) get start => parseTime(m['startTime'] as String?) ?? (0, 0);
  (int, int)? get end => parseTime(m['endTime'] as String?);
  int get startMinutes => start.$1 * 60 + start.$2;
}

(int, int)? parseTime(String? s) {
  if (s == null || !s.contains(':')) return null;
  final p = s.split(':');
  return (int.tryParse(p[0]) ?? 0, int.tryParse(p[1]) ?? 0);
}

String timeStr((int, int) t) => '${t.$1.toString().padLeft(2, '0')}:${t.$2.toString().padLeft(2, '0')}';
String timeIso((int, int) t) => '${timeStr(t)}:00';
