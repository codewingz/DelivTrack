// Real FirestoreCustomerRepository on the Android emulator against the Auth + Firestore emulators.
// Run (an Android emulator must be running):
//   firebase emulators:exec --only auth,firestore --project delivtrack-codewingz \
//     "flutter test test_emulator -d <android-emulator>"
// The Firebase SDK reaches the host's emulators through the Android emulator's host alias.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:deliv_track/core/errors/app_failure.dart';
import 'package:deliv_track/features/customers/data/customer_repository.dart';
import 'package:deliv_track/features/customers/domain/customer.dart';
import 'package:deliv_track/firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

Future<void> signUpNewUser(String tag) async {
  await FirebaseAuth.instance.signOut();
  await FirebaseAuth.instance.createUserWithEmailAndPassword(
    email: '$tag${DateTime.now().microsecondsSinceEpoch}@codewingz.com',
    password: 'secret123',
  );
}

Future<List<Customer>> current(
  CustomerRepository repo, {
  bool Function(List<Customer>)? until,
}) => repo
    .watchAll()
    .firstWhere(until ?? (_) => true)
    .timeout(
      const Duration(seconds: 10),
      onTimeout: () =>
          throw StateError('List never reached the expected state'),
    );

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late FirestoreCustomerRepository repo;

  setUpAll(() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    repo = FirestoreCustomerRepository();
  });

  testWidgets(
    'add returns an id; customers are listed sorted by name with cleaned fields',
    (t) async {
      await signUpNewUser('cadd');
      final id1 = await repo.add(
        name: '  zara   khan ',
        phone: ' 0300 1111111 ',
        address: '  House 1, Sahiwal ',
      );
      final id2 = await repo.add(
        name: 'Ali Raza',
        phone: '+92 301 2222222',
        address: 'Shop 4, Main Bazaar',
      );
      expect(id1, isNot(id2));

      final list = await current(repo, until: (l) => l.length == 2);
      expect(list.map((c) => c.name), ['Ali Raza', 'zara khan']);
      final zara = list.firstWhere((c) => c.id == id1);
      expect(zara.phone, '0300 1111111');
      expect(zara.address, 'House 1, Sahiwal');
      expect(zara.phoneNormalized, '03001111111');
    },
  );

  testWidgets('update changes the fields; the id stays', (t) async {
    await signUpNewUser('cupd');
    final id = await repo.add(
      name: 'Old Name',
      phone: '03001111111',
      address: 'Old address 1',
    );
    await repo.update(
      id,
      name: 'New Name',
      phone: '0302 3333333',
      address: 'New address 22',
    );
    final list = await current(
      repo,
      until: (l) => l.any((c) => c.name == 'New Name'),
    );
    expect(list.single.id, id);
    expect(list.single.phone, '0302 3333333');
    expect(list.single.address, 'New address 22');
  });

  testWidgets(
    'findByPhone matches any written form of the same number and can exclude one customer',
    (t) async {
      await signUpNewUser('cfind');
      final a = await repo.add(
        name: 'Ali',
        phone: '+92 300 4444444',
        address: 'Address one',
      );
      await current(repo, until: (l) => l.length == 1);

      for (final form in [
        '03004444444',
        '0300-4444444',
        '+923004444444',
        '923004444444',
        '0300 4444444',
      ]) {
        expect((await repo.findByPhone(form))?.id, a, reason: form);
      }
      expect(await repo.findByPhone('03005555555'), isNull);
      expect(
        await repo.findByPhone('03004444444', excludeId: a),
        isNull,
        reason: 'editing the same customer is not a duplicate',
      );
    },
  );

  testWidgets(
    'users are isolated: B sees none of A\'s customers, find/direct reads are denied',
    (t) async {
      await signUpNewUser('cuserA');
      final aUid = FirebaseAuth.instance.currentUser!.uid;
      final aId = await repo.add(
        name: 'A Customer',
        phone: '03006666666',
        address: 'A address 123',
      );
      await current(repo, until: (l) => l.length == 1);

      await signUpNewUser('cuserB');
      expect(await current(repo), isEmpty);
      expect(
        await repo.findByPhone('03006666666'),
        isNull,
        reason: 'B cannot find A\'s customer by phone',
      );
      await repo.add(
        name: 'A Customer',
        phone: '03006666666',
        address: 'B address 456',
      ); // same data is fine for B
      expect(
        (await current(repo, until: (l) => l.length == 1)).single.address,
        'B address 456',
      );

      final db = FirebaseFirestore.instance;
      for (final action in <Future<Object?> Function()>[
        () => db.doc('users/$aUid/customers/$aId').get(),
        () => db.collection('users/$aUid/customers').get(),
        () => db.doc('users/$aUid/customers/$aId').update({
          'address': 'hijacked address',
        }),
      ]) {
        await expectLater(
          action(),
          throwsA(
            isA<FirebaseException>().having(
              (e) => e.code,
              'code',
              'permission-denied',
            ),
          ),
        );
      }
    },
  );

  testWidgets('signed-out use fails with a friendly message', (t) async {
    await FirebaseAuth.instance.signOut();
    await expectLater(
      repo.add(name: 'Nobody', phone: '03007777777', address: 'No address 1'),
      throwsA(isA<AppFailure>()),
    );
    await expectLater(
      repo.findByPhone('03007777777'),
      throwsA(isA<AppFailure>()),
    );
  });
}
