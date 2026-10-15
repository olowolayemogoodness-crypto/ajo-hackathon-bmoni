import '../../core/theme/app_colors.dart';
import '../models/models.dart';

class DemoSeed {
  const DemoSeed({
    required this.currentRound,
    required this.currentDueAt,
    required this.members,
    required this.obligations,
    required this.payouts,
  });

  static const contributionKobo = 500000;
  static const totalRounds = 10;
  static const circleName = 'Campus Ajo';
  static const signedInName = 'Tolu Adebayo';

  final int currentRound;
  final DateTime currentDueAt;
  final List<Member> members;
  final List<Obligation> obligations;
  final List<Payout> payouts;

  /// Builds the PRD section 13 scenario. Identity, order, amounts and history
  /// are fixed; only the calendar anchor moves so the demo remains current.
  factory DemoSeed.build({DateTime? now}) {
    final clock = now ?? DateTime.now();
    final today = DateTime(clock.year, clock.month, clock.day);
    const currentRound = 4;
    final currentDue = today.subtract(const Duration(days: 1));

    const people = <({String id, String name, bool isMe})>[
      (id: 'm1', name: 'Chioma Okafor', isMe: false),
      (id: 'm2', name: 'Emeka Nwosu', isMe: false),
      (id: 'm3', name: 'Aisha Bello', isMe: false),
      (id: 'me', name: signedInName, isMe: true),
      (id: 'm5', name: 'Femi Adeyemi', isMe: false),
      (id: 'm6', name: 'Ngozi Eze', isMe: false),
      (id: 'm7', name: 'Bayo Balogun', isMe: false),
      (id: 'm8', name: 'Zainab Musa', isMe: false),
      (id: 'm9', name: 'Kelechi Obi', isMe: false),
      (id: 'm10', name: 'Damilola Yusuf', isMe: false),
    ];
    final members = <Member>[
      for (var i = 0; i < people.length; i++)
        Member(
          id: people[i].id,
          name: people[i].name,
          color: AppColors.avatarPalette[i % AppColors.avatarPalette.length],
          isMe: people[i].isMe,
        ),
    ];

    // Selected past payments resolve after their deadlines to produce varied,
    // explainable reliability histories without implying anyone's intent.
    const lateByDays = <String, int>{
      '1:m3': 3,
      '1:m6': 2,
      '1:m10': 5,
      '2:m1': 1,
      '2:m7': 4,
      '2:m9': 1,
      '3:m5': 1,
      '3:m10': 1,
    };
    final obligations = <Obligation>[];
    DateTime dueOf(int round) =>
        currentDue.add(Duration(days: (round - currentRound) * 7));
    for (var round = 1; round <= totalRounds; round++) {
      for (final member in members) {
        final due = dueOf(round);
        final obligation = Obligation(
          round: round,
          memberId: member.id,
          amountKobo: contributionKobo,
          dueAt: due,
        );
        if (round < currentRound || (round == currentRound && !member.isMe)) {
          final lateDays = lateByDays['$round:${member.id}'];
          obligation.paidKobo = contributionKobo;
          obligation.paidLate = lateDays != null;
          obligation.paidAt = lateDays == null
              ? due.subtract(const Duration(days: 1))
              : due.add(Duration(days: lateDays));
        }
        obligations.add(obligation);
      }
    }

    final pot = contributionKobo * members.length;
    final payouts = <Payout>[];
    for (var i = 0; i < totalRounds; i++) {
      final round = i + 1;
      final payout = Payout(
        round: round,
        recipientId: members[i].id,
        amountKobo: pot,
        status: round < currentRound
            ? PayoutStatus.settled
            : PayoutStatus.scheduled,
      );
      if (round < currentRound) {
        payout.settledAt = dueOf(round).add(const Duration(days: 1));
        payout.reference = 'AJO-DEMO-PAYOUT-$round';
      }
      payouts.add(payout);
    }

    return DemoSeed(
      currentRound: currentRound,
      currentDueAt: currentDue,
      members: members,
      obligations: obligations,
      payouts: payouts,
    );
  }
}
