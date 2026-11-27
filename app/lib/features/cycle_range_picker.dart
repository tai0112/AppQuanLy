import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';

/// Lịch tháng chọn khoảng ngày kỳ kinh ngay trong bảng ghi:
/// - BẤM ngày bắt đầu rồi KÉO tới ngày kết thúc (dải tô liền theo ngón tay);
/// - hoặc chạm ngày bắt đầu, rồi chạm ngày kết thúc;
/// - chạm lại một ngày khác khi đã có đủ 2 đầu → chọn lại từ đầu.
/// [end] = null nghĩa là "đang diễn ra" (chưa có ngày kết thúc): hiện dải mờ dự kiến [expectedDays] ngày.
class CycleRangePicker extends StatefulWidget {
  const CycleRangePicker({
    super.key,
    required this.start,
    required this.end,
    required this.color,
    required this.onChanged,
    this.firstDayOfWeek = 1,
    this.expectedDays = 5,
    this.otherDays = const {},
  });

  final DateTime start;
  final DateTime? end;
  final Color color;
  final void Function(DateTime start, DateTime? end) onChanged;

  /// 1 = Thứ 2 … 7 = Chủ nhật.
  final int firstDayOfWeek;
  final int expectedDays;

  /// Ngày thuộc các kỳ khác đã ghi (đánh dấu chấm nhỏ để tránh ghi trùng).
  final Set<DateTime> otherDays;

  @override
  State<CycleRangePicker> createState() => _CycleRangePickerState();
}

class _CycleRangePickerState extends State<CycleRangePicker> {
  late DateTime _month = DateTime(widget.start.year, widget.start.month);
  int _dir = 1;

  // Trạng thái thao tác
  DateTime? _down; // ngày đặt ngón tay
  bool _moved = false;
  bool _awaitEnd = false; // vừa chạm ngày bắt đầu → lần chạm sau là ngày kết thúc
  DateTime? _lastHover;

  static const _rowH = 44.0;

  static DateTime _d(DateTime x) => DateTime(x.year, x.month, x.day);

  List<DateTime> _cells() {
    final first = DateTime(_month.year, _month.month);
    final shift = (first.weekday - widget.firstDayOfWeek + 7) % 7;
    final start = first.subtract(Duration(days: shift));
    final weeks = ((shift + DateUtils.getDaysInMonth(_month.year, _month.month)) / 7).ceil();
    return [for (var i = 0; i < weeks * 7; i++) DateTime(start.year, start.month, start.day + i)];
  }

  DateTime? _dayAt(Offset p, double width, List<DateTime> cells) {
    final col = (p.dx / (width / 7)).floor();
    final row = (p.dy / _rowH).floor();
    if (col < 0 || col > 6 || row < 0) return null;
    final i = row * 7 + col;
    return i < cells.length ? cells[i] : null;
  }

  void _goMonth(int delta) => setState(() {
    _dir = delta.sign;
    _month = DateTime(_month.year, _month.month + delta);
  });

  void _emit(DateTime a, DateTime? b) {
    if (b != null && b.isBefore(a)) (a, b) = (b, a);
    widget.onChanged(a, b);
  }

  void _onDown(DateTime? d) {
    if (d == null) return;
    _down = d;
    _moved = false;
    _lastHover = d;
  }

  void _onMove(DateTime? d) {
    final down = _down;
    if (d == null || down == null || d == _lastHover) return;
    _lastHover = d;
    _moved = true;
    HapticFeedback.selectionClick();
    _awaitEnd = false;
    _emit(down, d); // kéo: dải từ ngày đặt tay tới ngày đang chạm
  }

