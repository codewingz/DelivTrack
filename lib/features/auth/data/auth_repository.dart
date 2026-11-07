import 'package:firebase_auth/firebase_auth.dart';

/// A user-presentable authentication failure.
class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

abstract class AuthRepository {
  /// Creates the account (saving [name] as the display name) and leaves the user signed in.
  /// Throws [AuthFailure] with a user-presentable message on failure.
  Future<void> signUp({required String name, required String email, required String password});

  /// Signs in an existing user. Throws [AuthFailure] with a user-presentable message.
  Future<void> signIn({required String email, required String password});

  /// Sends a password-reset link. An unknown email is reported as success so the
  /// app never reveals which emails are registered. Throws [AuthFailure] otherwise.
  Future<void> sendPasswordReset({required String email});
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;
  final FirebaseAuth _auth;

  @override
  Future<void> signUp({required String name, required String email, required String password}) async {
    final UserCredential credential;
    try {
      credential = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(authErrorMessage(e.code));
    }
    try {
      await credential.user?.updateDisplayName(name.trim());
    } on FirebaseAuthException {
      throw const AuthFailure('Account created, but your name could not be saved. Please log in and try again.');
    }
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(authErrorMessage(e.code));
    }
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') return;
      throw AuthFailure(authErrorMessage(e.code));
    }
  }
}

String authErrorMessage(String code) => switch (code) {
      'email-already-in-use' => 'This email is already registered. Try logging in instead.',
      'invalid-email' => 'Enter a valid email address.',
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' ||
      'invalid-login-credentials' =>
        'Incorrect email or password.',
      'user-disabled' => 'This account has been disabled.',
      'weak-password' => 'Password is too weak. Use at least 6 characters.',
      'network-request-failed' => 'No internet connection. Check your network and try again.',
      'too-many-requests' => 'Too many attempts. Please wait a moment and try again.',
      'operation-not-allowed' => 'Email sign-up is not enabled for this app.',
      _ => 'Something went wrong. Please try again.',
    };
