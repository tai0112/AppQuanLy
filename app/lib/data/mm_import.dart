import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:uuid/uuid.dart';

import 'local_store.dart';
import 'sqlite_reader.dart';

/// Nhập bản sao lưu của app "Money Manager" (.mmbackup) — đọc hoàn toàn trên máy.
/// Định dạng: vài byte đầu + zip { MyFinance.db (SQLite), photos/*.jpg, backup_meta }.
/// Số tiền trong file được lưu ×100. Liên kết giao dịch ↔ tài khoản / danh mục / ảnh nằm ở bảng sync_link.
class MmBackup {
  MmBackup._(this._zip, this.accounts, this.categories, this.transactions, this.transfers);

  final Archive _zip;
  final List<MmAccount> accounts;
  final List<MmCategory> categories;
  final List<MmTxn> transactions;
  final List<MmTransfer> transfers;

  int get photoLinks => transactions.fold(0, (s, t) => s + t.photos.length);
  int get photosAvailable => transactions.fold(0, (s, t) => s + t.photos.where(hasPhoto).length);
  bool hasPhoto(String path) => _entry(path) != null;
  Uint8List? photo(String path) => _entry(path)?.readBytes();
  ArchiveFile? _entry(String path) {
    final name = path.split('/').last;
    return _zip.findFile('photos/$name') ?? _zip.findFile(name);
  }

  (DateTime, DateTime)? get dateRange {
    final ds = [...transactions.map((t) => t.date), ...transfers.map((t) => t.date)].whereType<DateTime>().toList()..sort();
    return ds.isEmpty ? null : (ds.first, ds.last);
  }

  /// Đọc file. Ném [FormatException] nếu không đúng định dạng.
  static MmBackup parse(Uint8List bytes) {
    var start = -1;
    for (var i = 0; i + 3 < bytes.length && i < 64; i++) {
      if (bytes[i] == 0x50 && bytes[i + 1] == 0x4B && bytes[i + 2] == 0x03 && bytes[i + 3] == 0x04) {
        start = i;
        break;
      }
    }
    if (start < 0) throw const FormatException('Không phải file sao lưu Money Manager (.mmbackup)');
    final Archive zip;
    try {
      zip = ZipDecoder().decodeBytes(Uint8List.sublistView(bytes, start));
    } catch (_) {
      throw const FormatException('File sao lưu bị hỏng, không giải nén được');
    }
    final dbBytes = zip.findFile('MyFinance.db')?.readBytes();
    if (dbBytes == null) throw const FormatException('File sao lưu không có dữ liệu (thiếu MyFinance.db)');
    final db = SqliteReader(dbBytes);

    bool alive(Map<String, Object?> r) => (r['isRemoved'] as int? ?? 0) == 0;
    String? s(Object? v) => v?.toString();
    int n(Object? v) => v is int ? v : (v is double ? v.round() : int.tryParse('$v') ?? 0);

    // Liên kết: (loại, uid) → (loại khác → các uid), theo thứ tự sửa.
    final links = <String, Map<String, List<String>>>{};
    final linkRows = db.rows('sync_link').where(alive).toList()..sort((a, b) => (s(a['modified']) ?? '').compareTo(s(b['modified']) ?? ''));
    for (final r in linkRows) {
      ((links['${r['entityType']}|${r['entityUid']}'] ??= {})[s(r['otherType'])!] ??= []).add(s(r['otherUid'])!);
    }
    String? one(String type, String uid, String other) => links['$type|$uid']?[other]?.last;

    final files = {
      for (final r in db.rows('sync_file'))
        if (alive(r) && r['fileType'] == 'photo' && r['localPath'] != null) s(r['uid'])!: s(r['localPath'])!,
    };
    final balances = {for (final r in db.rows('account_balance')) s(r['uid'])!: n(r['value'])};

    final accounts = [
      for (final r in db.rows('account'))
        if (alive(r))
          MmAccount(
            uid: s(r['uid'])!,
            title: s(r['title']) ?? '',
            icon: s(r['icon']),
            color: r['color'] as int?,
            currency: s(r['currencyCode']) ?? 'VND',
            balance: balances[s(r['uid'])] ?? 0,
            archived: n(r['isArchived']) != 0,
            excluded: n(r['ignoreInBalance']) != 0,
            position: n(r['position']),
          ),
    ]..sort((a, b) => a.position.compareTo(b.position));

    final categories = [
      for (final r in db.rows('category'))
        if (alive(r))
          MmCategory(
            uid: s(r['uid'])!,
            title: s(r['title']) ?? '',
            income: r['type'] == 'Income',
            icon: s(r['icon']),
            color: r['color'] as int?,
            position: n(r['position']),
          ),
    ]..sort((a, b) => a.position.compareTo(b.position));

    final transactions = [
      for (final r in db.rows('transaction'))
        if (alive(r))
          MmTxn(
            uid: s(r['uid'])!,
            income: r['type'] == 'Income',
            amount: n(r['amountInAccountCurrency']).abs(),
            currency: s(r['accountCurrencyCode']),
            date: _date(s(r['date'])),
            created: DateTime.tryParse(s(r['created']) ?? ''),
            note: s(r['comment']),
            accountUid: one('Transaction', s(r['uid'])!, 'Account'),
            categoryUid: one('Transaction', s(r['uid'])!, 'Category'),
            photos: {...?links['Transaction|${r['uid']}']?['Photo']?.map((p) => files[p]).whereType<String>()}.toList(),
          ),
    ];

    final transfers = [
      for (final r in db.rows('transfer'))
        if (alive(r))
          MmTransfer(
            uid: s(r['uid'])!,
            fromAmount: n(r['fromAmount']).abs(),
            toAmount: r['toAmount'] == null ? null : n(r['toAmount']).abs(),
            currency: s(r['fromCurrencyCode']),
            date: _date(s(r['date'])),
            created: DateTime.tryParse(s(r['created']) ?? ''),
            note: s(r['comment']),
            fromUid: one('Transfer', s(r['uid'])!, 'FromAccount'),
            toUid: one('Transfer', s(r['uid'])!, 'ToAccount'),
          ),
    ];

    return MmBackup._(zip, accounts, categories, transactions, transfers);
  }

