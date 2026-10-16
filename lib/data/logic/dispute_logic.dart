import '../models/models.dart';

class DisputeError implements Exception {
  const DisputeError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Disputes only move a record to "Under review" and attach a reason.
/// They never touch payouts, payout order or membership.
class DisputeLogic {
  DisputeLogic._();

  static const minReasonLength = 10;
  static const maxReasonLength = 300;

  static String? validateReason(String reason) {
    final r = reason.trim();
    if (r.length < minReasonLength) {
      return 'Tell the organiser what looks wrong (at least $minReasonLength characters).';
    }
    if (r.length > maxReasonLength) {
      return 'Keep the reason under $maxReasonLength characters.';
    }
    return null;
  }

  static bool canDispute(Obligation o, {required int currentRound}) =>
      o.round <= currentRound && !o.isDisputed;

  static void open(
    Obligation o, {
    required String reason,
    required DateTime now,
    required int currentRound,
  }) {
    if (!canDispute(o, currentRound: currentRound)) {
      throw const DisputeError('This record cannot be disputed right now.');
    }
    final problem = validateReason(reason);
    if (problem != null) throw DisputeError(problem);
    o.underReview = true;
    o.disputeReason = reason.trim();
    o.disputedAt = now;
  }

  static void resolve(Obligation o) {
    o.underReview = false;
    o.disputeReason = null;
    o.disputedAt = null;
  }
}
