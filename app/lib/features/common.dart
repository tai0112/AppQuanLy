import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show SynchronousFuture, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../data/local_store.dart';
import '../data/models.dart';
import '../data/time_config.dart';

import '../providers.dart';
import 'pickers.dart';

export 'pickers.dart';

/// Chọn / chụp ảnh → lưu vào máy, xếp hàng upload. Trả về danh sách fileId.
Future<List<String>> pickPhotos(BuildContext context, WidgetRef ref, {bool multiple = true, List<String>? outPaths}) async {
  final source = await showModalBottomSheet<ImageSource>(
    sheetAnimationStyle: kSheetAnim,
    context: context,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_rounded),
            title: const Text('Chụp ảnh'),
            subtitle: const Text('Chụp hoá đơn, ảnh kỷ niệm để đính kèm'),
            onTap: () => Navigator.pop(c, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded),
            title: const Text('Chọn từ thư viện'),
            subtitle: const Text('Chỉ những ảnh bạn chọn được đọc'),
            onTap: () => Navigator.pop(c, ImageSource.gallery),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              'Ảnh chỉ dùng để đính kèm vào mục bạn đang sửa. Ứng dụng không tự chụp hay quét thư viện ảnh.',
              style: TextStyle(fontSize: 12, color: Theme.of(c).colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    ),
  );
  if (source == null) return [];
  final picker = ImagePicker();
  final files = <XFile>[];
  try {
    if (source == ImageSource.gallery && multiple) {
      files.addAll(await picker.pickMultiImage(maxWidth: 1600, imageQuality: 80));
    } else {
      final f = await picker.pickImage(source: source, maxWidth: 1600, imageQuality: 80);
      if (f != null) files.add(f);
    }
  } on PlatformException catch (e) {
    // Người dùng đã từ chối quyền: hướng dẫn bật lại, không lỗi khó hiểu
    if (context.mounted) {
      final denied = e.code.contains('access_denied');
      showToast(
        context,
        denied
            ? (source == ImageSource.camera
                  ? 'Chưa có quyền dùng máy ảnh. Bật trong Cài đặt iPhone → LinTin → Máy ảnh.'
                  : 'Chưa có quyền truy cập ảnh. Bật trong Cài đặt iPhone → LinTin → Ảnh.')
            : 'Không mở được ảnh: ${e.message ?? e.code}',
        error: true,
      );
    }
    return [];
  } catch (e) {
    if (context.mounted) showToast(context, 'Không mở được ảnh: $e', error: true);
    return [];
  }
  final store = ref.read(storeProvider);
  final ids = <String>[];
  for (final f in files) {
    outPaths?.add(f.path);
    final bytes = await f.readAsBytes();
    final mime = f.mimeType ?? (f.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg');
    ids.add(store.addFile(bytes, mime, name: f.name));
  }
  return ids;
}

/// Ảnh theo fileId: bản trên máy (chưa upload, đọc từ đĩa khi cần) hoặc tải từ server.
class FileImage2 extends ConsumerWidget {
  const FileImage2(this.fileId, {super.key, this.fit = BoxFit.cover, this.radius = 14});
  final String fileId;
  final BoxFit fit;
  final double radius;

  static final _inFlight = <String>{};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    if (store.hasLocalFile(fileId)) {
      return AppImage(image: StoredImage(fileId, store), fit: fit, radius: radius);
    }
    // Nếu chưa có trong cache phiên, kích hoạt nạp ngầm để lần tới mở xem sẽ có sẵn tức thì 0ms
    if (!kIsWeb) {
      _cacheInBackground(ref, fileId);
    }
    return AppImage(url: ref.read(apiProvider).fileUrl(fileId), fit: fit, radius: radius);
  }

  static void _cacheInBackground(WidgetRef ref, String fid) {
    if (fid.isEmpty || _inFlight.contains(fid)) return;
    _inFlight.add(fid);
    ref.read(apiProvider).download(fid).then((f) async {
      if (f != null) {
        await ref.read(storeProvider).saveDownloadedFile(fid, f.bytes, f.mime);
      }
    }).catchError((_) {}).whenComplete(() => _inFlight.remove(fid));
  }
}

/// Ảnh lưu trên máy: chỉ đọc nội dung từ đĩa khi Flutter cần vẽ, giải mã xong là bỏ bytes
/// (ảnh đã giải mã nằm trong bộ đệm ảnh chung của Flutter, có giới hạn) → không giữ ảnh gốc trong RAM.
class StoredImage extends ImageProvider<StoredImage> {
  const StoredImage(this.id, this.store);
  final String id;
  final LocalStore store;

