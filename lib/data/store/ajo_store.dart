import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/utils/dates.dart';
import '../../core/utils/money.dart';
import '../logic/circle_rules_logic.dart';
import '../logic/dispute_logic.dart';
import '../logic/ledger_logic.dart';
import '../logic/reliability_logic.dart';
import '../logic/reminder_logic.dart';
import '../mock/seed_data.dart';
import '../models/circle_rules.dart';
import '../models/models.dart';
import '../payments/mock_payments_adapter.dart';
import '../payments/payments_adapter.dart';

/// Single source of truth for the prototype. All money logic is deterministic
/// and in integer kobo. The assistant only READS from here.
class AjoStore extends ChangeNotifier {
  AjoStore._() {
    _seed();
  }

  static final AjoStore instance = AjoStore._();

  final PaymentsAdapter payments = MockPaymentsAdapter();

  String meName = DemoSeed.signedInName;
  String circleName = DemoSeed.circleName;
  int contributionKobo = DemoSeed.contributionKobo;
  int totalRounds = DemoSeed.totalRounds;
  int currentRound = 4;

  bool remindersOn = true;
  bool pidginDefault = false;

  List<Member> members = [];
  List<Obligation> obligations = [];
  List<Payout> payouts = [];
  List<LedgerEvent> events = [];
  final List<DraftCircle> otherCircles = [];

  int _seq = 0;
  final Set<String> _applied = {};
  final Set<String> _submitted = {};
  late DateTime _r4Due;

  // ---------------------------------------------------------------- seed

  void _seed() {
    _seq = 0;
    _applied.clear();
    _submitted.clear();
    events = [];
    otherCircles.clear();
    final seed = DemoSeed.build();
    currentRound = seed.currentRound;
    _r4Due = seed.currentDueAt;
    members = seed.members;
    obligations = seed.obligations;
    payouts = seed.payouts;

    // A little recent history so the activity feed feels alive.
    final t = DateTime.now();
    _logAt(
      'payment_confirmed',
      'Chioma paid ${Money.fmt(contributionKobo)}',
      t.subtract(const Duration(days: 3, hours: 2)),
      4,
    );
    _logAt(
      'payment_confirmed',
      'Zainab paid ${Money.fmt(contributionKobo)}',
      t.subtract(const Duration(days: 2, hours: 5)),
      4,
    );
    _logAt(
      'payment_confirmed',
      'Femi paid ${Money.fmt(contributionKobo)}',
      t.subtract(const Duration(days: 2)),
      4,
    );
    _logAt(
      'reminder_due',
      'Your private overdue reminder is ready',
      t.subtract(const Duration(hours: 4)),
      4,
    );
    _logAt(
      'round_started',
      'Round 4 started — it\'s your turn to receive',
      t.subtract(const Duration(days: 8)),
      4,
    );
    events.sort((a, b) => b.at.compareTo(a.at));

    _reconcile();
  }

  // ------------------------------------------------------------- getters

  int get pot => contributionKobo * members.length;

  DateTime dueOf(int round) =>
      DateTime(_r4Due.year, _r4Due.month, _r4Due.day + (round - 4) * 7);

  Member member(String id) => members.firstWhere((m) => m.id == id);

  Member get me => members.firstWhere((m) => m.isMe);

  String nameOf(String id) => member(id).isMe ? 'You' : member(id).name;

  Payout? payoutOf(int round) {
    for (final p in payouts) {
      if (p.round == round) return p;
    }
    return null;
  }

  Payout? get currentPayout => payoutOf(currentRound);

  Payout get myPayout => payouts.firstWhere((p) => p.recipientId == 'me');

  Obligation? obligationOf(int round, String memberId) {
    for (final o in obligations) {
      if (o.round == round && o.memberId == memberId) return o;
    }
    return null;
  }

  List<Obligation> obligationsFor(int round) =>
      obligations.where((o) => o.round == round).toList();

  ObligationStatus statusOf(Obligation obligation, {DateTime? now}) =>
      LedgerLogic.statusFor(
        obligation,
        currentRound: currentRound,
        now: now ?? DateTime.now(),
      );

  ContributionReliability reliabilityOf(String memberId, {DateTime? now}) =>
      ReliabilityLogic.calculate(
        obligations.where((o) => o.memberId == memberId),
        now: now ?? DateTime.now(),
      );

