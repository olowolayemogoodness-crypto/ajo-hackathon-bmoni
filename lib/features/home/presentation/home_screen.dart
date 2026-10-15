import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/bounce_tap.dart';
import '../../../core/widgets/count_up_money.dart';
import '../../../core/widgets/demo_badge.dart';
import '../../../core/widgets/member_avatar.dart';
import '../../../core/widgets/reveal.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/status_chip.dart';
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
              Reveal(child: _Header(greeting: _greeting(), store: s)),
              const SizedBox(height: 18),
              Reveal(index: 1, child: _HeroCard(store: s)),
              const SizedBox(height: 14),
              Reveal(index: 2, child: _NextMove(store: s)),
              const SizedBox(height: 14),
              Reveal(index: 3, child: _Stats(store: s)),
              const SizedBox(height: 22),
              Reveal(
                index: 4,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('The ajo wheel 🎡',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    TextButton(
                      onPressed: () => onGoTo(1),
                      child: const Text('See all'),
                    ),
                  ],
                ),
              ),
              Reveal(index: 5, child: _Wheel(store: s, onTap: () => onGoTo(1))),
              const SizedBox(height: 22),
              Reveal(
                index: 6,
                child: const Text('Circle activity',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 4),
              const Reveal(
                index: 6,
                child: Text('Every action is written to the ledger.',
                    style: TextStyle(color: AppColors.muted, fontSize: 13)),
              ),
              const SizedBox(height: 10),
              Reveal(index: 7, child: _Activity(store: s)),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.greeting, required this.store});

  final String greeting;
  final AjoStore store;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        MemberAvatar(member: store.me, size: 46, ring: true),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$greeting, ${store.meName} 👋',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const DemoBadge(),
            ],
          ),
        ),
        PopupMenuButton<String>(
          icon: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.mintLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.add_rounded, color: AppColors.primary),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          onSelected: (v) => context.push(v),
          itemBuilder: (_) => const [
            PopupMenuItem(value: '/circles/new', child: Text('Create a circle')),
            PopupMenuItem(value: '/circles/join', child: Text('Join with a code')),
          ],
        ),
      ],
    );
  }
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
      return 'Paid out ✅';
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
                      color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              StatusChip(
                label: payoutChipLabel(payout.status),
                color: held ? AppColors.warning : AppColors.primaryDark,
                background: held ? AppColors.warningLight : Colors.white,
                icon: held ? Icons.pause_circle_filled_rounded : Icons.bolt_rounded,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Round $cur of ${s.totalRounds}',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
          const SizedBox(height: 18),
          CountUpMoney(
            kobo: s.collected(cur),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          Text('of ${Money.fmt(s.pot)} collected this round',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14)),
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
              Icon(Icons.people_alt_rounded, size: 16, color: Colors.white.withValues(alpha: 0.85)),
              const SizedBox(width: 6),
              Text('${s.paidMembers(cur)} of ${s.members.length} fully paid',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13)),
              const Spacer(),
              Text(
                payout.status == PayoutStatus.settled
                    ? 'Settled'
                    : 'Due ${Dates.short(due)}',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
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
                const Text('🎉', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    recipient.isMe
                        ? 'This round\'s pot is yours!'
                        : 'This round\'s pot goes to ${recipient.name}',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
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
      return const SectionCard(
        color: AppColors.mintLight,
        borderColor: Color(0xFFBFE8D1),
        child: Row(
          children: [
            Text('🎉', style: TextStyle(fontSize: 28)),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'You\'re all paid up. Nothing due right now!',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
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
                child: const Text('💸', style: TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(early ? 'Pay early for Round ${o.round}' : 'Your contribution is due',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                    const SizedBox(height: 2),
                    Text('Due ${Dates.short(o.dueAt)} · ${Dates.relative(o.dueAt)}',
                        style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                  ],
                ),
              ),
              Text(Money.fmt(o.remainingKobo),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
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
              child: const Text('Review & pay',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15.5)),
            ),
          ),
        ],
      ),
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
        Expanded(child: _Stat(emoji: '🔥', value: '${h.streak}', label: 'On-time streak')),
        const SizedBox(width: 10),
        Expanded(child: _Stat(emoji: '🏆', value: turn, label: 'Your turn')),
        const SizedBox(width: 10),
        Expanded(child: _Stat(emoji: '👥', value: '${store.members.length}', label: 'Members')),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.emoji, required this.value, required this.label});

  final String emoji;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
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
          final past = p.round < store.currentRound ||
              p.status == PayoutStatus.settled;
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
                  Text('R${p.round}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: current ? Colors.white70 : AppColors.muted,
                      )),
                  const SizedBox(height: 4),
                  past
                      ? const Icon(Icons.check_circle_rounded,
                          color: AppColors.primary, size: 26)
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
                          child: Text(m.initial,
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: current ? AppColors.primary : m.color)),
                        ),
                  const SizedBox(height: 4),
                  Text(
                    m.isMe ? 'You' : m.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
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
      return Icons.pause_circle_filled_rounded;
    case 'payout_ready':
      return Icons.celebration_rounded;
    case 'payout_approved':
      return Icons.verified_rounded;
    case 'payout_settled':
      return Icons.savings_rounded;
    case 'reminder_sent':
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
                  Icon(eventIcon(items[i].type), size: 20, color: eventColor(items[i].type)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(items[i].text,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  Text(Dates.timeAgo(items[i].at),
                      style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                ],
              ),
            ),
            if (i != items.length - 1) const Divider(height: 1, color: AppColors.border),
          ],
        ],
      ),
    );
  }
}
