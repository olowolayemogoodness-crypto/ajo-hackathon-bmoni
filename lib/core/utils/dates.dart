import 'package:intl/intl.dart';

class Dates {
  Dates._();

  static String short(DateTime d) => DateFormat('EEE d MMM').format(d);

  static String full(DateTime d) => DateFormat('d MMM yyyy, h:mm a').format(d);

  static int daysFromToday(DateTime d) {
    final t = DateTime.now();
    final a = DateTime.utc(t.year, t.month, t.day);
    final b = DateTime.utc(d.year, d.month, d.day);
    return b.difference(a).inDays;
  }

  static String relative(DateTime d) {
    final n = daysFromToday(d);
    if (n == 0) return 'today';
    if (n == 1) return 'tomorrow';
    if (n == -1) return 'yesterday';
    if (n > 1) return 'in $n days';
    return '${-n} days ago';
  }

  static String timeAgo(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
