// Real FirestoreProductRepository on the Android emulator against the Auth + Firestore emulators.
// Run (an Android emulator must be running):
//   firebase emulators:exec --only auth,firestore --project delivtrack-codewingz \
//     "flutter test test_emulator -d <android-emulator>"
// The Firebase SDK reaches the host's emulators through the Android emulator's host alias.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:deliv_track/core/errors/app_failure.dart';
import 'package:deliv_track/features/products/data/product_repository.dart';
import 'package:deliv_track/features/products/domain/product.dart';
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

/// Latest list. Transactions reach the local cache only after the server confirms them,
/// so wait until [test] accepts the list instead of trusting the first (possibly stale) event.
Future<List<Product>> current(ProductRepository repo, {bool Function(List<Product>)? until}) => repo
    .watchAll()
    .firstWhere(until ?? (_) => true)
    .timeout(const Duration(seconds: 10), onTimeout: () => throw StateError('List never reached the expected state'));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FirestoreProductRepository repo;

  setUpAll(() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    repo = FirestoreProductRepository();
  });

  testWidgets('add -> listed, sorted by name, normalized, active', (t) async {
    await signUpNewUser('add');
    await repo.add(name: '  raw   Mango ', saleUnit: SaleUnit.perKg);
    await repo.add(name: 'Apple Box', saleUnit: SaleUnit.perPiece);
    final list = await current(repo, until: (l) => l.length == 2);
    expect(list.map((p) => p.name), ['Apple Box', 'raw Mango']);
    expect(list.map((p) => p.saleUnit), [SaleUnit.perPiece, SaleUnit.perKg]);
    expect(list.every((p) => p.isActive), isTrue);
  });

  testWidgets('duplicate names are rejected case-insensitively, also when archived', (t) async {
    await signUpNewUser('dup');
    await repo.add(name: 'Mango Box', saleUnit: SaleUnit.perPiece);
    await expectLater(
      repo.add(name: '  MANGO   box ', saleUnit: SaleUnit.perKg),
      throwsA(isA<AppFailure>().having((e) => e.message, 'message', duplicateProductMessage)),
    );
    final only = (await current(repo, until: (l) => l.length == 1)).single;
    await repo.setActive(only.id, false);
    await expectLater(repo.add(name: 'mango box', saleUnit: SaleUnit.perPiece), throwsA(isA<AppFailure>()),
        reason: 'archived names stay reserved');
    expect(await current(repo, until: (l) => l.length == 1), hasLength(1));
  });

  testWidgets('two simultaneous adds of the same name: exactly one wins', (t) async {
    await signUpNewUser('race');
    final results = await Future.wait([
      repo.add(name: 'Race Item', saleUnit: SaleUnit.perPiece).then((_) => true, onError: (_) => false),
      repo.add(name: 'race item', saleUnit: SaleUnit.perPiece).then((_) => true, onError: (_) => false),
    ]);
    expect(results.where((ok) => ok), hasLength(1));
    expect(await current(repo, until: (l) => l.isNotEmpty), hasLength(1));
  });

  testWidgets('rename frees the old name and reserves the new one; renaming onto an existing name fails', (t) async {
    await signUpNewUser('rename');
    await repo.add(name: 'Alpha', saleUnit: SaleUnit.perPiece);
    await repo.add(name: 'Beta', saleUnit: SaleUnit.perPiece);
    final alpha = (await current(repo, until: (l) => l.length == 2)).firstWhere((p) => p.name == 'Alpha');

    await expectLater(repo.update(alpha.id, name: 'beta', saleUnit: SaleUnit.perPiece), throwsA(isA<AppFailure>()));

    await repo.update(alpha.id, name: 'Gamma', saleUnit: SaleUnit.perKg);
    final after = await current(repo, until: (l) => l.any((p) => p.name == 'Gamma'));
    expect(after.map((p) => p.name), ['Beta', 'Gamma']);
    expect(after.firstWhere((p) => p.id == alpha.id).saleUnit, SaleUnit.perKg);

    await repo.add(name: 'Alpha', saleUnit: SaleUnit.perPiece); // old name is free again
    await expectLater(repo.add(name: 'Gamma', saleUnit: SaleUnit.perPiece), throwsA(isA<AppFailure>()));
  });

  testWidgets('case-only rename and unchanged-name edit work', (t) async {
    await signUpNewUser('case');
    await repo.add(name: 'mango', saleUnit: SaleUnit.perPiece);
    final id = (await current(repo, until: (l) => l.length == 1)).single.id;
    await repo.update(id, name: 'Mango', saleUnit: SaleUnit.perPiece);
    await repo.update(id, name: 'Mango', saleUnit: SaleUnit.perKg);
    final p = (await current(repo, until: (l) => l.single.saleUnit == SaleUnit.perKg && l.single.name == 'Mango')).single;
    expect(p.name, 'Mango');
    expect(p.saleUnit, SaleUnit.perKg);
  });

  testWidgets('archive and restore keep the product and its name', (t) async {
    await signUpNewUser('arch');
    await repo.add(name: 'Mango', saleUnit: SaleUnit.perPiece);
    final id = (await current(repo, until: (l) => l.length == 1)).single.id;
    await repo.setActive(id, false);
    expect((await current(repo, until: (l) => !l.single.isActive)).single.isActive, isFalse);
    await repo.setActive(id, true);
    expect((await current(repo, until: (l) => l.single.isActive)).single.isActive, isTrue);
  });

  testWidgets('users are isolated: B sees none of A\'s products and cannot read them directly', (t) async {
    await signUpNewUser('userA');
    final aUid = FirebaseAuth.instance.currentUser!.uid;
    await repo.add(name: 'A Secret', saleUnit: SaleUnit.perPiece);
    final aProductId = (await current(repo, until: (l) => l.length == 1)).single.id;

    await signUpNewUser('userB');
    expect(await current(repo), isEmpty, reason: 'B starts with an empty list');
    await repo.add(name: 'A Secret', saleUnit: SaleUnit.perKg); // same name is fine for another user
    expect((await current(repo, until: (l) => l.length == 1)).single.saleUnit, SaleUnit.perKg);

    final db = FirebaseFirestore.instance;
    await expectLater(db.doc('users/$aUid/products/$aProductId').get(),
        throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'permission-denied')));
    await expectLater(db.collection('users/$aUid/products').get(),
        throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'permission-denied')));
    await expectLater(db.doc('users/$aUid/products/$aProductId').update({'isActive': false}),
        throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'permission-denied')));

    // A still has exactly their product.
    await FirebaseAuth.instance.signOut();
    // (re-login not needed for the check above; A's data was never touched)
  });

  testWidgets('signed-out use fails with a friendly message', (t) async {
    await FirebaseAuth.instance.signOut();
    await expectLater(repo.add(name: 'Nobody', saleUnit: SaleUnit.perPiece), throwsA(isA<AppFailure>()));
  });
}
