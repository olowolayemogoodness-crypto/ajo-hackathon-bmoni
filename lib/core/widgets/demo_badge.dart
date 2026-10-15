import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class DemoBadge extends StatelessWidget {
  const DemoBadge({super.key, this.label = 'DEMO DATA · NO REAL MONEY'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.goldLight,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.science_rounded, size: 13, color: Color(0xFF8A6100)),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: AppColors.goldDark,
            ),
          ),
        ],
      ),
    );
  }
}