  static DateTime? _date(String? ymd) {
    final p = ymd?.split('-');
    if (p == null || p.length != 3) return null;
    final y = int.tryParse(p[0]), m = int.tryParse(p[1]), d = int.tryParse(p[2]);
    return y == null || m == null || d == null ? null : DateTime(y, m, d);
  }
}

class MmAccount {
  MmAccount({
    required this.uid,
    required this.title,
    this.icon,
    this.color,
    required this.currency,
    required this.balance,
    required this.archived,
    required this.excluded,
    required this.position,
  });
  final String uid, title, currency;
  final String? icon;
  final int? color;
  final int balance, position;
  final bool archived, excluded;
}

class MmCategory {
  MmCategory({required this.uid, required this.title, required this.income, this.icon, this.color, required this.position});
  final String uid, title;
  final bool income;
  final String? icon;
  final int? color;
  final int position;
}

class MmTxn {
  MmTxn({
    required this.uid,
    required this.income,
    required this.amount,
    this.currency,
    this.date,
    this.created,
    this.note,
    this.accountUid,
    this.categoryUid,
    required this.photos,
  });
  final String uid;
  final bool income;
  final int amount;
  final String? currency, note, accountUid, categoryUid;
  final DateTime? date, created;
  final List<String> photos;
}

class MmTransfer {
  MmTransfer({required this.uid, required this.fromAmount, this.toAmount, this.currency, this.date, this.created, this.note, this.fromUid, this.toUid});
  final String uid;
  final int fromAmount;
  final int? toAmount;
  final String? currency, note, fromUid, toUid;
  final DateTime? date, created;
}

class MmImportResult {
  int accountsCreated = 0, accountsMatched = 0, categoriesCreated = 0, categoriesMatched = 0;
  int transactions = 0, transfers = 0, skipped = 0, photos = 0, photosMissing = 0;
}

