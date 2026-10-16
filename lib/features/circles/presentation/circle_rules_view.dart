import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/section_card.dart';
import '../../../data/logic/circle_rules_logic.dart';
import '../../../data/models/circle_rules.dart';
import '../../../data/models/models.dart';

/// Read-only view of a circle's rules, full contribution schedule and payout
/// order. Used after creating a circle and in the review-before-joining step,
/// so everyone sees exactly the same thing.
class CircleRulesView extends StatelessWidget {
  const CircleRulesView({
    super.key,
    required this.rules,
    required this.slotLabel,
    this.mySlot,
  });

  final CircleRules rules;

  /// Display name for a payout slot (1..memberCount).
  final String Function(int slot) slotLabel;

  /// Highlights the row that belongs to the person reviewing the circle.
  final int? mySlot;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final dates = CircleRulesLogic.scheduleFor(rules);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Circle rules', style: text.titleMedium),
              if (rules.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  rules.description,
                  style: text.bodyMedium?.copyWith(color: AppColors.muted),
                ),
              ],
              const SizedBox(height: 12),
              _row(
                context,
                'Contribution',
                '${Money.fmt(rules.amountKobo)} ${rules.frequency.label.toLowerCase()}',
                money: true,
              ),
              _row(context, 'Members', '${rules.memberCount}'),
              _row(
                context,
                'Runs',
                '${Dates.short(rules.startDate)} to ${Dates.short(rules.endDate)}',
              ),
              _row(context, 'Deadline', CircleRulesLogic.deadlineLabel(rules)),
              _row(
                context,
                'Grace period',
                rules.graceDays == 0
                    ? 'None'
                    : '${rules.graceDays} ${rules.graceDays == 1 ? 'day' : 'days'} after each deadline',
              ),
              _row(
                context,
                'Membership',
                rules.approvalRequired
                    ? 'Organiser approves each new member'
                    : 'Anyone with the invite code can join',
              ),
              const Divider(height: 22, color: AppColors.border),
              Text('If a payment is missed', style: text.titleSmall),
              const SizedBox(height: 4),
              Text(
                rules.missedPolicy.label,
                style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                rules.missedPolicy.description,
                style: text.bodySmall?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              Text('Payout order', style: text.titleSmall),
              const SizedBox(height: 4),
              Text(
                rules.payoutMode.label,
                style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                rules.payoutMode.description,
                style: text.bodySmall?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.skyLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Contribution history and disputes never change the payout order or remove anyone from the circle.',
                  style: text.bodySmall,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Schedule and payout order', style: text.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Everyone contributes by each deadline; the recipient is paid after the pot is full.',
                style: text.bodySmall?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < dates.length; i++)
                _cycleRow(context, i, dates[i]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    String value, {
    bool money = false,
  }) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: text.bodyMedium?.copyWith(color: AppColors.muted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: money
                  ? context.type.moneyBody
                  : text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cycleRow(BuildContext context, int index, DateTime deadline) {
    final text = Theme.of(context).textTheme;
    final slot = rules.payoutOrder[index];
    final mine = mySlot != null && slot == mySlot;
    final grace = rules.graceDays == 0
        ? null
        : 'grace until ${Dates.short(CircleRulesLogic.graceEnd(deadline, rules.graceDays))}';
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: mine ? AppColors.mintLight : const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: mine ? const Color(0xFFBFE8D1) : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              '${index + 1}',
              style: text.titleSmall?.copyWith(color: AppColors.muted),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Dates.short(deadline),
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (grace != null)
                  Text(
                    grace,
                    style: text.bodySmall?.copyWith(color: AppColors.muted),
                  ),
              ],
            ),
          ),
          Flexible(
            child: Text(
              slotLabel(slot),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: text.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: mine ? AppColors.primaryDark : AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
