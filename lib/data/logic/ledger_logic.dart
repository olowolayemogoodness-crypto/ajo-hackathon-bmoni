import '../models/models.dart';

class LedgerLogic {
  LedgerLogic._();

  static ObligationStatus statusFor(
    Obligation obligation, {
    required int currentRound,
    required DateTime now,
  }) {
    if (obligation.underReview || obligation.pendingKobo > 0) {
      return ObligationStatus.underReview;
    }
    if (obligation.isPaid) return ObligationStatus.paid;
    if (obligation.paidKobo > 0) return ObligationStatus.partiallyPaid;
    if (obligation.round > currentRound) return ObligationStatus.upcoming;

    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(
      obligation.dueAt.year,
      obligation.dueAt.month,
      obligation.dueAt.day,
    );
    if (due.isBefore(today)) return ObligationStatus.overdue;
    return ObligationStatus.awaitingPayment;
  }
}
