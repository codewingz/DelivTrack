// Real FirestoreParcelRepository on the Android emulator against the Auth + Firestore emulators.
// Run: firebase emulators:start --only auth,firestore --project delivtrack-codewingz
//      flutter test integration_test/parcels_repository_test.dart -d <android-emulator>
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:deliv_track/core/errors/app_failure.dart';
import 'package:deliv_track/core/time/pakistan_time.dart';
import 'package:deliv_track/features/customers/domain/customer.dart';
import 'package:deliv_track/features/parcels/data/parcel_repository.dart';
import 'package:deliv_track/features/parcels/domain/parcel.dart';
import 'package:deliv_track/features/parcels/domain/parcel_enums.dart';
import 'package:deliv_track/features/parcels/domain/parcel_input.dart';
import 'package:deliv_track/features/parcels/domain/parcel_item.dart';
import 'package:deliv_track/firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _customer = Customer(id: 'cust1', name: 'Ali Raza', phone: '0300 1234567', address: 'House 5, Sahiwal');

ParcelInput _input({
  String reference = 'VPP 12345',
  CollectionMethod method = CollectionMethod.postalCollection,
  PostalService service = PostalService.vpp,
  String? otherName,
  ParcelStatus status = ParcelStatus.sent,
  int? charge = 15000,
  int? packedGrams,
  String? payDate,
  List<ParcelItem>? items,
}) =>
    ParcelInput(
      customer: _customer,
      items: items ?? [ParcelItem.pieces(productId: 'p1', productName: 'Mango Box', quantity: 2, unitPricePaisa: 250000)],
      method: method,
      service: service,
      otherServiceName: otherName,
      postalReference: reference,
      deliveryChargePaisa: charge,
      packedWeightGrams: packedGrams,
      estimatedPaymentDate: payDate,
      status: status,
    );

Future<void> signUpNewUser(String tag) async {
  await FirebaseAuth.instance.signOut();
  await FirebaseAuth.instance.createUserWithEmailAndPassword(
    email: '$tag${DateTime.now().microsecondsSinceEpoch}@codewingz.com',
    password: 'secret123',
  );
}

