import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../core/ui.dart';

/// Ảnh chụp từ màn máy ảnh trong app: bytes JPEG đã cắt đúng khung nhìn + file tạm (để quét hoá đơn).
class CapturedPhoto {
  const CapturedPhoto(this.bytes, this.path, this.name);
  final Uint8List bytes;
  final String path;
  final String name;
}

/// Kết quả màn chụp: ảnh, hoặc người dùng muốn chuyển sang chọn từ thư viện.
sealed class CaptureResult {}

class CaptureDone extends CaptureResult {
  CaptureDone(this.photo);
  final CapturedPhoto photo;
}

class CaptureUseGallery extends CaptureResult {}

/// Không mở được camera (không có / lỗi) → nơi gọi quay về máy ảnh hệ thống.
class CaptureUnavailable extends CaptureResult {
  CaptureUnavailable({this.denied = false});
  final bool denied;
}

/// Mở màn chụp toàn màn hình. null = người dùng đóng.
Future<CaptureResult?> captureFullScreen(BuildContext context) async {
  if (kIsWeb) return CaptureUnavailable();
  List<CameraDescription> cams;
  try {
    cams = await availableCameras();
  } catch (_) {
    return CaptureUnavailable();
  }
  if (cams.isEmpty || !context.mounted) return CaptureUnavailable();
  return Navigator.of(context).push<CaptureResult>(
    PageRouteBuilder(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => _CameraPage(cameras: cams),
      transitionsBuilder: (_, a, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: a, curve: Curves.easeOutCubic),
        child: ScaleTransition(
          scale: Tween(begin: 1.04, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    ),
  );
}

/// Xoay đúng chiều theo EXIF → cắt phần giữa theo tỉ lệ [aspect] (rộng / cao, đúng như khung xem phủ màn hình)
/// → thu nhỏ cạnh rộng tối đa [maxWidth] → JPEG [quality]. Chạy trong isolate (qua [compute]).
Uint8List cropToAspect(Uint8List bytes, double aspect, {int maxWidth = 1600, int quality = 80, bool mirror = false}) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;
  var image = img.bakeOrientation(decoded);
  if (mirror) image = img.flipHorizontal(image);
  final w = image.width, h = image.height;
  var cw = w, ch = h;
  if (w / h > aspect) {
    cw = (h * aspect).round(); // ảnh rộng hơn khung → cắt hai bên
  } else {
    ch = (w / aspect).round(); // ảnh cao hơn khung → cắt trên dưới
  }
  image = img.copyCrop(image, x: (w - cw) ~/ 2, y: (h - ch) ~/ 2, width: cw, height: ch);
  if (image.width > maxWidth) image = img.copyResize(image, width: maxWidth, interpolation: img.Interpolation.average);
  return Uint8List.fromList(img.encodeJpg(image, quality: quality));
}

Uint8List _cropJob((Uint8List, double, bool) a) => cropToAspect(a.$1, a.$2, mirror: a.$3);

class _CameraPage extends StatefulWidget {
  const _CameraPage({required this.cameras});
  final List<CameraDescription> cameras;

  @override
  State<_CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<_CameraPage> with WidgetsBindingObserver, TickerProviderStateMixin {
  CameraController? _ctrl;
  late int _camIndex = _backIndex();
  FlashMode _flash = FlashMode.off;
  double _zoom = 1, _minZoom = 1, _maxZoom = 1, _zoomStart = 1;
  Offset? _focusAt;
  bool _busy = false;
  CapturedPhoto? _shot;
  late final _flashAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
  late final _focusAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  int _backIndex() {
    final i = widget.cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
    return i < 0 ? 0 : i;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _open();
  }

  Future<void> _open() async {
    final old = _ctrl;
    _ctrl = null;
    if (mounted) setState(() {});
    await old?.dispose();
    final c = CameraController(widget.cameras[_camIndex], ResolutionPreset.veryHigh, enableAudio: false, imageFormatGroup: ImageFormatGroup.jpeg);
    try {
      await c.initialize();
      await c.setFlashMode(_flash).catchError((_) {});
      _minZoom = await c.getMinZoomLevel().catchError((_) => 1.0);
      _maxZoom = (await c.getMaxZoomLevel().catchError((_) => 1.0)).clamp(1.0, 8.0);
      _zoom = _minZoom;
    } on CameraException catch (e) {
      await c.dispose();
      if (!mounted) return;
      final denied = e.code.contains('ccess') || e.code.contains('ermission');
      Navigator.of(context).pop(CaptureUnavailable(denied: denied));
      return;
    }
    if (!mounted) {
      await c.dispose();
      return;
    }
    setState(() => _ctrl = c);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Theo hướng dẫn gói camera: vào nền thì trả camera cho hệ thống, quay lại thì mở lại.
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      final c = _ctrl;
      _ctrl = null;
      c?.dispose();
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed && _ctrl == null && _shot == null) {
      _open();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ctrl?.dispose();
    _flashAnim.dispose();
    _focusAnim.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    final c = _ctrl;
    if (c == null || !c.value.isInitialized || _busy || c.value.isTakingPicture) return;
    HapticFeedback.mediumImpact();
    setState(() => _busy = true);
    _flashAnim.forward(from: 0).then((_) => _flashAnim.reverse());
    try {
      final file = await c.takePicture();
      final raw = await file.readAsBytes();
      final size = MediaQuery.sizeOf(context);
      final mirror = widget.cameras[_camIndex].lensDirection == CameraLensDirection.front;
      final bytes = await compute(_cropJob, (raw, size.width / size.height, mirror));
      final dir = await getTemporaryDirectory();
      final name = 'IMG_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = '${dir.path}/$name';
      await File(path).writeAsBytes(bytes, flush: true);
      unawaited(File(file.path).delete().catchError((_) => File(file.path)));
      if (mounted) setState(() => _shot = CapturedPhoto(bytes, path, name));
    } catch (e) {
      if (mounted) showToast(context, 'Không chụp được ảnh: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _retake() {
    final p = _shot?.path;
    setState(() => _shot = null);
    if (p != null) File(p).delete().catchError((_) => File(p));
  }

  Future<void> _toggleFlash() async {
    final next = switch (_flash) {
      FlashMode.off => FlashMode.auto,
      FlashMode.auto => FlashMode.always,
      _ => FlashMode.off,
    };
    HapticFeedback.selectionClick();
    setState(() => _flash = next);
    await _ctrl?.setFlashMode(next).catchError((_) {});
  }

  Future<void> _switchCamera() async {
    if (widget.cameras.length < 2) return;
    HapticFeedback.selectionClick();
    final dir = widget.cameras[_camIndex].lensDirection;
    var i = widget.cameras.indexWhere((c) => c.lensDirection != dir);
    if (i < 0) i = (_camIndex + 1) % widget.cameras.length;
    _camIndex = i;
    await _open();
  }

  void _focus(TapUpDetails d, BoxConstraints box) {
    final c = _ctrl;
    if (c == null) return;
    final p = Offset((d.localPosition.dx / box.maxWidth).clamp(0, 1), (d.localPosition.dy / box.maxHeight).clamp(0, 1));
    c.setFocusPoint(p).catchError((_) {});
    c.setExposurePoint(p).catchError((_) {});
    setState(() => _focusAt = d.localPosition);
    _focusAnim.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return PopScope(
      canPop: _shot == null,
      onPopInvokedWithResult: (did, _) {
        if (!did && _shot != null) _retake();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            _preview(),
            // Chớp trắng khi bấm chụp
            IgnorePointer(
              child: FadeTransition(
                opacity: Tween(begin: 0.0, end: 0.55).animate(_flashAnim),
                child: const ColoredBox(color: Colors.white),
              ),
            ),
            // Ảnh vừa chụp: xem lại toàn màn hình
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOutCubic,
              child: _shot == null
                  ? const SizedBox.shrink()
                  : ColoredBox(
                      key: ValueKey(_shot!.path),
                      color: Colors.black,
                      child: Image.memory(_shot!.bytes, fit: BoxFit.cover, gaplessPlayback: true),
                    ),
            ),
            // Thanh trên
            Positioned(
              top: pad.top + 8,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  _RoundBtn(icon: Icons.close_rounded, tooltip: 'Đóng', onTap: () => _shot != null ? _retake() : Navigator.of(context).pop()),
                  const Spacer(),
                  AnimatedOpacity(
                    opacity: _shot == null ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: IgnorePointer(
                      ignoring: _shot != null,
                      child: _RoundBtn(
                        icon: switch (_flash) {
                          FlashMode.auto => Icons.flash_auto_rounded,
                          FlashMode.always => Icons.flash_on_rounded,
                          _ => Icons.flash_off_rounded,
                        },
                        tooltip: 'Đèn flash',
                        active: _flash != FlashMode.off,
                        onTap: _toggleFlash,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Thanh dưới
            Positioned(
              left: 0,
              right: 0,
              bottom: pad.bottom + 20,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                transitionBuilder: (c, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(a),
                    child: c,
                  ),
                ),
                child: _shot == null ? _shootBar() : _reviewBar(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _preview() {
    final c = _ctrl;
    if (c == null || !c.value.isInitialized) {
      return const Center(
        child: SizedBox.square(dimension: 28, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white54)),
      );
    }
    // previewSize là chiều ngang của cảm biến → khi cầm dọc thì đảo lại; phủ kín màn hình (cắt phần thừa)
    final ps = c.value.previewSize ?? const Size(1920, 1080);
    return LayoutBuilder(
      builder: (context, box) => GestureDetector(
        onTapUp: (d) => _focus(d, box),
        onScaleStart: (_) => _zoomStart = _zoom,
        onScaleUpdate: (d) {
          if (d.pointerCount < 2) return;
          final z = (_zoomStart * d.scale).clamp(_minZoom, _maxZoom);
          if ((z - _zoom).abs() < 0.01) return;
          setState(() => _zoom = z);
          c.setZoomLevel(z).catchError((_) {});
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRect(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(width: ps.height, height: ps.width, child: CameraPreview(c)),
              ),
            ),
            if (_focusAt != null)
              AnimatedBuilder(
                animation: _focusAnim,
                builder: (_, __) {
                  final t = _focusAnim.value;
                  final size = 86 - 22 * Curves.easeOutBack.transform((t * 2).clamp(0, 1));
                  return Positioned(
                    left: _focusAt!.dx - size / 2,
                    top: _focusAt!.dy - size / 2,
                    child: Opacity(
                      opacity: t < 0.75 ? 1 : (1 - (t - 0.75) * 4).clamp(0, 1),
                      child: Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFFFD54F), width: 1.6),
                        ),
                      ),
                    ),
                  );
                },
              ),
            if (_maxZoom > _minZoom + 0.05)
              Positioned(
                left: 0,
                right: 0,
                bottom: MediaQuery.paddingOf(context).bottom + 130,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _zoom > _minZoom + 0.05 ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                      child: Text(
                        '${_zoom.toStringAsFixed(1)}×',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _shootBar() => Padding(
    key: const ValueKey('shoot'),
    padding: const EdgeInsets.symmetric(horizontal: 32),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _RoundBtn(icon: Icons.photo_library_rounded, tooltip: 'Chọn từ thư viện', size: 50, onTap: () => Navigator.of(context).pop(CaptureUseGallery())),
        _Shutter(busy: _busy, onTap: _capture),
        Opacity(
          opacity: widget.cameras.length > 1 ? 1 : 0,
          child: _RoundBtn(icon: Icons.cameraswitch_rounded, tooltip: 'Đổi camera', size: 50, onTap: _switchCamera),
        ),
      ],
    ),
  );

  Widget _reviewBar() => Padding(
    key: const ValueKey('review'),
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white54),
              backgroundColor: Colors.black38,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _retake,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Chụp lại', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).pop(CaptureDone(_shot!));
            },
            icon: const Icon(Icons.check_rounded),
            label: const Text('Dùng ảnh', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    ),
  );
}

/// Nút chụp: vòng trắng, nhún khi bấm, hiện vòng xoay khi đang xử lý.
class _Shutter extends StatefulWidget {
  const _Shutter({required this.busy, required this.onTap});
  final bool busy;
  final VoidCallback onTap;

  @override
  State<_Shutter> createState() => _ShutterState();
}

class _ShutterState extends State<_Shutter> {
  bool _down = false;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Chụp',
    child: GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) {
        setState(() => _down = false);
        widget.onTap();
      },
      child: Container(
        width: 78,
        height: 78,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
        ),
        child: AnimatedScale(
          scale: _down ? 0.84 : 1,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: Container(
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
            child: widget.busy
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black54),
                  )
                : null,
          ),
        ),
      ),
    ),
  );
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({required this.icon, required this.tooltip, required this.onTap, this.size = 44, this.active = false});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final double size;
  final bool active;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: active ? const Color(0xFFFFD54F) : Colors.black45),
        child: Icon(icon, color: active ? Colors.black87 : Colors.white, size: size * 0.48),
      ),
    ),
  );
}
