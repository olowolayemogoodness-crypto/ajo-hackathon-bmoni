import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
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
              Reveal(
                child: Text(
                  'Friends',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
              ),
              const SizedBox(height: 2),
              Reveal(
                index: 1,
                child: Text(
                  '${s.circleName} · ${s.members.length} members',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
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
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        '${s.paidMembers(cur)} of ${s.members.length} paid · ${Money.fmt(s.collected(cur))} of ${Money.fmt(s.pot)}',
                        style: context.type.moneyCaption.copyWith(
                          color: AppColors.muted,
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
    Widget chip;
    if (o.isPaid) {
      chip = o.paidLate
          ? const StatusChip(
              label: 'Paid late',
              color: AppColors.goldDark,
              background: AppColors.goldLight,
              icon: Icons.check_rounded,
            )
          : const StatusChip(
              label: 'Paid',
              color: AppColors.primary,
              background: AppColors.mintLight,
              icon: Icons.check_rounded,
            );
    } else if (o.paidKobo > 0) {
      chip = StatusChip(
        label: '${Money.fmt(o.paidKobo)} of ${Money.fmt(o.amountKobo)}',
        color: AppColors.goldDark,
        background: AppColors.goldLight,
        icon: Icons.timelapse_rounded,
      );
    } else if (Dates.daysFromToday(o.dueAt) < 0) {
      chip = const StatusChip(
        label: 'Overdue',
        color: AppColors.warningDark,
        background: AppColors.warningLight,
        icon: Icons.error_outline_rounded,
      );
    } else {
      chip = const StatusChip(
        label: 'Not yet',
        color: AppColors.muted,
        background: Color(0xFFF0F1F4),
        icon: Icons.schedule_rounded,
      );
    }

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
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (isRecipient) ...[
                      const SizedBox(width: 5),
                      const Icon(
                        Icons.emoji_events_rounded,
                        size: 16,
                        color: AppColors.goldDark,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isRecipient
                      ? 'Receiving this round'
                      : 'Round ${store.currentRound} contribution',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              chip,
              if (!o.isPaid && !member.isMe)
                TextButton.icon(
                  onPressed: () {
                    store.nudge(member.id);
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
                              child: Text('Reminder sent to ${member.name}'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.notifications_rounded, size: 15),
                  label: const Text('Nudge'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryDark,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.only(top: 6),
                    textStyle: Theme.of(context).textTheme.labelMedium,
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
        child: SectionCard(child: Text('No rounds have settled yet.')),
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
            style: context.type.moneyBody,
          ),
          subtitle: Text(
            '${p.settledAt == null ? '' : 'Settled ${Dates.short(p.settledAt!)} · '}$onTime/${obs.length} on time',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
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
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      o.isPaid
                          ? Icons.check_circle_rounded
                          : Icons.error_rounded,
                      size: 16,
                      color: o.isPaid
                          ? (o.paidLate
                                ? AppColors.goldDark
                                : AppColors.primaryDark)
                          : AppColors.warningDark,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      o.isPaid
                          ? (o.paidLate ? 'Paid late' : 'On time')
                          : 'Unpaid',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: o.isPaid
                            ? (o.paidLate
                                  ? AppColors.goldDark
                                  : AppColors.primaryDark)
                            : AppColors.warningDark,
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
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        'Contribution history',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.muted,
                        ),
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
                  AppColors.primaryDark,
                  AppColors.mintLight,
                ),
                const SizedBox(width: 10),
                _count(
                  context,
                  '${h.late}',
                  'Late',
                  AppColors.goldDark,
                  AppColors.goldLight,
                ),
                const SizedBox(width: 10),
                _count(
                  context,
                  '${h.missed}',
                  'Missed',
                  AppColors.warningDark,
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
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: AppColors.muted),
                        ),
                        const SizedBox(height: 2),
                        Icon(
                          markIcon(m.mark),
                          size: 16,
                          color: markColor(m.mark),
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
                      Icon(markIcon(m), size: 14, color: markColor(m)),
                      const SizedBox(width: 4),
                      Text(
                        markLabel(m),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_rounded,
                    size: 18,
                    color: AppColors.sky,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This is a factual record from the ledger across ${h.roundsCounted} rounds — not a score or a credit rating.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
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
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(color: fg),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg),
          ),
        ],
      ),
    ),
  );
}
