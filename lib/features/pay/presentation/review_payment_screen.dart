import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/confetti.dart';
import '../../../core/widgets/demo_badge.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/section_card.dart';
import '../../../data/models/models.dart';
import '../../../data/payments/payments_adapter.dart';
import '../../../data/store/ajo_store.dart';

enum _ReviewStage { ready, submitting, confirming, confirmed, error }

class ReviewPaymentScreen extends StatefulWidget {
  const ReviewPaymentScreen({super.key});

  @override
  State<ReviewPaymentScreen> createState() => _ReviewPaymentScreenState();
}

class _ReviewPaymentScreenState extends State<ReviewPaymentScreen> {
  final AjoStore _store = AjoStore.instance;
  late final Obligation? _obligation = _store.myNextObligation;
  _ReviewStage _stage = _ReviewStage.ready;
  PaymentIntent? _intent;
  int _confirmedAmount = 0;

  bool get _busy =>
      _stage == _ReviewStage.submitting || _stage == _ReviewStage.confirming;

  Future<void> _confirm() async {
    final obligation = _obligation;
    if (obligation == null || _busy || obligation.isPaid) return;
    _confirmedAmount = obligation.remainingKobo;
    setState(() => _stage = _ReviewStage.submitting);
    try {
      final intent = await _store.startPayment(obligation);
      if (!mounted) return;
      setState(() {
        _intent = intent;
        _stage = _ReviewStage.confirming;
      });
      await _store.confirmPayment(intent, obligation);
      if (!mounted) return;
      setState(() => _stage = _ReviewStage.confirmed);
    } catch (_) {
      if (!mounted) return;
      setState(() => _stage = _ReviewStage.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          automaticallyImplyLeading: !_busy,
          title: const Text(
            'Review simulated payment',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        body: Stack(
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: _body(),
              ),
            ),
            if (_stage == _ReviewStage.confirmed)
              const Positioned.fill(child: ConfettiBurst()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    final obligation = _obligation;
    if (obligation == null) {
      return Center(
        child: PrimaryButton(
          label: 'Back to home',
          onPressed: () => context.go('/home'),
        ),
      );
    }
    switch (_stage) {
      case _ReviewStage.ready:
      case _ReviewStage.error:
        return _review(obligation);
      case _ReviewStage.submitting:
        return _progress(
          'Submitting to Ajo Sandbox…',
          'Creating one idempotent simulated transaction.',
        );
      case _ReviewStage.confirming:
        return _progress(
          'Awaiting sandbox confirmation…',
          'The ledger stays under review until confirmation arrives.',
          reference: _intent?.reference,
        );
      case _ReviewStage.confirmed:
        return _success(obligation);
    }
  }

  Widget _review(Obligation obligation) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DemoBadge(),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: AppColors.heroGradient,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sandbox contribution',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.82)),
              ),
              const SizedBox(height: 6),
              Text(
                Money.fmt(obligation.remainingKobo),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '${_store.circleName} · Round ${obligation.round}',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          child: Column(
            children: [
              _row('Contribution', Money.fmt(obligation.remainingKobo)),
              _row('Fee', '₦0'),
              _row('Due date', Dates.short(obligation.dueAt)),
              const Divider(color: AppColors.border),
              _row('Total', Money.fmt(obligation.remainingKobo), bold: true),
              _row('Pay with', _store.payments.name),
            ],
          ),
        ),
        if (_stage == _ReviewStage.error) ...[
          const SizedBox(height: 12),
          const Text(
            'The simulation did not confirm. No real money moved; you can safely retry.',
            style: TextStyle(
              color: AppColors.warning,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const Spacer(),
        const Text(
          'By confirming, you create a simulated ledger entry only. Retrying the same payment will not create a duplicate.',
          style: TextStyle(color: AppColors.muted, height: 1.4, fontSize: 12.5),
        ),
        const SizedBox(height: 12),
        PrimaryButton(
          label: 'Confirm simulated payment',
          icon: Icons.lock_rounded,
          onPressed: _confirm,
        ),
      ],
    );
  }

  Widget _progress(String title, String subtitle, {String? reference}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 24),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, height: 1.4),
          ),
          if (reference != null) ...[
            const SizedBox(height: 14),
            Text('Reference: $reference'),
          ],
        ],
      ),
    );
  }

  Widget _success(Obligation obligation) {
    return Column(
      children: [
        const Spacer(),
        const Icon(
          Icons.check_circle_rounded,
          color: AppColors.primary,
          size: 96,
        ),
        const SizedBox(height: 16),
        const Text(
          'Sandbox payment confirmed',
          style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text(
          'The contribution ledger and reliability facts are now updated.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 20),
        SectionCard(
          child: Column(
            children: [
              _row('Amount', Money.fmt(_confirmedAmount)),
              _row('Round', '${obligation.round}'),
              _row('Reference', _intent?.reference ?? '—'),
              _row('Status', 'Paid', bold: true),
            ],
          ),
        ),
        const Spacer(),
        PrimaryButton(
          label: 'Back to dashboard',
          onPressed: () => context.go('/home'),
        ),
      ],
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: AppColors.muted)),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
                fontSize: bold ? 16 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
