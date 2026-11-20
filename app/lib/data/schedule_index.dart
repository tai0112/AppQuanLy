import '../core/format.dart';
import 'local_store.dart';
import 'logic.dart';
import 'models.dart';

/// Chỉ mục lịch trình — dựng MỘT lần mỗi khi dữ liệu đổi (theo LocalStore.version) rồi dùng lại cho mọi ô lịch / thẻ.
///
/// Trước đây mỗi ô ngày của lịch tháng duyệt lại toàn bộ lịch trình + tính lặp lại (42 ô × 400 lịch ≈ 17.000 lần/khung hình).
/// Nay: mỗi tháng chỉ duyệt lịch trình 1 lần, chia sẵn theo ngày; hoạt động / ảnh / người tham gia nhóm sẵn theo lịch trình.
class ScheduleIndex {
  ScheduleIndex._(this._store) : version = _key(_store);

  static const _deps = [E.events, E.eventItems, E.eventPhotos, E.eventParticipants];
  static String _key(LocalStore s) => s.versionKey(_deps);

  static ScheduleIndex? _cache;

  /// Lấy chỉ mục hiện tại (tự dựng lại khi dữ liệu đã thay đổi).
  static ScheduleIndex of(LocalStore store) {
    final c = _cache;
    if (c != null && identical(c._store, store) && c.version == _key(store)) return c;
    return _cache = ScheduleIndex._(store);
  }

  final LocalStore _store;
  final String version;

  late final List<EventRec> events = _store.all(E.events).map(EventRec.new).toList();

  /// Lịch theo ngày, tính theo từng "cửa sổ tháng" (đầu tháng −7 ngày → cuối tháng +14 ngày) khi được hỏi tới.
  final _windows = <int, Map<DateTime, List<(DateTime, EventRec)>>>{};

  List<(DateTime, EventRec)> on(DateTime day) {
    final d = dateOnly(day);
    final key = d.year * 12 + d.month;
    final bucket = _windows.putIfAbsent(
      key,
      () => _build(DateTime(d.year, d.month, 1).subtract(const Duration(days: 7)), DateTime(d.year, d.month + 1, 1).add(const Duration(days: 14))),
    );
    return bucket[d] ?? const [];
  }

  Map<DateTime, List<(DateTime, EventRec)>> _build(DateTime from, DateTime to) {
    final m = <DateTime, List<(DateTime, EventRec)>>{};
    void put(DateTime day, (DateTime, EventRec) v) => (m[day] ??= []).add(v);
    for (final e in events) {
      for (final o in Recurrence.occurrences(e, from, to)) {
        final start = dateOnly(o);
        put(start, (o, e));
        // Lịch nhiều ngày (không lặp): hiện ở mọi ngày nó kéo dài qua
        final end = e.endAt;
        if (e.rrule == null && end != null) {
          var d = start.add(const Duration(days: 1));
          final last = dateOnly(end);
          var guard = 0;
          while (!d.isAfter(last) && d.isBefore(to) && guard++ < 60) {
            if (!d.isBefore(from)) put(d, (o, e));
            d = d.add(const Duration(days: 1));
          }
        }
      }
    }
    for (final list in m.values) {
      list.sort((a, b) => a.$1.compareTo(b.$1));
    }
    return m;
  }

  /// Hoạt động theo giờ nhóm theo lịch trình.
  late final Map<String, List<EventItemRec>> _items = () {
    final m = <String, List<EventItemRec>>{};
    for (final it in _store.all(E.eventItems).map(EventItemRec.new)) {
      (m[it.eventId] ??= []).add(it);
    }
    return m;
  }();

  List<EventItemRec> itemsOn(String eventId, DateTime day) {
    final iso = Fmt.isoDate(day);
    final list = (_items[eventId] ?? const <EventItemRec>[]).where((i) => i.occurrenceDate == null || i.occurrenceDate == iso).toList()
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    return list;
  }

  late final Map<String, List<EventPhoto>> _photos = () {
    final m = <String, List<EventPhoto>>{};
    for (final p in _store.all(E.eventPhotos).map(EventPhoto.new)) {
      (m[p.eventId] ??= []).add(p);
    }
    return m;
  }();

  List<EventPhoto> photosOf(String eventId) => _photos[eventId] ?? const [];

  late final Set<String> _shared = _store.all(E.eventParticipants).map((p) => p['eventId'] as String).toSet();

  bool isShared(String eventId) => _shared.contains(eventId);
}
