import 'dart:typed_data';
import 'dart:ui' show PointerDeviceKind;

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'icons.dart';
import 'theme.dart';

/// Khung bấm có hiệu ứng thu nhỏ + rung nhẹ, dùng cho mọi nút/thẻ để bấm "mượt".
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.onLongPress, this.scale = 0.92, this.haptic = true});
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool haptic;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  bool _hover = false;
  double _downScale = 1, _hoverScale = 1;

  /// Mức lún / nhô tính theo kích thước thật của khối (đo lúc bấm, không tốn thêm khi dựng):
  /// nút nhỏ lún rõ, khối lớn (ô thời gian, nút rộng cả màn) chỉ lún vài px → không còn cảm giác "giật".
  void _measure() {
    final size = context.size;
    final d = size == null ? 0.0 : (size.width > size.height ? size.width : size.height);
    _downScale = d <= 0 ? widget.scale : (1 - 7 / d).clamp(widget.scale, 0.985);
    _hoverScale = d <= 0 ? 1.03 : (1 + 3 / d).clamp(1.0, 1.03);
  }

  void _set(bool v) {
    if (v) _measure();
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    // Trên trình duyệt/máy tính: rê chuột vào sẽ nhô lên nhẹ; bấm sẽ lún xuống.
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: enabled
          ? (_) => setState(() {
              _measure();
              _hover = true;
            })
          : null,
      onExit: enabled ? (_) => setState(() => _hover = false) : null,
      child: _gesture(enabled),
    );
  }

  Widget _gesture(bool enabled) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) HapticFeedback.selectionClick();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              HapticFeedback.mediumImpact();
              widget.onLongPress!();
            },
      child: AnimatedScale(
        scale: _down ? _downScale : (_hover ? _hoverScale : 1),
        duration: Duration(milliseconds: _down ? 90 : 260),
        curve: _down ? Curves.easeOut : Curves.easeOutBack,
        child: widget.child, // chỉ lún nhẹ, không làm mờ/nháy
      ),
    );
  }
}

/// Thẻ bo góc có thể bấm.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(16), this.color, this.gradient});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null
            ? (color ?? (Theme.of(context).brightness == Brightness.dark ? scheme.surfaceContainerHigh : scheme.surfaceContainerLowest))
            : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        // Tối: viền sáng rất mảnh tạo chiều sâu; sáng: bóng mềm
        border: Theme.of(context).brightness == Brightness.dark ? Border.all(color: Colors.white.withValues(alpha: 0.05)) : null,
        boxShadow: Theme.of(context).brightness == Brightness.dark
            ? null
            : [BoxShadow(color: scheme.primary.withValues(alpha: 0.06), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Material(type: MaterialType.transparency, child: child),
    );
    return onTap == null ? card : Pressable(onTap: onTap, scale: 0.98, child: card);
  }
}

/// Icon tròn màu của danh mục / tài khoản.
class CircleIcon extends StatelessWidget {
  const CircleIcon({super.key, required this.icon, required this.color, this.size = 44});
  final String? icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(size * 0.34)),
    child: Icon(iconOf(icon), color: color, size: size * 0.52),
  );
}

