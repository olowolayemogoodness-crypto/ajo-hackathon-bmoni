import 'package:ajo/data/logic/circle_rules_logic.dart';
import 'package:ajo/data/models/circle_rules.dart';
import 'package:ajo/data/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Monday 19 Oct 2026.
  final monday = DateTime(2026, 10, 19);

  CircleRulesDraft draft({
    String name = 'Test Circle',
    int? amount = 500000,
    int members = 4,
    Frequency frequency = Frequency.weekly,
    bool noStart = false,
    bool noEnd = false,
    DateTime? start,
    DateTime? end,
    int grace = 2,
    int deadlineDay = DateTime.friday,
    PayoutOrderMode mode = PayoutOrderMode.randomised,
    List<int> order = const [],
    bool approval = false,
  }) {
    return CircleRulesDraft(
      name: name,
      amountKobo: amount,
      memberCount: members,
      frequency: frequency,
      startDate: noStart ? null : (start ?? monday),
      endDate: noEnd ? null : (end ?? DateTime(2026, 11, 20)),
      graceDays: grace,
      deadlineDay: deadlineDay,
      payoutMode: mode,
      payoutOrder: order,
      randomSeed: 7,
      approvalRequired: approval,
    );
  }

  group('validation', () {
    test('a complete draft has no errors', () {
      expect(CircleRulesLogic.validate(draft()), isEmpty);
    });

    test('name is required', () {
      expect(CircleRulesLogic.validate(draft(name: '  ')), contains('name'));
    });

    test('amount must be positive', () {
      expect(CircleRulesLogic.validate(draft(amount: 0)), contains('amount'));
      expect(CircleRulesLogic.validate(draft(amount: -100)), contains('amount'));
      expect(CircleRulesLogic.validate(draft(amount: null)), contains('amount'));
      expect(CircleRulesLogic.validate(draft(amount: 100)), isEmpty);
    });

    test('member count must be at least 2', () {
      expect(CircleRulesLogic.validate(draft(members: 1)), contains('members'));
      expect(CircleRulesLogic.validate(draft(members: 0)), contains('members'));
      expect(CircleRulesLogic.validate(draft(members: 2)), isEmpty);
    });

    test('end date must be after the start date', () {
      expect(CircleRulesLogic.validate(draft(end: monday)), contains('end'));
      expect(
        CircleRulesLogic.validate(draft(end: DateTime(2026, 10, 1))),
        contains('end'),
      );
      expect(
        CircleRulesLogic.validate(draft(end: DateTime(2026, 10, 20))),
        isEmpty,
      );
    });

    test('start and end dates are required', () {
      expect(CircleRulesLogic.validate(draft(noStart: true)), contains('start'));
      expect(CircleRulesLogic.validate(draft(noEnd: true)), contains('end'));
    });

    test('grace period cannot be negative', () {
      expect(CircleRulesLogic.validate(draft(grace: -1)), contains('grace'));
      expect(CircleRulesLogic.validate(draft(grace: 0)), isEmpty);
    });

    test('deadline must fit the frequency', () {
      expect(
        CircleRulesLogic.validate(draft(deadlineDay: 8)),
        contains('deadline'),
      );
      expect(
        CircleRulesLogic.validate(
          draft(frequency: Frequency.monthly, deadlineDay: 29),
        ),
        contains('deadline'),
      );
      expect(
        CircleRulesLogic.validate(
          draft(frequency: Frequency.monthly, deadlineDay: 28),
        ),
        isEmpty,
      );
    });

    test('manual payout order must place every member exactly once', () {
      expect(
        CircleRulesLogic.validate(
          draft(mode: PayoutOrderMode.manual, order: [1, 2, 3]),
        ),
        contains('order'),
      );
      expect(
        CircleRulesLogic.validate(
          draft(mode: PayoutOrderMode.manual, order: [1, 1, 2, 3]),
        ),
        contains('order'),
      );
      expect(
        CircleRulesLogic.validate(
          draft(mode: PayoutOrderMode.manual, order: [3, 1, 4, 2]),
        ),
        isEmpty,
      );
    });

    test('build refuses an invalid draft and trims a valid one', () {
      expect(() => CircleRulesLogic.build(draft(members: 1)), throwsArgumentError);
      final rules = CircleRulesLogic.build(draft(name: '  Hostel Ajo  '));
      expect(rules.name, 'Hostel Ajo');
      expect(rules.payoutOrder, hasLength(4));
    });
  });

  group('schedule and payout order', () {
    test('weekly deadlines land on the chosen weekday', () {
      final dates = CircleRulesLogic.schedule(
        start: monday,
        frequency: Frequency.weekly,
        deadlineDay: DateTime.friday,
        cycles: 3,
      );
      expect(dates, [
        DateTime(2026, 10, 23),
        DateTime(2026, 10, 30),
        DateTime(2026, 11, 6),
      ]);
    });

    test('monthly deadlines roll to the next month when already past', () {
      final dates = CircleRulesLogic.schedule(
        start: DateTime(2026, 10, 26),
        frequency: Frequency.monthly,
        deadlineDay: 25,
        cycles: 3,
      );
      expect(dates, [
        DateTime(2026, 11, 25),
        DateTime(2026, 12, 25),
        DateTime(2027, 1, 25),
      ]);
    });

    test('randomised order is a fixed permutation for a given seed', () {
      final a = CircleRulesLogic.randomisedOrder(8, 42);
      final b = CircleRulesLogic.randomisedOrder(8, 42);
      expect(a, b);
      expect([...a]..sort(), [1, 2, 3, 4, 5, 6, 7, 8]);
    });

    test('total obligation is amount x cycles in integer kobo', () {
      final rules = CircleRulesLogic.build(draft());
      expect(CircleRulesLogic.totalObligationKobo(rules), 2000000);
    });

    test('fallback rules give every circle a full schedule', () {
      const circle = DraftCircle(
        name: 'Open circle',
        amountKobo: 200000,
        size: 6,
        frequency: Frequency.weekly,
        code: 'AJO-TEST',
        organizer: 'Aisha',
        memberCount: 5,
      );
      final rules = CircleRulesLogic.fallbackFor(
        circle,
        now: DateTime(2026, 10, 15),
      );
      expect(CircleRulesLogic.scheduleFor(rules), hasLength(6));
      expect(rules.payoutOrder, hasLength(6));
      expect(
        CircleRulesLogic.validate(
          CircleRulesDraft(
            name: rules.name,
            amountKobo: rules.amountKobo,
            memberCount: rules.memberCount,
            frequency: rules.frequency,
            startDate: rules.startDate,
            endDate: rules.endDate,
            payoutOrder: rules.payoutOrder,
            deadlineDay: rules.deadlineDay,
            graceDays: rules.graceDays,
          ),
        ),
        isEmpty,
      );
    });
  });
}
