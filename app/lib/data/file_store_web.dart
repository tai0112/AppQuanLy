import 'dart:typed_data';

import 'package:hive_ce/hive.dart';

import 'file_store.dart';

Future<FileStore> openFileStore({String? dir}) async => _WebFileStore(await Hive.openLazyBox<Uint8List>('file_blobs'));

/// LazyBox: chỉ khoá nằm trong RAM, nội dung ảnh đọc từ IndexedDB khi cần.
class _WebFileStore implements FileStore {
  _WebFileStore(this.box);
  final LazyBox<Uint8List> box;

  @override
  Future<void> write(String id, Uint8List bytes) => box.put(id, bytes);

  @override
  Future<Uint8List?> read(String id) => box.get(id);

  @override
  Future<void> delete(String id) => box.delete(id);

  @override
  Future<void> clear() async => box.clear();
}
