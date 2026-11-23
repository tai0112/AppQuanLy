import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:lht_money/data/api.dart';
import 'package:lht_money/data/local_store.dart';
import 'package:lht_money/data/sync.dart';

void main() {
  late Directory tempDir;
  late LocalStore store;
  late SyncEngine sync;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('lht_test_sync_');
    Hive.init(tempDir.path);
    store = LocalStore();
    await store.initForTest(filesDir: '${tempDir.path}/files');
    sync = SyncEngine(store, ApiClient(store));
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('applyRemote handles dynamically typed maps without throwing TypeError', () {
    final dynamic rawMap = <dynamic, dynamic>{
      'id': 'tx-1234',
      'type': 1,
      'amount': 50000,
      'currencyCode': 'VND',
      'accountId': 'acc-1',
      'occurredAt': '2026-11-23T10:00:00+07:00',
      'note': 'Ăn trưa',
    };

    store.applyRemote(E.transactions, Map<String, dynamic>.from(rawMap as Map));
    final all = store.all(E.transactions);
    expect(all.length, 1);
    expect(all.first['note'], 'Ăn trưa');
    expect(all.first['amount'], 50000);
  });
}