  ContributionReminder? get myReminder {
    final current = obligationOf(currentRound, 'me');
    if (current == null) return null;
    return ReminderLogic.forObligation(
      current,
      now: DateTime.now(),
      nextDueAt: obligationOf(currentRound + 1, 'me')?.dueAt,
    );
  }

  int contributedBy(String memberId) => obligations
      .where((o) => o.memberId == memberId)
      .fold(0, (sum, obligation) => sum + obligation.paidKobo);

  Payout? get nextPayout {
    for (final payout in payouts) {
      if (payout.round > currentRound) return payout;
    }
    return null;
  }

  int collected(int round) =>
      obligationsFor(round).fold(0, (sum, o) => sum + o.paidKobo);

  int shortfall(int round) => pot - collected(round);

  int paidMembers(int round) =>
      obligationsFor(round).where((o) => o.isPaid).length;

  List<Obligation> unpaid(int round) =>
      obligationsFor(round).where((o) => !o.isPaid).toList();

  Obligation? get myNextObligation {
    final mine =
        obligations
            .where(
              (o) =>
                  o.memberId == 'me' &&
                  !o.isPaid &&
                  o.round <= currentRound + 1,
            )
            .toList()
          ..sort((a, b) => a.round.compareTo(b.round));
    return mine.isEmpty ? null : mine.first;
  }

  bool get canAdvance =>
      currentPayout?.status == PayoutStatus.settled &&
      currentRound < totalRounds;

  // -------------------------------------------------------------- history

  MemberHistory historyOf(String memberId) {
    final marks = <RoundMark>[];
    var onTime = 0, late = 0, missed = 0;
    for (var r = 1; r <= totalRounds; r++) {
      final o = obligationOf(r, memberId);
      Mark m;
      if (o == null) {
        m = Mark.upcoming;
      } else if (o.isDisputed) {
        m = Mark.underReview; // unresolved: neither for nor against the member
      } else if (o.isPaid) {
        m = o.paidLate ? Mark.late : Mark.onTime;
      } else if (r < currentRound) {
        m = Mark.missed;
      } else if (r == currentRound) {
        if (o.paidKobo > 0) {
          m = Mark.partial;
        } else {
          m = Dates.daysFromToday(o.dueAt) < 0 ? Mark.overdue : Mark.pending;
        }
      } else {
        m = o.paidKobo > 0 ? Mark.partial : Mark.upcoming;
      }
      marks.add(RoundMark(r, m));
      if (r <= currentRound) {
        if (m == Mark.onTime) onTime++;
        if (m == Mark.late) late++;
        if (m == Mark.missed) missed++;
      }
    }
    // streak: consecutive on-time marks walking back from the latest paid round
    var streak = 0;
    for (var r = currentRound; r >= 1; r--) {
      final m = marks[r - 1].mark;
      if (m == Mark.onTime) {
        streak++;
      } else if (m == Mark.underReview) {
        continue;
      } else if (r == currentRound &&
          (m == Mark.pending || m == Mark.overdue || m == Mark.partial)) {
        continue;
      } else {
        break;
      }
    }
    return MemberHistory(
      marks: marks,
      onTime: onTime,
      late: late,
      missed: missed,
      roundsCounted: currentRound,
      streak: streak,
    );
  }

  // --------------------------------------------------------------- actions

  void setMeName(String name) {
    if (name.isEmpty || name == meName) return;
    meName = name;
    final i = members.indexWhere((m) => m.isMe);
    if (i >= 0) {
      members[i] = Member(
        id: 'me',
        name: name,
        color: members[i].color,
        isMe: true,
      );
    }
    notifyListeners();
  }

  void setReminders(bool v) {
    remindersOn = v;
    notifyListeners();
  }

  void setPidginDefault(bool v) {
    pidginDefault = v;
    notifyListeners();
  }

  Future<PaymentIntent> startPayment(Obligation ob) async {
    final key = 'obl-${ob.round}-${ob.memberId}-${ob.paidKobo}';
    final intent = await payments.createIntent(
      idempotencyKey: key,
      memberId: ob.memberId,
      round: ob.round,
      amountKobo: ob.remainingKobo,
    );
    ob.pendingKobo = intent.amountKobo;
    if (_submitted.add(intent.id)) {
      _log(
        'payment_submitted',
        'You submitted ${Money.fmt(intent.amountKobo)} — awaiting confirmation',
        amount: intent.amountKobo,
        round: ob.round,
      );
    }
    notifyListeners();
    return intent;
  }

