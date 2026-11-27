import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../core/ui.dart';

/// Kết quả lấy vị trí hiện tại gồm địa chỉ và tọa độ GPS.
class LocationResult {
  const LocationResult({required this.address, required this.latitude, required this.longitude});
  final String address;
  final double latitude;
  final double longitude;
}

/// Lấy vị trí hiện tại (tọa độ + địa chỉ reverse geocoding, an toàn cả khi offline / web).
Future<LocationResult?> fetchCurrentLocation(BuildContext context) async {
  try {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      if (context.mounted) showToast(context, 'Vui lòng bật dịch vụ vị trí (GPS)', error: true);
      return null;
    }

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      if (context.mounted) {
        showToast(context, perm == LocationPermission.deniedForever ? 'Quyền vị trí đang bị chặn trong Cài đặt' : 'Chưa được cấp quyền vị trí', error: true);
      }
      return null;
    }

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 10)),
    );

    String address = '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
    if (!kIsWeb) {
      try {
        final marks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
        if (marks.isNotEmpty) {
          final p = marks.first;
          final parts = <String>[
            if (p.street != null && p.street!.trim().isNotEmpty) p.street!.trim(),
            if (p.subLocality != null && p.subLocality!.trim().isNotEmpty) p.subLocality!.trim(),
            if (p.locality != null && p.locality!.trim().isNotEmpty) p.locality!.trim(),
            if (p.administrativeArea != null && p.administrativeArea!.trim().isNotEmpty) p.administrativeArea!.trim(),
          ];
          final seen = <String>{};
          final unique = parts.where((x) => seen.add(x)).toList();
          if (unique.isNotEmpty) address = unique.join(', ');
        }
      } catch (_) {}
    }

    return LocationResult(address: address, latitude: pos.latitude, longitude: pos.longitude);
  } catch (e) {
    if (context.mounted) showToast(context, 'Không lấy được vị trí hiện tại', error: true);
    return null;
  }
}

/// Lấy vị trí hiện tại một cách lặng lẽ (dùng khi tự gắn vị trí cho giao dịch mới): không hiện thông báo, lỗi gì cũng trả null.
/// [mayAsk] = được phép hiện hộp thoại xin quyền (chỉ nên cho lần đầu; bị từ chối thì thôi, không hỏi lại).
/// [onAsked] được gọi khi đã thực sự hỏi quyền, để nơi gọi ghi nhớ.
Future<LocationResult?> fetchLocationSilently({required bool mayAsk, VoidCallback? onAsked}) async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied && mayAsk) {
      onAsked?.call();
      perm = await Geolocator.requestPermission();
    }
    if (perm != LocationPermission.always && perm != LocationPermission.whileInUse) return null;

    Position? pos;
    if (!kIsWeb) {
      pos = await Geolocator.getLastKnownPosition();
      // Vị trí cũ quá 10 phút thì lấy mới (người dùng có thể đã đi chỗ khác).
      if (pos != null && DateTime.now().difference(pos.timestamp).inMinutes > 10) pos = null;
    }
    pos ??= await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 8)),
    );
    return LocationResult(address: await _addressOf(pos), latitude: pos.latitude, longitude: pos.longitude);
  } catch (_) {
    return null;
  }
}

/// Địa chỉ dạng "đường, phường, quận, tỉnh" từ toạ độ; không tra được (offline / web) thì trả toạ độ.
Future<String> _addressOf(Position pos) async {
  final fallback = '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
  if (kIsWeb) return fallback;
  try {
    final marks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
    if (marks.isEmpty) return fallback;
    final p = marks.first;
    final seen = <String>{};
    final parts = [
      p.street,
      p.subLocality,
      p.locality,
      p.administrativeArea,
    ].whereType<String>().map((s) => s.trim()).where((s) => s.isNotEmpty && seen.add(s));
    return parts.isEmpty ? fallback : parts.join(', ');
  } catch (_) {
    return fallback;
  }
}

/// Lấy địa chỉ hiện tại dạng chuỗi (tương thích ngược).
Future<String?> fetchCurrentLocationText(BuildContext context) async => (await fetchCurrentLocation(context))?.address;

/// Nút lấy vị trí hiện tại kèm vòng quay loading.
class GpsIconButton extends StatefulWidget {
  const GpsIconButton({super.key, this.onPicked, this.onPickedResult, this.tooltip = 'Lấy vị trí hiện tại'});
  final ValueChanged<String>? onPicked;
  final ValueChanged<LocationResult>? onPickedResult;
  final String tooltip;

  @override
  State<GpsIconButton> createState() => _GpsIconButtonState();
}

class _GpsIconButtonState extends State<GpsIconButton> {
  bool _loading = false;

  Future<void> _tap() async {
    if (_loading) return;
    setState(() => _loading = true);
    final res = await fetchCurrentLocation(context);
    if (!mounted) return;
    setState(() => _loading = false);
    if (res != null) {
      widget.onPickedResult?.call(res);
      widget.onPicked?.call(res.address);
      showToast(context, 'Đã lấy vị trí hiện tại');
    }
  }

  @override
  Widget build(BuildContext context) => _loading
      ? const Padding(
          padding: EdgeInsets.all(12),
          child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
        )
      : IconButton(
          tooltip: widget.tooltip,
          onPressed: _tap,
          icon: Icon(Icons.my_location_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
        );
}