  void _onUp() {
    final d = _down;
    _down = null;
    if (d == null || _moved) return;
    HapticFeedback.selectionClick();
    // Chạm (không kéo)
    if (_awaitEnd && !d.isBefore(widget.start)) {
      _awaitEnd = false;
      _emit(widget.start, d);
    } else {
      _awaitEnd = true;
      _emit(d, null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = widget.color;
    final cells = _cells();
    final s = _d(widget.start);
    final e = widget.end == null ? null : _d(widget.end!);
    final expectedEnd = s.add(Duration(days: widget.expectedDays - 1));
    final today = _d(DateTime.now());

    bool inRange(DateTime d) => !d.isBefore(s) && !d.isAfter(e ?? s);
    bool inExpected(DateTime d) => e == null && d.isAfter(s) && !d.isAfter(expectedEnd);

    final dows = [for (var i = 0; i < 7; i++) Fmt.weekdaysShort[(widget.firstDayOfWeek - 1 + i) % 7]];

    return Column(
      children: [
        // Tháng: ‹ Tháng 11, 2026 ›
        Row(
          children: [
            IconButton(visualDensity: VisualDensity.compact, onPressed: () => _goMonth(-1), icon: const Icon(Icons.chevron_left_rounded)),
            Expanded(
              child: ClipRect(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  transitionBuilder: (child, a) {
                    final incoming = child.key == ValueKey(_month);
                    return FadeTransition(
                      opacity: a,
                      child: SlideTransition(
                        position: Tween(begin: Offset((incoming ? 0.3 : -0.3) * _dir, 0), end: Offset.zero).animate(a),
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    'Tháng ${_month.month}, ${_month.year}',
                    key: ValueKey(_month),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
              ),
            ),
            IconButton(visualDensity: VisualDensity.compact, onPressed: () => _goMonth(1), icon: const Icon(Icons.chevron_right_rounded)),
          ],
        ),
        Row(
          children: [
            for (final (i, w) in dows.indexed)
              Expanded(
                child: Center(
                  child: Text(
                    w,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: (widget.firstDayOfWeek - 1 + i) % 7 == 6 ? Colors.red.shade400 : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth;
            final cellW = w / 7;
            return AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              // Thắng ngay mọi cử chỉ trong vùng lịch (không để bảng / vùng cuộn giành mất thao tác kéo chọn ngày).
              child: RawGestureDetector(
                gestures: {EagerGestureRecognizer: GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(EagerGestureRecognizer.new, (_) {})},
                child: Listener(
                  onPointerDown: (ev) => _onDown(_dayAt(ev.localPosition, w, cells)),
                  onPointerMove: (ev) => _onMove(_dayAt(ev.localPosition, w, cells)),
                  onPointerUp: (_) => _onUp(),
                  onPointerCancel: (_) => _down = null,
                  child: SizedBox(
                    height: cells.length / 7 * _rowH,
                    child: Stack(
                      children: [
                        for (final (i, d) in cells.indexed)
                          Positioned(
                            left: (i % 7) * cellW,
                            top: (i ~/ 7) * _rowH,
                            width: cellW,
                            height: _rowH,
                            child: _Cell(
                              day: d,
                              outside: d.month != _month.month,
                              today: d == today,
                              selected: inRange(d),
                              isStart: d == s,
                              isEnd: d == (e ?? s),
                              expected: inExpected(d),
                              joinLeft:
                                  (inRange(d) && inRange(d.subtract(const Duration(days: 1))) && i % 7 != 0) ||
                                  (inExpected(d) &&
                                      (inExpected(d.subtract(const Duration(days: 1))) || d.subtract(const Duration(days: 1)) == s) &&
                                      i % 7 != 0),
                              joinRight:
                                  (inRange(d) && inRange(d.add(const Duration(days: 1))) && i % 7 != 6) ||
                                  ((inExpected(d) || d == s) && e == null && inExpected(d.add(const Duration(days: 1))) && i % 7 != 6),
                              other: widget.otherDays.contains(d),
                              color: c,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.day,
    required this.outside,
    required this.today,
    required this.selected,
    required this.isStart,
    required this.isEnd,
    required this.expected,
    required this.joinLeft,
    required this.joinRight,
    required this.other,
    required this.color,
  });

  final DateTime day;
  final bool outside, today, selected, isStart, isEnd, expected, joinLeft, joinRight, other;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final edge = isStart || isEnd;
    // Dải nền nối liền giữa các ngày trong khoảng
    final band = selected || expected;
    final bandColor = selected ? color.withValues(alpha: 0.22) : color.withValues(alpha: 0.08);
    return Stack(
      alignment: Alignment.center,
      children: [
        if (band)
          Positioned.fill(
            top: 5,
            bottom: 5,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              decoration: BoxDecoration(
                color: bandColor,
                borderRadius: BorderRadius.horizontal(left: Radius.circular(joinLeft ? 0 : 17), right: Radius.circular(joinRight ? 0 : 17)),
              ),
            ),
          ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: selected && edge ? color : Colors.transparent,
            shape: BoxShape.circle,
            border: today && !(selected && edge) ? Border.all(color: color, width: 1.5) : null,
            boxShadow: selected && edge ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 2))] : null,
          ),
          alignment: Alignment.center,
          child: Text(
            '${day.day}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected || today ? FontWeight.w800 : FontWeight.w500,
              color: selected && edge
                  ? Colors.white
                  : outside
                  ? scheme.onSurfaceVariant.withValues(alpha: 0.4)
                  : selected
                  ? color
                  : null,
            ),
          ),
        ),
        if (other && !selected)
          Positioned(
            bottom: 4,
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.6), shape: BoxShape.circle),
            ),
          ),
      ],
    );
  }
}
