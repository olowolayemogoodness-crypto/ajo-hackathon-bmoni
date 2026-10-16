import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/bounce_tap.dart';
import '../../../core/widgets/count_up_money.dart';
import '../../../core/widgets/member_avatar.dart';
import '../../../core/widgets/reveal.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/status_chip.dart';
import '../../assistant/presentation/assistant_sheet.dart';
import '../../../data/models/models.dart';
import '../../../data/store/ajo_store.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onGoTo});

  final void Function(int tab) onGoTo;

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final s = AjoStore.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        return SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            children: [
              Reveal(
                child: _TopBar(greeting: _greeting(), store: s),
              ),
              const SizedBox(height: 16),
              Reveal(index: 1, child: _BalanceCard(store: s)),
              const SizedBox(height: 18),
              Reveal(index: 1, child: _QuickActions(onGoTo: onGoTo)),
              const SizedBox(height: 18),
              Reveal(index: 2, child: _HeroCard(store: s)),
              const SizedBox(height: 14),
              Reveal(index: 2, child: _NextMove(store: s)),
              const SizedBox(height: 14),
              Reveal(index: 3, child: _PrivateReminder(store: s)),
              const SizedBox(height: 14),
              Reveal(index: 4, child: _Stats(store: s)),
              const SizedBox(height: 22),
              Reveal(index: 5, child: _ContributionLedger(store: s)),
              const SizedBox(height: 22),
              Reveal(
                index: 6,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'The ajo wheel 🎡',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextButton(
                      onPressed: () => onGoTo(1),
                      child: const Text('See all'),
                    ),
                  ],
                ),
              ),
              Reveal(
                index: 7,
                child: _Wheel(store: s, onTap: () => onGoTo(1)),
              ),
              const SizedBox(height: 22),
              Reveal(
                index: 8,
                child: const Text(
                  'Circle activity',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 4),
              const Reveal(
                index: 8,
                child: Text(
                  'Every action is written to the ledger.',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ),
              const SizedBox(height: 10),
              Reveal(index: 9, child: _Activity(store: s)),
            ],
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.greeting, required this.store});

  final String greeting;
  final AjoStore store;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        MemberAvatar(member: store.me, size: 44, ring: true),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Hi, ${store.meName.split(' ').first}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
        _RoundIcon(
          icon: Icons.support_agent_rounded,
          onTap: () => AssistantSheet.show(context),
        ),
        const SizedBox(width: 8),
        _RoundIcon(
          icon: Icons.notifications_none_rounded,
          dot: store.disputedRecords.isNotEmpty || store.unpaid(store.currentRound).isNotEmpty,
          onTap: () => AssistantSheet.show(context),
        ),
      ],
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap, this.dot = false});

  final IconData icon;
  final VoidCallback onTap;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return BounceTap(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: AppColors.mintLight,
          shape: BoxShape.circle,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, color: AppColors.primary, size: 22),
            if (dot)
              Positioned(
                top: 9,
                right: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.warning,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.mintLight, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Wallet-style balance card: what the member has paid into the circle so far.
class _BalanceCard extends StatefulWidget {
  const _BalanceCard({required this.store});

  final AjoStore store;

  @override
  State<_BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<_BalanceCard> {
  bool _hidden = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final saved = s.obligations
        .where((o) => o.memberId == s.me.id)
        .fold<int>(0, (sum, o) => sum + o.paidKobo);
    final next = s.myNextObligation;
    final mine = s.myPayout;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Total saved in circles',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _hidden = !_hidden),
                child: Icon(
                  _hidden
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _hidden ? '₦ ••••••' : Money.fmt(saved),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  next == null
                      ? 'You are all paid up'
                      : 'Next: ${Money.fmt(next.remainingKobo)} · ${Dates.relative(next.dueAt)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12.5,
                  ),
                ),
              ),
              BounceTap(
                onTap: () => context.push('/pay'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.add_circle_rounded,
                        size: 16,
                        color: AppColors.primaryDark,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        next == null ? 'View' : 'Pay now',
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (mine.status != PayoutStatus.settled) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.emoji_events_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your payout of ${Money.fmt(mine.amountKobo)} comes in Round ${mine.round}',
                      style: const TextStyle(color: Colors.white, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onGoTo});

  final void Function(int tab) onGoTo;

  @override
  Widget build(BuildContext context) {
    final items = <_Action>[
      _Action('Pay', Icons.payments_rounded, AppColors.primary,
          AppColors.mintLight, () => context.push('/pay')),
      _Action('My Turn', Icons.emoji_events_rounded, AppColors.goldDark,
          AppColors.goldLight, () => onGoTo(1)),
      _Action('Members', Icons.groups_rounded, AppColors.sky,
          AppColors.skyLight, () => onGoTo(2)),
      _Action('Ask Ajo', Icons.auto_awesome_rounded, AppColors.purple,
          AppColors.purpleLight, () => AssistantSheet.show(context)),
      _Action('New circle', Icons.add_circle_rounded, AppColors.primary,
          AppColors.mintLight, () => context.push('/circles/new')),
      _Action('Join', Icons.group_add_rounded, AppColors.sky,
          AppColors.skyLight, () => context.push('/circles/join')),
      _Action('History', Icons.receipt_long_rounded, AppColors.warningDark,
          AppColors.warningLight, () => onGoTo(2)),
      _Action('Profile', Icons.person_rounded, AppColors.purple,
          AppColors.purpleLight, () => onGoTo(3)),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 14,
        childAspectRatio: 0.95,
        children: [
          for (final a in items)
            BounceTap(
              onTap: a.onTap,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: a.bg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(a.icon, color: a.fg, size: 24),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    a.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Action {
  const _Action(this.label, this.icon, this.fg, this.bg, this.onTap);

  final String label;
  final IconData icon;
  final Color fg;
  final Color bg;
  final VoidCallback onTap;
}

String payoutChipLabel(PayoutStatus st) {
  switch (st) {
    case PayoutStatus.scheduled:
      return 'Collecting';
    case PayoutStatus.held:
      return 'Payout on hold';
    case PayoutStatus.awaitingApproval:
      return 'Ready for approval';
    case PayoutStatus.processing:
      return 'Sending…';
    case PayoutStatus.settled:
      return 'Paid out';
  }
}

IconData payoutChipIcon(PayoutStatus status) {
  switch (status) {
    case PayoutStatus.scheduled:
      return Icons.savings_rounded;
    case PayoutStatus.held:
      return Icons.pause_circle_rounded;
    case PayoutStatus.awaitingApproval:
      return Icons.approval_rounded;
    case PayoutStatus.processing:
      return Icons.sync_rounded;
    case PayoutStatus.settled:
      return Icons.check_circle_rounded;
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.store});

  final AjoStore store;

  @override
  Widget build(BuildContext context) {
    final s = store;
    final cur = s.currentRound;
    final payout = s.currentPayout!;
    final recipient = s.member(payout.recipientId);
    final progress = (s.collected(cur) / s.pot).clamp(0.0, 1.0);
    final held = payout.status == PayoutStatus.held;
    final due = s.dueOf(cur);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  s.circleName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              StatusChip(
                label: payoutChipLabel(payout.status),
                color: held ? AppColors.warningDark : AppColors.primaryDark,
                background: held ? AppColors.warningLight : Colors.white,
                icon: held
                    ? Icons.pause_circle_filled_rounded
                    : Icons.bolt_rounded,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Round $cur of ${s.totalRounds}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 18),
          CountUpMoney(
            kobo: s.collected(cur),
            style: context.type.moneyDisplay.copyWith(color: Colors.white),
          ),
          Text(
            'of ${Money.fmt(s.pot)} collected this round',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          Text(
            'of ${Money.fmt(s.pot)} collected this round',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: progress),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 10,
                backgroundColor: Colors.white.withValues(alpha: 0.22),
                valueColor: const AlwaysStoppedAnimation(Color(0xFFB6F27A)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(
                Icons.people_alt_rounded,
                size: 16,
                color: Colors.white.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 6),
              Text(
                '${s.paidMembers(cur)} of ${s.members.length} fully paid',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Text(
                payout.status == PayoutStatus.settled
                    ? 'Settled'
                    : 'Due ${Dates.short(due)}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.emoji_events_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    recipient.isMe
                        ? 'This round\'s pot is yours!'
                        : 'This round\'s pot goes to ${recipient.name}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NextMove extends StatelessWidget {
  const _NextMove({required this.store});

  final AjoStore store;

  @override
  Widget build(BuildContext context) {
    final o = store.myNextObligation;
    if (o == null) {
      return SectionCard(
        color: AppColors.mintLight,
        borderColor: const Color(0xFFBFE8D1),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              size: 28,
              color: AppColors.primaryDark,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'You\'re all paid up. Nothing due right now!',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ],
        ),
      );
    }
    final early = o.round > store.currentRound;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.purpleLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.payments_rounded,
                  color: AppColors.purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      early
                          ? 'Pay early for Round ${o.round}'
                          : 'Your contribution is due',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Due ${Dates.short(o.dueAt)} · ${Dates.relative(o.dueAt)}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                Money.fmt(o.remainingKobo),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          BounceTap(
            onTap: () => context.push('/pay'),
            child: Container(
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'Pay now',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivateReminder extends StatelessWidget {
  const _PrivateReminder({required this.store});

  final AjoStore store;

  @override
  Widget build(BuildContext context) {
    final reminder = store.myReminder;
    if (!store.remindersOn || reminder == null) {
      return const SizedBox.shrink();
    }
    return SectionCard(
      color: AppColors.skyLight,
      borderColor: const Color(0xFFBFDDF3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.notifications_active_rounded, color: AppColors.sky),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Private reminder',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(reminder.message, style: const TextStyle(height: 1.4)),
                const SizedBox(height: 6),
                const Text(
                  'Only you can see this reminder.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContributionLedger extends StatefulWidget {
  const _ContributionLedger({required this.store});

  final AjoStore store;

  @override
  State<_ContributionLedger> createState() => _ContributionLedgerState();
}

class _ContributionLedgerState extends State<_ContributionLedger> {
  late int _round;

  @override
  void initState() {
    super.initState();
    _round = widget.store.currentRound;
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final rows = store.obligationsFor(_round);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contribution ledger',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Shared statuses only — no private account details.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            DropdownButton<int>(
              value: _round,
              borderRadius: BorderRadius.circular(14),
              underline: const SizedBox.shrink(),
              items: [
                for (var round = 1; round <= store.totalRounds; round++)
                  DropdownMenuItem(value: round, child: Text('Round $round')),
              ],
              onChanged: (round) {
                if (round != null) setState(() => _round = round);
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        SectionCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                _LedgerRow(store: store, obligation: rows[i]),
                if (i != rows.length - 1)
                  const Divider(height: 1, color: AppColors.border),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final status in ObligationStatus.values)
              _LedgerStatusChip(status: status),
          ],
        ),
      ],
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.store, required this.obligation});

  final AjoStore store;
  final Obligation obligation;

  @override
  Widget build(BuildContext context) {
    final member = store.member(obligation.memberId);
    final status = store.statusOf(obligation);
    final timestamp = obligation.paidAt == null
        ? 'No confirmed payment'
        : 'Confirmed ${Dates.full(obligation.paidAt!)}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  member.isMe ? '${member.name} (you)' : member.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 8),
              _LedgerStatusChip(status: status),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'Expected ${Money.fmt(obligation.amountKobo)}  ·  '
            'Received ${Money.fmt(obligation.paidKobo)}  ·  '
            'Outstanding ${Money.fmt(obligation.remainingKobo)}',
            style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
          ),
          const SizedBox(height: 2),
          Text(
            timestamp,
            style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _LedgerStatusChip extends StatelessWidget {
  const _LedgerStatusChip({required this.status});

  final ObligationStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, background) = switch (status) {
      ObligationStatus.paid => (AppColors.primary, AppColors.mintLight),
      ObligationStatus.overdue => (AppColors.warning, AppColors.warningLight),
      ObligationStatus.partiallyPaid => (
        const Color(0xFF8A6100),
        AppColors.goldLight,
      ),
      ObligationStatus.underReview => (AppColors.purple, AppColors.purpleLight),
      ObligationStatus.awaitingPayment => (AppColors.sky, AppColors.skyLight),
      ObligationStatus.upcoming => (AppColors.muted, const Color(0xFFF0F1F4)),
    };
    return StatusChip(
      label: status.label,
      color: color,
      background: background,
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.store});

  final AjoStore store;

  @override
  Widget build(BuildContext context) {
    final h = store.historyOf('me');
    final myRound = store.myPayout.round;
    final turn = myRound == store.currentRound
        ? 'Now!'
        : myRound > store.currentRound
        ? 'In ${myRound - store.currentRound}'
        : 'Done';
    return Row(
      children: [
        Expanded(
          child: _Stat(
            emoji: '🔥',
            value: '${h.streak}',
            label: 'On-time streak',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Stat(emoji: '🏆', value: turn, label: 'Your turn'),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Stat(
            emoji: '👥',
            value: '${store.members.length}',
            label: 'Members',
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Column(
        children: [
          Icon(icon, size: 22, color: AppColors.primaryDark),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _Wheel extends StatelessWidget {
  const _Wheel({required this.store, required this.onTap});

  final AjoStore store;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: store.payouts.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final p = store.payouts[i];
          final m = store.member(p.recipientId);
          final past =
              p.round < store.currentRound || p.status == PayoutStatus.settled;
          final current = p.round == store.currentRound;
          return BounceTap(
            onTap: onTap,
            child: Container(
              width: 68,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: current
                    ? AppColors.primary
                    : past
                    ? AppColors.mintLight
                    : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: current ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'R${p.round}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: current ? Colors.white70 : AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  past
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.primary,
                          size: 26,
                        )
                      : Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: current
                                ? Colors.white
                                : m.color.withValues(alpha: 0.16),
                          ),
                          child: Text(
                            m.initial,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: current ? AppColors.primary : m.color,
                            ),
                          ),
                        ),
                  const SizedBox(height: 4),
                  Text(
                    m.isMe ? 'You' : m.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: current ? Colors.white : AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

IconData eventIcon(String type) {
  switch (type) {
    case 'payment_confirmed':
      return Icons.check_circle_rounded;
    case 'payment_submitted':
      return Icons.hourglass_top_rounded;
    case 'payout_held':
      return Icons.pause_circle_rounded;
    case 'payout_ready':
      return Icons.celebration_rounded;
    case 'payout_approved':
      return Icons.verified_rounded;
    case 'payout_settled':
      return Icons.savings_rounded;
    case 'reminder_sent':
    case 'reminder_due':
      return Icons.notifications_active_rounded;
    case 'round_started':
      return Icons.flag_rounded;
    case 'circle_created':
    case 'circle_joined':
      return Icons.group_add_rounded;
    default:
      return Icons.circle;
  }
}

Color eventColor(String type) {
  switch (type) {
    case 'payout_held':
      return AppColors.warning;
    case 'payment_submitted':
      return AppColors.gold;
    case 'payout_ready':
    case 'payout_approved':
    case 'payout_settled':
      return AppColors.purple;
    case 'reminder_sent':
      return AppColors.sky;
    default:
      return AppColors.primary;
  }
}

class _Activity extends StatelessWidget {
  const _Activity({required this.store});

  final AjoStore store;

  @override
  Widget build(BuildContext context) {
    final items = store.events.take(6).toList();
    return SectionCard(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    eventIcon(items[i].type),
                    size: 20,
                    color: eventColor(items[i].type),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      items[i].text,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    Dates.timeAgo(items[i].at),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            if (i != items.length - 1)
              const Divider(height: 1, color: AppColors.border),
          ],
        ],
      ),
    );
  }
}