  Future<void> confirmPayment(PaymentIntent intent, Obligation ob) async {
    final confirmed = await payments.confirm(intent);
    if (_applied.contains(confirmed.id)) return; // idempotent
    _applied.add(confirmed.id);
    ob.pendingKobo = 0;
    ob.paidKobo = min(ob.paidKobo + confirmed.amountKobo, ob.amountKobo);
    final now = DateTime.now();
    ob.paidAt = now;
    ob.paidLate = Dates.daysFromToday(ob.dueAt) < 0;
    _log(
      'payment_confirmed',
      'You paid ${Money.fmt(confirmed.amountKobo)} for Round ${ob.round}',
      amount: confirmed.amountKobo,
      round: ob.round,
    );
    _reconcile();
    notifyListeners();
  }

  /// Demo only: pretend another member paid what they owe this round.
  void simulateMemberPays(String memberId) {
    final o = obligationOf(currentRound, memberId);
    if (o == null || o.isPaid) return;
    final amt = o.remainingKobo;
    o.paidKobo += amt;
    o.paidAt = DateTime.now();
    o.paidLate = Dates.daysFromToday(o.dueAt) < 0;
    _log(
      'payment_confirmed',
      '${member(memberId).name} paid ${Money.fmt(amt)}',
      amount: amt,
      round: currentRound,
    );
    _reconcile();
    notifyListeners();
  }

  void nudge(String memberId) {
    // Reminders are private and intentionally excluded from the shared ledger.
    notifyListeners();
  }

  // ---------------------------------------------------------------- disputes

  /// Records currently under dispute, oldest round first (organiser view).
  List<Obligation> get disputedRecords =>
      obligations.where((o) => o.isDisputed).toList()
        ..sort((a, b) {
          final byRound = a.round.compareTo(b.round);
          return byRound != 0 ? byRound : a.memberId.compareTo(b.memberId);
        });

  /// A member's records they are allowed to dispute.
  List<Obligation> disputableFor(String memberId) =>
      obligations
          .where(
            (o) =>
                o.memberId == memberId &&
                DisputeLogic.canDispute(o, currentRound: currentRound),
          )
          .toList()
        ..sort((a, b) => a.round.compareTo(b.round));

  /// Moves a ledger record to "Under review" with a reason. Never changes the
  /// payout order, payout status or membership.
  void openDispute({
    required int round,
    required String memberId,
    required String reason,
    DateTime? now,
  }) {
    final o = obligationOf(round, memberId);
    if (o == null) throw const DisputeError('That record was not found.');
    DisputeLogic.open(
      o,
      reason: reason,
      now: now ?? DateTime.now(),
      currentRound: currentRound,
    );
    _log(
      'dispute_opened',
      '${nameOf(memberId)} disputed the Round $round record — under review',
      round: round,
    );
    notifyListeners();
  }

  /// Organiser resolves a dispute (demo). Payout order stays untouched.
  void resolveDispute(int round, String memberId) {
    final o = obligationOf(round, memberId);
    if (o == null || !o.isDisputed) return;
    DisputeLogic.resolve(o);
    _log(
      'dispute_resolved',
      'Organiser resolved the Round $round record for ${nameOf(memberId)}',
      round: round,
    );
    notifyListeners();
  }

  void approvePayout() {
    final p = currentPayout;
    if (p == null || p.status != PayoutStatus.awaitingApproval) return;
    p.status = PayoutStatus.processing;
    _log(
      'payout_approved',
      'Organizer Emeka approved the payout — sending ${Money.fmt(p.amountKobo)} to ${nameOf(p.recipientId).toLowerCase() == 'you' ? 'you' : nameOf(p.recipientId)} (mock)',
      amount: p.amountKobo,
      round: p.round,
    );
    notifyListeners();
    Timer(const Duration(seconds: 3), _settle);
  }

  void _settle() {
    final p = currentPayout;
    if (p == null || p.status != PayoutStatus.processing) return;
    p.status = PayoutStatus.settled;
    p.settledAt = DateTime.now();
    p.reference =
        'AJO-PO-R${p.round}-${DateTime.now().millisecondsSinceEpoch % 100000}';
    _log(
      'payout_settled',
      'Payout settled: ${Money.fmt(p.amountKobo)} to ${nameOf(p.recipientId) == 'You' ? 'you' : nameOf(p.recipientId)}',
      amount: p.amountKobo,
      round: p.round,
    );
    notifyListeners();
  }

