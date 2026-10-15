import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/section_card.dart';
import '../../../data/logic/circle_rules_logic.dart';
import '../../../data/models/models.dart';
import '../../../data/store/ajo_store.dart';
import 'circle_rules_view.dart';

/// Opens the review-and-accept step. Resolves to true only if the member
/// explicitly accepted and the membership was recorded. Use this from every
/// join entry point (invite code, recommended circles).
Future<bool?> openJoinReview(BuildContext context, DraftCircle circle) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(builder: (_) => JoinReviewScreen(circle: circle)),
  );
}

class JoinReviewScreen extends StatefulWidget {
  const JoinReviewScreen({super.key, required this.circle});

  final DraftCircle circle;

  @override
  State<JoinReviewScreen> createState() => _JoinReviewScreenState();
}

class _JoinReviewScreenState extends State<JoinReviewScreen> {
  bool _accepted = false;

  void _confirm() {
    final messenger = ScaffoldMessenger.of(context);
    final ok = AjoStore.instance.joinCircle(
      widget.circle,
      accepted: _accepted,
    );
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('You are already part of this circle.'),
        ),
      );
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.circle;
    final rules = c.rules ?? CircleRulesLogic.fallbackFor(c);
    final text = Theme.of(context).textTheme;
    final full = c.memberCount >= c.size;
    final mySlot = c.memberCount + 1;
    final dates = CircleRulesLogic.scheduleFor(rules);
    final myCycle = rules.payoutOrder.indexOf(mySlot);

    String slotLabel(int slot) {
      if (slot == 1) return '${c.organizer} (organiser)';
      if (slot == mySlot) return 'You';
      if (slot < mySlot) return 'Member $slot';
      return 'Open slot $slot';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Review before joining')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                children: [
                  Text(c.name, style: text.headlineMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Organiser: ${c.organizer} · ${c.memberCount} of ${c.size} members',
                    style: text.bodyMedium?.copyWith(color: AppColors.muted),
                  ),
                  const SizedBox(height: 14),
                  SectionCard(
                    color: AppColors.mintLight,
                    borderColor: const Color(0xFFBFE8D1),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('What you would owe', style: text.titleMedium),
                        const SizedBox(height: 8),
                        Text(
                          '${Money.fmt(rules.amountKobo)} × ${rules.memberCount} cycles = ${Money.fmt(CircleRulesLogic.totalObligationKobo(rules))}',
                          style: context.type.moneyBody,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'First deadline ${Dates.short(dates.first)}, last ${Dates.short(dates.last)}.',
                          style: text.bodyMedium,
                        ),
                        if (myCycle >= 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            'You would be paid in cycle ${myCycle + 1} (${Dates.short(dates[myCycle])}).',
                            style: text.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  CircleRulesView(
                    rules: rules,
                    slotLabel: slotLabel,
                    mySlot: mySlot,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Prototype: synthetic data only. No real money moves and no banking details are collected.',
                    style: text.bodySmall?.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (full)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'This circle is full, so you can\'t join it.',
                        style: text.bodyMedium?.copyWith(
                          color: AppColors.warningDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  CheckboxListTile(
                    value: _accepted,
                    onChanged: full
                        ? null
                        : (v) => setState(() => _accepted = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.primary,
                    title: Text(
                      'I have read and accept the rules, schedule and my obligations.',
                      style: text.bodyMedium,
                    ),
                  ),
                  PrimaryButton(
                    label: rules.approvalRequired
                        ? 'I accept — request to join'
                        : 'I accept & join',
                    icon: Icons.handshake_rounded,
                    onPressed: (_accepted && !full) ? _confirm : null,
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
