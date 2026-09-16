import 'package:intl/intl.dart';

final NumberFormat _money =
    NumberFormat('#,##0', 'en_US');
final NumberFormat _area = NumberFormat('#,##0.######', 'en_US');
final NumberFormat _litres = NumberFormat('#,##0.##', 'en_US');
final NumberFormat _quantity = NumberFormat('#,##0.##', 'en_US');

/// Formats a value as a TSh amount, e.g. 4500 -> "TSh 4,500".
String fmtMoney(num value) => 'TSh ${_money.format(value)}';

String fmtMoneyPlain(num value) => _money.format(value);

String fmtArea(num value) => '${_area.format(value)} m²';

String fmtLitres(num value) => '${_litres.format(value)} L';

String fmtQuantity(num value) => _quantity.format(value);

String fmtSigned(num value) =>
    value < 0 ? '-${_money.format(value.abs())}' : '+${_money.format(value)}';

String fmtNumber(num value) => _quantity.format(value);

/// Human friendly relative time e.g. "2 minutes ago".
String timeAgo(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'} ago';
  if (diff.inHours < 24) return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
  if (diff.inDays < 30) return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
  return '${dt.day}/${dt.month}/${dt.year}';
}

String fmtDate(DateTime dt) => '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

String fmtDateShort(DateTime dt) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${dt.day} ${months[dt.month - 1]}';
}

String fmtDateTime(DateTime dt) =>
    '${fmtDate(dt)} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

DateTime dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

/// Returns true when [dt] lands inside the range (inclusive).
bool inRange(DateTime dt, DateTime from, DateTime to) {
  final d = dateOnly(dt);
  final f = dateOnly(from);
  final t = dateOnly(to);
  return (d.isAfter(f) || d.isAtSameMomentAs(f)) &&
      (d.isBefore(t) || d.isAtSameMomentAs(t));
}

bool isSameDate(DateTime a, DateTime b) {
  final x = dateOnly(a);
  final y = dateOnly(b);
  return x.isAtSameMomentAs(y);
}