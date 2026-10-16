import 'package:flutter/material.dart';

import 'circle_rules.dart';

class Member {
  const Member({
    required this.id,
    required this.name,
    required this.color,
    this.isMe = false,
  });

  final String id;
  final String name;
  final Color color;
  final bool isMe;

  String get initial => name.isEmpty ? '?' : name[0].toUpperCase();
}

/// One obligation per (round, member). Amounts are integer kobo.
class Obligation {
  Obligation({
    required this.round,
    required this.memberId,
    required this.amountKobo,
    required this.dueAt,
  });

  final int round;
  final String memberId;
  final int amountKobo;
  final DateTime dueAt;

  int paidKobo = 0;
  int pendingKobo = 0; // submitted, awaiting confirmation
  DateTime? paidAt;
  bool paidLate = false;
  bool underReview = false;

  /// Set when a member disputes this record. A dispute only moves the record
  /// to "Under review"; it never changes payouts, order or membership.
  String? disputeReason;
  DateTime? disputedAt;

  bool get isDisputed => underReview && disputeReason != null;

  int get remainingKobo => amountKobo - paidKobo;
  bool get isPaid => remainingKobo <= 0;
}

/// The six contribution states defined by the product ledger contract.
enum ObligationStatus {
  upcoming,
  awaitingPayment,
  paid,
  partiallyPaid,
  overdue,
  underReview,
}

extension ObligationStatusLabel on ObligationStatus {
  String get label {
    switch (this) {
      case ObligationStatus.upcoming:
        return 'Upcoming';
      case ObligationStatus.awaitingPayment:
        return 'Awaiting payment';
      case ObligationStatus.paid:
        return 'Paid';
      case ObligationStatus.partiallyPaid:
        return 'Partially paid';
      case ObligationStatus.overdue:
        return 'Overdue';
      case ObligationStatus.underReview:
        return 'Under review';
    }
  }
}

enum PayoutStatus { scheduled, held, awaitingApproval, processing, settled }

class Payout {
  Payout({
    required this.round,
    required this.recipientId,
    required this.amountKobo,
    this.status = PayoutStatus.scheduled,
  });

  final int round;
  final String recipientId;
  final int amountKobo;
  PayoutStatus status;
  DateTime? settledAt;
  String? reference;
}

class LedgerEvent {
  const LedgerEvent({
    required this.id,
    required this.type,
    required this.text,
    required this.at,
    this.amountKobo,
    this.round,
  });

  final String id;
  final String type;
  final String text;
  final DateTime at;
  final int? amountKobo;
  final int? round;
}

enum Frequency { weekly, biweekly, monthly }

extension FrequencyLabel on Frequency {
  String get label {
    switch (this) {
      case Frequency.weekly:
        return 'Weekly';
      case Frequency.biweekly:
        return 'Every 2 weeks';
      case Frequency.monthly:
        return 'Monthly';
    }
  }

  int get days {
    switch (this) {
      case Frequency.weekly:
        return 7;
      case Frequency.biweekly:
        return 14;
      case Frequency.monthly:
        return 30;
    }
  }
}

/// A circle the user created or joined in the demo (separate from the seeded one).
class DraftCircle {
  const DraftCircle({
    required this.name,
    required this.amountKobo,
    required this.size,
    required this.frequency,
    required this.code,
    required this.organizer,
    required this.memberCount,
    this.joined = false,
    this.rules,
    this.acceptedAt,
    this.awaitingApproval = false,
  });

  final String name;
  final int amountKobo;
  final int size;
  final Frequency frequency;
  final String code;
  final String organizer;
  final int memberCount;
  final bool joined;

  /// Full rules the member reviewed. Null for legacy/synthetic circles; the
  /// review step derives defaults in that case.
  final CircleRules? rules;

  /// When the member explicitly accepted the rules. Null until they do.
  final DateTime? acceptedAt;

  /// True when the organiser must still approve this member.
  final bool awaitingApproval;

  DraftCircle asJoined({required DateTime acceptedAt}) => DraftCircle(
    name: name,
    amountKobo: amountKobo,
    size: size,
    frequency: frequency,
    code: code,
    organizer: organizer,
    memberCount: memberCount + 1,
    joined: true,
    rules: rules,
    acceptedAt: acceptedAt,
    awaitingApproval: rules?.approvalRequired ?? false,
  );
}

enum Mark {
  onTime,
  late,
  partial,
  overdue,
  missed,
  pending,
  upcoming,
  underReview,
}

class RoundMark {
  const RoundMark(this.round, this.mark);
  final int round;
  final Mark mark;
}

class MemberHistory {
  const MemberHistory({
    required this.marks,
    required this.onTime,
    required this.late,
    required this.missed,
    required this.roundsCounted,
    required this.streak,
  });

  final List<RoundMark> marks;
  final int onTime;
  final int late;
  final int missed;
  final int roundsCounted;
  final int streak; // consecutive on-time payments, most recent first
}
