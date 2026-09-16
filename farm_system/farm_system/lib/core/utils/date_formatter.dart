import 'package:intl/intl.dart';

class DateFormatter {
  DateFormatter._();

  static final _dmy = DateFormat('dd/MM/yyyy');
  static final _dmyHm = DateFormat('dd/MM/yyyy HH:mm');
  static final _time = DateFormat('HH:mm');

  static String date(DateTime dt) => _dmy.format(dt);
  static String dateTime(DateTime dt) => _dmyHm.format(dt);
  static String time(DateTime dt) => _time.format(dt);

  static String relative(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'} ago';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    }
    return date(dt);
  }

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool isToday(DateTime dt) => isSameDay(dt, DateTime.now());

  static bool isYesterday(DateTime dt) =>
      isSameDay(dt, DateTime.now().subtract(const Duration(days: 1)));

  static bool isThisWeek(DateTime dt) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeekMidnight =
        DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    return dt.isAfter(startOfWeekMidnight) ||
        isSameDay(dt, startOfWeekMidnight);
  }

  static bool isThisMonth(DateTime dt) {
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month;
  }
}