  @override
  Future<StoredImage> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(StoredImage key, ImageDecoderCallback decode) =>
      MultiFrameImageStreamCompleter(codec: _load(decode), scale: 1, debugLabel: 'StoredImage($id)');

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    final bytes = await store.readFile(id);
    if (bytes == null) throw StateError('Không còn ảnh $id trên máy');
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }

  @override
  bool operator ==(Object other) => other is StoredImage && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Lưới ảnh có thể xoá + nút thêm ảnh.
class PhotoGrid extends ConsumerWidget {
  const PhotoGrid({super.key, required this.fileIds, this.onAdd, this.onRemove, this.size = 92});
  final List<String> fileIds;
  final VoidCallback? onAdd;
  final void Function(String)? onRemove;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (i, id) in fileIds.indexed)
          Stack(
            children: [
              Pressable(
                onTap: () => openGallery(context, fileIds, i),
                child: Hero(
                  tag: 'photo-$id',
                  child: SizedBox(width: size, height: size, child: FileImage2(id)),
                ),
              ),
              if (onRemove != null)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Pressable(
                    onTap: () => onRemove!(id),
                    child: const CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.black54,
                      child: Icon(Icons.close, size: 14, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ).stagger(i),
        if (onAdd != null)
          Pressable(
            onTap: onAdd,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Icon(Icons.add_a_photo_rounded, color: scheme.primary),
            ),
          ),
      ],
    );
  }
}

/// Xem ảnh toàn màn hình, vuốt qua lại, phóng to.
void openGallery(BuildContext context, List<String> ids, int index) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (_, __, ___) => _Gallery(ids: ids, index: index),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    ),
  );
}

class _Gallery extends StatelessWidget {
  const _Gallery({required this.ids, required this.index});
  final List<String> ids;
  final int index;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
    body: PageView(
      controller: PageController(initialPage: index),
      children: [
        for (final id in ids)
          InteractiveViewer(
            child: Center(
              child: Hero(
                tag: 'photo-$id',
                child: FileImage2(id, fit: BoxFit.contain, radius: 0),
              ),
            ),
          ),
      ],
    ),
  );
}

/// Ô nhập số tiền lớn.
class AmountField extends StatelessWidget {
  const AmountField({super.key, required this.controller, this.color, this.suffix, this.autofocus = false, this.label});
  final TextEditingController controller;
  final Color? color;
  final String? suffix;
  final bool autofocus;
  final String? label;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    autofocus: autofocus,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: const [ThousandsInputFormatter()],
    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: color),
    decoration: InputDecoration(labelText: label, hintText: '0', suffixText: suffix),
  );
}

/// Chọn danh mục dạng lưới (cấp 1, chạm để mở cấp 2).
Future<Category?> pickCategory(BuildContext context, WidgetRef ref, int type) {
  return showModalBottomSheet<Category>(
    sheetAnimationStyle: kSheetAnim,
    context: context,
    isScrollControlled: true,
    builder: (c) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      builder: (c, scroll) => _CategoryPicker(type: type, scroll: scroll),
    ),
  );
}

class _CategoryPicker extends ConsumerStatefulWidget {
  const _CategoryPicker({required this.type, required this.scroll});
  final int type;
  final ScrollController scroll;

  @override
  ConsumerState<_CategoryPicker> createState() => _CategoryPickerState();
}

class _CategoryPickerState extends ConsumerState<_CategoryPicker> {
  String? expanded;

