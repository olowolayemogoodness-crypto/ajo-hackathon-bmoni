import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/confetti.dart';
import '../../../data/models/models.dart';
import '../../../data/store/ajo_store.dart';
import '../../assistant/presentation/assistant_sheet.dart';
import '../../friends/presentation/friends_screen.dart';
import '../../home/presentation/home_screen.dart';
import '../../my_turn/presentation/my_turn_screen.dart';
import '../../profile/presentation/profile_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final AjoStore _store = AjoStore.instance;
  int _index = 0;
  bool _confetti = false;
  PayoutStatus? _prev;

  @override
  void initState() {
    super.initState();
    final name = FirebaseAuth.instance.currentUser?.displayName;
    if (name != null && name.trim().isNotEmpty) {
      _store.setMeName(name.trim().split(' ').first);
    }
    _prev = _store.myPayout.status;
    _store.addListener(_onStore);
  }

  @override
  void dispose() {
    _store.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    final p = _store.myPayout;
    final now = p.status;
    if (_prev != PayoutStatus.settled && now == PayoutStatus.settled) {
      if (mounted) {
        setState(() => _confetti = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.primaryDark,
            content: Text('💸 ${Money.fmt(p.amountKobo)} has landed! (mock)'),
          ),
        );
        Future<void>.delayed(const Duration(milliseconds: 3200), () {
          if (mounted) setState(() => _confetti = false);
        });
      }
    }
    _prev = now;
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(onGoTo: (i) => setState(() => _index = i)),
      const MyTurnScreen(),
      const FriendsScreen(),
      const ProfileScreen(),
    ];
    return Stack(
      children: [
        Scaffold(
          body: IndexedStack(index: _index, children: pages),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => AssistantSheet.show(context),
            backgroundColor: AppColors.primaryDark,
            foregroundColor: Colors.white,
            elevation: 3,
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text('Ask Ajo', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            backgroundColor: Colors.white,
            indicatorColor: AppColors.mintLight,
            surfaceTintColor: Colors.transparent,
            height: 68,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded, color: AppColors.primary),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.emoji_events_outlined),
                selectedIcon: Icon(Icons.emoji_events_rounded, color: AppColors.primary),
                label: 'My Turn',
              ),
              NavigationDestination(
                icon: Icon(Icons.groups_outlined),
                selectedIcon: Icon(Icons.groups_rounded, color: AppColors.primary),
                label: 'Friends',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded, color: AppColors.primary),
                label: 'Profile',
              ),
            ],
          ),
        ),
        if (_confetti) const Positioned.fill(child: ConfettiBurst()),
      ],
    );
  }
}
