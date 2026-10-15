import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/confetti.dart';
import '../../../core/widgets/demo_badge.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/section_card.dart';
import '../../../data/models/models.dart';
import '../../../data/payments/payments_adapter.dart';
import '../../../data/store/ajo_store.dart';

enum _Stage { review, submitting, submitted, confirmed, error }

class PayScreen extends StatefulWidget {
  const PayScreen({super.key});

  @override
  State<PayScreen> createState() => _PayScreenState();
}

class _PayScreenState extends State<PayScreen> {
  final AjoStore _s = AjoStore.instance;
  late final Obligation? _ob = _s.myNextObligation;
  _Stage _stage = _Stage.review;
  PaymentIntent? _intent;
  int _amount = 0;

  Future<void> _pay() async {
    final ob = _ob;
    if (ob == null) return;
    _amount = ob.remainingKobo;
    setState(() => _stage = _Stage.submitting);
    try {
      final intent = await _s.startPayment(ob);
      if (!mounted) return;
      setState(() {
        _intent = intent;
        _stage = _Stage.submitted;
      });
      await _s.confirmPayment(intent, ob);
      if (!mounted) return;
      setState(() => _stage = _Stage.confirmed);
    } catch (_) {
      if (!mounted) return;
      setState(() => _stage = _Stage.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _stage == _Stage.submitting || _stage == _Stage.submitted;
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Review payment'),
          leading: busy
              ? const SizedBox.shrink()
              : IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => context.pop(),
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
            if (_stage == _Stage.confirmed)
              const Positioned.fill(child: ConfettiBurst()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    final ob = _ob;
    if (ob == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              size: 56,
              color: AppColors.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Nothing to pay right now',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            PrimaryButton(label: 'Back', onPressed: () => context.pop()),
          ],
        ),
      );
    }
    switch (_stage) {
      case _Stage.review:
      case _Stage.error:
        return _review(ob);
      case _Stage.submitting:
        return _status(
          title: 'Sending your payment…',
          subtitle: 'Hang tight, this only takes a moment.',
          loader: true,
        );
      case _Stage.submitted:
        return _status(
          title: 'Payment submitted',
          subtitle:
              'Awaiting confirmation. Ajo only marks you as paid once it\'s confirmed.',
          loader: true,
          reference: _intent?.reference,
        );
      case _Stage.confirmed:
        return _done(ob);
    }
  }

  Widget _review(Obligation ob) {
    final early = ob.round > _s.currentRound;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                early ? 'Paying early' : 'You\'re paying',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.88),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                Money.fmt(ob.remainingKobo),
                style: context.type.moneyDisplay.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                '${_s.circleName} · Round ${ob.round}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          child: Column(
            children: [
              _row('Contribution', Money.fmt(ob.remainingKobo)),
              _row('Due date', Dates.short(ob.dueAt)),
              _row('Fee', '₦0'),
              const Divider(color: AppColors.border),
              _row('Total', Money.fmt(ob.remainingKobo), bold: true),
              const SizedBox(height: 4),
              _row('Pay with', 'Ajo Sandbox Wallet'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_stage == _Stage.error)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warningLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.error_rounded,
                  color: AppColors.warningDark,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'That didn\'t go through. You haven\'t been charged — try again.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.warningDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const Spacer(),
        const Center(child: DemoBadge()),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Prototype — no real money moves.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
          ),
        ),
        const SizedBox(height: 12),
        PrimaryButton(
          label: 'Pay ${Money.fmt(ob.remainingKobo)}',
          icon: Icons.lock_rounded,
          onPressed: _pay,
        ),
      ],
    );
  }

  Widget _status({
    required String title,
    required String subtitle,
    required bool loader,
    String? reference,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 84,
            height: 84,
            child: CircularProgressIndicator(
              strokeWidth: 6,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
          if (reference != null) ...[
            const SizedBox(height: 16),
            Text(
              'Ref: $reference',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _done(Obligation ob) {
    return Column(
      children: [
        const Spacer(),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 700),
          curve: Curves.elasticOut,
          builder: (context, v, child) =>
              Transform.scale(scale: v, child: child),
          child: Container(
            width: 104,
            height: 104,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 64,
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Payment confirmed!',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 6),
        Text(
          'You\'re all set for Round ${ob.round}.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 22),
        SectionCard(
          child: Column(
            children: [
              _row('Amount', Money.fmt(_amount)),
              _row('Round', '${ob.round}'),
              _row('Reference', _intent?.reference ?? '-'),
              _row('Time', Dates.full(DateTime.now())),
            ],
          ),
        ),
        const Spacer(),
        PrimaryButton(label: 'Done', onPressed: () => context.pop()),
      ],
    );
  }

  Widget _row(String k, String v, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            k,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
          Flexible(
            child: Text(
              v,
              textAlign: TextAlign.right,
              style: v.startsWith('₦')
                  ? (bold ? context.type.moneyTitle : context.type.moneyBody)
                  : (bold
                        ? Theme.of(context).textTheme.titleMedium
                        : Theme.of(context).textTheme.titleSmall),
            ),
          ),
        ],
      ),
    );
  }
}