Future<Parcel> read(ParcelRepository repo, String id) => repo
    .watch(id)
    .firstWhere((p) => p != null)
    .timeout(const Duration(seconds: 10), onTimeout: () => throw StateError('parcel never appeared'))
    .then((p) => p!);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late FirestoreParcelRepository repo;

  setUpAll(() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    repo = FirestoreParcelRepository();
  });

  testWidgets('order numbers run 1, 2, 3 and the saved parcel carries everything', (t) async {
    await signUpNewUser('pseq');
    final id1 = await repo.create(_input(reference: 'VPP 11111', packedGrams: 1500));
    final id2 = await repo.create(_input(reference: 'VPP 22222'));
    final id3 = await repo.create(_input(reference: 'VPP 33333'));

    final first = await read(repo, id1);
    expect(first.orderNumber, 'ADT-000001');
    expect(first.orderSequence, 1);
    expect((await read(repo, id2)).orderNumber, 'ADT-000002');
    expect((await read(repo, id3)).orderNumber, 'ADT-000003');

    expect(first.customerName, 'Ali Raza');
    expect(first.customerPhone, '0300 1234567');
    expect(first.items.single.lineTotalPaisa, 500000);
    expect(first.expectedPaisa, 500000);
    expect(first.outstandingPaisa, 500000);
    expect(first.receivedPaisa, 0);
    expect(first.paymentStatus, PaymentStatus.pending);
    expect(first.status, ParcelStatus.sent);
    expect(first.method, CollectionMethod.postalCollection);
    expect(first.service, PostalService.vpp);
    expect(first.postalReference, 'VPP 11111');
    expect(first.deliveryChargePaisa, 15000);
    expect(first.packedWeightGrams, 1500);
    expect(first.sendingDate, pakistanDate(DateTime.now().toUtc()));

    final all = await repo.watchAll().firstWhere((l) => l.length == 3).timeout(const Duration(seconds: 10));
    expect(all.map((p) => p.orderNumber), ['ADT-000003', 'ADT-000002', 'ADT-000001'], reason: 'newest first');
  });

  testWidgets('five simultaneous saves get five different consecutive numbers', (t) async {
    await signUpNewUser('prace');
    final ids = await Future.wait([for (var i = 0; i < 5; i++) repo.create(_input(reference: 'VPP 9000$i'))]);
    expect(ids.toSet(), hasLength(5));
    final parcels = await Future.wait([for (final id in ids) read(repo, id)]);
    final numbers = parcels.map((p) => p.orderSequence).toList()..sort();
    expect(numbers, [1, 2, 3, 4, 5]);
  });

  testWidgets('a postal reference can be used once per service, however it is typed', (t) async {
    await signUpNewUser('pref');
    final first = await repo.create(_input(reference: 'VPP 12345'));
    final firstNumber = (await read(repo, first)).orderNumber;

    for (final typed in ['vpp12345', 'VPP  12345', ' vpp 12 345 ']) {
      await expectLater(
        repo.create(_input(reference: typed)),
        throwsA(isA<AppFailure>().having((e) => e.message, 'message', 'This postal reference is already used on $firstNumber.')),
        reason: typed,
      );
    }
    // The same text on a different service is a different reference.
    await repo.create(_input(reference: 'VPP 12345', service: PostalService.vpl, method: CollectionMethod.advance));
    // "Other" services are told apart by name.
    await repo.create(_input(reference: 'ABC 123', service: PostalService.other, otherName: 'Fast Courier'));
    await repo.create(_input(reference: 'ABC 123', service: PostalService.other, otherName: 'Other Courier'));
    await expectLater(repo.create(_input(reference: 'abc123', service: PostalService.other, otherName: ' fast   courier ')), throwsA(isA<AppFailure>()));

    final all = await repo.watchAll().firstWhere((l) => l.length == 4).timeout(const Duration(seconds: 10));
    expect(all.map((p) => p.orderSequence), [4, 3, 2, 1], reason: 'refused saves must not use up order numbers');
  });

  testWidgets('drafts, Pay Later with a date, free parcels and Other services are stored correctly', (t) async {
    await signUpNewUser('pkinds');
    final draft = await read(repo, await repo.create(_input(status: ParcelStatus.draft, reference: '', charge: null)));
    expect(draft.status, ParcelStatus.draft);
    expect(draft.postalReference, isEmpty);
    expect(draft.deliveryChargePaisa, isNull);

    final later = await read(
      repo,
      await repo.create(_input(method: CollectionMethod.payLater, service: PostalService.vpl, reference: 'VPL 55555', payDate: '2999-01-31')),
    );
    expect(later.method, CollectionMethod.payLater);
    expect(later.estimatedPaymentDate, '2999-01-31');

    final free = await read(
      repo,
      await repo.create(_input(method: CollectionMethod.giftFree, service: PostalService.vpl, reference: 'VPL 66666', items: [
        ParcelItem.pieces(productId: 'p1', productName: 'Mango Box', quantity: 1, unitPricePaisa: 0),
      ])),
    );
    expect(free.expectedPaisa, 0);
    expect(free.outstandingPaisa, 0);
    expect(free.paymentStatus, PaymentStatus.notRequired);

    final other = await read(repo, await repo.create(_input(service: PostalService.other, otherName: ' Fast   Courier ', reference: 'XYZ 99999')));
    expect(other.service, PostalService.other);
    expect(other.otherServiceName, 'Fast Courier');
    expect(other.serviceLabel, 'Fast Courier');
  });

  testWidgets('invalid input is refused before anything is written and does not use an order number', (t) async {
    await signUpNewUser('pbad');
    await expectLater(repo.create(_input(items: [])), throwsA(isA<AppFailure>()));
    await expectLater(repo.create(_input(charge: null)), throwsA(isA<AppFailure>()));
    await expectLater(repo.create(_input(payDate: '2999-01-01')), throwsA(isA<AppFailure>()), reason: 'not a Pay Later parcel');
    final id = await repo.create(_input());
    expect((await read(repo, id)).orderNumber, 'ADT-000001');
  });

  testWidgets('users are isolated: separate numbering, no access to the other user\'s parcels, same references allowed', (t) async {
    await signUpNewUser('puserA');
    final aUid = FirebaseAuth.instance.currentUser!.uid;
    final aId = await repo.create(_input(reference: 'VPP 77777'));
    expect((await read(repo, aId)).orderNumber, 'ADT-000001');

    await signUpNewUser('puserB');
    expect(await repo.watchAll().first, isEmpty);
    final bId = await repo.create(_input(reference: 'VPP 77777')); // same reference: B has their own references
    expect((await read(repo, bId)).orderNumber, 'ADT-000001', reason: 'B starts again at 1');

    final db = FirebaseFirestore.instance;
    for (final action in <Future<Object?> Function()>[
      () => db.doc('users/$aUid/parcels/$aId').get(),
      () => db.collection('users/$aUid/parcels').get(),
      () => db.doc('users/$aUid/counters/orders').get(),
      () => db.doc('users/$aUid/parcels/$aId').update({'parcelStatus': 'returned'}),
      () => db.doc('users/$aUid/counters/orders').set({'lastSequence': 99}),
    ]) {
      await expectLater(action(), throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'permission-denied')));
    }
  });

  testWidgets('signed-out use fails with a friendly message', (t) async {
    await FirebaseAuth.instance.signOut();
    await expectLater(repo.create(_input()), throwsA(isA<AppFailure>()));
  });
}
