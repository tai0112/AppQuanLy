import 'local_store.dart';

/// Dữ liệu mặc định lần đầu mở app (chạy offline, chưa cần tài khoản).
void seedDefaults(LocalStore store) {
  if (store.meta('seeded') == '1') return;
  final keys = <String>[];

  void add(String entity, Map<String, dynamic> data) {
    final r = store.put(entity, data, notify: false);
    keys.add('$entity|${r['id']}');
  }

  add(E.appSettings, {'theme': 'system', 'baseCurrencyCode': 'VND', 'financeMonthStartDay': 1, 'firstDayOfWeek': 1});

  add(E.currencies, {'code': 'VND', 'name': 'Việt Nam Đồng', 'symbol': '₫', 'decimals': 0, 'symbolPosition': 1, 'isBase': true});
  add(E.currencies, {'code': 'USD', 'name': 'Đô la Mỹ', 'symbol': r'$', 'decimals': 2, 'symbolPosition': 2, 'isBase': false});
  add(E.exchangeRates, {'fromCode': 'USD', 'toCode': 'VND', 'rate': 25000, 'effectiveDate': '2026-01-01'});

  add(E.accounts, {
    'name': 'Tiền mặt',
    'type': 1,
    'icon': 'payments',
    'color': '#30A46C',
    'currencyCode': 'VND',
    'openingBalance': 0,
    'includeInTotal': true,
    'sortOrder': 1,
  });
  add(E.accounts, {
    'name': 'Ngân hàng',
    'type': 2,
    'icon': 'account_balance',
    'color': '#3E63DD',
    'currencyCode': 'VND',
    'openingBalance': 0,
    'includeInTotal': true,
    'sortOrder': 2,
  });

  var order = 0;
  void cat(int type, String name, String icon, String color, [List<(String, String)> children = const []]) {
    final parent = store.put(E.categories, {'name': name, 'type': type, 'icon': icon, 'color': color, 'sortOrder': order++}, notify: false);
    keys.add('${E.categories}|${parent['id']}');
    for (final (n, i) in children) {
      add(E.categories, {'name': n, 'type': type, 'icon': i, 'color': color, 'parentId': parent['id'], 'sortOrder': order++});
    }
  }

  cat(1, 'Ăn uống', 'restaurant', '#F76B15', [
    ('Ăn sáng', 'local_cafe'),
    ('Ăn trưa', 'restaurant'),
    ('Cà phê', 'local_cafe'),
    ('Đi chợ', 'local_grocery_store'),
  ]);
  cat(1, 'Đi lại', 'two_wheeler', '#0090FF', [('Xăng xe', 'local_gas_station'), ('Gửi xe', 'two_wheeler'), ('Taxi/Grab', 'directions_car')]);
  cat(1, 'Nhà cửa', 'home', '#12A594', [('Tiền nhà', 'house'), ('Điện', 'bolt'), ('Nước', 'water_drop'), ('Internet', 'wifi')]);
  cat(1, 'Mua sắm', 'shopping_bag', '#8E4EC6', [('Quần áo', 'checkroom'), ('Đồ gia dụng', 'build')]);
  cat(1, 'Giải trí', 'movie', '#E5484D', [('Phim ảnh', 'movie'), ('Du lịch', 'flight')]);
  cat(1, 'Hẹn hò', 'favorite', '#E93D82', [('Quà tặng', 'card_giftcard')]);
  cat(1, 'Sức khoẻ', 'local_hospital', '#30A46C', [('Thuốc', 'medication'), ('Thể thao', 'fitness_center')]);
  cat(1, 'Học tập', 'school', '#6E56CF');
  cat(1, 'Khác', 'more_horiz', '#8D8D86');
  cat(2, 'Lương', 'payments', '#30A46C');
  cat(2, 'Thưởng', 'redeem', '#12A594');
  cat(2, 'Bán đồ', 'sell', '#F76B15');
  cat(2, 'Được tặng', 'card_giftcard', '#E93D82');
  cat(2, 'Thu khác', 'trending_up', '#3E63DD');

  // Bảng giá điện sinh hoạt (mặc định, người dùng tự sửa khi EVN đổi giá).
  final table = store.put(E.priceTables, {'name': 'Điện sinh hoạt', 'vatPercent': 8, 'fixedFee': 0, 'isDefault': true}, notify: false);
  keys.add('${E.priceTables}|${table['id']}');
  const tiers = [(0, 50, 1984), (51, 100, 2050), (101, 200, 2380), (201, 300, 2998), (301, 400, 3350), (401, null, 3460)];
  for (var i = 0; i < tiers.length; i++) {
    add(E.tiers, {'priceTableId': table['id'], 'tierOrder': i + 1, 'fromKwh': tiers[i].$1, 'toKwh': tiers[i].$2, 'price': tiers[i].$3});
  }

  keys.addAll(ensureEventCategories(store));
  keys.addAll(ensureActivityTemplates(store));

  add(E.cycleSettings, {
    'subject': 1,
    'defaultCycleDays': 28,
    'defaultPeriodDays': 5,
    'lutealDays': 14,
    'fertileDaysBefore': 5,
    'fertileDaysAfter': 1,
    'syncEnabled': false,
  });

  store.markSeed(keys);
  store.setMeta('seeded', '1');
  store.notifyRemoteApplied();
}

