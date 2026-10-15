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
      final sequence = _byKey.length + 1;
      return PaymentIntent(
        id: 'pi_demo_$sequence',
        idempotencyKey: idempotencyKey,
        amountKobo: amountKobo,
        reference: 'AJO-SANDBOX-${sequence.toString().padLeft(4, '0')}',
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
