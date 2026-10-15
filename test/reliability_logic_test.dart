import 'package:ajo/data/logic/reliability_logic.dart';
import 'package:ajo/data/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Obligation record(int round, {int? paidDay, bool paidLate = false}) {
    final due = DateTime(2026, 10, round);
    final obligation = Obligation(
      round: round,
      memberId: 'member',
      amountKobo: 500000,
      dueAt: due,
    );
    if (paidDay != null) {
      obligation.paidKobo = 500000;
      obligation.paidAt = DateTime(2026, 10, paidDay);
      obligation.paidLate = paidLate;
    }
    return obligation;
  }

  test('explains completion, timing, resolved delays and limited history', () {
    final indicator = ReliabilityLogic.calculate([
      record(1, paidDay: 1),
      record(2, paidDay: 2),
      record(3, paidDay: 5, paidLate: true),
      record(4),
    ], now: DateTime(2026, 10, 5));

    expect(indicator.historyLength, 4);
    expect(indicator.completed, 3);
    expect(indicator.completionPercent, 75);
    expect(indicator.onTime, 2);
    expect(indicator.delayed, 1);
    expect(indicator.resolvedMisses, 1);
    expect(indicator.averageDelayDays, 2);
    expect(indicator.hasLimitedHistory, isTrue);
    expect(indicator.summary, contains('3 of 4 contributions completed'));
    expect(indicator.uncertainty, contains('Limited history'));
  });
}
