import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
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
                  Reveal(
                    index: 1,
                    child: Text(
                      'Save together.\nKnow where\neveryone stands.',
                      style: Theme.of(context).textTheme.displayLarge,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Reveal(
                    index: 2,
                    child: Text(
                      'The ajo / esusu circle your family has always run, now with a clear ledger.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: AppColors.muted),
                    ),
                  ),
                  const SizedBox(height: 26),
                  const Reveal(
                    index: 3,
                    child: _Perk(
                      Icons.lock_rounded,
                      'Invite-only circles with friends you trust',
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Reveal(
                    index: 4,
                    child: _Perk(
                      Icons.receipt_long_rounded,
                      'Every naira tracked in one honest ledger',
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Reveal(
                    index: 5,
                    child: _Perk(
                      Icons.auto_awesome_rounded,
                      'Ajo AI explains it in English or Pidgin',
                    ),
                  ),
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
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppColors.warningDark,
                                fontWeight: FontWeight.w600,
                              ),
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
                          side: const BorderSide(
                            color: AppColors.border,
                            width: 1.4,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: Theme.of(context).textTheme.labelLarge,
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                ),
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
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      'Never share your PIN, OTP or card details with anyone.',
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
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
  const _Perk(this.icon, this.text);

  final IconData icon;
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
          child: Icon(icon, size: 20, color: AppColors.primaryDark),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
