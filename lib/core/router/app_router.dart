import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_screen.dart';
import '../../features/circles/presentation/create_circle_screen.dart';
import '../../features/circles/presentation/join_circle_screen.dart';
import '../../features/pay/presentation/pay_screen.dart';
import '../../features/pay/presentation/review_payment_screen.dart';
import '../../features/shell/presentation/main_shell.dart';
import '../../features/splash/presentation/splash_screen.dart';

CustomTransitionPage<void> _fade(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondary, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

CustomTransitionPage<void> _slideUp(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 320),
    transitionsBuilder: (context, animation, secondary, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  // Ignore the Firebase reCAPTCHA / auth return link; anything else -> auth.
  onException: (context, state, router) {
    if (state.uri.host == 'firebaseauth') return;
    router.go('/auth');
  },
  routes: [
    GoRoute(
      path: '/',
      pageBuilder: (context, state) => _fade(state, const SplashScreen()),
    ),
    GoRoute(
      path: '/auth',
      pageBuilder: (context, state) => _fade(state, const AuthScreen()),
    ),
    GoRoute(
      path: '/home',
      pageBuilder: (context, state) => _fade(state, const MainShell()),
    ),
    GoRoute(
      path: '/pay',
      pageBuilder: (context, state) => _slideUp(state, const PayScreen()),
    ),
    GoRoute(
      path: '/pay/review',
      pageBuilder: (context, state) =>
          _slideUp(state, const ReviewPaymentScreen()),
    ),
    GoRoute(
      path: '/circles/new',
      pageBuilder: (context, state) =>
          _slideUp(state, const CreateCircleScreen()),
    ),
    GoRoute(
      path: '/circles/join',
      pageBuilder: (context, state) =>
          _slideUp(state, const JoinCircleScreen()),
    ),
  ],
);
