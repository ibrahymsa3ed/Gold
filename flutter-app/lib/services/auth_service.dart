import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

final sharedGoogleSignIn = GoogleSignIn(
  serverClientId: '190629243449-p8f2shp44omgprs7dlngst9sdnbe48ce.apps.googleusercontent.com',
);

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authState => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<void> signInEmailPassword(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (error) {
      throw Exception(_friendlyAuthMessage(error));
    } on FirebaseException catch (error) {
      throw Exception(_friendlyFirebaseException(error));
    } catch (error) {
      throw Exception(_friendlyUnknownError(error));
    }
  }

  Future<void> signUpEmailPassword(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (error) {
      throw Exception(_friendlyAuthMessage(error));
    } on FirebaseException catch (error) {
      throw Exception(_friendlyFirebaseException(error));
    } catch (error) {
      throw Exception(_friendlyUnknownError(error));
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        try {
          await _auth.signInWithPopup(provider);
        } on FirebaseAuthException catch (popupError) {
          // Popup can be blocked/auto-closed by browser policies.
          if (_shouldUseRedirectFallback(popupError)) {
            await _auth.signInWithRedirect(provider);
            return;
          }
          rethrow;
        }
        return;
      }

      final googleUser = await sharedGoogleSignIn.signIn();
      if (googleUser == null) return;
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (error) {
      throw Exception(_friendlyAuthMessage(error));
    } on FirebaseException catch (error) {
      throw Exception(_friendlyFirebaseException(error));
    } catch (error) {
      throw Exception(_friendlyUnknownError(error));
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (error) {
      throw Exception(_friendlyAuthMessage(error));
    } on FirebaseException catch (error) {
      throw Exception(_friendlyFirebaseException(error));
    } catch (error) {
      throw Exception(_friendlyUnknownError(error));
    }
  }

  Future<String?> getIdToken() async {
    return _auth.currentUser?.getIdToken();
  }

  Future<void> logout() async {
    await sharedGoogleSignIn.signOut();
    await _auth.signOut();
  }

  String _friendlyAuthMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'configuration-not-found':
        return 'Firebase Auth is not set up yet. Go to Firebase Console > Authentication > Get started, then enable Email/Password and Google providers.';
      case 'operation-not-allowed':
        return 'This sign-in provider is disabled. Enable it in Firebase Console > Authentication > Sign-in method.';
      case 'invalid-credential':
        return 'Invalid credentials. Please try again.';
      case 'account-exists-with-different-credential':
        return 'Account exists with another provider. Use the original sign-in method.';
      case 'wrong-password':
        return 'Wrong password.';
      case 'user-not-found':
        return 'No account found for this email.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'weak-password':
        return 'Password is too weak (minimum 6 characters).';
      case 'invalid-email':
        return 'Invalid email format.';
      case 'popup-blocked':
        return 'Popup blocked. Allow popups and try Google sign-in again.';
      case 'popup-closed-by-user':
        return 'Sign-in popup was closed before completion.';
      case 'unauthorized-domain':
        return 'Domain not authorized in Firebase. Add localhost in Firebase Auth authorized domains.';
      default:
        return error.message ?? 'Authentication failed (${error.code}).';
    }
  }

  String _friendlyFirebaseException(FirebaseException error) {
    final code = error.code.toLowerCase();
    if (code.contains('operation-not-allowed')) {
      return 'Sign-in provider is disabled in Firebase Authentication settings.';
    }
    if (code.contains('unauthorized-domain')) {
      return 'Domain not authorized in Firebase. Add localhost and 127.0.0.1 in Firebase Auth authorized domains.';
    }
    return error.message ?? 'Firebase error (${error.code}).';
  }

  String _friendlyUnknownError(Object error) {
    final message = error.toString();
    if (message.trim().toLowerCase() == 'error') {
      return 'Google sign-in failed. Enable Google provider in Firebase Auth, add localhost/127.0.0.1 to authorized domains, and allow popups.';
    }
    if (message.toLowerCase().contains('popup')) {
      return 'Popup sign-in failed. Allow popups and try again.';
    }
    return 'Auth failed: $message';
  }

  bool _shouldUseRedirectFallback(FirebaseAuthException error) {
    const redirectCodes = {
      'popup-blocked',
      'popup-closed-by-user',
      'cancelled-popup-request',
      'operation-not-supported-in-this-environment',
      'web-storage-unsupported',
    };
    return redirectCodes.contains(error.code);
  }
}
