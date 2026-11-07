import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/errors/app_failure.dart';

abstract class AuthRepository {
  bool get isSignedIn;

  /// Emits true/false whenever the user signs in or out (including remote revocation).
  Stream<bool> get signedInChanges;

  String? get displayName;

  /// The signed-in account's email address.
  String? get email;

  /// Emits the current display name, then every change (e.g. saved right after sign-up).
  Stream<String?> get displayNameChanges;

  Future<void> signOut();

  /// Signs out locally if the server says this session is no longer valid
  /// (password changed/reset elsewhere, account disabled or deleted).
  /// Network errors are ignored: an offline user stays signed in.
  Future<void> verifySession();

  /// Creates the account (saving [name] as the display name) and leaves the user signed in.
  /// Throws [AppFailure] with a user-presentable message on failure.
  Future<void> signUp({required String name, required String email, required String password});

  /// Signs in an existing user. Throws [AppFailure] with a user-presentable message.
  Future<void> signIn({required String email, required String password});

  /// Sends a password-reset link. An unknown email is reported as success so the
  /// app never reveals which emails are registered. Throws [AppFailure] otherwise.
  Future<void> sendPasswordReset({required String email});
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;
  final FirebaseAuth _auth;

  static const _invalidSessionCodes = {
    'user-token-expired',
    'invalid-user-token',
    'user-disabled',
    'user-not-found',
  };

  @override
  bool get isSignedIn => _auth.currentUser != null;

  @override
  Stream<bool> get signedInChanges => _auth.authStateChanges().map((user) => user != null);

  @override
  String? get displayName => _auth.currentUser?.displayName;

  @override
  String? get email => _auth.currentUser?.email;

  @override
  Stream<String?> get displayNameChanges => _auth.userChanges().map((user) => user?.displayName);

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> verifySession() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await user.reload();
    } on FirebaseAuthException catch (e) {
      if (_invalidSessionCodes.contains(e.code)) await _auth.signOut();
    }
  }

  @override
  Future<void> signUp({required String name, required String email, required String password}) async {
    final UserCredential credential;
    try {
      credential = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    } on FirebaseAuthException catch (e) {
      throw AppFailure(authErrorMessage(e.code));
    }
    try {
      await credential.user?.updateDisplayName(name.trim());
    } on FirebaseAuthException {
      throw const AppFailure('Account created, but your name could not be saved. Please log in and try again.');
    }
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
    } on FirebaseAuthException catch (e) {
      throw AppFailure(authErrorMessage(e.code));
    }
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') return;
      throw AppFailure(authErrorMessage(e.code));
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
