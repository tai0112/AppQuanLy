// Ảnh luôn được đưa lên SERVER khi đã đăng nhập: kho trên máy chỉ là chỗ giữ tạm tới khi upload thành công.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:lht_money/data/api.dart';
import 'package:lht_money/data/local_store.dart';
import 'package:lht_money/data/sync.dart';

/// Giả lập server: ghi lại ảnh nhận được; có thể giả mất mạng.
class FakeApi extends ApiClient {
  FakeApi(super.store);
  bool loggedIn = false;
  bool offline = false;
  final uploaded = <String, int>{}; // id → số byte server nhận

  @override
  bool get isLoggedIn => loggedIn;

  @override
  Future<Map<String, dynamic>> upload(String id, Uint8List bytes, String mime, String name) async {
    if (offline) throw ApiException('Mất kết nối', offline: true);
    uploaded[id] = bytes.length;
    return {'id': id};
  }

  @override
  Future<T> get<T>(String path, {Map<String, dynamic>? query}) async =>
      {'changes': <String, dynamic>{}, 'serverTime': DateTime.now().toUtc().toIso8601String()} as T;

  @override
  Future<T> post<T>(String path, [Object? body]) async => {'accepted': <String>[], 'rejected': <Map<String, dynamic>>[]} as T;
}

void main() {
  late Directory dir;
  late String filesDir;
  late LocalStore store;
  late FakeApi api;
  late SyncEngine sync;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('lht_upload');
    filesDir = '${dir.path}/files';
    Hive.init(dir.path);
    store = LocalStore();
    await store.initForTest(filesDir: filesDir);
    api = FakeApi(store);
    sync = SyncEngine(store, api);
  });

  tearDown(() async {
    sync.dispose();
    await Hive.close();
    await dir.delete(recursive: true);
  });

  Uint8List img(int n) => Uint8List.fromList(List.filled(n, 9));
  List<FileSystemEntity> filesOnDisk() => Directory(filesDir).listSync();

  test('chưa đăng nhập: ảnh giữ trên máy; đăng nhập xong: tải lên server rồi mới xoá bản trên máy', () async {
    final id = store.addFile(img(250 * 1024), 'image/jpeg');
    await Future<void>.delayed(const Duration(milliseconds: 100));

    await sync.sync();
    expect(sync.state, SyncState.localOnly);
    expect(api.uploaded, isEmpty);
    expect(store.hasLocalFile(id), isTrue);

    api.loggedIn = true;
    await sync.sync();
    expect(api.uploaded[id], 250 * 1024, reason: 'server phải nhận đủ ảnh');
    expect(store.hasLocalFile(id), isFalse);
    expect(filesOnDisk(), isEmpty);
    expect(store.pendingUploads(), isEmpty);
  });

  test('mất mạng: ảnh KHÔNG bị xoá, có mạng lại thì tải lên tiếp', () async {
    api.loggedIn = true;
    api.offline = true;
    final id = store.addFile(img(1000), 'image/png');
    await Future<void>.delayed(const Duration(milliseconds: 100));

    await sync.sync();
    expect(sync.state, SyncState.offline);
    expect(store.hasLocalFile(id), isTrue);
    expect(filesOnDisk(), hasLength(1));

    api.offline = false;
    await sync.sync();
    expect(api.uploaded.keys, contains(id));
    expect(store.hasLocalFile(id), isFalse);
    expect(filesOnDisk(), isEmpty);
  });

  test('đồng bộ chạy ngay lúc ảnh còn đang ghi xuống đĩa: vẫn tải lên đủ, không để lại file thừa', () async {
    api.loggedIn = true;
    final ids = [for (var i = 0; i < 5; i++) store.addFile(img(400 * 1024), 'image/jpeg')];
    await sync.sync(); // không chờ ghi xong
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(api.uploaded.keys.toSet(), ids.toSet());
    expect(api.uploaded.values.every((n) => n == 400 * 1024), isTrue);
    expect(filesOnDisk(), isEmpty, reason: 'không được còn file mồ côi');
  });
}
