import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/demo_badge.dart';
import '../../../core/widgets/google_logo.dart';
import '../../../core/widgets/reveal.dart';
import '../application/auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Already signed in? Skip straight to the app.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && FirebaseAuth.instance.currentUser != null) {
        context.go('/home');
      }
    });
  }

  Future<void> _google() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cred = await AuthService.instance.signInWithGoogle();
      if (!mounted) return;
      if (cred != null) {
        context.go('/home');
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = AuthService.instance.friendlyError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned(
            top: -90,
            right: -70,
            child: _blob(240, AppColors.mintLight),
          ),
          Positioned(
            top: 120,
            left: -80,
            child: _blob(160, AppColors.goldLight),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Reveal(
                    child: Image.asset(
                      'assets/brand/ajo_logo_full_transparent.png',
                      height: 44,
                      fit: BoxFit.contain,
                      alignment: Alignment.centerLeft,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Reveal(
                    index: 1,
                    child: Text(
                      'Save together.\nKnow where\neveryone stands. 🤝',
                      style: TextStyle(
                        fontSize: 36,
                        height: 1.12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                        letterSpacing: -0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Reveal(
                    index: 2,
                    child: Text(
                      'The ajo / esusu circle your family has always run, now with a clear ledger.',
                      style: TextStyle(fontSize: 16, height: 1.4, color: AppColors.muted),
                    ),
                  ),
                  const SizedBox(height: 26),
                  const Reveal(index: 3, child: _Perk('🔒', 'Invite-only circles with friends you trust')),
                  const SizedBox(height: 10),
                  const Reveal(index: 4, child: _Perk('📒', 'Every naira tracked in one honest ledger')),
                  const SizedBox(height: 10),
                  const Reveal(index: 5, child: _Perk('✨', 'Ajo AI explains it in English or Pidgin')),
                  const Spacer(),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.warningLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  Reveal(
                    index: 6,
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton(
                        onPressed: _loading ? null : _google,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.ink,
                          side: const BorderSide(color: AppColors.border, width: 1.4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.4),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  GoogleLogo(size: 22),
                                  SizedBox(width: 12),
                                  Text('Continue with Google'),
                                ],
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Center(child: DemoBadge()),
                  const SizedBox(height: 10),
                  const Center(
                    child: Text(
                      'Prototype only. Never enter a real BVN, PIN or card.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _blob(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );
}

class _Perk extends StatelessWidget {
  const _Perk(this.emoji, this.text);

  final String emoji;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(emoji, style: const TextStyle(fontSize: 18)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
        ),
      ],
    );
  }
}
