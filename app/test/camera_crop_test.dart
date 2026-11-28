// Ảnh chụp từ máy ảnh trong app được cắt đúng khung nhìn toàn màn hình (phần giữa), xoay đúng chiều EXIF, rộng tối đa 1600.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lht_money/features/camera_capture.dart';

void main() {
  const screen = 9 / 19.5; // màn điện thoại cầm dọc

  /// Ảnh dọc w×h: dải giữa (theo chiều cắt) màu đỏ, hai mép màu xanh.
  Uint8List shot(int w, int h, {int? orientation}) {
    final im = img.Image(width: w, height: h);
    img.fill(im, color: img.ColorRgb8(0, 0, 255));
    final keepW = (h * screen).round();
    img.fillRect(im, x1: (w - keepW) ~/ 2 + 4, y1: 0, x2: (w + keepW) ~/ 2 - 4, y2: h - 1, color: img.ColorRgb8(255, 0, 0));
    if (orientation != null) im.exif.imageIfd.orientation = orientation;
    return Uint8List.fromList(img.encodeJpg(im, quality: 95));
  }

  test('ảnh 3:4 (cảm biến 4:3 cầm dọc) → cắt hai bên còn đúng tỉ lệ màn hình, chỉ còn phần giữa', () {
    final out = img.decodeJpg(cropToAspect(shot(900, 1200), screen))!;
    expect(out.width / out.height, closeTo(screen, 0.01));
    expect(out.height, 1200);
    // Mép trái / phải sau khi cắt vẫn là màu đỏ (phần xanh hai bên đã bị bỏ)
    for (final x in [8, out.width - 9]) {
      final p = out.getPixel(x, out.height ~/ 2);
      expect(p.r, greaterThan(200), reason: 'x=$x');
      expect(p.b, lessThan(60), reason: 'x=$x');
    }
  });

  test('ảnh 9:16 (preset 1080p) → cắt ít, chiều cao giữ nguyên', () {
    final out = img.decodeJpg(cropToAspect(shot(1080, 1920), screen))!;
    expect(out.height, 1920);
    expect(out.width, (1920 * screen).round());
  });

  test('ảnh dài hơn màn hình → cắt trên dưới', () {
    final out = img.decodeJpg(cropToAspect(shot(400, 1200), screen))!;
    expect(out.width, 400);
    expect(out.width / out.height, closeTo(screen, 0.01));
  });

  test('ảnh lưu nằm ngang kèm EXIF xoay 90° → xoay lại thành dọc rồi mới cắt', () {
    final out = img.decodeJpg(cropToAspect(shot(1920, 1080, orientation: 6), screen))!;
    expect(out.height, greaterThan(out.width));
    expect(out.width / out.height, closeTo(screen, 0.01));
  });

  test('ảnh rất lớn → thu về rộng tối đa 1600', () {
    final out = img.decodeJpg(cropToAspect(shot(3000, 3000), 1.0))!;
    expect(out.width, 1600);
    expect(out.height, 1600);
  });
}
