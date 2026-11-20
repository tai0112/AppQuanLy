import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'file_store.dart';

Future<FileStore> openFileStore({String? dir}) async {
  String base;
  try {
    base = dir ?? '${(await getApplicationSupportDirectory()).path}/lht_money/files';
  } catch (_) {
    base = Directory.systemTemp.createTempSync('lht_files').path; // test (không có plugin path_provider)
  }
  final d = Directory(base);
  if (!d.existsSync()) d.createSync(recursive: true);
  return _IoFileStore(d);
}

class _IoFileStore implements FileStore {
  _IoFileStore(this.dir);
  final Directory dir;

  // id là UUID do app sinh → an toàn làm tên file; vẫn chặn ký tự đường dẫn cho chắc.
  File _f(String id) => File('${dir.path}/${id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}');

  @override
  Future<void> write(String id, Uint8List bytes) async {
    // Ghi file tạm rồi đổi tên → không bao giờ để lại ảnh ghi dở nếu app bị tắt giữa chừng.
    final tmp = File('${_f(id).path}.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(_f(id).path);
  }

  @override
  Future<Uint8List?> read(String id) async {
    final f = _f(id);
    return await f.exists() ? f.readAsBytes() : null;
  }

  @override
  Future<void> delete(String id) async {
    final f = _f(id);
    if (await f.exists()) await f.delete();
  }

  @override
  Future<void> clear() async {
    if (await dir.exists()) {
      await for (final e in dir.list()) {
        if (e is File) await e.delete();
      }
    }
  }
}
