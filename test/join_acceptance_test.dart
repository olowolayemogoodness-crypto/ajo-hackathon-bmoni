import 'package:ajo/data/logic/circle_rules_logic.dart';
import 'package:ajo/data/models/circle_rules.dart';
import 'package:ajo/data/models/models.dart';
import 'package:ajo/data/store/ajo_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final store = AjoStore.instance;

  setUp(() => store.resetDemo());

  CircleRules rules({bool approval = false}) => CircleRulesLogic.build(
    CircleRulesDraft(
      name: 'Hostel Ajo',
      description: 'Rent fund',
      amountKobo: 300000,
      memberCount: 4,
      frequency: Frequency.weekly,
      startDate: DateTime(2026, 10, 19),
      endDate: DateTime(2026, 11, 20),
      payoutOrder: const [2, 1, 4, 3],
      payoutMode: PayoutOrderMode.manual,
      deadlineDay: DateTime.friday,
      graceDays: 1,
      approvalRequired: approval,
    ),
  );

  test('no membership is recorded without explicit acceptance', () {
    final circle = store.lookupInvite('FUN-2026')!;
    final before = store.otherCircles.length;

    final joined = store.joinCircle(circle, accepted: false);

    expect(joined, isFalse);
    expect(store.otherCircles.length, before);
  });

  test('accepting records the membership and the acceptance time', () {
    final circle = store.lookupInvite('FUN-2026')!;
    final at = DateTime(2026, 10, 15, 10, 30);

    final joined = store.joinCircle(circle, accepted: true, now: at);

    expect(joined, isTrue);
    final membership = store.otherCircles.single;
    expect(membership.joined, isTrue);
    expect(membership.acceptedAt, at);
    expect(membership.memberCount, circle.memberCount + 1);
  });

  test('joining the same circle twice does not duplicate membership', () {
    final circle = store.lookupInvite('FUN-2026')!;
    expect(store.joinCircle(circle, accepted: true), isTrue);
    expect(store.joinCircle(circle, accepted: true), isFalse);
    expect(store.otherCircles, hasLength(1));
  });

  test('approval-required circles keep the member waiting for approval', () {
    final r = rules(approval: true);
    final circle = DraftCircle(
      name: r.name,
      amountKobo: r.amountKobo,
      size: r.memberCount,
      frequency: r.frequency,
      code: 'AJO-APRV',
      organizer: 'Femi',
      memberCount: 2,
      rules: r,
    );

    expect(store.joinCircle(circle, accepted: true), isTrue);
    expect(store.otherCircles.single.awaitingApproval, isTrue);
  });

  test('a created circle appears in the store with its full schedule', () {
    final r = rules();
    final created = store.createCircleWithRules(r);

    expect(store.otherCircles, contains(created));
    expect(created.rules, isNotNull);
    expect(created.rules!.payoutOrder, [2, 1, 4, 3]);
    expect(CircleRulesLogic.scheduleFor(created.rules!), hasLength(4));
    expect(created.code, startsWith('AJO-'));
  });
}
