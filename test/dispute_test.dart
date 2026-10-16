import 'package:ajo/data/logic/dispute_logic.dart';
import 'package:ajo/data/models/models.dart';
import 'package:ajo/data/store/ajo_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final store = AjoStore.instance;

  setUp(() => store.resetDemo());

  List<String> payoutOrder() => store.payouts.map((p) => p.recipientId).toList();
  List<PayoutStatus> payoutStatuses() =>
      store.payouts.map((p) => p.status).toList();

  const reason = 'I paid by transfer on Friday morning';

  test('disputing a record moves it to under review', () {
    final record = store.obligationOf(store.currentRound, 'me')!;
    expect(store.statusOf(record), ObligationStatus.overdue);

    store.openDispute(round: record.round, memberId: 'me', reason: reason);

    expect(store.statusOf(record), ObligationStatus.underReview);
    expect(record.isDisputed, isTrue);
    expect(record.disputeReason, reason);
    expect(record.disputedAt, isNotNull);
    expect(store.disputedRecords, contains(record));
  });

  test('a dispute never changes payout order or payout status', () {
    final orderBefore = payoutOrder();
    final statusesBefore = payoutStatuses();

    store.openDispute(
      round: store.currentRound,
      memberId: 'me',
      reason: reason,
    );

    expect(payoutOrder(), orderBefore);
    expect(payoutStatuses(), statusesBefore);
    expect(store.members.where((m) => m.isMe), hasLength(1));
    expect(store.members, hasLength(10));
  });

  test('the reliability indicator treats a disputed record as unresolved', () {
    final before = store.reliabilityOf('me');
    final missedBefore = store.historyOf('me').missed;

    store.openDispute(
      round: store.currentRound,
      memberId: 'me',
      reason: reason,
    );
    final after = store.reliabilityOf('me');

    expect(after.unresolvedDisputes, 1);
    expect(after.historyLength, before.historyLength - 1);
    expect(after.completed, before.completed);
    expect(after.completionPercent, greaterThanOrEqualTo(before.completionPercent));
    expect(after.summary, contains('under review'));

    final history = store.historyOf('me');
    expect(history.marks[store.currentRound - 1].mark, Mark.underReview);
    expect(history.missed, missedBefore);
  });

  test('a reason is required and is validated', () {
    final record = store.obligationOf(store.currentRound, 'me')!;

    expect(
      () => store.openDispute(round: record.round, memberId: 'me', reason: 'bad'),
      throwsA(isA<DisputeError>()),
    );
    expect(record.isDisputed, isFalse);
    expect(DisputeLogic.validateReason('   '), isNotNull);
    expect(DisputeLogic.validateReason(reason), isNull);
  });

  test('only records up to the current round can be disputed, once', () {
    expect(
      () => store.openDispute(
        round: store.currentRound + 3,
        memberId: 'me',
        reason: reason,
      ),
      throwsA(isA<DisputeError>()),
    );

    store.openDispute(round: store.currentRound, memberId: 'me', reason: reason);
    expect(
      () => store.openDispute(
        round: store.currentRound,
        memberId: 'me',
        reason: reason,
      ),
      throwsA(isA<DisputeError>()),
    );
  });

  test('the organiser can resolve a dispute without touching payouts', () {
    final orderBefore = payoutOrder();
    final record = store.obligationOf(store.currentRound, 'me')!;
    store.openDispute(round: record.round, memberId: 'me', reason: reason);

    store.resolveDispute(record.round, 'me');

    expect(record.isDisputed, isFalse);
    expect(store.disputedRecords, isEmpty);
    expect(store.statusOf(record), ObligationStatus.overdue);
    expect(payoutOrder(), orderBefore);
  });
}
