import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/demo_controls.dart';
import '../../../core/widgets/reveal.dart';
import '../../../core/widgets/section_card.dart';
import '../../../data/models/models.dart';
import '../../../data/store/ajo_store.dart';
import '../../auth/application/auth_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    await AuthService.instance.signOut();
    if (context.mounted) context.go('/auth');
  }

  @override
  Widget build(BuildContext context) {
    final s = AjoStore.instance;
    final user = FirebaseAuth.instance.currentUser;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final h = s.historyOf('me');
        final photo = user?.photoURL;
        return SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            children: [
              Reveal(
                child: Text(
                  'Profile',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
              ),
              const SizedBox(height: 14),
              Reveal(
                index: 1,
                child: SectionCard(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: AppColors.mintLight,
                        backgroundImage: photo != null
                            ? NetworkImage(photo)
                            : null,
                        child: photo == null
                            ? Text(
                                s.meName.isEmpty
                                    ? '?'
                                    : s.meName[0].toUpperCase(),
                                style: Theme.of(context).textTheme.headlineLarge
                                    ?.copyWith(color: AppColors.primaryDark),
                              )
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.displayName ?? s.meName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user?.email ?? 'Signed in with Google',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Reveal(
                index: 2,
                child: Row(
                  children: [
                    Expanded(
                      child: _tile(
                        context,
                        Icons.check_circle_rounded,
                        '${h.onTime}',
                        'On time',
                        AppColors.mintLight,
                        AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _tile(
                        context,
                        Icons.schedule_rounded,
                        '${h.late}',
                        'Late',
                        AppColors.goldLight,
                        AppColors.goldDark,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _tile(
                        context,
                        Icons.local_fire_department_rounded,
                        '${h.streak}',
                        'Streak',
                        AppColors.warningLight,
                        AppColors.warningDark,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Reveal(
                index: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                  child: Text(
                    'Your record is a plain count from the ledger, not a score.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Reveal(
                index: 3,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'My circles',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Reveal(
                index: 3,
                child: SectionCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  child: Column(
                    children: [
                      _circleRow(
                        context,
                        Icons.school_rounded,
                        s.circleName,
                        '${s.members.length} members · ${Money.fmt(s.contributionKobo)} weekly · Round ${s.currentRound}/${s.totalRounds}',
                      ),
                      for (final c in s.otherCircles) ...[
                        const Divider(height: 1, color: AppColors.border),
                        _circleRow(
                          context,
                          c.joined
                              ? Icons.handshake_rounded
                              : Icons.spa_rounded,
                          c.name,
                          '${c.memberCount}/${c.size} members · ${Money.fmt(c.amountKobo)} ${c.frequency.label.toLowerCase()} · code ${c.code}',
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Reveal(
                index: 4,
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('/circles/new'),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Create'),
                        style: _outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('/circles/join'),
                        icon: const Icon(Icons.vpn_key_rounded),
                        label: const Text('Join'),
                        style: _outlined,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Reveal(
                index: 5,
                child: Text(
                  'Settings',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 10),
              Reveal(
                index: 5,
                child: SectionCard(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: s.remindersOn,
                        onChanged: s.setReminders,
                        activeThumbColor: AppColors.primary,
                        secondary: const Icon(
                          Icons.notifications_rounded,
                          color: AppColors.primaryDark,
                        ),
                        title: Text(
                          'Payment reminders',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        subtitle: const Text(
                          'Get nudged before a round is due',
                        ),
                      ),
                      const Divider(height: 1, color: AppColors.border),
                      SwitchListTile(
                        value: s.pidginDefault,
                        onChanged: s.setPidginDefault,
                        activeThumbColor: AppColors.primary,
                        secondary: const Icon(
                          Icons.translate_rounded,
                          color: AppColors.primaryDark,
                        ),
                        title: Text(
                          'Ajo AI in Pidgin',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        subtitle: const Text(
                          'Ask and get answers in Naija Pidgin',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const Reveal(index: 6, child: DemoControls()),
              const SizedBox(height: 22),
              Reveal(
                index: 7,
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () => _signOut(context),
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Sign out'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.warningDark,
                      side: const BorderSide(color: AppColors.warningDark),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  'Never share your PIN, OTP or card details with anyone.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static final ButtonStyle _outlined = OutlinedButton.styleFrom(
    foregroundColor: AppColors.primaryDark,
    side: const BorderSide(color: AppColors.border, width: 1.4),
    backgroundColor: Colors.white,
    minimumSize: const Size.fromHeight(50),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  );

  Widget _tile(
    BuildContext context,
    IconData icon,
    String value,
    String label,
    Color bg,
    Color fg,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: fg),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _circleRow(
    BuildContext context,
    IconData icon,
    String name,
    String sub,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.mintLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 20, color: AppColors.primaryDark),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: context.type.moneyCaption.copyWith(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
