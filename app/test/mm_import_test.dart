// Nhập file sao lưu Money Manager: đọc trên máy, "chỉ lưu trên máy" không bao giờ gửi lên server cho tới khi người dùng đồng ý.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:lht_money/data/api.dart';
import 'package:lht_money/data/local_store.dart';
import 'package:lht_money/data/mm_import.dart';
import 'package:lht_money/data/sync.dart';

/// File sao lưu thật đặt ở thư mục gốc dự án (không đưa vào git). Không có thì bỏ qua test.
final _backup = File('../MoneyManager_20261123T083204.mmbackup');

class _Api extends ApiClient {
  _Api(super.store);
  final pushed = <String, int>{}; // bảng → số bản ghi đã đẩy
  final uploaded = <String>{};

  @override
  bool get isLoggedIn => true;

  @override
  Future<Map<String, dynamic>> upload(String id, Uint8List bytes, String mime, String name) async {
    uploaded.add(id);
    return {'id': id};
  }

  @override
  Future<({Uint8List bytes, String mime})?> download(String fileId) async => null;

  @override
  Future<T> get<T>(String path, {Map<String, dynamic>? query}) async =>
      {'changes': <String, dynamic>{}, 'serverTime': DateTime.now().toUtc().toIso8601String()} as T;

  @override
  Future<T> post<T>(String path, [Object? body]) async {
    final ids = <String>[];
    if (body is Map && body['changes'] is List) {
      for (final c in body['changes'] as List) {
        pushed[c['entity'] as String] = (pushed[c['entity'] as String] ?? 0) + 1;
        ids.add(c['data']['id'] as String);
      }
    }
    return {'accepted': ids, 'rejected': <Map<String, dynamic>>[]} as T;
  }
}

double _balance(LocalStore s, String accountId) {
  final acc = s.get(E.accounts, accountId)!;
  var b = (acc['openingBalance'] as num).toDouble();
  for (final t in s.all(E.transactions)) {
    final amt = (t['amount'] as num).toDouble();
    if (t['accountId'] == accountId) b += t['type'] == 2 ? amt : -amt;
    if (t['toAccountId'] == accountId) b += ((t['toAmount'] ?? t['amount']) as num).toDouble();
  }
  return b;
}

void main() {
  late Directory dir;
  late LocalStore store;
  late _Api api;
  late SyncEngine sync;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('lht_mm');
    Hive.init(dir.path);
    store = LocalStore();
    await store.initForTest(filesDir: '${dir.path}/files');
    api = _Api(store);
    sync = SyncEngine(store, api);
  });

  tearDown(() async {
    sync.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 500)); // Hive còn ghi/dọn tệp sau loạt xoá cờ đồng bộ
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test('đọc file: đủ tài khoản, danh mục, giao dịch, ảnh; số tiền lớn không bị sai', () {
    final b = MmBackup.parse(_backup.readAsBytesSync());
    expect(b.accounts.map((a) => a.title), ['TPBank', 'Momo']);
    expect(b.categories, hasLength(16));
    expect(b.transactions, hasLength(230));
    expect(b.transfers.single.fromAmount, 2800000000, reason: 'số > 2^31 phải đọc đúng');
    expect(b.accounts.firstWhere((a) => a.title == 'Momo').balance, 2788800000);
    expect(b.photosAvailable, 121);
    expect(b.photo(b.transactions.expand((t) => t.photos).firstWhere(b.hasPhoto))!.length, greaterThan(1000));
  }, skip: !_backup.existsSync());

  test('chỉ lưu trên máy: không đẩy gì lên server; đồng ý thì mới đồng bộ cả dữ liệu lẫn ảnh', () async {
    final b = MmBackup.parse(_backup.readAsBytesSync());
    final r = await importMoneyManager(store, b, localOnly: true);
    expect(r.transactions, 230);
    expect(r.transfers, 1);
    expect(r.photos, 121);

    // Số dư khớp Money Manager.
    final tp = store.all(E.accounts).firstWhere((a) => a['name'] == 'TPBank');
    final momo = store.all(E.accounts).firstWhere((a) => a['name'] == 'Momo');
    expect(_balance(store, tp['id'] as String), closeTo(6841716, 0.01));
    expect(_balance(store, momo['id'] as String), closeTo(27888000, 0.01));

    await sync.sync();
    expect(api.pushed[E.transactions], isNull, reason: 'dữ liệu chỉ lưu trên máy không được gửi lên');
    expect(api.uploaded, isEmpty);
    expect(store.localOnlyCounts()[E.transactions], 231);

    // Sửa một giao dịch đã nhập: vẫn chỉ ở trên máy.
    final tx = store.all(E.transactions).first;
    store.put(E.transactions, {...tx, 'note': 'sửa'});
    await sync.sync();
    expect(api.pushed[E.transactions], isNull);

    // Nhập lại cùng file: không trùng.
    final again = await importMoneyManager(store, b, localOnly: true);
    expect(again.transactions + again.transfers, 0);
    expect(again.skipped, 231);

    // Người dùng đồng ý → đẩy hết lên, kèm ảnh.
    store.promoteLocalOnly();
    await sync.sync();
    expect(api.pushed[E.transactions], 231);
    expect(api.pushed[E.attachments], 121);
    expect(api.uploaded, hasLength(store.all(E.attachments).map((a) => a['fileId']).toSet().length));
    expect(store.localOnlyCounts(), isEmpty);
  }, skip: !_backup.existsSync());

  test('lưu & đồng bộ ngay: đẩy lên ở lượt đồng bộ đầu', () async {
    final b = MmBackup.parse(_backup.readAsBytesSync());
    await importMoneyManager(store, b, localOnly: false);
    await sync.sync();
    expect(api.pushed[E.transactions], 231);
    expect(api.uploaded, isNotEmpty);
    expect(store.localOnlyCounts(), isEmpty);
  }, skip: !_backup.existsSync());
}
