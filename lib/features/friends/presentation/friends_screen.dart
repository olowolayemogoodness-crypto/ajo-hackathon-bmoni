import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/member_avatar.dart';
import '../../../core/widgets/reveal.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../data/models/models.dart';
import '../../../data/store/ajo_store.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  int _tab = 0;

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
              const Reveal(
                child: Text(
                  'Friends 👯',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 2),
              Reveal(
                index: 1,
                child: Text(
                  '${s.circleName} · ${s.members.length} members',
                  style: const TextStyle(color: AppColors.muted),
                ),
              ),
              const SizedBox(height: 14),
              Reveal(
                index: 2,
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('This week')),
                      ButtonSegment(value: 1, label: Text('Past rounds')),
                    ],
                    selected: {_tab},
                    onSelectionChanged: (v) => setState(() => _tab = v.first),
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      backgroundColor: Colors.white,
                      selectedBackgroundColor: AppColors.mintLight,
                      selectedForegroundColor: AppColors.primaryDark,
                      textStyle: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_tab == 0) _ThisWeek(store: s) else _PastRounds(store: s),
            ],
          ),
        );
      },
    );
  }
}

class _ThisWeek extends StatelessWidget {
  const _ThisWeek({required this.store});

  final AjoStore store;

  @override
  Widget build(BuildContext context) {
    final s = store;
    final cur = s.currentRound;
    final payout = s.currentPayout!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Reveal(
          index: 3,
          child: SectionCard(
            color: AppColors.mintLight,
            borderColor: const Color(0xFFBFE8D1),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_month_rounded,
                  size: 24,
                  color: AppColors.primaryDark,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Round $cur · due ${Dates.short(s.dueOf(cur))}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '${s.paidMembers(cur)} of ${s.members.length} paid · ${Money.fmt(s.collected(cur))} of ${Money.fmt(s.pot)}',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < s.members.length; i++)
          Reveal(
            index: 4 + (i > 6 ? 6 : i),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _MemberRow(
                store: s,
                member: s.members[i],
                isRecipient: s.members[i].id == payout.recipientId,
              ),
            ),
          ),
        const SizedBox(height: 4),
        Text(
          'Tap a member to see their payment history. Ajo shows facts from the ledger — not scores.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
        ),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.store,
    required this.member,
    required this.isRecipient,
  });

  final AjoStore store;
  final Member member;
  final bool isRecipient;

  @override
  Widget build(BuildContext context) {
    final o = store.obligationOf(store.currentRound, member.id)!;
    final status = store.statusOf(o);
    final chip = switch (status) {
      ObligationStatus.paid => const StatusChip(
        label: 'Paid',
        color: AppColors.primary,
        background: AppColors.mintLight,
        icon: Icons.check_rounded,
      ),
      ObligationStatus.overdue => const StatusChip(
        label: 'Overdue',
        color: AppColors.warning,
        background: AppColors.warningLight,
        icon: Icons.error_outline_rounded,
      ),
      ObligationStatus.partiallyPaid => const StatusChip(
        label: 'Partially paid',
        color: Color(0xFF8A6100),
        background: AppColors.goldLight,
        icon: Icons.timelapse_rounded,
      ),
      ObligationStatus.underReview => const StatusChip(
        label: 'Under review',
        color: AppColors.purple,
        background: AppColors.purpleLight,
        icon: Icons.hourglass_top_rounded,
      ),
      ObligationStatus.awaitingPayment => const StatusChip(
        label: 'Awaiting payment',
        color: AppColors.sky,
        background: AppColors.skyLight,
        icon: Icons.schedule_rounded,
      ),
      ObligationStatus.upcoming => const StatusChip(
        label: 'Upcoming',
        color: AppColors.muted,
        background: Color(0xFFF0F1F4),
        icon: Icons.event_outlined,
      ),
    };

    return SectionCard(
      padding: const EdgeInsets.all(12),
      onTap: () => showHistorySheet(context, store, member),
      child: Row(
        children: [
          MemberAvatar(member: member, size: 44, ring: isRecipient),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        member.isMe ? '${member.name} (you)' : member.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15.5,
                        ),
                      ),
                    ),
                    if (isRecipient)
                      const Text('  👑', style: TextStyle(fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isRecipient
                      ? 'Receiving this round'
                      : 'Round ${store.currentRound} contribution',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              chip,
              if (!o.isPaid && !member.isMe)
                TextButton(
                  onPressed: () {
                    store.nudge(member.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        behavior: SnackBarBehavior.floating,
                        content: Text(
                          'Private reminder sent to ${member.name} 👋',
                        ),
                      ),
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'Nudge',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PastRounds extends StatelessWidget {
  const _PastRounds({required this.store});

  final AjoStore store;

  @override
  Widget build(BuildContext context) {
    final s = store;
    final rounds = <int>[];
    for (var r = s.currentRound; r >= 1; r--) {
      final p = s.payoutOf(r)!;
      if (p.status == PayoutStatus.settled) rounds.add(r);
    }
    if (rounds.isEmpty) {
      return const Reveal(
        index: 3,
        child: SectionCard(
          child: Text(
            'No rounds have settled yet.',
            style: TextStyle(color: AppColors.muted),
          ),
        ),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < rounds.length; i++)
          Reveal(
            index: 3 + i,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PastRoundCard(store: s, round: rounds[i]),
            ),
          ),
      ],
    );
  }
}

class _PastRoundCard extends StatelessWidget {
  const _PastRoundCard({required this.store, required this.round});

  final AjoStore store;
  final int round;

  @override
  Widget build(BuildContext context) {
    final s = store;
    final p = s.payoutOf(round)!;
    final recipient = s.member(p.recipientId);
    final obs = s.obligationsFor(round);
    final onTime = obs.where((o) => o.isPaid && !o.paidLate).length;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          leading: MemberAvatar(member: recipient, size: 40),
          title: Text(
            'Round $round · ${recipient.isMe ? 'You' : recipient.name} received ${Money.fmt(p.amountKobo)}',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
          ),
          subtitle: Text(
            '${p.settledAt == null ? '' : 'Settled ${Dates.short(p.settledAt!)} · '}$onTime/${obs.length} on time',
            style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
          ),
          children: [
            for (final o in obs)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    MemberAvatar(member: s.member(o.memberId), size: 26),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        s.nameOf(o.memberId),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      o.isPaid
                          ? (o.paidLate ? 'Paid late' : 'On time')
                          : 'Unpaid',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                        color: o.isPaid
                            ? (o.paidLate
                                  ? const Color(0xFF8A6100)
                                  : AppColors.primary)
                            : AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Color markColor(Mark m) {
  switch (m) {
    case Mark.onTime:
      return AppColors.primary;
    case Mark.late:
      return AppColors.gold;
    case Mark.partial:
      return AppColors.gold;
    case Mark.overdue:
    case Mark.missed:
      return AppColors.warning;
    case Mark.pending:
    case Mark.upcoming:
      return AppColors.border;
  }
}

String markLabel(Mark m) {
  switch (m) {
    case Mark.onTime:
      return 'On time';
    case Mark.late:
      return 'Late';
    case Mark.partial:
      return 'Part-paid';
    case Mark.overdue:
      return 'Overdue';
    case Mark.missed:
      return 'Missed';
    case Mark.pending:
      return 'Due';
    case Mark.upcoming:
      return 'Upcoming';
  }
}

IconData markIcon(Mark mark) {
  switch (mark) {
    case Mark.onTime:
      return Icons.check_rounded;
    case Mark.late:
      return Icons.schedule_rounded;
    case Mark.partial:
      return Icons.timelapse_rounded;
    case Mark.overdue:
    case Mark.missed:
      return Icons.priority_high_rounded;
    case Mark.pending:
      return Icons.hourglass_top_rounded;
    case Mark.upcoming:
      return Icons.more_horiz_rounded;
  }
}

void showHistorySheet(BuildContext context, AjoStore store, Member member) {
  final h = store.historyOf(member.id);
  final reliability = store.reliabilityOf(member.id);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                MemberAvatar(member: member, size: 52),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.isMe ? '${member.name} (you)' : member.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Text(
                        'Contribution Reliability Indicator',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                _count(
                  context,
                  '${h.onTime}',
                  'On time',
                  AppColors.primary,
                  AppColors.mintLight,
                ),
                const SizedBox(width: 10),
                _count(
                  context,
                  '${h.late}',
                  'Late',
                  const Color(0xFF8A6100),
                  AppColors.goldLight,
                ),
                const SizedBox(width: 10),
                _count(
                  context,
                  '${h.missed}',
                  'Missed',
                  AppColors.warning,
                  AppColors.warningLight,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in h.marks)
                  Container(
                    width: 52,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: markColor(m.mark).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'R${m.round}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: markColor(m.mark),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                for (final m in [
                  Mark.onTime,
                  Mark.late,
                  Mark.overdue,
                  Mark.upcoming,
                ])
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: markColor(m),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        markLabel(m),
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.skyLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reliability.summary,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    reliability.uncertainty,
                    style: const TextStyle(fontSize: 12.5, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'This is a transparent record indicator, not a credit score or a guarantee. It never changes payout order or automatically excludes anyone, and it does not claim to know a member’s intentions. To dispute a record, contact the circle organiser.',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      behavior: SnackBarBehavior.floating,
                      content: Text(
                        'Record issue noted. The circle organiser will review it; the payout order stays unchanged.',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.flag_outlined),
                label: const Text('Dispute a ledger record'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _count(
  BuildContext context,
  String n,
  String label,
  Color fg,
  Color bg,
) {
  return Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            n,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    ),
  );
}
