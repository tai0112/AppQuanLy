// Kho ảnh trên máy: nội dung ảnh nằm trên đĩa (FileStore), không nạp vào RAM; kho cũ (Hive box 'files') được chuyển sang.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:lht_money/data/local_store.dart';

void main() {
  late Directory dir;
  late String filesDir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('lht_store');
    filesDir = '${dir.path}/files';
    Hive.init(dir.path);
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  Uint8List img(int n, int v) => Uint8List.fromList(List.filled(n, v));

  test('ảnh mới được ghi ra file, đọc lại đúng, tải lên xong vẫn giữ tệp', () async {
    final store = LocalStore();
    await store.initForTest(filesDir: filesDir);

    final id = store.addFile(img(300 * 1024, 7), 'image/jpeg', name: 'a.jpg');
    expect(store.hasLocalFile(id), isTrue);
    expect((await store.readFile(id))!.length, 300 * 1024, reason: 'đọc được ngay cả khi đang ghi');

    await Future<void>.delayed(const Duration(milliseconds: 200)); // chờ ghi xong
    final f = File('$filesDir/$id');
    expect(f.existsSync(), isTrue);
    expect(f.lengthSync(), 300 * 1024);
    expect(Directory(filesDir).listSync().where((e) => e.path.endsWith('.tmp')), isEmpty);

    final pending = store.pendingUploads();
    expect(pending.single.id, id);
    expect(pending.single.mime, 'image/jpeg');

    await store.fileUploaded(id);
    expect(store.hasLocalFile(id), isTrue);
    expect(f.existsSync(), isTrue);
    expect(store.pendingUploads(), isEmpty);

    await store.fileUploaded('mat-roi', missing: true); // ảnh không còn trên máy → chỉ bỏ khỏi hàng đợi
    expect(store.hasLocalFile('mat-roi'), isFalse);
  });

  test('kho cũ (Hive box "files" nạp hết vào RAM) được chuyển sang file rồi xoá', () async {
    final old = await Hive.openBox<Uint8List>('files');
    await old.put('old-1', img(1000, 1));
    await old.put('old-2', img(2000, 2));
    final meta = await Hive.openBox<String>('file_meta');
    await meta.put('old-1', '{"mime":"image/jpeg","name":"1.jpg"}');
    await meta.put('old-2', '{"mime":"image/png","name":"2.png"}');
    await Hive.close();

    final store = LocalStore();
    await store.initForTest(filesDir: filesDir);

    expect(await Hive.boxExists('files'), isFalse, reason: 'box cũ phải bị xoá');
    expect((await store.readFile('old-1'))!.first, 1);
    expect((await store.readFile('old-2'))!.length, 2000);
    expect(store.pendingUploads().map((e) => e.id).toSet(), {'old-1', 'old-2'});
  });

  test('đăng xuất (wipe) xoá luôn file ảnh', () async {
    final store = LocalStore();
    await store.initForTest(filesDir: filesDir);
    final id = store.addFile(img(10, 3), 'image/jpeg');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await store.wipe();
    expect(store.hasLocalFile(id), isFalse);
    expect(Directory(filesDir).listSync(), isEmpty);
  });
}
