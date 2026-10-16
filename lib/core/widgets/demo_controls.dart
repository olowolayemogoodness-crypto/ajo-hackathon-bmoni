import 'package:flutter/material.dart';

import '../../data/models/models.dart';
import '../../data/store/ajo_store.dart';
import '../utils/money.dart';
import '../theme/app_colors.dart';
import 'section_card.dart';

/// Lets a judge drive the whole story without waiting for real people.
class DemoControls extends StatelessWidget {
  const DemoControls({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AjoStore.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final payout = s.currentPayout!;
        final unpaid = s
            .unpaid(s.currentRound)
            .where((o) => !o.memberId.startsWith('me'))
            .toList();
        final actions = <Widget>[];

        for (final o in unpaid) {
          actions.add(
            _btn(
              'Simulate ${s.member(o.memberId).name} paying ${Money.fmt(o.remainingKobo)}',
              Icons.payments_rounded,
              () => s.simulateMemberPays(o.memberId),
            ),
          );
        }
        if (payout.status == PayoutStatus.awaitingApproval) {
          actions.add(
            _btn(
              'Organizer approves payout',
              Icons.verified_rounded,
              s.approvePayout,
            ),
          );
        }
        if (payout.status == PayoutStatus.processing) {
          actions.add(
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text('Sending payout……'),
            ),
          );
        }
        if (s.canAdvance) {
          actions.add(
            _btn(
              'Start Round ${s.currentRound + 1}',
              Icons.skip_next_rounded,
              s.advanceRound,
            ),
          );
        }
        if (actions.isEmpty) {
          actions.add(const Text('Nothing to do right now.'));
        }

        return SectionCard(
          color: AppColors.goldLight.withValues(alpha: 0.5),
          borderColor: AppColors.gold.withValues(alpha: 0.4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Organiser tools', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                'Record what other members do so the ledger, pot and payout update.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: actions),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: s.resetDemo,
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: const Text('Reset circle'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.warningDark,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _btn(String label, IconData icon, VoidCallback onTap) {
    return FilledButton.tonalIcon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primaryDark,
        side: const BorderSide(color: AppColors.border),
      ),
    );
  }
}
