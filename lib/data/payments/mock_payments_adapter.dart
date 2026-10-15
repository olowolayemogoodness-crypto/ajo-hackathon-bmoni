import 'payments_adapter.dart';

class MockPaymentsAdapter implements PaymentsAdapter {
  final Map<String, PaymentIntent> _byKey = {};

  @override
  String get name => 'Ajo Sandbox (mock)';

  @override
  Future<PaymentIntent> createIntent({
    required String idempotencyKey,
    required String memberId,
    required int round,
    required int amountKobo,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    // Same idempotency key -> same intent. Retrying never double-charges.
    return _byKey.putIfAbsent(idempotencyKey, () {
      final ms = DateTime.now().millisecondsSinceEpoch;
      return PaymentIntent(
        id: 'pi_$ms',
        idempotencyKey: idempotencyKey,
        amountKobo: amountKobo,
        reference: 'AJO-${ms % 1000000}',
      );
    });
  }

  @override
  Future<PaymentIntent> confirm(PaymentIntent intent) async {
    await Future<void>.delayed(const Duration(milliseconds: 1800));
    intent.status = IntentStatus.confirmed;
    return intent;
  }
}
