import 'dart:typed_data';

import 'file_store_web.dart' if (dart.library.io) 'file_store_io.dart' as impl;

/// Nơi giữ NỘI DUNG ảnh trên máy — không nạp vào RAM, chỉ đọc khi cần hiển thị/tải lên.
///  - iOS/Android/desktop: mỗi ảnh một file trong thư mục của app.
///  - Web: Hive LazyBox (IndexedDB) — RAM chỉ giữ danh sách khoá.
/// Thông tin mô tả (mime, tên, trạng thái) vẫn nằm trong LocalStore.
abstract class FileStore {
  Future<void> write(String id, Uint8List bytes);
  Future<Uint8List?> read(String id);
  Future<void> delete(String id);
  Future<void> clear();

  /// [dir]: thư mục riêng (chỉ dùng trong test, nền tảng có file system).
  static Future<FileStore> open({String? dir}) => impl.openFileStore(dir: dir);
}
