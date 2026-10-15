import 'package:ajo/data/logic/reminder_logic.dart';
import 'package:ajo/data/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 15, 12);

  Obligation due(DateTime date, {bool paid = false}) {
    final obligation = Obligation(
      round: 4,
      memberId: 'me',
      amountKobo: 500000,
      dueAt: date,
    );
    if (paid) obligation.paidKobo = 500000;
    return obligation;
  }

  test('creates a respectful due-soon reminder', () {
    final reminder = ReminderLogic.forObligation(
      due(DateTime(2026, 10, 16)),
      now: now,
    );
    expect(reminder?.kind, ReminderKind.dueSoon);
    expect(reminder?.message, 'Your ₦5,000 contribution is due tomorrow.');
  });

  test('creates a respectful overdue reminder', () {
    final reminder = ReminderLogic.forObligation(
      due(DateTime(2026, 10, 14)),
      now: now,
    );
    expect(reminder?.kind, ReminderKind.overdue);
    expect(reminder?.message, contains('contact your circle organiser'));
  });

  test('acknowledges a paid week and gives the next date', () {
    final reminder = ReminderLogic.forObligation(
      due(DateTime(2026, 10, 14), paid: true),
      now: now,
      nextDueAt: DateTime(2026, 10, 21),
    );
    expect(reminder?.kind, ReminderKind.paidThisWeek);
    expect(reminder?.message, contains('You have contributed this week'));
    expect(reminder?.message, contains('Wed 21 Oct'));
  });
}