/// Số tiền chạy (đếm lên) khi thay đổi.
/// Công tắc nhỏ dạng viên thuốc, nền trượt mượt sang lựa chọn đang bật. [labels] có thể bỏ trống để chỉ hiện icon.
class PillToggle<T> extends StatelessWidget {
  const PillToggle({
    super.key,
    required this.value,
    required this.values,
    required this.icons,
    this.labels,
    this.colors,
    this.itemWidth,
    required this.onChanged,
  });
  final double? itemWidth;
  final T value;
  final List<T> values;
  final List<IconData> icons;
  final List<String>? labels;
  final List<Color>? colors;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final w = itemWidth ?? (labels == null ? 34.0 : 74.0);
    const h = 30.0;
    final idx = values.indexOf(value);
    final active = colors?[idx] ?? scheme.primary;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            left: idx * w,
            top: 0,
            width: w,
            height: h,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              decoration: BoxDecoration(color: active, borderRadius: BorderRadius.circular(9)),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (i, v) in values.indexed)
                Tooltip(
                  message: labels?[i] ?? '',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (v != value) HapticFeedback.selectionClick();
                      onChanged(v);
                    },
                    child: SizedBox(
                      width: w,
                      height: h,
                      child: AnimatedScale(
                        scale: v == value ? 1 : 0.9,
                        duration: const Duration(milliseconds: 220),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icons[i], size: 16, color: v == value ? Colors.white : scheme.onSurfaceVariant),
                              if (labels != null) ...[
                                const SizedBox(width: 4),
                                Text(
                                  labels![i],
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: v == value ? Colors.white : scheme.onSurfaceVariant),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Số tiền chạy (đếm lên/xuống) khi thay đổi.
class AnimatedAmount extends StatelessWidget {
  const AnimatedAmount({super.key, required this.value, required this.format, this.style, this.textAlign});
  final double value;
  final String Function(double) format;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) => CountText(values: [value], text: (v) => format(v[0]), style: style, textAlign: textAlign, countUp: true);
}

/// Chữ có chứa một hay nhiều con số: mỗi khi số đổi thì chạy mượt từ giá trị cũ sang giá trị mới
/// Lần đầu hiện: hiện ngay giá trị cuối (số trong danh sách không "nhảy" khi mở màn / cuộn);
/// chỉ các số tổng quan trọng bật [countUp] mới đếm từ 0 lên — và không đếm khi phần tử xuất hiện do đang cuộn.
class CountText extends StatefulWidget {
  const CountText({super.key, required this.values, required this.text, this.style, this.textAlign, this.maxLines, this.overflow, this.countUp = false});
  final bool countUp;
  final List<double> values;
  final String Function(List<double> v) text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  static const duration = Duration(milliseconds: 900);

  @override
  State<CountText> createState() => _CountTextState();
}

class _CountTextState extends State<CountText> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: CountText.duration);
  late final _anim = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
  late List<double> _from = List.filled(widget.values.length, 0);
  late List<double> _to = widget.values;

  @override
  void initState() {
    super.initState();
    _c.value = 1; // mặc định: hiện ngay giá trị cuối
  }

  bool _decided = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_decided) return;
    _decided = true;
    final scrolling = Scrollable.maybeOf(context)?.position.isScrollingNotifier.value ?? false;
    if (widget.countUp && !scrolling) _c.forward(from: 0);
  }

  @override
  void didUpdateWidget(CountText old) {
    super.didUpdateWidget(old);
    if (!_same(widget.values, _to)) {
      final cur = _current();
      _from = List.generate(widget.values.length, (i) => i < cur.length ? cur[i] : 0);
      _to = widget.values;
      _c.forward(from: 0);
    }
  }

  static bool _same(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  List<double> _current() {
    final t = _anim.value;
    return [for (var i = 0; i < _to.length; i++) _from[i] + (_to[i] - _from[i]) * t];
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (context, _) => Text(
      widget.text(_c.isCompleted ? _to : _current()),
      // Chữ số cùng độ rộng → số chạy mượt, không bị rung ngang.
      style: (widget.style ?? const TextStyle()).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      textAlign: widget.textAlign,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.subtitle, this.action});
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(color: scheme.primaryContainer.withValues(alpha: 0.5), shape: BoxShape.circle),
              child: Icon(icon, size: 40, color: scheme.primary),
            ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                style: TextStyle(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        ),
        if (trailing != null) trailing!,
      ],
    ),
  );
}

/// Hiệu ứng xuất hiện so le cho phần tử danh sách.
extension StaggerX on Widget {
  /// Cô lập vùng vẽ lại: hiệu ứng lặp liên tục chỉ vẽ lại đúng widget này, không kéo cả màn hình vẽ theo.
  Widget isolated() => RepaintBoundary(child: this);

  /// Gắn key ở lớp ngoài cùng (cần cho danh sách kéo-thả khi đã bọc hiệu ứng).
  Widget withKey(Key key) => KeyedSubtree(key: key, child: this);

  /// Hiệu ứng xuất hiện lần lượt. Phần tử được dựng do người dùng đang CUỘN thì hiện ngay (không chạy lại hiệu ứng)
  /// — tránh cảnh cuộn lên xuống mà các thẻ cứ nhảy lại, tốn khung hình.
  Widget stagger(int index) => _Stagger(index: index, child: this);
}