  void advanceRound() {
    if (!canAdvance) return;
    currentRound++;
    _log('round_started', 'Round $currentRound started', round: currentRound);
    _reconcile();
    notifyListeners();
  }

  void resetDemo() {
    _seed();
    notifyListeners();
  }

  DraftCircle createCircle({
    required String name,
    required int amountKobo,
    required int size,
    required Frequency frequency,
  }) {
    final c = DraftCircle(
      name: name,
      amountKobo: amountKobo,
      size: size,
      frequency: frequency,
      code: _code(),
      organizer: 'You',
      memberCount: 1,
    );
    otherCircles.add(c);
    _log('circle_created', 'You created the circle "$name"');
    notifyListeners();
    return c;
  }

  /// Creates a circle from validated rules. The full schedule and payout order
  /// are derived from the rules and visible to everyone who reviews the circle.
  DraftCircle createCircleWithRules(CircleRules rules) {
    final c = DraftCircle(
      name: rules.name,
      amountKobo: rules.amountKobo,
      size: rules.memberCount,
      frequency: rules.frequency,
      code: _code(),
      organizer: 'You',
      memberCount: 1,
      rules: rules,
    );
    otherCircles.add(c);
    _log('circle_created', 'You created the circle "${rules.name}"');
    notifyListeners();
    return c;
  }

  DraftCircle? lookupInvite(String raw) {
    final code = raw.trim().toUpperCase();
    if (code == 'FUN-2026') {
      final base = DraftCircle(
        name: 'Weekend Hustlers',
        amountKobo: 200000,
        size: 6,
        frequency: Frequency.weekly,
        code: code,
        organizer: 'Aisha',
        memberCount: 5,
      );
      final rules = CircleRulesLogic.fallbackFor(base);
      return DraftCircle(
        name: base.name,
        amountKobo: base.amountKobo,
        size: base.size,
        frequency: base.frequency,
        code: base.code,
        organizer: base.organizer,
        memberCount: base.memberCount,
        rules: rules,
      );
    }
    return null;
  }

  /// Records membership only after an explicit acceptance. Returns false (and
  /// changes nothing) if the member has not accepted or is already in.
  bool joinCircle(DraftCircle c, {required bool accepted, DateTime? now}) {
    if (!accepted) return false;
    if (otherCircles.any((x) => x.code == c.code)) return false;
    final joined = c.asJoined(acceptedAt: now ?? DateTime.now());
    otherCircles.add(joined);
    _log(
      'circle_joined',
      joined.awaitingApproval
          ? 'You asked to join "${c.name}" — waiting for organiser approval'
          : 'You joined "${c.name}"',
    );
    notifyListeners();
    return true;
  }

  // --------------------------------------------------------------- private

  void _reconcile() {
    final p = currentPayout;
    if (p == null) return;
    if (p.status == PayoutStatus.processing ||
        p.status == PayoutStatus.settled) {
      return;
    }
    final full = collected(currentRound) >= pot;
    PayoutStatus next;
    if (full) {
      next = PayoutStatus.awaitingApproval;
    } else if (Dates.daysFromToday(dueOf(currentRound)) < 0) {
      next = PayoutStatus.held;
    } else {
      next = PayoutStatus.scheduled;
    }
    if (next == p.status) return;
    p.status = next;
    if (next == PayoutStatus.held) {
      _log(
        'payout_held',
        'Round $currentRound payout is on hold — ${Money.fmt(shortfall(currentRound))} short',
        amount: shortfall(currentRound),
        round: currentRound,
      );
    } else if (next == PayoutStatus.awaitingApproval) {
      _log(
        'payout_ready',
        'Pot is full — Round $currentRound payout is waiting for organizer approval',
        amount: pot,
        round: currentRound,
      );
    }
  }

  void _log(String type, String text, {int? amount, int? round}) {
    _logAt(type, text, DateTime.now(), round, amount);
    events.sort((a, b) => b.at.compareTo(a.at));
  }

  void _logAt(
    String type,
    String text,
    DateTime at, [
    int? round,
    int? amount,
  ]) {
    _seq++;
    events.add(
      LedgerEvent(
        id: 'evt_${_seq}_${at.millisecondsSinceEpoch}',
        type: type,
        text: text,
        at: at,
        amountKobo: amount,
        round: round,
      ),
    );
  }

  String _code() {
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final r = Random();
    return 'AJO-${List.generate(4, (_) => chars[r.nextInt(chars.length)]).join()}';
  }
}
