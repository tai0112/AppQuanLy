import 'package:animations/animations.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// Bảng màu & theme. Màu chủ đạo cấu hình được trong Cài đặt.
class AppColors {
  static const expense = Color(0xFFE5484D);
  static const income = Color(0xFF30A46C);
  static const transfer = Color(0xFF3E63DD);
  static const warning = Color(0xFFF5A524);
  static const love = Color(0xFFE93D82);
  static const cycle = Color(0xFFD6409F);

  static const seeds = <Color>[
    Color(0xFF12A594),
    Color(0xFF3E63DD),
    Color(0xFF8E4EC6),
    Color(0xFFE93D82),
    Color(0xFFF76B15),
    Color(0xFF30A46C),
    Color(0xFF0090FF),
    Color(0xFF6E56CF),
  ];

  static const palette = <Color>[
    Color(0xFFE5484D),
    Color(0xFFF76B15),
    Color(0xFFFFC53D),
    Color(0xFF30A46C),
    Color(0xFF12A594),
    Color(0xFF0090FF),
    Color(0xFF3E63DD),
    Color(0xFF8E4EC6),
    Color(0xFFE93D82),
    Color(0xFF8D8D86),
    Color(0xFFAD7F58),
    Color(0xFF46A758),
  ];
}

Color hexColor(String? hex, [Color fallback = const Color(0xFF8D8D86)]) {
  if (hex == null || hex.isEmpty) return fallback;
  final h = hex.replaceAll('#', '');
  final v = int.tryParse(h.length == 6 ? 'FF$h' : h, radix: 16);
  return v == null ? fallback : Color(v);
}

String colorHex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// Màu "đồng hành" cho gradient: xoay nhẹ sắc độ và tối hơn chút (đẹp hơn trộn với tertiary).
Color accentOf(Color c, {double hue = 28, double light = -0.07}) {
  final h = HSLColor.fromColor(c);
  return h.withHue((h.hue + hue) % 360).withLightness((h.lightness + light).clamp(0.0, 1.0)).toColor();
}

/// Màu đậm cho thẻ "nổi bật" (thẻ số dư…): cùng sắc độ màu chủ đạo nhưng đủ đậm để chữ trắng rõ ở cả nền sáng lẫn tối.
Color heroOf(Color c) {
  final h = HSLColor.fromColor(c);
  return h.withLightness(0.36).withSaturation((h.saturation * 1.1).clamp(0.45, 0.9)).toColor();
}

/// Bo góc dùng chung toàn app (mềm, hiện đại).
class AppRadius {
  static const sm = 12.0, md = 16.0, lg = 22.0, xl = 28.0;
}

ThemeData buildTheme(Brightness brightness, Color seed) {
  final dark = brightness == Brightness.dark;
  // "fidelity": giữ đúng sắc độ màu chủ đạo người dùng chọn (tươi hơn tonalSpot mặc định)
  final base = ColorScheme.fromSeed(seedColor: seed, brightness: brightness, dynamicSchemeVariant: DynamicSchemeVariant.fidelity);
  // Nền & bề mặt pha nhẹ màu chủ đạo cho có chiều sâu, không bị xám phẳng
  final bg = dark ? Color.lerp(const Color(0xFF0C0E12), seed, 0.035)! : Color.lerp(const Color(0xFFF4F6FA), seed, 0.02)!;
  final scheme = base.copyWith(
    surface: bg,
    surfaceContainerLowest: dark ? Color.lerp(const Color(0xFF14171C), seed, 0.03) : Colors.white,
    surfaceContainerLow: dark ? Color.lerp(const Color(0xFF171A20), seed, 0.04) : Color.lerp(const Color(0xFFF9FAFC), seed, 0.02),
    surfaceContainer: dark ? Color.lerp(const Color(0xFF1A1E24), seed, 0.05) : Color.lerp(const Color(0xFFF1F3F7), seed, 0.03),
    surfaceContainerHigh: dark ? Color.lerp(const Color(0xFF1E2229), seed, 0.06) : Color.lerp(const Color(0xFFEBEEF3), seed, 0.04),
    surfaceContainerHighest: dark ? Color.lerp(const Color(0xFF262B33), seed, 0.07) : Color.lerp(const Color(0xFFE3E7EE), seed, 0.05),
    outlineVariant: dark ? const Color(0xFF2E333B) : const Color(0xFFDDE2EA),
  );
  final transitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: SharedAxisPageTransitionsBuilder(transitionType: SharedAxisTransitionType.horizontal, fillColor: bg),
      TargetPlatform.iOS: const CupertinoPageTransitionsBuilder(),
      TargetPlatform.linux: SharedAxisPageTransitionsBuilder(transitionType: SharedAxisTransitionType.horizontal, fillColor: bg),
      TargetPlatform.macOS: const CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: SharedAxisPageTransitionsBuilder(transitionType: SharedAxisTransitionType.horizontal, fillColor: bg),
    },
  );
  RoundedRectangleBorder r(double v) => RoundedRectangleBorder(borderRadius: BorderRadius.circular(v));
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    pageTransitionsTheme: transitions,
    scaffoldBackgroundColor: bg,
    // Không nháy sáng khi bấm: phản hồi bằng hiệu ứng thu nhỏ (Pressable) + rung nhẹ
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    splashColor: Colors.transparent,
    hoverColor: Colors.transparent,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: scheme.onSurface),
    ),
    cardTheme: CardThemeData(elevation: 0, margin: EdgeInsets.zero, color: scheme.surfaceContainerLowest, shape: r(AppRadius.lg)),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHigh,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 50),
        shape: r(AppRadius.md),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: const Size(64, 48), shape: r(AppRadius.md)),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(shape: r(AppRadius.sm))),
    floatingActionButtonTheme: FloatingActionButtonThemeData(shape: r(20), elevation: 3, highlightElevation: 6),
    segmentedButtonTheme: SegmentedButtonThemeData(style: SegmentedButton.styleFrom(shape: r(AppRadius.md))),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      side: BorderSide(color: scheme.outlineVariant),
    ),
    dialogTheme: DialogThemeData(shape: r(AppRadius.xl)),
    popupMenuTheme: PopupMenuThemeData(shape: r(AppRadius.md)),
    snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, shape: r(AppRadius.md)),
    listTileTheme: ListTileThemeData(shape: r(AppRadius.md)),
    switchTheme: SwitchThemeData(
      thumbIcon: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? const Icon(Icons.check_rounded, size: 14) : null),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      elevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primary.withValues(alpha: dark ? 0.22 : 0.14),
      indicatorShape: const StadiumBorder(),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(color: s.contains(WidgetState.selected) ? scheme.primary : scheme.onSurfaceVariant)),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 11.5,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? scheme.primary : scheme.onSurfaceVariant,
        ),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      showDragHandle: true,
      backgroundColor: scheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
    ),
  );
}

/// Bảng trượt từ dưới lên: mở chậm, mềm; đóng nhanh gọn.
const kSheetAnim = AnimationStyle(
  duration: Duration(milliseconds: 460),
  reverseDuration: Duration(milliseconds: 280),
  curve: Curves.easeOutCubic,
  reverseCurve: Curves.easeInCubic,
);
