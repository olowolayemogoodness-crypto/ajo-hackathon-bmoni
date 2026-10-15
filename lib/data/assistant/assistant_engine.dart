import '../../core/utils/dates.dart';
import '../../core/utils/money.dart';
import '../models/models.dart';
import '../store/ajo_store.dart';

/// Read-only, ledger-grounded assistant. It never moves money and never
/// invents numbers: every figure comes from AjoStore. Swap `reply` for an LLM
/// call later; keep the same grounded-facts contract.
class AssistantEngine {
  AssistantEngine._();

  static const _pidginWords = [
    'abeg',
    'wetin',
    ' dey ',
    'wahala',
    ' oga ',
    'how far',
    ' abi ',
    'sabi',
    'na so',
    ' una ',
    ' wey ',
  ];

  static bool looksPidgin(String q) {
    final t = ' ${q.toLowerCase()} ';
    return _pidginWords.any((w) => t.contains(w));
  }

  static bool _has(String t, List<String> words) =>
      words.any((w) => t.contains(w));

  static String reply(String q, AjoStore s, {required bool pidgin}) {
    final t = q.toLowerCase();
    String pick(String en, String pcm) => pidgin ? pcm : en;
    const footer = '\n\n(I only read your ledger — I can\'t move money.)';
    const footerP = '\n\n(I dey only read your ledger — I no fit move money.)';
    String f() => pidgin ? footerP : footer;

    final cur = s.currentRound;
    final payout = s.currentPayout!;
    final recipient = s.member(payout.recipientId);
    final recipientName = recipient.isMe ? 'you' : recipient.name;

    // Core PRD questions are matched before broader keyword branches.
    if (_has(t, [
      'this week',
      'weekly summary',
      'circle summary',
      'week summary',
    ])) {
      final paid = s.paidMembers(cur);
      final open = s.members.length - paid;
      return pick(
        'This week, ${Money.fmt(s.collected(cur))} of ${Money.fmt(s.pot)} is confirmed. $paid of ${s.members.length} members are paid and $open ${open == 1 ? "status is" : "statuses are"} still open. The Round $cur pot is for $recipientName and is ${statusText(payout.status, false)}. The deadline was ${Dates.short(s.dueOf(cur))}.${f()}',
        'This week, ${Money.fmt(s.collected(cur))} out of ${Money.fmt(s.pot)} don confirm. $paid of ${s.members.length} people don pay and $open still get open status. Round $cur pot na for $recipientName and e ${statusText(payout.status, true)}. Deadline na ${Dates.short(s.dueOf(cur))}.${f()}',
      );
    }

    if (_has(t, ['who receives next', 'who gets next', 'next recipient'])) {
      return pick(
        'The next payout is Round $cur for $recipientName on the current schedule (${Dates.short(s.dueOf(cur))}). The recorded order stays fixed regardless of anyone’s reliability indicator.${f()}',
        'Next payout na Round $cur for $recipientName for the current schedule (${Dates.short(s.dueOf(cur))}). Reliability indicator no dey change the order.${f()}',
      );
    }

    if (_has(t, [
      'how much have i contributed',
      'how much did i contribute',
      'my total contribution',
    ])) {
      return pick(
        'Your ledger shows ${Money.fmt(s.contributedBy('me'))} in confirmed contributions across all recorded rounds.${f()}',
        'Your ledger show ${Money.fmt(s.contributedBy('me'))} confirmed contribution for all the recorded rounds.${f()}',
      );
    }

    if (_has(t, [
      'next payment due',
      'next contribution due',
      'when do i pay',
    ])) {
      final obligation = s.myNextObligation;
      if (obligation == null) {
        return pick(
          'You are all paid up. There is no open contribution right now.${f()}',
          'You don pay everything. No open contribution dey now.${f()}',
        );
      }
      return pick(
        'Your next contribution is ${Money.fmt(obligation.remainingKobo)} for Round ${obligation.round}, due ${Dates.short(obligation.dueAt)} (${Dates.relative(obligation.dueAt)}).${f()}',
        'Your next contribution na ${Money.fmt(obligation.remainingKobo)} for Round ${obligation.round}, due ${Dates.short(obligation.dueAt)} (${Dates.relative(obligation.dueAt)}).${f()}',
      );
    }

    if (_has(t, ['am i behind', 'do i owe', 'my status'])) {
      final mine = s.obligationOf(cur, 'me')!;
      final status = s.statusOf(mine);
      if (mine.isPaid) {
        return pick(
          'You are not behind. Your Round $cur contribution is confirmed as Paid.${f()}',
          'You no dey behind. Your Round $cur contribution don confirm as Paid.${f()}',
        );
      }
      return pick(
        'Your Round $cur status is ${status.label}. ${Money.fmt(mine.remainingKobo)} is outstanding; the deadline was ${Dates.short(mine.dueAt)}.${f()}',
        'Your Round $cur status na ${status.label}. ${Money.fmt(mine.remainingKobo)} remain; deadline na ${Dates.short(mine.dueAt)}.${f()}',
      );
    }

    // Member-specific factual history
    for (final m in s.members) {
      if (!m.isMe &&
          t.contains(m.name.toLowerCase()) &&
          _has(t, [
            'reliab',
            'trust',
            'score',
            'history',
            'record',
            'late',
            'pay',
          ])) {
        final h = s.historyOf(m.id);
        return pick(
          'I don\'t give people scores — here\'s the factual record for ${m.name}: ${h.onTime} on time, ${h.late} late, ${h.missed} missed across ${h.roundsCounted} rounds.${f()}',
          'I no dey give person score — na the facts for ${m.name}: ${h.onTime} on time, ${h.late} late, ${h.missed} missed for ${h.roundsCounted} rounds.${f()}',
        );
      }
    }

    // Why held / stuck
    if (_has(t, ['hold', 'held', 'stuck', 'delay', 'why'])) {
      if (payout.status == PayoutStatus.held) {
        final owing = s
            .unpaid(cur)
            .map(
              (o) =>
                  '${s.nameOf(o.memberId)} ${pidgin ? "owe" : "owes"} ${Money.fmt(o.remainingKobo)}',
            )
            .join(', ');
        return pick(
          'Round $cur\'s payout (${Money.fmt(payout.amountKobo)} for $recipientName) is on hold because the pot is ${Money.fmt(s.shortfall(cur))} short: $owing. Once the pot is full it goes to the organizer for approval. Nobody gets paid short.${f()}',
          'Round $cur payout (${Money.fmt(payout.amountKobo)} for $recipientName) dey hold because pot still short by ${Money.fmt(s.shortfall(cur))}: $owing. Once pot full, e go go organizer for approval. Nobody go collect short.${f()}',
        );
      }
      return pick(
        'Nothing is on hold right now — Round $cur payout is ${statusText(payout.status, false)}.${f()}',
        'Nothing dey hold now — Round $cur payout dey ${statusText(payout.status, true)}.${f()}',
      );
    }

    // Who hasn't paid
    if (_has(t, [
      'unpaid',
      'owe',
      'owing',
      "hasn't",
      'hasnt',
      'behind',
      'not paid',
      'who',
    ])) {
      final list = s.unpaid(cur);
      if (list.isEmpty) {
        return pick(
          'Everyone has paid for Round $cur 🎉${f()}',
          'Everybody don pay for Round $cur 🎉${f()}',
        );
      }
      final lines = list
          .map((o) => '• ${s.nameOf(o.memberId)}: ${s.statusOf(o).label}')
          .join('\n');
      return pick(
        'For Round $cur, ${list.length} ${list.length == 1 ? "member has" : "members have"} an open contribution status:\n$lines\n\nOnly shared ledger statuses are shown; private account details stay private.${f()}',
        'For Round $cur, ${list.length} ${list.length == 1 ? "person" : "people"} still get open contribution status:\n$lines\n\nNa shared ledger status only; private account details remain private.${f()}',
      );
    }

    // My turn
    if (_has(t, [
      'turn',
      'when',
      'collect',
      'receive',
      'my payout',
      'my pot',
      'payout',
    ])) {
      final mine = s.myPayout;
      if (mine.round == cur) {
        return pick(
          'It\'s your turn this round (Round $cur)! Pot: ${Money.fmt(mine.amountKobo)}. Status: ${statusText(mine.status, false)}.${f()}',
          'Na your turn this round (Round $cur)! Pot: ${Money.fmt(mine.amountKobo)}. Status: ${statusText(mine.status, true)}.${f()}',
        );
      } else if (mine.round > cur) {
        final n = mine.round - cur;
        final when = Dates.short(s.dueOf(mine.round));
        return pick(
          'Your turn is Round ${mine.round} — in $n round${n == 1 ? "" : "s"}, around $when.${f()}',
          'Your turn na Round ${mine.round} — $n round${n == 1 ? "" : "s"} from now, around $when.${f()}',
        );
      }
      return pick(
        'You already received your payout in Round ${mine.round} ✅${f()}',
        'You don collect your payout for Round ${mine.round} ✅${f()}',
      );
    }

    // Pot
    if (_has(t, ['pot', 'how much', 'total', 'collected', 'balance'])) {
      final c = s.collected(cur);
      final pct = (c * 100 / s.pot).round();
      return pick(
        '${Money.fmt(c)} of ${Money.fmt(s.pot)} collected for Round $cur ($pct%). ${s.paidMembers(cur)} of ${s.members.length} members are fully paid.${f()}',
        '${Money.fmt(c)} out of ${Money.fmt(s.pot)} don enter for Round $cur ($pct%). ${s.paidMembers(cur)} of ${s.members.length} people don pay finish.${f()}',
      );
    }

    // History / reliability
    if (_has(t, ['history', 'record', 'reliab', 'trust', 'score', 'streak'])) {
      final h = s.historyOf('me');
      return pick(
        'Ajo shows facts, not scores. Your record: ${h.onTime} on time, ${h.late} late, ${h.missed} missed across ${h.roundsCounted} rounds${h.streak > 1 ? " — a ${h.streak}-round on-time streak 🔥" : ""}. Tap any member in Friends to see theirs.${f()}',
        'Ajo dey show facts, no be score. Your record: ${h.onTime} on time, ${h.late} late, ${h.missed} missed for ${h.roundsCounted} rounds${h.streak > 1 ? " — ${h.streak}-round on-time streak 🔥" : ""}. Tap any member for Friends to see their own.${f()}',
      );
    }

    // My next payment
    if (_has(t, ['pay', 'next', 'due', 'contribution'])) {
      final o = s.myNextObligation;
      if (o == null) {
        return pick(
          'You\'re all paid up 🎉 Nothing due right now.${f()}',
          'You don pay everything 🎉 Nothing dey due now.${f()}',
        );
      }
      final d = Dates.short(o.dueAt);
      return pick(
        'Your next contribution is ${Money.fmt(o.remainingKobo)} for Round ${o.round}, due $d (${Dates.relative(o.dueAt)}). Tap "Pay" on Home to review and pay (prototype — no real money).${f()}',
        'Your next contribution na ${Money.fmt(o.remainingKobo)} for Round ${o.round}, due $d (${Dates.relative(o.dueAt)}). Tap "Pay" for Home to review am (prototype — no real money).${f()}',
      );
    }

    if (_has(t, [
      'hi',
      'hello',
      'hey',
      'how far',
      'good morning',
      'good evening',
    ])) {
      return pick(
        'Hi ${s.meName}! 👋 Ask me about your turn, who hasn\'t paid, or why a payout is held.',
        'How far ${s.meName}! 👋 Ask me about your turn, who never pay, or why payout dey hold.',
      );
    }

    return pick(
      'I can help with: when your turn is, who hasn\'t paid, why a payout is held, the pot total, or your payment history. Try one of the suggestions below ✨',
      'I fit help with: when your turn be, who never pay, why payout dey hold, pot total, or your payment history. Try one of the suggestions below ✨',
    );
  }

  static String statusText(PayoutStatus s, bool pidgin) {
    switch (s) {
      case PayoutStatus.scheduled:
        return pidgin ? 'dey collect money' : 'collecting contributions';
      case PayoutStatus.held:
        return pidgin
            ? 'on hold (pot never full)'
            : 'on hold (pot not full yet)';
      case PayoutStatus.awaitingApproval:
        return pidgin
            ? 'wait organizer approval'
            : 'waiting for organizer approval';
      case PayoutStatus.processing:
        return pidgin ? 'dey go (processing)' : 'being sent (processing)';
      case PayoutStatus.settled:
        return pidgin ? 'don settle ✅' : 'settled ✅';
    }
  }
}