class _Stagger extends StatefulWidget {
  const _Stagger({required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  State<_Stagger> createState() => _StaggerState();
}

class _StaggerState extends State<_Stagger> {
  bool? _play;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Quyết định MỘT lần khi gắn vào cây: đang cuộn → không chạy hiệu ứng.
    _play ??= !(Scrollable.maybeOf(context)?.position.isScrollingNotifier.value ?? false);
  }

  @override
  Widget build(BuildContext context) {
    if (_play != true) return widget.child;
    final d = (60 * (widget.index % 12)).ms;
    return widget.child
        .animate()
        .fadeIn(duration: 450.ms, delay: d)
        .slideY(begin: 0.25, end: 0, duration: 500.ms, delay: d, curve: Curves.easeOutCubic)
        .scaleXY(begin: 0.94, end: 1, duration: 500.ms, delay: d, curve: Curves.easeOutBack);
  }
}

/// Chọn màu: một hàng cuộn ngang, chấm nhỏ, màu đang chọn có dấu tích.
class ColorPickerRow extends StatelessWidget {
  const ColorPickerRow({super.key, required this.value, required this.onChanged, this.size = 30});
  final Color value;
  final ValueChanged<Color> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: size + 8,
    child: ListView(
      scrollDirection: Axis.horizontal,
      children: [
        for (final c in AppColors.palette)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Pressable(
              onTap: () => onChanged(c),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: c.toARGB32() == value.toARGB32() ? size + 6 : size,
                height: c.toARGB32() == value.toARGB32() ? size + 6 : size,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  boxShadow: c.toARGB32() == value.toARGB32() ? [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 8)] : null,
                ),
                child: c.toARGB32() == value.toARGB32() ? const Icon(Icons.check_rounded, color: Colors.white, size: 18) : null,
              ),
            ),
          ),
      ],
    ),
  );
}

/// Nhóm trường trong form: tiêu đề nhỏ + thẻ bo góc, các dòng ngăn bằng đường mảnh.
class FormSection extends StatelessWidget {
  const FormSection({super.key, this.title, required this.children, this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 4)});
  final String? title;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 18, 6, 8),
            child: Text(
              title!.toUpperCase(),
              style: TextStyle(fontSize: 12, letterSpacing: 0.8, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant),
            ),
          ),
        AppCard(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, c) in children.indexed) ...[if (i > 0) Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.5)), c],
            ],
          ),
        ),
      ],
    );
  }
}

/// Ô nhập không nền, dùng bên trong FormSection.
class SectionField extends StatelessWidget {
  const SectionField({
    super.key,
    required this.controller,
    required this.hint,
    this.icon,
    this.keyboardType,
    this.maxLines = 1,
    this.style,
    this.inputFormatters,
  });
  final List<TextInputFormatter>? inputFormatters;
  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final TextInputType? keyboardType;
  final int maxLines;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: keyboardType,
    inputFormatters: inputFormatters,
    maxLines: maxLines,
    minLines: 1,
    style: style,
    decoration: InputDecoration(
      hintText: hint,
      filled: false,
      border: InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(vertical: 14),
      prefixIcon: icon == null ? null : Icon(icon, size: 22),
    ),
  );
}

/// Chọn icon trong bộ icon.
class IconPickerGrid extends StatelessWidget {
  const IconPickerGrid({super.key, required this.value, required this.color, required this.onChanged});
  final String? value;
  final Color color;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final e in appIcons.entries)
        Pressable(
          onTap: () => onChanged(e.key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: e.key == value ? color.withValues(alpha: 0.2) : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: e.key == value ? color : Colors.transparent, width: 2),
            ),
            child: Icon(e.value, color: e.key == value ? color : Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
    ],
  );
}

/// Ảnh: ưu tiên bytes local (chưa upload), sau đó tải từ server.
class AppImage extends StatelessWidget {
  const AppImage({super.key, this.bytes, this.url, this.image, this.fit = BoxFit.cover, this.radius = 14});
  final Uint8List? bytes;
  final String? url;

  /// Ảnh từ nguồn tuỳ ý (vd ảnh lưu trên máy, đọc từ đĩa khi cần) — ưu tiên hơn [bytes]/[url].
  final ImageProvider? image;
  final BoxFit fit;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(child: Icon(Icons.image_outlined)),
    );
    // Giải mã ảnh đúng kích thước hiển thị → ít bộ nhớ, cuộn không giật.
    final img = LayoutBuilder(
      builder: (context, box) {
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final w = box.maxWidth.isFinite ? (box.maxWidth * dpr).round().clamp(64, 2048) : null;
        if (image != null) {
          return Image(
            image: ResizeImage.resizeIfNeeded(w, null, image!),
            fit: fit,
            gaplessPlayback: true,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) => placeholder,
          );
        }
        if (bytes != null) {
          return Image.memory(bytes!, fit: fit, gaplessPlayback: true, cacheWidth: w, width: double.infinity, height: double.infinity);
        }
        if (url != null) {
          return Image.network(
            url!,
            fit: fit,
            gaplessPlayback: true,
            cacheWidth: w,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) => placeholder,
            frameBuilder: (c, child, frame, sync) => sync
                ? child
                : AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: const Duration(milliseconds: 350), curve: Curves.easeOut, child: child),
          );
        }
        return placeholder;
      },
    );
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: img);
  }
}

