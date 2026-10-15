import 'dart:math';

import '../models/circle_rules.dart';
import '../models/models.dart';

/// Raw values from the create-circle form. Nullable fields are "not filled in".
class CircleRulesDraft {
  const CircleRulesDraft({
    this.name = '',
    this.description = '',
    this.amountKobo,
    this.memberCount = 0,
    this.frequency = Frequency.weekly,
    this.startDate,
    this.endDate,
    this.payoutMode = PayoutOrderMode.randomised,
    this.payoutOrder = const [],
    this.randomSeed = 0,
    this.deadlineDay = 5,
    this.graceDays = 0,
    this.missedPolicy = MissedPaymentPolicy.reminderThenReview,
    this.approvalRequired = false,
  });

  final String name;
  final String description;
  final int? amountKobo;
  final int memberCount;
  final Frequency frequency;
  final DateTime? startDate;
  final DateTime? endDate;
  final PayoutOrderMode payoutMode;
  final List<int> payoutOrder;
  final int randomSeed;
  final int deadlineDay;
  final int graceDays;
  final MissedPaymentPolicy missedPolicy;
  final bool approvalRequired;
}

class CircleRulesLogic {
  CircleRulesLogic._();

  static const maxMembers = 30;
  static const maxGraceDays = 14;

  static const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  /// Returns field -> message. Empty means the draft is valid.
  static Map<String, String> validate(CircleRulesDraft d) {
    final errors = <String, String>{};

    if (d.name.trim().isEmpty) {
      errors['name'] = 'Give your circle a name.';
    } else if (d.name.trim().length > 60) {
      errors['name'] = 'Keep the name under 60 characters.';
    }
    if (d.description.trim().length > 280) {
      errors['description'] = 'Keep the description under 280 characters.';
    }

    final amount = d.amountKobo;
    if (amount == null || amount <= 0) {
      errors['amount'] = 'Enter a contribution amount greater than ₦0.';
    }

    if (d.memberCount < 2) {
      errors['members'] = 'A circle needs at least 2 members.';
    } else if (d.memberCount > maxMembers) {
      errors['members'] = 'A circle can have up to $maxMembers members.';
    }

    if (d.startDate == null) {
      errors['start'] = 'Pick a start date.';
    }
    if (d.endDate == null) {
      errors['end'] = 'Pick an expected end date.';
    } else if (d.startDate != null && !d.endDate!.isAfter(d.startDate!)) {
      errors['end'] = 'The end date must be after the start date.';
    }

    if (d.graceDays < 0) {
      errors['grace'] = 'The grace period cannot be negative.';
    } else if (d.graceDays > maxGraceDays) {
      errors['grace'] = 'The grace period can be at most $maxGraceDays days.';
    }

    final maxDeadline = d.frequency == Frequency.monthly ? 28 : 7;
    if (d.deadlineDay < 1 || d.deadlineDay > maxDeadline) {
      errors['deadline'] = d.frequency == Frequency.monthly
          ? 'Choose a day between 1 and 28.'
          : 'Choose a weekday.';
    }

    if (d.payoutMode == PayoutOrderMode.manual &&
        !isValidOrder(d.payoutOrder, d.memberCount)) {
      errors['order'] = 'Set a payout position for every member.';
    }

    return errors;
  }

  static bool isValidOrder(List<int> order, int memberCount) {
    if (memberCount < 1 || order.length != memberCount) return false;
    final sorted = [...order]..sort();
    for (var i = 0; i < sorted.length; i++) {
      if (sorted[i] != i + 1) return false;
    }
    return true;
  }

