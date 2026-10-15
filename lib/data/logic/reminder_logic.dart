import '../../core/utils/dates.dart';
import '../../core/utils/money.dart';
import '../models/models.dart';

enum ReminderKind { dueSoon, overdue, paidThisWeek }

class ContributionReminder {
  const ContributionReminder({required this.kind, required this.message});

  final ReminderKind kind;
  final String message;
}

class ReminderLogic {
  ReminderLogic._();

  static ContributionReminder? forObligation(
    Obligation obligation, {
    required DateTime now,
    DateTime? nextDueAt,
  }) {
    if (obligation.isPaid) {
      final next = nextDueAt == null
          ? ''
          : ' Your next scheduled contribution is on ${Dates.short(nextDueAt)}.';
      return ContributionReminder(
        kind: ReminderKind.paidThisWeek,
        message: 'You have contributed this week.$next',
      );
    }

    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(
      obligation.dueAt.year,
      obligation.dueAt.month,
      obligation.dueAt.day,
    );
    final days = due.difference(today).inDays;
    if (days < 0) {
      return const ContributionReminder(
        kind: ReminderKind.overdue,
        message: 'Your contribution deadline has passed. Please update your payment status or contact your circle organiser.',
      );
    }
    if (days <= 1) {
      final when = days == 0 ? 'today' : 'tomorrow';
      return ContributionReminder(
        kind: ReminderKind.dueSoon,
        message:
            'Your ${Money.fmt(obligation.remainingKobo)} contribution is due $when.',
      );
    }
    return null;
  }
}
