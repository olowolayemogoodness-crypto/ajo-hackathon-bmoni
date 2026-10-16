import 'models.dart';

/// How the payout order of a circle is decided. It is shown to every member
/// before they join and it is never changed by reliability or disputes.
enum PayoutOrderMode { manual, randomised }

extension PayoutOrderModeLabel on PayoutOrderMode {
  String get label {
    switch (this) {
      case PayoutOrderMode.manual:
        return 'Set by the organiser';
      case PayoutOrderMode.randomised:
        return 'Randomised draw';
    }
  }

  String get description {
    switch (this) {
      case PayoutOrderMode.manual:
        return 'The organiser chose the order. Everyone sees it before joining.';
      case PayoutOrderMode.randomised:
        return 'The order was drawn once from a fixed seed. Everyone sees the same order before joining.';
    }
  }
}

/// Preset missed-payment policies. None of them reorders payouts or removes a
/// member automatically.
enum MissedPaymentPolicy { reminderThenReview, holdPayout, organiserDecides }

extension MissedPaymentPolicyText on MissedPaymentPolicy {
  String get label {
    switch (this) {
      case MissedPaymentPolicy.reminderThenReview:
        return 'Reminder, then organiser review';
      case MissedPaymentPolicy.holdPayout:
        return 'Hold the payout until the pot is full';
      case MissedPaymentPolicy.organiserDecides:
        return 'Organiser agrees a plan with the member';
    }
  }

  String get description {
    switch (this) {
      case MissedPaymentPolicy.reminderThenReview:
        return 'A private reminder goes out first. If the contribution is still unpaid after the grace period, the organiser reviews it with the member.';
      case MissedPaymentPolicy.holdPayout:
        return 'The round\'s payout is held until every contribution is in. Nobody is paid short.';
      case MissedPaymentPolicy.organiserDecides:
        return 'The organiser talks to the member and agrees a plan. The payout order never changes automatically.';
    }
  }
}

/// The full rule set a member reviews and accepts before joining a circle.
class CircleRules {
  const CircleRules({
    required this.name,
    required this.description,
    required this.amountKobo,
    required this.memberCount,
    required this.frequency,
    required this.startDate,
    required this.endDate,
    required this.payoutMode,
    required this.payoutOrder,
    required this.deadlineDay,
    required this.graceDays,
    required this.missedPolicy,
    required this.approvalRequired,
    this.randomSeed = 0,
  });

  final String name;
  final String description;
  final int amountKobo;
  final int memberCount;
  final Frequency frequency;
  final DateTime startDate;
  final DateTime endDate;
  final PayoutOrderMode payoutMode;

  /// Slot numbers (1..memberCount). Index 0 is the first cycle's recipient.
  final List<int> payoutOrder;

  /// 1-7 (Mon-Sun) for weekly/biweekly, 1-28 (day of month) for monthly.
  final int deadlineDay;
  final int graceDays;
  final MissedPaymentPolicy missedPolicy;
  final bool approvalRequired;
  final int randomSeed;
}
