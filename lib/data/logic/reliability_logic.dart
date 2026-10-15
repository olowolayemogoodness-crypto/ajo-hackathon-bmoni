import '../models/models.dart';

class ContributionReliability {
  const ContributionReliability({
    required this.historyLength,
    required this.completed,
    required this.onTime,
    required this.delayed,
    required this.resolvedMisses,
    required this.averageDelayDays,
  });

  final int historyLength;
  final int completed;
  final int onTime;
  final int delayed;
  final int resolvedMisses;
  final double averageDelayDays;

  int get completionPercent =>
      historyLength == 0 ? 0 : (completed * 100 / historyLength).round();

  bool get hasLimitedHistory => historyLength < 5;

  String get summary {
    if (historyLength == 0) return 'No completed contribution history yet.';
    final completion =
        '$completed of $historyLength contributions completed '
        '($completionPercent%).';
    final timing = delayed == 0
        ? '$onTime paid on time with no recorded delays.'
        : '$onTime paid on time; $delayed delayed by about '
              '${averageDelayDays.toStringAsFixed(averageDelayDays % 1 == 0 ? 0 : 1)} '
              '${averageDelayDays == 1 ? 'day' : 'days'} on average.';
    final resolved = resolvedMisses == 0
        ? ''
        : ' $resolvedMisses late ${resolvedMisses == 1 ? 'payment was' : 'payments were'} later resolved.';
    return '$completion $timing$resolved';
  }

  String get uncertainty => hasLimitedHistory
      ? 'Limited history: this indicator may change as more rounds are recorded.'
      : 'Based on $historyLength recorded contribution periods.';
}

class ReliabilityLogic {
  ReliabilityLogic._();

  static ContributionReliability calculate(
    Iterable<Obligation> obligations, {
    required DateTime now,
  }) {
    final considered = obligations.where((o) => !o.dueAt.isAfter(now)).toList();
    var completed = 0;
    var onTime = 0;
    var delayed = 0;
    var delayDays = 0;

    for (final obligation in considered) {
      if (!obligation.isPaid) continue;
      completed++;
      final paidAt = obligation.paidAt;
      final wasLate =
          obligation.paidLate ||
          (paidAt != null && paidAt.isAfter(obligation.dueAt));
      if (!wasLate) {
        onTime++;
        continue;
      }
      delayed++;
      if (paidAt != null) {
        final delay = paidAt.difference(obligation.dueAt);
        final days = (delay.inMinutes / Duration.minutesPerDay).ceil();
        delayDays += days < 1 ? 1 : days;
      } else {
        delayDays++;
      }
    }

    return ContributionReliability(
      historyLength: considered.length,
      completed: completed,
      onTime: onTime,
      delayed: delayed,
      resolvedMisses: delayed,
      averageDelayDays: delayed == 0 ? 0 : delayDays / delayed,
    );
  }
}
