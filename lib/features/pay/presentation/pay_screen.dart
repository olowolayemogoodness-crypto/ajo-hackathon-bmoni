import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/demo_badge.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/section_card.dart';
import '../../../data/store/ajo_store.dart';

class PayScreen extends StatelessWidget {
  const PayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AjoStore.instance;
    final obligation = store.myNextObligation;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Make a contribution',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: obligation == null
              ? _NothingDue(onBack: () => context.pop())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const DemoBadge(),
                    const SizedBox(height: 14),
                    Text(
                      Money.fmt(obligation.remainingKobo),
                      style: const TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${store.circleName} · Round ${obligation.round}',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 20),
                    SectionCard(
                      child: Column(
                        children: [
                          _row('Expected', Money.fmt(obligation.amountKobo)),
                          _row('Received', Money.fmt(obligation.paidKobo)),
                          _row(
                            'Outstanding',
                            Money.fmt(obligation.remainingKobo),
                            bold: true,
                          ),
                          const Divider(color: AppColors.border),
                          _row('Due date', Dates.short(obligation.dueAt)),
                          _row('Method', 'Ajo Sandbox Wallet'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const SectionCard(
                      color: AppColors.skyLight,
                      borderColor: Color(0xFFBFDDF3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.science_rounded, color: AppColors.sky),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Simulation only. No bank account is charged and no real money moves.',
                              style: TextStyle(height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    PrimaryButton(
                      label: 'Continue to review',
                      icon: Icons.arrow_forward_rounded,
                      onPressed: () => context.push('/pay/review'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _NothingDue extends StatelessWidget {
  const _NothingDue({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.task_alt_rounded,
            size: 64,
            color: AppColors.primary,
          ),
          const SizedBox(height: 12),
          const Text(
            'Nothing to pay right now',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 24),
          PrimaryButton(label: 'Back', onPressed: onBack),
        ],
      ),
    );
  }
}

Widget _row(String label, String value, {bool bold = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: AppColors.muted)),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
            fontSize: bold ? 16 : 14,
          ),
        ),
      ],
    ),
  );
}