  /// Builds immutable rules from a valid draft. Throws if the draft is invalid.
  static CircleRules build(CircleRulesDraft d) {
    final errors = validate(d);
    if (errors.isNotEmpty) {
      throw ArgumentError('Invalid circle rules: ${errors.values.join(' ')}');
    }
    final order = d.payoutMode == PayoutOrderMode.randomised
        ? randomisedOrder(d.memberCount, d.randomSeed)
        : List<int>.unmodifiable(d.payoutOrder);
    return CircleRules(
      name: d.name.trim(),
      description: d.description.trim(),
      amountKobo: d.amountKobo!,
      memberCount: d.memberCount,
      frequency: d.frequency,
      startDate: d.startDate!,
      endDate: d.endDate!,
      payoutMode: d.payoutMode,
      payoutOrder: order,
      randomSeed: d.randomSeed,
      deadlineDay: d.deadlineDay,
      graceDays: d.graceDays,
      missedPolicy: d.missedPolicy,
      approvalRequired: d.approvalRequired,
    );
  }

  /// Deterministic: the same seed always yields the same order, so every
  /// member sees the same draw.
  static List<int> randomisedOrder(int count, int seed) {
    final order = List<int>.generate(count, (i) => i + 1);
    order.shuffle(Random(seed));
    return List<int>.unmodifiable(order);
  }

  /// Contribution deadlines, one per cycle (a cycle ends with one payout).
  static List<DateTime> schedule({
    required DateTime start,
    required Frequency frequency,
    required int deadlineDay,
    required int cycles,
  }) {
    final s = DateTime(start.year, start.month, start.day);
    DateTime first;
    if (frequency == Frequency.monthly) {
      var candidate = DateTime(s.year, s.month, deadlineDay);
      if (candidate.isBefore(s)) {
        candidate = DateTime(s.year, s.month + 1, deadlineDay);
      }
      first = candidate;
    } else {
      final diff = (deadlineDay - s.weekday) % 7;
      first = DateTime(s.year, s.month, s.day + diff);
    }
    return [
      for (var i = 0; i < cycles; i++)
        frequency == Frequency.monthly
            ? DateTime(first.year, first.month + i, first.day)
            : DateTime(first.year, first.month, first.day + i * frequency.days),
    ];
  }

  static List<DateTime> scheduleFor(CircleRules r) => schedule(
        start: r.startDate,
        frequency: r.frequency,
        deadlineDay: r.deadlineDay,
        cycles: r.memberCount,
      );

  static DateTime graceEnd(DateTime deadline, int graceDays) =>
      DateTime(deadline.year, deadline.month, deadline.day + graceDays);

  /// What one member owes over the whole circle: amount x cycles.
  static int totalObligationKobo(CircleRules r) => r.amountKobo * r.memberCount;

  static String deadlineLabel(CircleRules r) {
    switch (r.frequency) {
      case Frequency.weekly:
        return 'Every ${weekdays[r.deadlineDay - 1]}';
      case Frequency.biweekly:
        return 'Every other ${weekdays[r.deadlineDay - 1]}';
      case Frequency.monthly:
        return 'Day ${r.deadlineDay} of each month';
    }
  }

  /// Rules for circles that were created without any (for example synthetic
  /// open circles in seed data), so the review-and-accept step always works.
  static CircleRules fallbackFor(DraftCircle c, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final seed = c.code.codeUnits.fold<int>(7, (a, b) => (a * 31 + b) & 0x7fffffff);
    final start = DateTime(today.year, today.month, today.day + 3);
    final deadlineDay = c.frequency == Frequency.monthly ? 25 : DateTime.friday;
    final dates = schedule(
      start: start,
      frequency: c.frequency,
      deadlineDay: deadlineDay,
      cycles: c.size,
    );
    return CircleRules(
      name: c.name,
      description: 'A savings circle organised by ${c.organizer}.',
      amountKobo: c.amountKobo,
      memberCount: c.size,
      frequency: c.frequency,
      startDate: start,
      endDate: dates.last,
      payoutMode: PayoutOrderMode.randomised,
      payoutOrder: randomisedOrder(c.size, seed),
      randomSeed: seed,
      deadlineDay: deadlineDay,
      graceDays: 2,
      missedPolicy: MissedPaymentPolicy.reminderThenReview,
      approvalRequired: false,
    );
  }
}
