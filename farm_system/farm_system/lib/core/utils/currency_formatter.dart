import 'package:intl/intl.dart';

/// All money in this system is stored as an integer number of
/// Tanzanian Shillings (no fractional cents in practice for farm work).
/// Centralising formatting means every screen shows money identically.
class CurrencyFormatter {
  CurrencyFormatter._();

  static final NumberFormat _formatter = NumberFormat.decimalPattern('en_US');

  static String format(num amount) {
    final rounded = amount.round();
    final sign = rounded < 0 ? '-' : '';
    return '${sign}TSh ${_formatter.format(rounded.abs())}';
  }

  /// Formats a signed adjustment, e.g. "+TSh 500" or "-TSh 500".
  static String formatSigned(num amount) {
    final rounded = amount.round();
    final sign = rounded > 0 ? '+' : (rounded < 0 ? '-' : '');
    return '${sign}TSh ${_formatter.format(rounded.abs())}';
  }

  static String plain(num amount) => _formatter.format(amount.round());
}
