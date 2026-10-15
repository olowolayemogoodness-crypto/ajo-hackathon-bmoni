enum IntentStatus { submitted, confirmed, failed }

class PaymentIntent {
  PaymentIntent({
    required this.id,
    required this.idempotencyKey,
    required this.amountKobo,
    required this.reference,
    this.status = IntentStatus.submitted,
  });

  final String id;
  final String idempotencyKey;
  final int amountKobo;
  final String reference;
  IntentStatus status;
}

/// Payments sit behind this interface. The prototype uses MockPaymentsAdapter;
/// a BMONI sandbox adapter can emit the same events later without touching the UI.
abstract class PaymentsAdapter {
  String get name;

  Future<PaymentIntent> createIntent({
    required String idempotencyKey,
    required String memberId,
    required int round,
    required int amountKobo,
  });

  Future<PaymentIntent> confirm(PaymentIntent intent);
}
