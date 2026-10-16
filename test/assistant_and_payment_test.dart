import 'package:ajo/data/assistant/assistant_engine.dart';
import 'package:ajo/data/models/models.dart';
import 'package:ajo/data/store/ajo_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final store = AjoStore.instance;

  setUp(store.resetDemo);

  test('assistant answers every core question from the shared demo ledger', () {
    expect(
      AssistantEngine.reply('Who receives next payout?', store, pidgin: false),
      contains('Round 4 for you'),
    );
    expect(
      AssistantEngine.reply(
        'How much have I contributed?',
        store,
        pidgin: false,
      ),
      contains('₦15,000'),
    );
    expect(
      AssistantEngine.reply('Am I behind?', store, pidgin: false),
      contains('Overdue'),
    );
    expect(
      AssistantEngine.reply(
        'When is my next payment due?',
        store,
        pidgin: false,
      ),
      contains('Round 4'),
    );
    expect(
      AssistantEngine.reply(
        'This week\'s circle summary',
        store,
        pidgin: false,
      ),
      allOf(contains('₦45,000'), contains('₦50,000')),
    );
  });

  test(
    'sandbox confirmation updates once and ignores a duplicate callback',
    () async {
      final obligation = store.obligationOf(store.currentRound, 'me')!;
      final intent = await store.startPayment(obligation);

      await store.confirmPayment(intent, obligation);
      final confirmedEvents = store.events
          .where((event) => event.type == 'payment_confirmed')
          .length;
      await store.confirmPayment(intent, obligation);

      expect(obligation.paidKobo, obligation.amountKobo);
      expect(obligation.pendingKobo, 0);
      expect(
        store.events.where((event) => event.type == 'payment_confirmed').length,
        confirmedEvents,
      );
    },
  );

  test('payout stays processing until explicitly simulated as settled', () {
    final payout = store.currentPayout!;
    payout.status = PayoutStatus.awaitingApproval;

    store.approvePayout();

    expect(payout.status, PayoutStatus.processing);
    expect(store.events.where((event) => event.type == 'payout_settled'), isEmpty);

    store.simulatePayoutSettlement();

    expect(payout.status, PayoutStatus.settled);
    expect(payout.reference, startsWith('AJO-DEMO-PO-'));
    expect(
      store.events.where((event) => event.type == 'payout_settled'),
      hasLength(1),
    );
  });
}
