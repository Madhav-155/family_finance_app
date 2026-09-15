import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

abstract final class IstTime {
  static late final tz.Location _location;
  static bool _initialized = false;

  static void initialize() {
    if (_initialized) return;
    tz.initializeTimeZones();
    _location = tz.getLocation('Asia/Kolkata');
    _initialized = true;
  }

  static tz.TZDateTime now() {
    initialize();
    return tz.TZDateTime.now(_location);
  }

  static tz.TZDateTime fromInstant(DateTime instant) {
    initialize();
    return tz.TZDateTime.from(instant.toUtc(), _location);
  }

  static tz.TZDateTime at({
    required int year,
    required int month,
    required int day,
    int hour = 0,
    int minute = 0,
  }) {
    initialize();
    return tz.TZDateTime(_location, year, month, day, hour, minute);
  }

  static DateTime dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static DateTime dateOnlyFromStoredInstant(DateTime instant) {
    final ist = fromInstant(instant);
    return DateTime(ist.year, ist.month, ist.day);
  }

  static String formatDateOnly(DateTime value) =>
      DateFormat('yyyy-MM-dd').format(dateOnly(value));

  static bool isCurrentMonth(DateTime financeDate, {DateTime? nowInstant}) {
    final current = nowInstant == null ? now() : fromInstant(nowInstant);
    return financeDate.year == current.year &&
        financeDate.month == current.month;
  }

  static bool isToday(DateTime financeDate, {DateTime? nowInstant}) {
    final current = nowInstant == null ? now() : fromInstant(nowInstant);
    return financeDate.year == current.year &&
        financeDate.month == current.month &&
        financeDate.day == current.day;
  }

  static String formatInstant(DateTime instant) =>
      DateFormat('d MMM, h:mm a').format(fromInstant(instant));
}