/// Ghi dữ liệu đã đọc vào kho trên máy.
/// [localOnly] = chỉ lưu trên máy (không đẩy lên server cho tới khi người dùng đồng ý); ngược lại xếp hàng đồng bộ như dữ liệu thường.
/// Id sinh cố định theo uid gốc → nhập lại cùng file không tạo bản trùng. Tài khoản / danh mục trùng tên được dùng chung.
Future<MmImportResult> importMoneyManager(LocalStore store, MmBackup b, {required bool localOnly, void Function(int done, int total)? onPhoto}) async {
  final res = MmImportResult();
  var ns = store.meta('mmImportNs');
  if (ns == null) store.setMeta('mmImportNs', ns = const Uuid().v4());
  String sid(String kind, String uid) => const Uuid().v5(ns!, '$kind|$uid');
  Map<String, dynamic> put(String entity, Map<String, dynamic> data) => store.put(entity, data, notify: false, localOnly: localOnly);

  // ---------------- Tài khoản
  final myAccounts = store.all(E.accounts);
  final accIds = <String, String>{};
  final accCurrency = <String, String>{};
  final newAccounts = <MmAccount, String>{};
  for (final a in b.accounts) {
    final id = sid('account', a.uid);
    final hit = store.get(E.accounts, id) ?? myAccounts.where((x) => _fold('${x['name']}') == _fold(a.title)).firstOrNull;
    if (hit != null) {
      res.accountsMatched++;
      accIds[a.uid] = hit['id'] as String;
      accCurrency[a.uid] = (hit['currencyCode'] as String?) ?? a.currency;
      continue;
    }
    put(E.accounts, {
      'id': id,
      'name': a.title.trim().isEmpty ? 'Tài khoản Money Manager' : a.title.trim(),
      'type': switch (a.icon) {
        'online_wallet' || 'wallet' => 3,
        'cash' => 1,
        'cards' => 2,
        _ => 99,
      },
      'icon': _icons[a.icon] ?? 'account_balance_wallet',
      'color': _hex(a.color),
      'currencyCode': a.currency,
      'openingBalance': 0,
      'includeInTotal': !a.excluded,
      'isArchived': a.archived,
      'sortOrder': myAccounts.length + res.accountsCreated + 1,
    });
    accIds[a.uid] = id;
    accCurrency[a.uid] = a.currency;
    newAccounts[a] = id;
    res.accountsCreated++;
  }

  // ---------------- Danh mục
  final myCats = store.all(E.categories).where((c) => c['type'] == 1 || c['type'] == 2).toList();
  final catIds = <String, String>{};
  var order = myCats.fold<int>(0, (m, c) => ((c['sortOrder'] as num?)?.toInt() ?? 0) > m ? (c['sortOrder'] as num).toInt() : m) + 1;
  for (final c in b.categories) {
    final type = c.income ? 2 : 1;
    final def = _defaults[c.uid];
    final name = c.title.trim().isNotEmpty ? c.title.trim() : def?.$1 ?? 'Danh mục Money Manager';
    final id = sid('category', c.uid);
    final hit =
        store.get(E.categories, id) ??
        (myCats.where((x) => x['type'] == type && _fold('${x['name']}') == _fold(name)).toList()
              ..sort((x, y) => (x['parentId'] == null ? 0 : 1).compareTo(y['parentId'] == null ? 0 : 1)))
            .firstOrNull;
    if (hit != null) {
      res.categoriesMatched++;
      catIds[c.uid] = hit['id'] as String;
      continue;
    }
    final rec = put(E.categories, {
      'id': id,
      'name': name,
      'type': type,
      'icon': def?.$2 ?? _icons[c.icon] ?? 'category',
      'color': _hex(c.color),
      'sortOrder': order++,
    });
    myCats.add(rec);
    catIds[c.uid] = id;
    res.categoriesCreated++;
  }

  final fallbackAcc = accIds.values.firstOrNull ?? (myAccounts.firstOrNull?['id'] as String?);
  final net = <String, double>{};

  // ---------------- Giao dịch + ảnh
  final totalPhotos = b.photoLinks;
  var donePhotos = 0;
  for (final t in b.transactions) {
    final id = sid('tx', t.uid);
    final acc = (t.accountUid == null ? null : accIds[t.accountUid]) ?? fallbackAcc;
    if (store.exists(E.transactions, id) || acc == null || t.amount == 0) {
      res.skipped++;
      donePhotos += t.photos.length;
      continue;
    }
    final amount = t.amount / 100;
    put(E.transactions, {
      'id': id,
      'type': t.income ? 2 : 1,
      'amount': amount,
      'currencyCode': t.currency ?? accCurrency[t.accountUid] ?? 'VND',
      'accountId': acc,
      'toAccountId': null,
      'toAmount': null,
      'categoryId': t.categoryUid == null ? null : catIds[t.categoryUid],
      'occurredAt': _when(t.date, t.created).toUtc().toIso8601String(),
      'note': (t.note ?? '').trim().isEmpty ? null : t.note!.trim(),
    });
    net[acc] = (net[acc] ?? 0) + (t.income ? amount : -amount);
    res.transactions++;

    for (final (i, path) in t.photos.indexed) {
      onPhoto?.call(++donePhotos, totalPhotos);
      final fileId = sid('photo', path);
      if (!store.hasLocalFile(fileId)) {
        final bytes = b.photo(path);
        if (bytes == null) {
          res.photosMissing++;
          continue;
        }
        await store.saveLocalFile(fileId, bytes, path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg');
      }
      if (!localOnly) store.queueUpload(fileId);
      put(E.attachments, {'id': sid('attachment', '${t.uid}|$path'), 'ownerType': 1, 'ownerId': id, 'fileId': fileId, 'sortOrder': i});
      res.photos++;
    }
  }

  // ---------------- Chuyển khoản
  for (final t in b.transfers) {
    final id = sid('transfer', t.uid);
    final from = t.fromUid == null ? null : accIds[t.fromUid];
    final to = t.toUid == null ? null : accIds[t.toUid];
    if (store.exists(E.transactions, id) || from == null || to == null || from == to || t.fromAmount == 0) {
      res.skipped++;
      continue;
    }
    final amount = t.fromAmount / 100;
    final toAmount = t.toAmount != null && t.toAmount != t.fromAmount ? t.toAmount! / 100 : null;
    put(E.transactions, {
      'id': id,
      'type': 3,
      'amount': amount,
      'currencyCode': t.currency ?? accCurrency[t.fromUid] ?? 'VND',
      'accountId': from,
      'toAccountId': to,
      'toAmount': toAmount,
      'categoryId': null,
      'occurredAt': _when(t.date, t.created).toUtc().toIso8601String(),
      'note': (t.note ?? '').trim().isEmpty ? null : t.note!.trim(),
    });
    net[from] = (net[from] ?? 0) - amount;
    net[to] = (net[to] ?? 0) + (toAmount ?? amount);
    res.transfers++;
  }

  // Tài khoản mới: số dư ban đầu sao cho số dư hiện tại khớp Money Manager.
  for (final MapEntry(key: a, value: id) in newAccounts.entries) {
    put(E.accounts, {'id': id, 'openingBalance': a.balance / 100 - (net[id] ?? 0)});
  }

  store.commit();
  return res;
}

/// Ngày giao dịch + giờ lúc tạo nếu cùng ngày (giờ máy), ngược lại 12:00.
DateTime _when(DateTime? date, DateTime? created) {
  final c = created?.toLocal();
  if (date == null) return c ?? DateTime.now();
  if (c != null && c.year == date.year && c.month == date.month && c.day == date.day) return c;
  return DateTime(date.year, date.month, date.day, 12);
}

String? _hex(int? argb) => argb == null ? null : '#${(argb % 0x1000000).toRadixString(16).padLeft(6, '0').toUpperCase()}';

String _fold(String s) {
  const from = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
  const to = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
  final b = StringBuffer();
  for (final ch in s.trim().toLowerCase().split('')) {
    final i = from.indexOf(ch);
    b.write(i < 0 ? ch : to[i]);
  }
  return b.toString();
}

/// Danh mục mặc định của Money Manager (tên gốc thường để trống) → tên tiếng Việt + icon của app.
const _defaults = <String, (String, String)>{
  'DefaultHome': ('Nhà cửa', 'home'),
  'DefaultPercents': ('Lãi tiết kiệm', 'savings'),
  'DefaultEducation': ('Học tập', 'school'),
  'DefaultSport': ('Thể thao', 'fitness_center'),
  'DefaultHealth': ('Sức khoẻ', 'local_hospital'),
  'DefaultSalary': ('Lương', 'payments'),
  'DefaultLeisure': ('Giải trí', 'movie'),
  'DefaultPresent': ('Được tặng', 'card_giftcard'),
  'DefaultCafe': ('Cà phê', 'local_cafe'),
  'DefaultPresents': ('Quà tặng', 'card_giftcard'),
  'DefaultProducts': ('Đi chợ', 'local_grocery_store'),
  'DefaultFamily': ('Gia đình', 'child_care'),
  'DefaultTransport': ('Đi lại', 'two_wheeler'),
  'other_income': ('Thu khác', 'trending_up'),
  'other_expense': ('Khác', 'more_horiz'),
};

/// Icon Money Manager → icon của app.
const _icons = <String?, String>{
  'home': 'home',
  'bank': 'account_balance',
  'education': 'school',
  'sport': 'fitness_center',
  'heart': 'local_hospital',
  'prepaid': 'payments',
  'purse': 'movie',
  'present': 'card_giftcard',
  'cafe': 'restaurant',
  'products': 'local_grocery_store',
  'family': 'child_care',
  'transport': 'two_wheeler',
  'other': 'more_horiz',
  'return': 'redeem',
  'cards': 'credit_card',
  'online_wallet': 'account_balance_wallet',
  'cash': 'payments',
  'wallet': 'account_balance_wallet',
};