/// Danh mục lịch trình mặc định (loại 3). Chạy cho cả người dùng cũ chưa có danh mục lịch trình.
/// Trả về khoá các bản ghi vừa tạo.
List<String> ensureEventCategories(LocalStore store) {
  if (store.all(E.categories).any((c) => c['type'] == 3)) return [];
  const defaults = [
    ('Đi chơi', 'beach_access', '#0090FF'),
    ('Công việc', 'work', '#3E63DD'),
    ('Hẹn hò', 'favorite', '#E93D82'),
    ('Gia đình', 'home', '#12A594'),
    ('Học tập', 'school', '#6E56CF'),
    ('Sức khoẻ', 'fitness_center', '#30A46C'),
    ('Du lịch', 'flight', '#F76B15'),
    ('Khác', 'event', '#8D8D86'),
  ];
  final keys = <String>[];
  for (final (i, (name, icon, color)) in defaults.indexed) {
    final r = store.put(E.categories, {'name': name, 'type': 3, 'icon': icon, 'color': color, 'sortOrder': 1000 + i}, notify: false);
    keys.add('${E.categories}|${r['id']}');
  }
  store.notifyRemoteApplied();
  return keys;
}

/// Mẫu hoạt động trong ngày (loại 4) — hiện thành nút chọn nhanh khi thêm hoạt động theo giờ. Người dùng tự thêm/sửa/xoá.
List<String> ensureActivityTemplates(LocalStore store) {
  if (store.all(E.categories).any((c) => c['type'] == 4)) return [];
  const defaults = [
    ('Ăn sáng', 'local_cafe', '#F76B15'),
    ('Di chuyển', 'directions_car', '#0090FF'),
    ('Tham quan', 'camera', '#12A594'),
    ('Ăn trưa', 'restaurant', '#F76B15'),
    ('Nghỉ ngơi', 'spa', '#8E4EC6'),
    ('Cà phê', 'local_cafe', '#AD7F58'),
    ('Mua sắm', 'shopping_bag', '#E93D82'),
    ('Ăn tối', 'restaurant', '#E5484D'),
    ('Check-in', 'hotel', '#3E63DD'),
    ('Họp', 'work', '#3E63DD'),
    ('Tập thể dục', 'fitness_center', '#30A46C'),
  ];
  final keys = <String>[];
  for (final (i, (name, icon, color)) in defaults.indexed) {
    final r = store.put(E.categories, {'name': name, 'type': 4, 'icon': icon, 'color': color, 'sortOrder': 2000 + i}, notify: false);
    keys.add('${E.categories}|${r['id']}');
  }
  store.notifyRemoteApplied();
  return keys;
}
