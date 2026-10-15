import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../firebase_options.dart';

/// Google-only sign-in.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const String _webClientId =
      '570968434666-a81mf7b6a6p4piibcp4342uogmclpcd3.apps.googleusercontent.com';

  bool _initialized = false;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    String? iosClientId;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      iosClientId = DefaultFirebaseOptions.currentPlatform.iosClientId;
    }
    await GoogleSignIn.instance.initialize(
      clientId: iosClientId,
      serverClientId: _webClientId,
    );
    _initialized = true;
  }

  /// Returns null if the user cancelled.
  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        return await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
      }
      await _ensureInit();
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      return await FirebaseAuth.instance.signInWithCredential(credential);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request') {
        return null;
      }
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      if (!kIsWeb) {
        await _ensureInit();
        await GoogleSignIn.instance.signOut();
      }
    } catch (_) {}
    await FirebaseAuth.instance.signOut();
  }

  String friendlyError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'network-request-failed':
          return 'No internet connection. Check your network and try again.';
        case 'account-exists-with-different-credential':
          return 'That email is already linked to another sign-in method.';
        case 'user-disabled':
          return 'This account has been disabled.';
        default:
          return 'Sign-in failed (${e.code}). Please try again.';
      }
    }
    if (e is GoogleSignInException) {
      return 'Google sign-in failed. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }
}
