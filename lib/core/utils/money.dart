import 'package:intl/intl.dart';

/// All money in Ajo is stored as integer kobo. Never use doubles for balances.
class Money {
  Money._();

  static final NumberFormat _f = NumberFormat('#,##0', 'en_US');

  static String fmt(int kobo) {
    final naira = kobo ~/ 100;
    final rem = kobo % 100;
    final base = '₦${_f.format(naira)}';
    if (rem == 0) return base;
    return '$base.${rem.toString().padLeft(2, '0')}';
  }

  static int toKobo(num naira) => (naira * 100).round();
}
