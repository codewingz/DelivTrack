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
import 'package:deliv_track/features/parcels/domain/payment.dart';
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

  group('editing', () {
    Future<List<Map<String, dynamic>>> auditEntries() async {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final snapshot = await FirebaseFirestore.instance.collection('users/$uid/audit_logs').get();
      return [for (final d in snapshot.docs) d.data()];
    }

    Future<Map<String, dynamic>> rawParcel(String id) async {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      return (await FirebaseFirestore.instance.doc('users/$uid/parcels/$id').get()).data()!;
    }

    Future<Parcel> waitFor(String id, bool Function(Parcel) test) => repo
        .watch(id)
        .firstWhere((p) => p != null && test(p))
        .timeout(const Duration(seconds: 10), onTimeout: () => throw StateError('parcel never reached the expected state'))
        .then((p) => p!);

    testWidgets('a draft becomes Sent: slip details saved, reference reserved, number/date/created time untouched, audit entry written', (t) async {
      await signUpNewUser('edraft');
      final id = await repo.create(_input(status: ParcelStatus.draft, reference: '', charge: null));
      final before = await rawParcel(id);

      await repo.update(id, _input(reference: 'vpp 77777', charge: 20000, packedGrams: 2500));
      final after = await waitFor(id, (p) => p.status == ParcelStatus.sent);
      expect(after.postalReference, 'vpp 77777');
      expect(after.deliveryChargePaisa, 20000);
      expect(after.packedWeightGrams, 2500);
      expect(after.orderNumber, 'ADT-000001');

      final raw = await rawParcel(id);
      for (final locked in ['orderNumber', 'orderSequence', 'sendingDateLocal', 'createdAt']) {
        expect(raw[locked], before[locked], reason: '$locked must never change');
      }
      expect(raw['postalReferenceNormalized'], 'VPP77777');

      // the reference is now taken
      await expectLater(
        repo.create(_input(reference: 'VPP 77777')),
        throwsA(isA<AppFailure>().having((e) => e.message, 'message', 'This postal reference is already used on ADT-000001.')),
      );

      final audit = await auditEntries();
      expect(audit, hasLength(1));
      expect(audit.single['entityType'], 'parcel');
      expect(audit.single['entityId'], id);
      expect(audit.single['orderNumber'], 'ADT-000001');
      expect(audit.single['changedFields'], containsAll(['parcelStatus', 'postalReference', 'postalReferenceNormalized', 'deliveryChargePaisa', 'actualPackedWeightGrams']));
    });

    testWidgets('changing the reference frees the old one and reserves the new one; a taken reference is refused and changes nothing', (t) async {
      await signUpNewUser('eref');
      final a = await repo.create(_input(reference: 'VPP 11111'));
      final b = await repo.create(_input(reference: 'VPP 22222'));
      final bNumber = (await read(repo, b)).orderNumber;

      await expectLater(
        repo.update(a, _input(reference: 'VPP22222')),
        throwsA(isA<AppFailure>().having((e) => e.message, 'message', 'This postal reference is already used on $bNumber.')),
      );
      expect((await rawParcel(a))['postalReference'], 'VPP 11111', reason: 'a refused edit changes nothing');
      expect(await auditEntries(), isEmpty, reason: 'and writes no audit entry');

      await repo.update(a, _input(reference: 'VPP 33333'));
      await waitFor(a, (p) => p.postalReference == 'VPP 33333');
      // the old reference can be used again, the new one cannot
      await repo.create(_input(reference: 'VPP 11111'));
      await expectLater(repo.create(_input(reference: 'VPP 33333')), throwsA(isA<AppFailure>()));
      // keeping its own reference while editing something else is not a conflict
      await repo.update(a, _input(reference: 'VPP 33333', charge: 999));
      expect((await waitFor(a, (p) => p.deliveryChargePaisa == 999)).postalReference, 'VPP 33333');
    });

    testWidgets('changed products recalculate the totals; Gift / Free expects nothing; payment status follows', (t) async {
      await signUpNewUser('etotals');
      final id = await repo.create(_input());
      expect((await read(repo, id)).expectedPaisa, 500000);

      await repo.update(id, _input(items: [
        ParcelItem.pieces(productId: 'p1', productName: 'Mango Box', quantity: 3, unitPricePaisa: 100000),
        ParcelItem.weight(productId: 'p2', productName: 'Dry Fruits', weightGrams: 1250, unitPricePaisa: 80000),
      ]));
      final bigger = await waitFor(id, (p) => p.items.length == 2);
      expect(bigger.expectedPaisa, 400000);
      expect(bigger.outstandingPaisa, 400000);
      expect(bigger.paymentStatus, PaymentStatus.pending);

      await repo.update(id, _input(method: CollectionMethod.giftFree, service: PostalService.vpl, items: [
        ParcelItem.pieces(productId: 'p1', productName: 'Mango Box', quantity: 3, unitPricePaisa: 0),
      ]));
      final gift = await waitFor(id, (p) => p.method == CollectionMethod.giftFree);
      expect(gift.expectedPaisa, 0);
      expect(gift.outstandingPaisa, 0);
      expect(gift.paymentStatus, PaymentStatus.notRequired);
    });

    testWidgets('optional fields can be removed again (charge, packed weight, service name, payment date)', (t) async {
      await signUpNewUser('eopt');
      final id = await repo.create(_input(
        method: CollectionMethod.payLater,
        service: PostalService.other,
        otherName: 'Fast Courier',
        reference: 'ABC 12345',
        packedGrams: 1500,
        payDate: '2999-01-31',
      ));
      expect((await rawParcel(id))['otherPostalServiceName'], 'Fast Courier');

      await repo.update(id, _input(
        status: ParcelStatus.draft,
        method: CollectionMethod.payLater,
        service: PostalService.vpl,
        reference: '',
        charge: null,
      ));
      await waitFor(id, (p) => p.status == ParcelStatus.draft);
      final raw = await rawParcel(id);
      for (final removed in ['otherPostalServiceName', 'deliveryChargePaisa', 'actualPackedWeightGrams', 'estimatedPaymentDateLocal']) {
        expect(raw.containsKey(removed), isFalse, reason: '$removed should be gone');
      }
      expect(raw['postalReferenceNormalized'], '');
      // clearing the reference released it
      await repo.create(_input(reference: 'ABC 12345', service: PostalService.other, otherName: 'Fast Courier'));
    });

    testWidgets('an edit that changes nothing writes nothing', (t) async {
      await signUpNewUser('enoop');
      final id = await repo.create(_input());
      final before = await rawParcel(id);
      await repo.update(id, _input());
      final after = await rawParcel(id);
      expect(after['updatedAt'], before['updatedAt']);
      expect(await auditEntries(), isEmpty);
    });

    testWidgets('unknown parcel and invalid input are refused', (t) async {
      await signUpNewUser('ebad');
      await expectLater(repo.update('does-not-exist', _input()), throwsA(isA<AppFailure>().having((e) => e.message, 'message', 'This parcel no longer exists.')));
      final id = await repo.create(_input());
      await expectLater(repo.update(id, _input(items: [])), throwsA(isA<AppFailure>()));
      await expectLater(repo.update(id, _input(charge: null)), throwsA(isA<AppFailure>()), reason: 'a sent parcel keeps its slip details');
      await expectLater(repo.update(id, _input(reference: '')), throwsA(isA<AppFailure>()));
    });

    testWidgets("another user cannot edit or read this user's parcel or audit log", (t) async {
      await signUpNewUser('eisoA');
      final aUid = FirebaseAuth.instance.currentUser!.uid;
      final id = await repo.create(_input(status: ParcelStatus.draft, reference: '', charge: null));
      await repo.update(id, _input(reference: 'VPP 99999'));
      await waitFor(id, (p) => p.status == ParcelStatus.sent);

      await signUpNewUser('eisoB');
      await expectLater(repo.update(id, _input()), throwsA(isA<AppFailure>()), reason: "B's own data has no such parcel");
      final db = FirebaseFirestore.instance;
      for (final action in <Future<Object?> Function()>[
        () => db.doc('users/$aUid/parcels/$id').update({'parcelStatus': 'returned'}),
        () => db.collection('users/$aUid/audit_logs').get(),
        () => db.collection('users/$aUid/audit_logs').add({'entityType': 'parcel', 'entityId': id, 'action': 'update', 'changedFields': ['x'], 'createdAt': FieldValue.serverTimestamp()}),
      ]) {
        await expectLater(action(), throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'permission-denied')));
      }
    });
  });

  group('payments', () {
    // Order total is Rs. 5,000 (2 x Rs. 2,500).
    Future<Parcel> waitFor(String id, bool Function(Parcel) test) => repo
        .watch(id)
        .firstWhere((p) => p != null && test(p))
        .timeout(const Duration(seconds: 10))
        .then((p) => p!);

    testWidgets('partial then final payment move the parcel to received; history is newest first', (t) async {
      await signUpNewUser('pay');
      final id = await repo.create(_input());
      await repo.recordPayment(id, amountPaisa: 200000, type: PaymentType.advance, note: '  first   part ');
      var parcel = await waitFor(id, (p) => p.receivedPaisa == 200000);
      expect(parcel.outstandingPaisa, 300000);
      expect(parcel.paymentStatus, PaymentStatus.partial);

      await repo.recordPayment(id, amountPaisa: 300000, type: PaymentType.postOfficeRemittance);
      parcel = await waitFor(id, (p) => p.receivedPaisa == 500000);
      expect(parcel.outstandingPaisa, 0);
      expect(parcel.paymentStatus, PaymentStatus.received);

      final history = await repo.watchPayments(id).firstWhere((l) => l.length == 2).timeout(const Duration(seconds: 10));
      expect(history.map((p) => p.amountPaisa), [300000, 200000], reason: 'newest first');
      expect(history.last.note, 'first part');
      expect(history.first.note, isNull);
      expect(history.last.type, PaymentType.advance);
    });

    testWidgets('overpaying, zero, a long note, a gift parcel and a missing parcel are refused', (t) async {
      await signUpNewUser('payneg');
      final id = await repo.create(_input());
      await expectLater(repo.recordPayment(id, amountPaisa: 500100, type: PaymentType.customerPayment), throwsA(isA<AppFailure>()));
      await expectLater(repo.recordPayment(id, amountPaisa: 0, type: PaymentType.customerPayment), throwsA(isA<AppFailure>()));
      await expectLater(
        repo.recordPayment(id, amountPaisa: 100, type: PaymentType.customerPayment, note: 'x' * 201),
        throwsA(isA<AppFailure>()),
      );
      final gift = await repo.create(_input(reference: 'VPL 99999', method: CollectionMethod.giftFree, service: PostalService.vpl));
      await expectLater(repo.recordPayment(gift, amountPaisa: 100, type: PaymentType.customerPayment), throwsA(isA<AppFailure>()));
      await expectLater(repo.recordPayment('nope', amountPaisa: 100, type: PaymentType.customerPayment), throwsA(isA<AppFailure>()));
      expect((await read(repo, id)).receivedPaisa, 0, reason: 'nothing was recorded');
      expect(await repo.watchPayments(id).first, isEmpty);
    });

    testWidgets('two payments at the same moment: both counted once, never above the order total', (t) async {
      await signUpNewUser('paypar');
      final id = await repo.create(_input());
      await Future.wait([
        for (var i = 0; i < 3; i++) repo.recordPayment(id, amountPaisa: 100000, type: PaymentType.customerPayment),
      ]);
      final parcel = await waitFor(id, (p) => p.receivedPaisa == 300000);
      expect(parcel.outstandingPaisa, 200000);
      expect(await repo.watchPayments(id).firstWhere((l) => l.length == 3).timeout(const Duration(seconds: 10)), hasLength(3));
    });

    testWidgets('overlapping payments that together exceed the total: the last one is refused, nothing is lost', (t) async {
      await signUpNewUser('payover');
      final id = await repo.create(_input());
      final results = await Future.wait([
        for (var i = 0; i < 3; i++)
          repo.recordPayment(id, amountPaisa: 200000, type: PaymentType.customerPayment).then((_) => true, onError: (_) => false),
      ]);
      expect(results.where((ok) => ok), hasLength(2), reason: '2 x Rs. 2,000 fit in Rs. 5,000, a third does not');
      final parcel = await waitFor(id, (p) => p.receivedPaisa == 400000);
      expect(parcel.outstandingPaisa, 100000);
    });

    testWidgets('editing a parcel keeps what was received and recalculates the balance', (t) async {
      await signUpNewUser('payedit');
      final id = await repo.create(_input());
      await repo.recordPayment(id, amountPaisa: 200000, type: PaymentType.advance);
      await repo.update(
        id,
        _input(items: [ParcelItem.pieces(productId: 'p1', productName: 'Mango Box', quantity: 3, unitPricePaisa: 250000)]),
      );
      final parcel = await waitFor(id, (p) => p.expectedPaisa == 750000);
      expect(parcel.receivedPaisa, 200000);
      expect(parcel.outstandingPaisa, 550000);
    });
  });

  group('returns, notes, Pay Later dates and corrections', () {
    Future<Parcel> waitFor(String id, bool Function(Parcel) test) => repo
        .watch(id)
        .firstWhere((p) => p != null && test(p))
        .timeout(const Duration(seconds: 10))
        .then((p) => p!);
    String today() => pakistanDate(DateTime.now().toUtc());
    Future<String> firstPaymentId(String id) async => (await repo.watchPayments(id).firstWhere((l) => l.isNotEmpty).timeout(const Duration(seconds: 10))).last.id;

    testWidgets('marking returned: flags review when money is involved, locks the parcel, refuses bad dates', (t) async {
      await signUpNewUser('ret');
      final id = await repo.create(_input());
      await expectLater(repo.markReturned(id, date: '2999-01-01'), throwsA(isA<AppFailure>()), reason: 'future');
      await expectLater(repo.markReturned(id, date: '2000-01-01'), throwsA(isA<AppFailure>()), reason: 'before sending');
      await expectLater(repo.markReturned(id, date: today(), reason: 'x' * 201), throwsA(isA<AppFailure>()));
      await repo.markReturned(id, date: today(), reason: '  Customer   refused ');
      final parcel = await waitFor(id, (p) => p.status == ParcelStatus.returned);
      expect(parcel.returnedDate, today());
      expect(parcel.returnReason, 'Customer refused');
      expect(parcel.paymentReviewRequired, isTrue, reason: 'Rs. 5,000 still outstanding');
      expect(parcel.outstandingPaisa, 500000, reason: 'nothing is changed automatically');

      await expectLater(repo.markReturned(id, date: today()), throwsA(isA<AppFailure>()), reason: 'already returned');
      await expectLater(repo.recordPayment(id, amountPaisa: 100, type: PaymentType.advance), throwsA(isA<AppFailure>()));
      await expectLater(repo.update(id, _input(reference: 'VPP 77777')), throwsA(isA<AppFailure>()));
    });

    testWidgets('a draft cannot be returned; a Gift / Free parcel returns without review', (t) async {
      await signUpNewUser('retdraft');
      final draft = await repo.create(_input(reference: '', charge: null, status: ParcelStatus.draft));
      await expectLater(repo.markReturned(draft, date: today()), throwsA(isA<AppFailure>()));
      final gift = await repo.create(_input(reference: 'VPL 55555', method: CollectionMethod.giftFree, service: PostalService.vpl));
      await repo.markReturned(gift, date: today());
      expect((await waitFor(gift, (p) => p.status == ParcelStatus.returned)).paymentReviewRequired, isFalse);
    });

    testWidgets('notes: saved, trimmed, kept through edits, removed when emptied, still editable after a return', (t) async {
      await signUpNewUser('notes');
      final id = await repo.create(_input());
      await repo.setNotes(id, '  Call before delivery ');
      expect((await waitFor(id, (p) => p.notes != null)).notes, 'Call before delivery');
      await expectLater(repo.setNotes(id, 'x' * 501), throwsA(isA<AppFailure>()));
      await repo.update(id, _input(charge: 20000));
      expect((await waitFor(id, (p) => p.deliveryChargePaisa == 20000)).notes, 'Call before delivery');
      await repo.markReturned(id, date: today());
      await repo.setNotes(id, 'Returned by the customer');
      expect((await waitFor(id, (p) => p.notes == 'Returned by the customer')).status, ParcelStatus.returned);
      await repo.setNotes(id, '   ');
      expect((await waitFor(id, (p) => p.notes == null)).notes, isNull);
    });

    testWidgets('Pay Later date: changed, cleared, refused in the past, refused on other types and when nothing is owed', (t) async {
      await signUpNewUser('paydate');
      final id = await repo.create(_input(reference: 'VPL 12121', method: CollectionMethod.payLater, service: PostalService.vpl, payDate: '2031-01-01'));
      await repo.setPayLaterDate(id, '2032-02-02');
      expect((await waitFor(id, (p) => p.estimatedPaymentDate == '2032-02-02')).estimatedPaymentDate, '2032-02-02');
      await expectLater(repo.setPayLaterDate(id, '2000-01-01'), throwsA(isA<AppFailure>()));
      await repo.setPayLaterDate(id, today());
      await waitFor(id, (p) => p.estimatedPaymentDate == today());
      await repo.setPayLaterDate(id, null);
      expect((await waitFor(id, (p) => p.estimatedPaymentDate == null)).estimatedPaymentDate, isNull);

      final other = await repo.create(_input());
      await expectLater(repo.setPayLaterDate(other, '2032-02-02'), throwsA(isA<AppFailure>()), reason: 'not a Pay Later parcel');
      await repo.recordPayment(id, amountPaisa: 500000, type: PaymentType.customerPayment);
      await expectLater(repo.setPayLaterDate(id, '2033-03-03'), throwsA(isA<AppFailure>()), reason: 'paid in full');
    });

    testWidgets('"received on": today is accepted; a future date or a date before the sending date is refused', (t) async {
      await signUpNewUser('recon');
      final id = await repo.create(_input());
      await expectLater(repo.recordPayment(id, amountPaisa: 100, type: PaymentType.advance, receivedOn: '2999-01-01'), throwsA(isA<AppFailure>()));
      await expectLater(repo.recordPayment(id, amountPaisa: 100, type: PaymentType.advance, receivedOn: '2000-01-01'), throwsA(isA<AppFailure>()));
      await repo.recordPayment(id, amountPaisa: 100000, type: PaymentType.advance, receivedOn: today());
      expect((await waitFor(id, (p) => p.receivedPaisa == 100000)).paymentStatus, PaymentStatus.partial);
      final history = await repo.watchPayments(id).first;
      expect(pakistanDate(history.single.receivedAt), today());
    });

    testWidgets('correcting a payment: reversal + replacement keep the history; totals follow; a payment is corrected once', (t) async {
      await signUpNewUser('cor');
      final id = await repo.create(_input());
      await repo.recordPayment(id, amountPaisa: 200000, type: PaymentType.advance, note: 'first');
      final original = await firstPaymentId(id);

      await expectLater(repo.correctPayment(id, original, correctedAmountPaisa: 300000, reason: 'oops'), throwsA(isA<AppFailure>()), reason: 'reason too short');
      await expectLater(repo.correctPayment(id, original, correctedAmountPaisa: 200000, reason: 'Wrong amount'), throwsA(isA<AppFailure>()), reason: 'unchanged');
      await expectLater(repo.correctPayment(id, original, correctedAmountPaisa: 600000, reason: 'Wrong amount'), throwsA(isA<AppFailure>()), reason: 'above the total');
      await repo.correctPayment(id, original, correctedAmountPaisa: 300000, reason: 'Wrong amount entered');

      final parcel = await waitFor(id, (p) => p.receivedPaisa == 300000);
      expect(parcel.outstandingPaisa, 200000);
      expect(parcel.paymentStatus, PaymentStatus.partial);
      final history = await repo.watchPayments(id).firstWhere((l) => l.length == 3).timeout(const Duration(seconds: 10));
      expect(history.map((p) => p.amountPaisa).toSet(), {200000, -200000, 300000});
      expect(history.where((p) => p.isReversal).single.correctionReason, 'Wrong amount entered');
      expect(history.where((p) => p.correctionOfPaymentId == original), hasLength(1));

      await expectLater(repo.correctPayment(id, original, correctedAmountPaisa: 100000, reason: 'Second try'), throwsA(isA<AppFailure>()), reason: 'already corrected');
      await expectLater(repo.correctPayment(id, 'rev_$original', correctedAmountPaisa: 100000, reason: 'Correct a reversal'), throwsA(isA<AppFailure>()), reason: 'reversals are final');
    });

    testWidgets('a correction to 0 only cancels the payment; two corrections at once: one wins', (t) async {
      await signUpNewUser('corzero');
      final id = await repo.create(_input());
      await repo.recordPayment(id, amountPaisa: 200000, type: PaymentType.advance);
      final original = await firstPaymentId(id);
      final results = await Future.wait([
        for (var i = 0; i < 2; i++)
          repo.correctPayment(id, original, correctedAmountPaisa: 0, reason: 'Entered by mistake').then((_) => true, onError: (_) => false),
      ]);
      expect(results.where((ok) => ok), hasLength(1));
      final parcel = await waitFor(id, (p) => p.receivedPaisa == 0);
      expect(parcel.paymentStatus, PaymentStatus.pending);
      expect(parcel.outstandingPaisa, 500000);
      expect(await repo.watchPayments(id).firstWhere((l) => l.length == 2).timeout(const Duration(seconds: 10)), hasLength(2), reason: 'the payment and its reversal');
    });

    testWidgets("another user cannot return, annotate or correct this user's parcel", (t) async {
      await signUpNewUser('own');
      final id = await repo.create(_input());
      await repo.recordPayment(id, amountPaisa: 100000, type: PaymentType.advance);
      final payment = await firstPaymentId(id);
      await signUpNewUser('intruder');
      await expectLater(repo.markReturned(id, date: today()), throwsA(isA<AppFailure>()));
      await expectLater(repo.setNotes(id, 'hello'), throwsA(isA<AppFailure>()));
      await expectLater(repo.correctPayment(id, payment, correctedAmountPaisa: 0, reason: 'Not yours'), throwsA(isA<AppFailure>()));
    });
  });
}
