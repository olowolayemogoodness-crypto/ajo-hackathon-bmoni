import 'package:ajo/data/logic/ledger_logic.dart';
import 'package:ajo/data/mock/seed_data.dart';
import 'package:ajo/data/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 15, 12);

  Obligation obligation({
    int round = 4,
    DateTime? dueAt,
    int paidKobo = 0,
    int pendingKobo = 0,
  }) {
    final result = Obligation(
      round: round,
      memberId: 'me',
      amountKobo: 500000,
      dueAt: dueAt ?? DateTime(2026, 10, 15),
    );
    result.paidKobo = paidKobo;
    result.pendingKobo = pendingKobo;
    return result;
  }

  test('classifies all six PRD ledger statuses', () {
    expect(
      LedgerLogic.statusFor(obligation(round: 5), currentRound: 4, now: now),
      ObligationStatus.upcoming,
    );
    expect(
      LedgerLogic.statusFor(obligation(), currentRound: 4, now: now),
      ObligationStatus.awaitingPayment,
    );
    expect(
      LedgerLogic.statusFor(
        obligation(paidKobo: 500000),
        currentRound: 4,
        now: now,
      ),
      ObligationStatus.paid,
    );
    expect(
      LedgerLogic.statusFor(
        obligation(paidKobo: 200000),
        currentRound: 4,
        now: now,
      ),
      ObligationStatus.partiallyPaid,
    );
    expect(
      LedgerLogic.statusFor(
        obligation(dueAt: DateTime(2026, 10, 14)),
        currentRound: 4,
        now: now,
      ),
      ObligationStatus.overdue,
    );
    expect(
      LedgerLogic.statusFor(
        obligation(pendingKobo: 500000),
        currentRound: 4,
        now: now,
      ),
      ObligationStatus.underReview,
    );
  });

  test('seed has ten members and exactly one current overdue contribution', () {
    final seed = DemoSeed.build(now: now);
    final current = seed.obligations
        .where((item) => item.round == seed.currentRound)
        .toList();
    final statuses = current
        .map(
          (item) => LedgerLogic.statusFor(
            item,
            currentRound: seed.currentRound,
            now: now,
          ),
        )
        .toList();

    expect(seed.members, hasLength(10));
    expect(current, hasLength(10));
    expect(current.every((item) => item.amountKobo == 500000), isTrue);
    expect(
      statuses.where((status) => status == ObligationStatus.overdue),
      hasLength(1),
    );
    expect(current.singleWhere((item) => !item.isPaid).memberId, 'me');
  });
}
