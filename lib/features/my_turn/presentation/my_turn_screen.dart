import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/demo_controls.dart';
import '../../../core/widgets/member_avatar.dart';
import '../../../core/widgets/reveal.dart';
import '../../../core/widgets/section_card.dart';
import '../../../data/models/models.dart';
import '../../../data/store/ajo_store.dart';

class MyTurnScreen extends StatelessWidget {
  const MyTurnScreen({super.key});

  static const _steps = [
    'Collecting contributions',
    'Pot is full',
    'Organizer approval',
    'Sending to you',
    'Paid out',
  ];

  int _stepIndex(PayoutStatus st) {
    switch (st) {
      case PayoutStatus.scheduled:
      case PayoutStatus.held:
        return 0;
      case PayoutStatus.awaitingApproval:
        return 2;
      case PayoutStatus.processing:
        return 3;
      case PayoutStatus.settled:
        return 4;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AjoStore.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final mine = s.myPayout;
        final live = mine.round == s.currentRound;
        final upcoming = mine.round > s.currentRound;
        final done = mine.status == PayoutStatus.settled;
        final held = live && mine.status == PayoutStatus.held;

        return SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            children: [
              Reveal(
                child: Text(
                  'My Turn',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
              ),
              const SizedBox(height: 14),
              Reveal(
                index: 1,
                child: _Hero(
                  store: s,
                  mine: mine,
                  upcoming: upcoming,
                  done: done,
                ),
              ),
              const SizedBox(height: 14),
              if (held) Reveal(index: 2, child: _HoldCard(store: s)),
              if (live && mine.status == PayoutStatus.awaitingApproval)
                Reveal(
                  index: 2,
                  child: SectionCard(
                    color: AppColors.purpleLight,
                    borderColor: Color(0xFFD5CBFF),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 26,
                          color: AppColors.purple,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'The pot is full! It\'s now waiting for the organizer (Emeka) to approve the payout.',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (live) ...[
                const SizedBox(height: 14),
                Reveal(
                  index: 3,
                  child: SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payout journey',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 14),
                        for (var i = 0; i < _steps.length; i++)
                          _Step(
                            label: _steps[i],
                            state: i < _stepIndex(mine.status)
                                ? _StepState.done
                                : i == _stepIndex(mine.status)
                                ? (mine.status == PayoutStatus.held
                                      ? _StepState.warning
                                      : mine.status == PayoutStatus.settled
                                      ? _StepState.done
                                      : _StepState.current)
                                : _StepState.todo,
                            last: i == _steps.length - 1,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              if (done && mine.reference != null) ...[
                const SizedBox(height: 14),
                Reveal(
                  index: 3,
                  child: SectionCard(
                    color: AppColors.mintLight,
                    borderColor: const Color(0xFFBFE8D1),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payout receipt (mock)',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        _kv(
                          context,
                          'Amount',
                          Money.fmt(mine.amountKobo),
                          money: true,
                        ),
                        _kv(context, 'Reference', mine.reference!),
                        _kv(
                          context,
                          'Settled',
                          mine.settledAt == null
                              ? '-'
                              : Dates.full(mine.settledAt!),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              Reveal(
                index: 4,
                child: Text(
                  'Who gets the pot, and when',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 10),
              Reveal(index: 5, child: _Order(store: s)),
              const SizedBox(height: 22),
              const Reveal(index: 6, child: _HowItWorks()),
              const SizedBox(height: 22),
              const Reveal(index: 7, child: DemoControls()),
            ],
          ),
        );
      },
    );
  }

  Widget _kv(BuildContext context, String k, String v, {bool money = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
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
                style: money
                    ? context.type.moneyBody
                    : Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ],
        ),
      );
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.store,
    required this.mine,
    required this.upcoming,
    required this.done,
  });

  final AjoStore store;
  final Payout mine;
  final bool upcoming;
  final bool done;

  @override
  Widget build(BuildContext context) {
    String title;
    String subtitle;
    if (done) {
      title = 'You\'ve been paid!';
      subtitle = 'Round ${mine.round} payout is settled.';
    } else if (upcoming) {
      final n = mine.round - store.currentRound;
      title = 'Your turn is Round ${mine.round}';
      subtitle =
          'In $n round${n == 1 ? '' : 's'} · around ${Dates.short(store.dueOf(mine.round))}';
    } else {
      title = 'It\'s your turn!';
      subtitle = 'Round ${mine.round} of ${store.totalRounds}';
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5B3FD6), Color(0xFF7C5CFC), Color(0xFF9B83FF)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.purple.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            Money.fmt(mine.amountKobo),
            style: context.type.moneyDisplay.copyWith(color: Colors.white),
          ),
          Text(
            'Full pot · ${store.members.length} members × ${Money.fmt(store.contributionKobo)}',
            style: context.type.moneyCaption.copyWith(
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
        ],
      ),
    );
  }
}

class _HoldCard extends StatelessWidget {
  const _HoldCard({required this.store});

  final AjoStore store;

  @override
  Widget build(BuildContext context) {
    final list = store
        .unpaid(store.currentRound)
        .where((o) => o.memberId != 'me')
        .toList();
    return SectionCard(
      color: AppColors.warningLight,
      borderColor: const Color(0xFFF6C8B8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.pause_circle_rounded,
                color: AppColors.warningDark,
              ),
              const SizedBox(width: 8),
              Text(
                'Payout on hold',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: AppColors.warningDark),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'The pot is ${Money.fmt(store.shortfall(store.currentRound))} short. Nobody gets paid short — once it\'s full, it goes to the organizer for approval.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          for (final o in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  MemberAvatar(member: store.member(o.memberId), size: 34),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${store.member(o.memberId).name} · ${Money.fmt(o.remainingKobo)} to go',
                      style: context.type.moneyBody,
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      store.nudge(o.memberId);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          behavior: SnackBarBehavior.floating,
                          content: Row(
                            children: [
                              const Icon(
                                Icons.notifications_active_rounded,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Reminder sent to ${store.member(o.memberId).name}',
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.warningDark,
                      side: const BorderSide(color: AppColors.warningDark),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Nudge'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

enum _StepState { done, current, warning, todo }

class _Step extends StatelessWidget {
  const _Step({required this.label, required this.state, required this.last});

  final String label;
  final _StepState state;
  final bool last;

  @override
  Widget build(BuildContext context) {
    Color c;
    Widget icon;
    switch (state) {
      case _StepState.done:
        c = AppColors.primary;
        icon = const Icon(Icons.check_rounded, color: Colors.white, size: 16);
        break;
      case _StepState.current:
        c = AppColors.purple;
        icon = const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        );
        break;
      case _StepState.warning:
        c = AppColors.warning;
        icon = const Icon(
          Icons.priority_high_rounded,
          color: Colors.white,
          size: 16,
        );
        break;
      case _StepState.todo:
        c = AppColors.border;
        icon = const SizedBox.shrink();
        break;
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: c),
                  child: icon,
                ),
                if (!last)
                  Expanded(child: Container(width: 2, color: AppColors.border)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18, top: 2),
              child: Text(
                label,
                style:
                    (state == _StepState.todo
                            ? Theme.of(context).textTheme.bodyMedium
                            : Theme.of(context).textTheme.titleSmall)
                        ?.copyWith(
                          color: state == _StepState.todo
                              ? AppColors.muted
                              : AppColors.ink,
                        ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Order extends StatelessWidget {
  const _Order({required this.store});

  final AjoStore store;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < store.payouts.length; i++) ...[
            _row(context, store.payouts[i]),
            if (i != store.payouts.length - 1)
              const Divider(height: 1, color: AppColors.border),
          ],
        ],
      ),
    );
  }

  Widget _row(BuildContext context, Payout p) {
    final m = store.member(p.recipientId);
    final current = p.round == store.currentRound;
    final settled = p.status == PayoutStatus.settled;
    return Container(
      color: m.isMe ? AppColors.mintLight.withValues(alpha: 0.5) : null,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              '${p.round}',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: AppColors.muted),
            ),
          ),
          MemberAvatar(member: m, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.isMe ? '${m.name} (you)' : m.name,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  Dates.short(store.dueOf(p.round)),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
          if (settled)
            const Icon(
              Icons.check_circle_rounded,
              color: AppColors.primary,
              size: 22,
            )
          else if (current)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.play_circle_rounded,
                  color: AppColors.purple,
                  size: 18,
                ),
                const SizedBox(width: 3),
                Text(
                  'NOW',
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: AppColors.purple),
                ),
              ],
            )
          else
            const Icon(
              Icons.schedule_rounded,
              color: AppColors.muted,
              size: 20,
            ),
        ],
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      color: AppColors.skyLight,
      borderColor: Color(0xFFBFDDF3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How payouts work',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '• Everyone pays the same amount each round.\n'
            '• The payout is only released when the pot is full.\n'
            '• If someone is short, the payout is held — never paid out short.\n'
            '• The organizer approves, then the money is sent.\n'
            '• Prototype: no real money moves.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