  @override
  Widget build(BuildContext context) {
    final f = ref.watch(financeProvider);
    final cats = f.categories.where((c) => c.type == widget.type).toList();
    final roots = cats.where((c) => c.parentId == null).toList();
    return ListView(
      controller: widget.scroll,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        const Text('Chọn danh mục', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 0.82,
          children: [
            for (final (i, c) in roots.indexed)
              Pressable(
                onTap: () {
                  final hasChildren = cats.any((x) => x.parentId == c.id);
                  if (hasChildren && expanded != c.id) {
                    setState(() => expanded = c.id);
                  } else {
                    Navigator.pop(context, c);
                  }
                },
                child: Column(
                  children: [
                    CircleIcon(icon: c.icon, color: hexColor(c.color), size: 52),
                    const SizedBox(height: 6),
                    Text(c.name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ).stagger(i),
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          child: expanded == null
              ? const SizedBox(width: double.infinity)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(height: 24),
                    Text('Trong "${f.category(expanded)?.name}"', style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(label: Text('Chọn "${f.category(expanded)?.name}"'), onPressed: () => Navigator.pop(context, f.category(expanded))),
                        for (final c in cats.where((x) => x.parentId == expanded))
                          ActionChip(
                            avatar: Icon(Icons.subdirectory_arrow_right_rounded, size: 16, color: hexColor(c.color)),
                            label: Text(c.name),
                            onPressed: () => Navigator.pop(context, c),
                          ),
                      ],
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Chọn tài khoản.
Future<Account?> pickAccount(BuildContext context, WidgetRef ref, {String? exclude}) {
  final f = ref.read(financeProvider);
  return showModalBottomSheet<Account>(
    sheetAnimationStyle: kSheetAnim,
    context: context,
    builder: (c) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('Chọn tài khoản', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          for (final a in f.accounts.where((a) => !a.isArchived && a.id != exclude))
            ListTile(
              leading: CircleIcon(icon: a.icon, color: hexColor(a.color), size: 40),
              title: Text(a.name),
              subtitle: CountText(values: [f.balance(a)], text: (cv) => f.money(cv[0], a.currencyCode)),
              onTap: () => Navigator.pop(c, a),
            ),
        ],
      ),
    ),
  );
}

/// Hàng nút chọn nhanh nguồn tiền (Tiền mặt / Ngân hàng / Ví...). Chạm 1 lần là chọn.
class AccountChips extends ConsumerWidget {
  const AccountChips({super.key, required this.selected, required this.onChanged, this.exclude, this.label});
  final String? selected;
  final ValueChanged<Account> onChanged;
  final String? exclude;
  final String? label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(financeProvider);
    final list = f.accounts.where((a) => !a.isArchived && a.id != exclude).toList()
      ..sort((a, b) => (a.isCash ? 0 : 1).compareTo(b.isCash ? 0 : 1)); // tiền mặt lên đầu
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(label!, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        SizedBox(
          height: 64,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final (i, a) in list.indexed)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Pressable(
                    onTap: () => onChanged(a),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: a.id == selected ? hexColor(a.color, scheme.primary).withValues(alpha: 0.18) : scheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: a.id == selected ? hexColor(a.color, scheme.primary) : scheme.outlineVariant,
                          width: a.id == selected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleIcon(icon: a.icon, color: hexColor(a.color), size: 34),
                          const SizedBox(width: 8),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                              CountText(
                                values: [f.balance(a)],
                                text: (cv) => f.money(cv[0], a.currencyCode),
                                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 200),
                            child: a.id == selected
                                ? Padding(
                                    padding: const EdgeInsets.only(left: 6),
                                    child: Icon(Icons.check_circle_rounded, size: 18, color: hexColor(a.color, scheme.primary)),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ).stagger(i),
              Pressable(
                onTap: () => GoRouter.of(context).push('/accounts/edit'),
                child: Container(
                  width: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Icon(Icons.add_rounded, color: scheme.primary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Chọn ngày (+ giờ nếu [withTime]) bằng bộ chọn hiện đại dùng chung toàn app.
Future<DateTime?> pickDateTime(BuildContext context, DateTime initial, {bool withTime = true, DateTime? firstDate, DateTime? lastDate, String? title}) =>
    showModernDatePicker(context, initial: initial, withTime: withTime, firstDate: firstDate, lastDate: lastDate, title: title);

/// Hàng thông tin dạng "nhãn — giá trị" có thể bấm.
class InfoTile extends StatelessWidget {
  const InfoTile({super.key, required this.icon, required this.label, required this.value, this.onTap, this.color});
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    scale: 0.98,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: color ?? Theme.of(context).colorScheme.primary),
          const SizedBox(width: 14),
          Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onTap != null) const Icon(Icons.chevron_right_rounded),
        ],
      ),
    ),
  );
}

String dateLabel(DateTime d) => Fmt.date(d);

/// Chọn ngày đầu tuần (T2 … CN), lưu ngay vào cài đặt — mọi lịch trong app đổi theo.
class FirstDayPicker extends ConsumerWidget {
  const FirstDayPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watchTables(const [E.appSettings]);
    final cfg = TimeConfig.of(store);
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var wd = 1; wd <= 7; wd++)
          Tooltip(
            message: Fmt.weekdays[wd - 1],
            child: Pressable(
              onTap: () {
                if (wd == cfg.firstDayOfWeek) return;
                HapticFeedback.selectionClick();
                cfg.copyWith(firstDayOfWeek: wd).save(store);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: wd == cfg.firstDayOfWeek ? scheme.primary : scheme.surfaceContainerHighest.withValues(alpha: 0.7),
                ),
                child: Text(
                  Fmt.weekdaysShort[wd - 1],
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: wd == cfg.firstDayOfWeek ? scheme.onPrimary : scheme.onSurfaceVariant),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
