// Real FirebaseAuthRepository on the Android emulator against the Auth emulator.
// Run (an Android emulator must be running):
//   firebase emulators:exec --only auth,firestore --project delivtrack-codewingz \
//     "sh test_emulator/run.sh <android-emulator>"
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:deliv_track/core/errors/app_failure.dart';
import 'package:deliv_track/features/auth/data/auth_repository.dart';
import 'package:deliv_track/firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late FirebaseAuthRepository auth;

  setUpAll(() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    auth = FirebaseAuthRepository();
  });

  String email(String tag) =>
      '$tag${DateTime.now().microsecondsSinceEpoch}@codewingz.com';

  Future<void> expectFailure(Future<void> call, String message) async {
    try {
      await call;
      fail('expected "$message"');
    } on AppFailure catch (e) {
      expect(e.message, message);
    }
  }

  testWidgets(
    'public sign-up works: a new account is created, named and signed in',
    (t) async {
      await FirebaseAuth.instance.signOut();
      final address = email('new');
      await auth.signUp(
        name: 'Muhammad Afzaal',
        email: address,
        password: 'strong123',
      );
      expect(auth.isSignedIn, isTrue);
      expect(auth.email, address);
      expect(auth.displayName, 'Muhammad Afzaal');
    },
  );

  testWidgets(
    'the same email cannot be registered twice; the message is clear',
    (t) async {
      final address = email('dup');
      await auth.signUp(
        name: 'First User',
        email: address,
        password: 'strong123',
      );
      await auth.signOut();
      await expectFailure(
        auth.signUp(
          name: 'Second User',
          email: address,
          password: 'another456',
        ),
        'This email is already registered. Try logging in instead.',
      );
      expect(auth.isSignedIn, isFalse);
    },
  );

  testWidgets(
    'a password the server rejects as too weak is reported in plain words',
    (t) async {
      await FirebaseAuth.instance.signOut();
      await expectFailure(
        auth.signUp(name: 'Weak User', email: email('weak'), password: '123'),
        'Password is too weak. Use at least 8 characters with letters and numbers.',
      );
    },
  );

  testWidgets(
    'login: right password works; wrong password and unknown email give the same message',
    (t) async {
      final address = email('login');
      await auth.signUp(
        name: 'Login User',
        email: address,
        password: 'strong123',
      );
      await auth.signOut();
      await expectFailure(
        auth.signIn(email: address, password: 'wrongpass1'),
        'Incorrect email or password.',
      );
      await expectFailure(
        auth.signIn(email: email('nobody'), password: 'strong123'),
        'Incorrect email or password.',
      );
      expect(auth.isSignedIn, isFalse);
      await auth.signIn(email: address, password: 'strong123');
      expect(auth.isSignedIn, isTrue);
      await auth.signOut();
      await auth.signIn(
        email: address,
        password: 'strong123',
      ); // an older 6-character password is not blocked at login either
      expect(auth.isSignedIn, isTrue);
    },
  );

  testWidgets(
    'password reset: succeeds for a known email and looks the same for an unknown one',
    (t) async {
      final address = email('reset');
      await auth.signUp(
        name: 'Reset User',
        email: address,
        password: 'strong123',
      );
      await auth.signOut();
      await auth.sendPasswordReset(email: address);
      await auth.sendPasswordReset(email: email('stranger'));
    },
  );

  testWidgets('switching accounts: the second account is its own user', (
    t,
  ) async {
    final a = email('swa');
    final b = email('swb');
    await auth.signUp(name: 'User A', email: a, password: 'strong123');
    final uidA = FirebaseAuth.instance.currentUser!.uid;
    await auth.signOut();
    await auth.signUp(name: 'User B', email: b, password: 'strong456');
    expect(FirebaseAuth.instance.currentUser!.uid, isNot(uidA));
    expect(auth.email, b);
    expect(auth.displayName, 'User B');
  });
}