void showToast(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger?.hideCurrentSnackBar();
  messenger?.showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? AppColors.expense : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

Future<bool> confirm(BuildContext context, String title, {String? message, String ok = 'Đồng ý', bool danger = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Huỷ')),
        FilledButton(
          style: danger
              ? FilledButton.styleFrom(backgroundColor: AppColors.expense, minimumSize: const Size(64, 40))
              : FilledButton.styleFrom(minimumSize: const Size(64, 40)),
          onPressed: () => Navigator.pop(c, true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// Thẻ "biến hình" thành trang chi tiết khi bấm (container transform) — quay lại thì thu về đúng chỗ.
class OpenCard extends StatelessWidget {
  const OpenCard({super.key, required this.child, required this.page, this.padding = const EdgeInsets.all(16), this.color, this.radius = 10, this.onClosed});
  final Widget child;
  final Widget page;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double radius;
  final VoidCallback? onClosed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bg = color ?? (theme.brightness == Brightness.dark ? scheme.surfaceContainerHigh : scheme.surfaceContainerLowest);
    return OpenContainer(
      transitionDuration: const Duration(milliseconds: 520),
      transitionType: ContainerTransitionType.fadeThrough,
      closedElevation: 0,
      openElevation: 0,
      closedColor: bg,
      middleColor: bg,
      openColor: theme.scaffoldBackgroundColor,
      closedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      onClosed: (_) => onClosed?.call(),
      openBuilder: (context, _) => page,
      closedBuilder: (context, open) => DefaultTextStyle(
        style: theme.textTheme.bodyMedium!.copyWith(color: scheme.onSurface),
        child: IconTheme(
          data: IconThemeData(color: scheme.onSurface),
          child: Pressable(
            scale: 0.97,
            onTap: () {
              HapticFeedback.lightImpact();
              open();
            },
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// Khung xương lấp lánh khi đang tải (thay cho vòng xoay).
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 6, this.avatar = true});
  final int count;
  final bool avatar;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    Widget bar(double w, double h) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(8)),
    );
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: count,
      itemBuilder: (c, i) =>
          Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Row(
                  children: [
                    if (avatar) ...[
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(color: base, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [bar(double.infinity, 14), const SizedBox(height: 8), bar(140.0 + (i % 3) * 30, 12)],
                      ),
                    ),
                  ],
                ),
              )
              .animate(onPlay: (c) => c.repeat())
              .shimmer(duration: 1300.ms, delay: (80 * i).ms, color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.6))
              .isolated(),
    );
  }
}

/// Cuộn nảy đàn hồi kiểu iOS ở mọi nơi, kéo được bằng chuột / trackpad trên máy tính.
class SmoothScrollBehavior extends MaterialScrollBehavior {
  const SmoothScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

  @override
  Set<PointerDeviceKind> get dragDevices => PointerDeviceKind.values.toSet();
}

/// Hiệu ứng khi đang kéo-thả: thẻ nhấc lên, phóng nhẹ, có bóng đổ.
Widget liftOnDrag(Widget child, int index, Animation<double> animation) => AnimatedBuilder(
  animation: animation,
  builder: (context, c) {
    final t = Curves.easeOutCubic.transform(animation.value);
    return Transform.scale(
      scale: 1 + 0.04 * t,
      child: Material(
        color: Colors.transparent,
        elevation: 0,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28 * t),
                blurRadius: 22 * t,
                offset: Offset(0, 8 * t),
              ),
            ],
          ),
          child: c,
        ),
      ),
    );
  },
  child: child,
);

