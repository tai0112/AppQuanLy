import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'local_store.dart';

/// Giao diện ô lịch do người dùng cấu hình (lưu trong CaiDat.CauHinhThoiGianJson → khoá "calendar", đồng bộ giữa các máy).
/// Giá trị màu: 'auto' = theo giao diện, 'none' = không viền, hoặc mã '#RRGGBB'.
class CalendarLook {
  const CalendarLook({
    this.cellBorder = 'auto',
    this.todayBorder = 'auto',
    this.selectedBorder = 'auto',
    this.borderWidth = 1.0,
    this.saturdayColor = 'auto',
    this.sundayColor = 'auto',
  });

  final String cellBorder;
  final String todayBorder;
  final String selectedBorder;
  final double borderWidth;
  final String saturdayColor;
  final String sundayColor;

  static Map<String, dynamic> _root(LocalStore store) {
    final raw = store.all(E.appSettings).firstOrNull?['timeConfigJson'] as String?;
    if (raw == null) return {};
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  factory CalendarLook.of(LocalStore store) {
    final m = (_root(store)['calendar'] as Map?)?.cast<String, dynamic>() ?? {};
    return CalendarLook(
      cellBorder: m['cellBorder'] as String? ?? 'auto',
      todayBorder: m['todayBorder'] as String? ?? 'auto',
      selectedBorder: m['selectedBorder'] as String? ?? 'auto',
      borderWidth: (m['borderWidth'] as num?)?.toDouble() ?? 1.0,
      saturdayColor: m['saturdayColor'] as String? ?? 'auto',
      sundayColor: m['sundayColor'] as String? ?? 'auto',
    );
  }

  CalendarLook copyWith({String? cellBorder, String? todayBorder, String? selectedBorder, double? borderWidth, String? saturdayColor, String? sundayColor}) =>
      CalendarLook(
        cellBorder: cellBorder ?? this.cellBorder,
        todayBorder: todayBorder ?? this.todayBorder,
        selectedBorder: selectedBorder ?? this.selectedBorder,
        borderWidth: borderWidth ?? this.borderWidth,
        saturdayColor: saturdayColor ?? this.saturdayColor,
        sundayColor: sundayColor ?? this.sundayColor,
      );

  void save(LocalStore store) {
    final s = store.all(E.appSettings).firstOrNull ?? {};
    final root = _root(store)
      ..['calendar'] = {
        'cellBorder': cellBorder,
        'todayBorder': todayBorder,
        'selectedBorder': selectedBorder,
        'borderWidth': borderWidth,
        'saturdayColor': saturdayColor,
        'sundayColor': sundayColor,
      };
    store.put(E.appSettings, {...s, 'timeConfigJson': jsonEncode(root)});
  }

  static Color? _resolve(String v, Color? auto) => v == 'none'
      ? null
      : v == 'auto'
      ? auto
      : hexColor(v, auto ?? Colors.grey);

  // ---- Màu đã tính theo theme hiện tại
  Color? cellBorderColor(ColorScheme s) => _resolve(cellBorder, s.outlineVariant.withValues(alpha: 0.45));
  Color todayBorderColor(ColorScheme s) => _resolve(todayBorder, s.primary.withValues(alpha: 0.6)) ?? Colors.transparent;
  Color selectedBorderColor(ColorScheme s) => _resolve(selectedBorder, s.primary) ?? Colors.transparent;
  Color? saturday(ColorScheme s) => _resolve(saturdayColor, s.brightness == Brightness.dark ? const Color(0xFF8AB0FF) : const Color(0xFF3E63DD));
  Color? sunday(ColorScheme s) => _resolve(sundayColor, s.brightness == Brightness.dark ? const Color(0xFFFF7B7F) : AppColors.expense);

  /// Màu chữ theo thứ (null = màu chữ thường).
  Color? weekdayColor(int weekday, ColorScheme s) => weekday == DateTime.sunday
      ? sunday(s)
      : weekday == DateTime.saturday
      ? saturday(s)
      : null;
}

const _dow = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

/// Tiêu đề thứ trong tuần cho mọi lịch: chữ đậm, cuối tuần có màu, cột hôm nay được tô nổi.
Widget calendarDow(BuildContext context, DateTime day, CalendarLook look) {
  final scheme = Theme.of(context).colorScheme;
  final isTodayCol = day.weekday == DateTime.now().weekday;
  final color = isTodayCol ? scheme.onPrimary : (look.weekdayColor(day.weekday, scheme) ?? scheme.onSurfaceVariant);
  return Center(
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: isTodayCol ? scheme.primary : Colors.transparent, borderRadius: BorderRadius.circular(6)),
      child: Text(
        _dow[day.weekday - 1],
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.3, color: color),
      ),
    ),
  );
}