/// Tay kéo duy nhất cho danh sách kéo-thả (tắt tay kéo mặc định của Flutter trên web/máy tính).
class DragHandle extends StatelessWidget {
  const DragHandle({super.key, required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => ReorderableDragStartListener(
    index: index,
    child: MouseRegion(
      cursor: SystemMouseCursors.grab,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Icon(Icons.drag_indicator_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ),
  );
}

/// Dòng cài đặt: tiêu đề bên trái, giá trị đang chọn bên phải (viên nhỏ), chạm để chọn → không bị chèn chữ.
class ValueTile extends StatelessWidget {
  const ValueTile({super.key, required this.icon, required this.title, required this.value, this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String value;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Pressable(
      scale: 0.98,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: scheme.onSurfaceVariant),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16)),
                  if (subtitle != null) Text(subtitle!, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  // Giá trị đang chọn nằm dưới tiêu đề → không chen ngang, không đẩy chữ xuống nhiều dòng
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (c, a) => FadeTransition(
                      opacity: a,
                      child: SizeTransition(sizeFactor: a, axis: Axis.horizontal, child: c),
                    ),
                    child: Container(
                      key: ValueKey(value),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: scheme.primary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// Bảng chọn một giá trị trong danh sách (dấu tích động, mục chọn nổi bật).
Future<T?> pickFromList<T>(BuildContext context, {required String title, required List<(T, String, IconData?)> items, T? selected}) {
  return showModalBottomSheet<T>(
    context: context,
    sheetAnimationStyle: kSheetAnim,
    isScrollControlled: true,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                children: [
                  for (final (i, (v, label, icon)) in items.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Pressable(
                        scale: 0.98,
                        onTap: () => Navigator.pop(ctx, v),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: v == selected ? scheme.primary.withValues(alpha: 0.14) : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: v == selected ? scheme.primary : Colors.transparent),
                          ),
                          child: Row(
                            children: [
                              if (icon != null) ...[
                                Icon(icon, size: 20, color: v == selected ? scheme.primary : scheme.onSurfaceVariant),
                                const SizedBox(width: 12),
                              ],
                              Expanded(
                                child: Text(label, style: TextStyle(fontWeight: v == selected ? FontWeight.w700 : FontWeight.w500)),
                              ),
                              if (v == selected) Icon(Icons.check_circle_rounded, color: scheme.primary),
                            ],
                          ),
                        ),
                      ).stagger(i),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Vuốt từ mép màn hình vào trong để chuyển trang (vd đổi tháng): mép trái → [onPrev], mép phải → [onNext].
/// Dải mép hẹp, nhận trọn cử chỉ trong dải → không tranh với vuốt-xoá dòng hay lịch bên dưới.
/// Mũi tên tròn trượt theo ngón tay; vượt ngưỡng thì rung nhẹ, thả tay mới chuyển.
class EdgeSwipe extends StatefulWidget {
  const EdgeSwipe({super.key, required this.child, required this.onPrev, required this.onNext, this.edgeWidth = 22});
  final Widget child;
  final VoidCallback onPrev, onNext;
  final double edgeWidth;

  @override
  State<EdgeSwipe> createState() => _EdgeSwipeState();
}

class _EdgeSwipeState extends State<EdgeSwipe> with SingleTickerProviderStateMixin {
  static const _threshold = 70.0;
  late final _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
  double _dx = 0; // quãng đã kéo vào trong (>= 0)
  bool _left = true, _armed = false;

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _start(bool left) {
    _left = left;
    _dx = 0;
    _armed = false;
    _anim.value = 0;
  }

  void _update(DragUpdateDetails d) {
    _dx = (_dx + (_left ? d.delta.dx : -d.delta.dx)).clamp(0, 160);
    final armed = _dx >= _threshold;
    if (armed && !_armed) HapticFeedback.selectionClick();
    _armed = armed;
    _anim.value = (_dx / _threshold).clamp(0, 1.4) / 1.4;
  }

  void _end(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    final fling = _left ? v > 600 : v < -600;
    if (_armed || fling) {
      HapticFeedback.lightImpact();
      _left ? widget.onPrev() : widget.onNext();
    }
    _anim.animateTo(0, curve: Curves.easeOutCubic);
  }

  Widget _strip(bool left) => Positioned(
    top: 0,
    bottom: 0,
    left: left ? 0 : null,
    right: left ? null : 0,
    width: widget.edgeWidth,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) => _start(left),
      onHorizontalDragUpdate: _update,
      onHorizontalDragEnd: _end,
      onHorizontalDragCancel: () => _anim.animateTo(0, curve: Curves.easeOutCubic),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        widget.child,
        _strip(true),
        _strip(false),
        // Mũi tên báo hiệu: chỉ vẽ lại phần này khi kéo
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _anim,
              builder: (context, _) {
                final p = _anim.value;
                if (p == 0) return const SizedBox.shrink();
                final armed = _dx >= _threshold;
                return Align(
                  alignment: _left ? Alignment.centerLeft : Alignment.centerRight,
                  child: Transform.translate(
                    offset: Offset((_left ? 1 : -1) * (-44 + 60 * p), 0),
                    child: Opacity(
                      opacity: p.clamp(0, 1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: armed ? scheme.primary : scheme.surfaceContainerHighest,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10)],
                        ),
                        child: Icon(
                          _left ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                          color: armed ? scheme.onPrimary : scheme.onSurfaceVariant,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
