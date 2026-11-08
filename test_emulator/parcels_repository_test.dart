// Real FirestoreParcelRepository on the Android emulator against the Auth + Firestore emulators.
// Run (an Android emulator must be running):
//   firebase emulators:exec --only auth,firestore --project delivtrack-codewingz \
//     "flutter test test_emulator -d <android-emulator>"
// The Firebase SDK reaches the host's emulators through the Android emulator's host alias.
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:deliv_track/core/errors/app_failure.dart';
import 'package:deliv_track/core/time/pakistan_time.dart';
import 'package:deliv_track/features/customers/domain/customer.dart';
import 'package:deliv_track/features/parcels/data/parcel_repository.dart';
import 'package:deliv_track/features/parcels/domain/parcel.dart';
import 'package:deliv_track/features/parcels/domain/parcel_enums.dart';
import 'package:deliv_track/features/parcels/domain/parcel_handover.dart';
import 'package:deliv_track/features/parcels/domain/parcel_input.dart';
import 'package:deliv_track/features/parcels/domain/parcel_item.dart';
import 'package:deliv_track/features/parcels/domain/payment.dart';
import 'package:deliv_track/firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _customer = Customer(
  id: 'cust1',
  name: 'Ali Raza',
  phone: '0300 1234567',
  address: 'House 5, Sahiwal',
);

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
}) => ParcelInput(
  customer: _customer,
  items:
      items ??
      [
        ParcelItem.pieces(
          productId: 'p1',
          productName: 'Mango Box',
          quantity: 2,
          unitPricePaisa: 250000,
        ),
      ],
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
  // The parcel rules now require the customer record the parcel's snapshot is copied from.
  final uid = FirebaseAuth.instance.currentUser!.uid;
  await FirebaseFirestore.instance.doc('users/$uid/customers/cust1').set({
    'displayName': 'Ali Raza',
    'displayNameLower': 'ali raza',
    'phone': '0300 1234567',
    'phoneNormalized': '03001234567',
    'address': 'House 5, Sahiwal',
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  });
}

Future<Parcel> read(ParcelRepository repo, String id) => repo
    .watch(id)
    .firstWhere((p) => p != null)
    .timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw StateError('parcel never appeared'),
    )
    .then((p) => p!);

/// Writes raw fields with the emulator's admin token (which bypasses the rules), to simulate a document
/// damaged or edited outside the app. [mask] limits the write to those fields (otherwise it replaces the document).
Future<void> writeRaw(
  String path,
  Map<String, Object> fields, {
  List<String>? mask,
}) async {
  final client = HttpClient();
  final query = mask == null
      ? ''
      : '?${mask.map((f) => 'updateMask.fieldPaths=$f').join('&')}';
  final request = await client.openUrl(
    'PATCH',
    Uri.parse(
      'http://10.0.2.2:8080/v1/projects/delivtrack-codewingz/databases/(default)/documents/$path$query',
    ),
  );
  request.headers.set('Authorization', 'Bearer owner');
  request.headers.contentType = ContentType.json;
  request.write(jsonEncode({'fields': fields}));
  final response = await request.close();
  await response.drain<void>();
  expect(response.statusCode, 200);
  client.close();
}

Map<String, Object?> _restValue(Object? v) => switch (v) {
  null => {'nullValue': null},
  bool b => {'booleanValue': b},
  int i => {'integerValue': '$i'},
  String s => {'stringValue': s},
  DateTime d => {'timestampValue': d.toUtc().toIso8601String()},
  List l => {
    'arrayValue': {
      'values': [for (final e in l) _restValue(e)],
    },
  },
  Map m => {
    'mapValue': {
      'fields': {
        for (final e in m.entries) e.key as String: _restValue(e.value),
      },
    },
  },
  _ => throw ArgumentError('unsupported $v'),
};

/// Writes many documents with the emulator's admin token (batches of 400), for load tests.
Future<void> writeManyRaw(Map<String, Map<String, Object?>> documents) async {
  final client = HttpClient();
  final entries = documents.entries.toList();
  for (var start = 0; start < entries.length; start += 400) {
    final request = await client.openUrl(
      'POST',
      Uri.parse(
        'http://10.0.2.2:8080/v1/projects/delivtrack-codewingz/databases/(default)/documents:commit',
      ),
    );
    request.headers.set('Authorization', 'Bearer owner');
    request.headers.contentType = ContentType.json;
    request.write(
      jsonEncode({
        'writes': [
          for (final entry in entries.skip(start).take(400))
            {
              'update': {
                'name':
                    'projects/delivtrack-codewingz/databases/(default)/documents/${entry.key}',
                'fields': {
                  for (final f in entry.value.entries)
                    f.key: _restValue(f.value),
                },
              },
            },
        ],
      }),
    );
    final response = await request.close();
    await response.drain<void>();
    expect(response.statusCode, 200);
  }
  client.close();
}

Map<String, Object?> _loadParcel(
  int sequence, {
  int received = 0,
  String? lastPaymentId,
}) => {
  'orderNumber': 'ADT-${sequence.toString().padLeft(6, '0')}',
  'orderSequence': sequence,
  'customerId': 'cust1',
  'customerSnapshot': {
    'name': 'Ali Raza',
    'phone': '0300 1234567',
    'address': 'House 5, Sahiwal',
  },
  'items': [
    {
      'productId': 'p1',
      'productName': 'Mango Box',
      'saleUnit': 'per_piece',
      'quantity': 2,
      'unitPricePaisa': 250000,
      'lineTotalPaisa': 500000,
    },
  ],
  'collectionMethod': 'postal_collection',
  'postalServiceType': 'VPP',
  'postalReference': 'VPP $sequence',
  'postalReferenceNormalized': 'VPP$sequence',
  'deliveryChargePaisa': 15000,
  'productAmountExpectedPaisa': 500000,
  'receivedPaisa': received,
  'outstandingPaisa': 500000 - received,
  'paymentStatus': received > 0 ? 'partial' : 'pending',
  'parcelStatus': 'sent',
  'sendingDateLocal': pakistanDate(DateTime.now().toUtc()),
  'lastPaymentId': ?lastPaymentId,
  'createdAt': DateTime.now().toUtc(),
  'updatedAt': DateTime.now().toUtc(),
};

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late FirestoreParcelRepository repo;

  setUpAll(() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    repo = FirestoreParcelRepository();
  });

  testWidgets(
    'order numbers run 1, 2, 3 and the saved parcel carries everything',
    (t) async {
      await signUpNewUser('pseq');
      final id1 = await repo.create(
        _input(reference: 'VPP 11111', packedGrams: 1500),
      );
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

      final all = await repo
          .watchAll()
          .firstWhere((l) => l.length == 3)
          .timeout(const Duration(seconds: 10));
      expect(all.map((p) => p.orderNumber), [
        'ADT-000003',
        'ADT-000002',
        'ADT-000001',
      ], reason: 'newest first');
    },
  );

  testWidgets(
    'five simultaneous saves get five different consecutive numbers',
    (t) async {
      await signUpNewUser('prace');
      final ids = await Future.wait([
        for (var i = 0; i < 5; i++)
          repo.create(_input(reference: 'VPP 9000$i')),
      ]);
      expect(ids.toSet(), hasLength(5));
      final parcels = await Future.wait([for (final id in ids) read(repo, id)]);
      final numbers = parcels.map((p) => p.orderSequence).toList()..sort();
      expect(numbers, [1, 2, 3, 4, 5]);
    },
  );

  testWidgets(
    'a postal reference can be used once per service, however it is typed',
    (t) async {
      await signUpNewUser('pref');
      final first = await repo.create(_input(reference: 'VPP 12345'));
      final firstNumber = (await read(repo, first)).orderNumber;

      for (final typed in ['vpp12345', 'VPP  12345', ' vpp 12 345 ']) {
        await expectLater(
          repo.create(_input(reference: typed)),
          throwsA(
            isA<AppFailure>().having(
              (e) => e.message,
              'message',
              'This postal reference is already used on $firstNumber.',
            ),
          ),
          reason: typed,
        );
      }
      // The same text on a different service is a different reference.
      await repo.create(
        _input(
          reference: 'VPP 12345',
          service: PostalService.vpl,
          method: CollectionMethod.advance,
        ),
      );
      // "Other" services are told apart by name.
      await repo.create(
        _input(
          reference: 'ABC 123',
          service: PostalService.other,
          otherName: 'Fast Courier',
        ),
      );
      await repo.create(
        _input(
          reference: 'ABC 123',
          service: PostalService.other,
          otherName: 'Other Courier',
        ),
      );
      await expectLater(
        repo.create(
          _input(
            reference: 'abc123',
            service: PostalService.other,
            otherName: ' fast   courier ',
          ),
        ),
        throwsA(isA<AppFailure>()),
      );

      final all = await repo
          .watchAll()
          .firstWhere((l) => l.length == 4)
          .timeout(const Duration(seconds: 10));
      expect(all.map((p) => p.orderSequence), [
        4,
        3,
        2,
        1,
      ], reason: 'refused saves must not use up order numbers');
    },
  );

  testWidgets(
    'drafts, Pay Later with a date, free parcels and Other services are stored correctly',
    (t) async {
      await signUpNewUser('pkinds');
      final draft = await read(
        repo,
        await repo.create(
          _input(status: ParcelStatus.draft, reference: '', charge: null),
        ),
      );
      expect(draft.status, ParcelStatus.draft);
      expect(draft.postalReference, isEmpty);
      expect(draft.deliveryChargePaisa, isNull);

      final later = await read(
        repo,
        await repo.create(
          _input(
            method: CollectionMethod.payLater,
            service: PostalService.vpl,
            reference: 'VPL 55555',
            payDate: '2999-01-31',
          ),
        ),
      );
      expect(later.method, CollectionMethod.payLater);
      expect(later.estimatedPaymentDate, '2999-01-31');

      final free = await read(
        repo,
        await repo.create(
          _input(
            method: CollectionMethod.giftFree,
            service: PostalService.vpl,
            reference: 'VPL 66666',
            items: [
              ParcelItem.pieces(
                productId: 'p1',
                productName: 'Mango Box',
                quantity: 1,
                unitPricePaisa: 0,
              ),
            ],
          ),
        ),
      );
      expect(free.expectedPaisa, 0);
      expect(free.outstandingPaisa, 0);
      expect(free.paymentStatus, PaymentStatus.notRequired);

      final other = await read(
        repo,
        await repo.create(
          _input(
            service: PostalService.other,
            otherName: ' Fast   Courier ',
            reference: 'XYZ 99999',
          ),
        ),
      );
      expect(other.service, PostalService.other);
      expect(other.otherServiceName, 'Fast Courier');
      expect(other.serviceLabel, 'Fast Courier');
    },
  );

  testWidgets(
    'invalid input is refused before anything is written and does not use an order number',
    (t) async {
      await signUpNewUser('pbad');
      await expectLater(
        repo.create(_input(items: [])),
        throwsA(isA<AppFailure>()),
      );
      await expectLater(
        repo.create(_input(charge: null)),
        throwsA(isA<AppFailure>()),
      );
      await expectLater(
        repo.create(_input(payDate: '2999-01-01')),
        throwsA(isA<AppFailure>()),
        reason: 'not a Pay Later parcel',
      );
      final id = await repo.create(_input());
      expect((await read(repo, id)).orderNumber, 'ADT-000001');
    },
  );

  testWidgets(
    'users are isolated: separate numbering, no access to the other user\'s parcels, same references allowed',
    (t) async {
      await signUpNewUser('puserA');
      final aUid = FirebaseAuth.instance.currentUser!.uid;
      final aId = await repo.create(_input(reference: 'VPP 77777'));
      expect((await read(repo, aId)).orderNumber, 'ADT-000001');

      await signUpNewUser('puserB');
      expect(await repo.watchAll().first, isEmpty);
      final bId = await repo.create(
        _input(reference: 'VPP 77777'),
      ); // same reference: B has their own references
      expect(
        (await read(repo, bId)).orderNumber,
        'ADT-000001',
        reason: 'B starts again at 1',
      );

      final db = FirebaseFirestore.instance;
      for (final action in <Future<Object?> Function()>[
        () => db.doc('users/$aUid/parcels/$aId').get(),
        () => db.collection('users/$aUid/parcels').get(),
        () => db.doc('users/$aUid/counters/orders').get(),
        () => db.doc('users/$aUid/parcels/$aId').update({
          'parcelStatus': 'returned',
        }),
        () => db.doc('users/$aUid/counters/orders').set({'lastSequence': 99}),
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
    await expectLater(repo.create(_input()), throwsA(isA<AppFailure>()));
  });

  group('editing', () {
    Future<List<Map<String, dynamic>>> auditEntries() async {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final snapshot = await FirebaseFirestore.instance
          .collection('users/$uid/audit_logs')
          .get();
      return [for (final d in snapshot.docs) d.data()];
    }

    Future<Map<String, dynamic>> rawParcel(String id) async {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      return (await FirebaseFirestore.instance
              .doc('users/$uid/parcels/$id')
              .get())
          .data()!;
    }

    Future<Parcel> waitFor(String id, bool Function(Parcel) test) => repo
        .watch(id)
        .firstWhere((p) => p != null && test(p))
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () =>
              throw StateError('parcel never reached the expected state'),
        )
        .then((p) => p!);

    testWidgets(
      'a draft becomes Sent: slip details saved, reference reserved, number/date/created time untouched, audit entry written',
      (t) async {
        await signUpNewUser('edraft');
        final id = await repo.create(
          _input(status: ParcelStatus.draft, reference: '', charge: null),
        );
        final before = await rawParcel(id);

        await repo.update(
          id,
          _input(reference: 'vpp 77777', charge: 20000, packedGrams: 2500),
        );
        final after = await waitFor(id, (p) => p.status == ParcelStatus.sent);
        expect(after.postalReference, 'vpp 77777');
        expect(after.deliveryChargePaisa, 20000);
        expect(after.packedWeightGrams, 2500);
        expect(after.orderNumber, 'ADT-000001');

        final raw = await rawParcel(id);
        for (final locked in [
          'orderNumber',
          'orderSequence',
          'sendingDateLocal',
          'createdAt',
        ]) {
          expect(
            raw[locked],
            before[locked],
            reason: '$locked must never change',
          );
        }
        expect(raw['postalReferenceNormalized'], 'VPP77777');

        // the reference is now taken
        await expectLater(
          repo.create(_input(reference: 'VPP 77777')),
          throwsA(
            isA<AppFailure>().having(
              (e) => e.message,
              'message',
              'This postal reference is already used on ADT-000001.',
            ),
          ),
        );

        final audit = await auditEntries();
        expect(audit, hasLength(1));
        expect(audit.single['entityType'], 'parcel');
        expect(audit.single['entityId'], id);
        expect(audit.single['orderNumber'], 'ADT-000001');
        expect(
          audit.single['changedFields'],
          containsAll([
            'parcelStatus',
            'postalReference',
            'postalReferenceNormalized',
            'deliveryChargePaisa',
            'actualPackedWeightGrams',
          ]),
        );
      },
    );

    testWidgets(
      'changing the reference frees the old one and reserves the new one; a taken reference is refused and changes nothing',
      (t) async {
        await signUpNewUser('eref');
        final a = await repo.create(_input(reference: 'VPP 11111'));
        final b = await repo.create(_input(reference: 'VPP 22222'));
        final bNumber = (await read(repo, b)).orderNumber;

        await expectLater(
          repo.update(a, _input(reference: 'VPP22222')),
          throwsA(
            isA<AppFailure>().having(
              (e) => e.message,
              'message',
              'This postal reference is already used on $bNumber.',
            ),
          ),
        );
        expect(
          (await rawParcel(a))['postalReference'],
          'VPP 11111',
          reason: 'a refused edit changes nothing',
        );
        expect(
          await auditEntries(),
          isEmpty,
          reason: 'and writes no audit entry',
        );

        await repo.update(a, _input(reference: 'VPP 33333'));
        await waitFor(a, (p) => p.postalReference == 'VPP 33333');
        // the old reference can be used again, the new one cannot
        await repo.create(_input(reference: 'VPP 11111'));
        await expectLater(
          repo.create(_input(reference: 'VPP 33333')),
          throwsA(isA<AppFailure>()),
        );
        // keeping its own reference while editing something else is not a conflict
        await repo.update(a, _input(reference: 'VPP 33333', charge: 999));
        expect(
          (await waitFor(
            a,
            (p) => p.deliveryChargePaisa == 999,
          )).postalReference,
          'VPP 33333',
        );
      },
    );

    testWidgets(
      'changed products recalculate the totals; Gift / Free expects nothing; payment status follows',
      (t) async {
        await signUpNewUser('etotals');
        final id = await repo.create(_input());
        expect((await read(repo, id)).expectedPaisa, 500000);

        await repo.update(
          id,
          _input(
            items: [
              ParcelItem.pieces(
                productId: 'p1',
                productName: 'Mango Box',
                quantity: 3,
                unitPricePaisa: 100000,
              ),
              ParcelItem.weight(
                productId: 'p2',
                productName: 'Dry Fruits',
                weightGrams: 1250,
                unitPricePaisa: 80000,
              ),
            ],
          ),
        );
        final bigger = await waitFor(id, (p) => p.items.length == 2);
        expect(bigger.expectedPaisa, 400000);
        expect(bigger.outstandingPaisa, 400000);
        expect(bigger.paymentStatus, PaymentStatus.pending);

        await repo.update(
          id,
          _input(
            method: CollectionMethod.giftFree,
            service: PostalService.vpl,
            items: [
              ParcelItem.pieces(
                productId: 'p1',
                productName: 'Mango Box',
                quantity: 3,
                unitPricePaisa: 0,
              ),
            ],
          ),
        );
        final gift = await waitFor(
          id,
          (p) => p.method == CollectionMethod.giftFree,
        );
        expect(gift.expectedPaisa, 0);
        expect(gift.outstandingPaisa, 0);
        expect(gift.paymentStatus, PaymentStatus.notRequired);
      },
    );

    testWidgets(
      'optional fields can be removed again (charge, packed weight, service name, payment date)',
      (t) async {
        await signUpNewUser('eopt');
        final id = await repo.create(
          _input(
            method: CollectionMethod.payLater,
            service: PostalService.other,
            otherName: 'Fast Courier',
            reference: 'ABC 12345',
            packedGrams: 1500,
            payDate: '2999-01-31',
          ),
        );
        expect((await rawParcel(id))['otherPostalServiceName'], 'Fast Courier');

        await repo.update(
          id,
          _input(
            status: ParcelStatus.draft,
            method: CollectionMethod.payLater,
            service: PostalService.vpl,
            reference: '',
            charge: null,
          ),
        );
        await waitFor(id, (p) => p.status == ParcelStatus.draft);
        final raw = await rawParcel(id);
        for (final removed in [
          'otherPostalServiceName',
          'deliveryChargePaisa',
          'actualPackedWeightGrams',
          'estimatedPaymentDateLocal',
        ]) {
          expect(
            raw.containsKey(removed),
            isFalse,
            reason: '$removed should be gone',
          );
        }
        expect(raw['postalReferenceNormalized'], '');
        // clearing the reference released it
        await repo.create(
          _input(
            reference: 'ABC 12345',
            service: PostalService.other,
            otherName: 'Fast Courier',
          ),
        );
      },
    );

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
      await expectLater(
        repo.update('does-not-exist', _input()),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.message,
            'message',
            'This parcel no longer exists.',
          ),
        ),
      );
      final id = await repo.create(_input());
      await expectLater(
        repo.update(id, _input(items: [])),
        throwsA(isA<AppFailure>()),
      );
      await expectLater(
        repo.update(id, _input(charge: null)),
        throwsA(isA<AppFailure>()),
        reason: 'a sent parcel keeps its slip details',
      );
      await expectLater(
        repo.update(id, _input(reference: '')),
        throwsA(isA<AppFailure>()),
      );
    });

    testWidgets(
      "another user cannot edit or read this user's parcel or audit log",
      (t) async {
        await signUpNewUser('eisoA');
        final aUid = FirebaseAuth.instance.currentUser!.uid;
        final id = await repo.create(
          _input(status: ParcelStatus.draft, reference: '', charge: null),
        );
        await repo.update(id, _input(reference: 'VPP 99999'));
        await waitFor(id, (p) => p.status == ParcelStatus.sent);

        await signUpNewUser('eisoB');
        await expectLater(
          repo.update(id, _input()),
          throwsA(isA<AppFailure>()),
          reason: "B's own data has no such parcel",
        );
        final db = FirebaseFirestore.instance;
        for (final action in <Future<Object?> Function()>[
          () => db.doc('users/$aUid/parcels/$id').update({
            'parcelStatus': 'returned',
          }),
          () => db.collection('users/$aUid/audit_logs').get(),
          () => db.collection('users/$aUid/audit_logs').add({
            'entityType': 'parcel',
            'entityId': id,
            'action': 'update',
            'changedFields': ['x'],
            'createdAt': FieldValue.serverTimestamp(),
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
  });

  group('payments', () {
    // Order total is Rs. 5,000 (2 x Rs. 2,500).
    Future<Parcel> waitFor(String id, bool Function(Parcel) test) => repo
        .watch(id)
        .firstWhere((p) => p != null && test(p))
        .timeout(const Duration(seconds: 10))
        .then((p) => p!);

    testWidgets(
      'partial then final payment move the parcel to received; history is newest first',
      (t) async {
        await signUpNewUser('pay');
        final id = await repo.create(_input());
        await repo.recordPayment(
          id,
          amountPaisa: 200000,
          type: PaymentType.advance,
          note: '  first   part ',
        );
        var parcel = await waitFor(id, (p) => p.receivedPaisa == 200000);
        expect(parcel.outstandingPaisa, 300000);
        expect(parcel.paymentStatus, PaymentStatus.partial);

        await repo.recordPayment(
          id,
          amountPaisa: 300000,
          type: PaymentType.postOfficeRemittance,
        );
        parcel = await waitFor(id, (p) => p.receivedPaisa == 500000);
        expect(parcel.outstandingPaisa, 0);
        expect(parcel.paymentStatus, PaymentStatus.received);

        final history = await repo
            .watchPayments(id)
            .firstWhere((l) => l.length == 2)
            .timeout(const Duration(seconds: 10));
        expect(history.map((p) => p.amountPaisa), [
          300000,
          200000,
        ], reason: 'newest first');
        expect(history.last.note, 'first part');
        expect(history.first.note, isNull);
        expect(history.last.type, PaymentType.advance);
      },
    );

    testWidgets(
      'overpaying, zero, a long note, a gift parcel and a missing parcel are refused',
      (t) async {
        await signUpNewUser('payneg');
        final id = await repo.create(_input());
        await expectLater(
          repo.recordPayment(
            id,
            amountPaisa: 500100,
            type: PaymentType.customerPayment,
          ),
          throwsA(isA<AppFailure>()),
        );
        await expectLater(
          repo.recordPayment(
            id,
            amountPaisa: 0,
            type: PaymentType.customerPayment,
          ),
          throwsA(isA<AppFailure>()),
        );
        await expectLater(
          repo.recordPayment(
            id,
            amountPaisa: 100,
            type: PaymentType.customerPayment,
            note: 'x' * 201,
          ),
          throwsA(isA<AppFailure>()),
        );
        final gift = await repo.create(
          _input(
            reference: 'VPL 99999',
            method: CollectionMethod.giftFree,
            service: PostalService.vpl,
          ),
        );
        await expectLater(
          repo.recordPayment(
            gift,
            amountPaisa: 100,
            type: PaymentType.customerPayment,
          ),
          throwsA(isA<AppFailure>()),
        );
        await expectLater(
          repo.recordPayment(
            'nope',
            amountPaisa: 100,
            type: PaymentType.customerPayment,
          ),
          throwsA(isA<AppFailure>()),
        );
        expect(
          (await read(repo, id)).receivedPaisa,
          0,
          reason: 'nothing was recorded',
        );
        expect(await repo.watchPayments(id).first, isEmpty);
      },
    );

    testWidgets(
      'two payments at the same moment: both counted once, never above the order total',
      (t) async {
        await signUpNewUser('paypar');
        final id = await repo.create(_input());
        await Future.wait([
          for (var i = 0; i < 3; i++)
            repo.recordPayment(
              id,
              amountPaisa: 100000,
              type: PaymentType.customerPayment,
            ),
        ]);
        final parcel = await waitFor(id, (p) => p.receivedPaisa == 300000);
        expect(parcel.outstandingPaisa, 200000);
        expect(
          await repo
              .watchPayments(id)
              .firstWhere((l) => l.length == 3)
              .timeout(const Duration(seconds: 10)),
          hasLength(3),
        );
      },
    );

    testWidgets(
      'overlapping payments that together exceed the total: the last one is refused, nothing is lost',
      (t) async {
        await signUpNewUser('payover');
        final id = await repo.create(_input());
        final results = await Future.wait([
          for (var i = 0; i < 3; i++)
            repo
                .recordPayment(
                  id,
                  amountPaisa: 200000,
                  type: PaymentType.customerPayment,
                )
                .then((_) => true, onError: (_) => false),
        ]);
        expect(
          results.where((ok) => ok),
          hasLength(2),
          reason: '2 x Rs. 2,000 fit in Rs. 5,000, a third does not',
        );
        final parcel = await waitFor(id, (p) => p.receivedPaisa == 400000);
        expect(parcel.outstandingPaisa, 100000);
      },
    );

    testWidgets(
      'editing a parcel keeps what was received and recalculates the balance',
      (t) async {
        await signUpNewUser('payedit');
        final id = await repo.create(_input());
        await repo.recordPayment(
          id,
          amountPaisa: 200000,
          type: PaymentType.advance,
        );
        await repo.update(
          id,
          _input(
            items: [
              ParcelItem.pieces(
                productId: 'p1',
                productName: 'Mango Box',
                quantity: 3,
                unitPricePaisa: 250000,
              ),
            ],
          ),
        );
        final parcel = await waitFor(id, (p) => p.expectedPaisa == 750000);
        expect(parcel.receivedPaisa, 200000);
        expect(parcel.outstandingPaisa, 550000);
      },
    );
  });

  group('returns, notes, Pay Later dates and corrections', () {
    Future<Parcel> waitFor(String id, bool Function(Parcel) test) => repo
        .watch(id)
        .firstWhere((p) => p != null && test(p))
        .timeout(const Duration(seconds: 10))
        .then((p) => p!);
    String today() => pakistanDate(DateTime.now().toUtc());
    Future<String> firstPaymentId(String id) async =>
        (await repo
                .watchPayments(id)
                .firstWhere((l) => l.isNotEmpty)
                .timeout(const Duration(seconds: 10)))
            .last
            .id;

    testWidgets(
      'marking returned: flags review when money is involved, locks the parcel, refuses bad dates',
      (t) async {
        await signUpNewUser('ret');
        final id = await repo.create(_input());
        await expectLater(
          repo.markReturned(id, date: '2999-01-01'),
          throwsA(isA<AppFailure>()),
          reason: 'future',
        );
        await expectLater(
          repo.markReturned(id, date: '2000-01-01'),
          throwsA(isA<AppFailure>()),
          reason: 'before sending',
        );
        await expectLater(
          repo.markReturned(id, date: today(), reason: 'x' * 201),
          throwsA(isA<AppFailure>()),
        );
        await repo.markReturned(
          id,
          date: today(),
          reason: '  Customer   refused ',
        );
        final parcel = await waitFor(
          id,
          (p) => p.status == ParcelStatus.returned,
        );
        expect(parcel.returnedDate, today());
        expect(parcel.returnReason, 'Customer refused');
        expect(
          parcel.paymentReviewRequired,
          isTrue,
          reason: 'Rs. 5,000 still outstanding',
        );
        expect(
          parcel.outstandingPaisa,
          500000,
          reason: 'nothing is changed automatically',
        );

        await expectLater(
          repo.markReturned(id, date: today()),
          throwsA(isA<AppFailure>()),
          reason: 'already returned',
        );
        await expectLater(
          repo.recordPayment(id, amountPaisa: 100, type: PaymentType.advance),
          throwsA(isA<AppFailure>()),
        );
        await expectLater(
          repo.update(id, _input(reference: 'VPP 77777')),
          throwsA(isA<AppFailure>()),
        );
      },
    );

    testWidgets(
      'a draft cannot be returned; a Gift / Free parcel returns without review',
      (t) async {
        await signUpNewUser('retdraft');
        final draft = await repo.create(
          _input(reference: '', charge: null, status: ParcelStatus.draft),
        );
        await expectLater(
          repo.markReturned(draft, date: today()),
          throwsA(isA<AppFailure>()),
        );
        final gift = await repo.create(
          _input(
            reference: 'VPL 55555',
            method: CollectionMethod.giftFree,
            service: PostalService.vpl,
          ),
        );
        await repo.markReturned(gift, date: today());
        expect(
          (await waitFor(
            gift,
            (p) => p.status == ParcelStatus.returned,
          )).paymentReviewRequired,
          isFalse,
        );
      },
    );

    testWidgets(
      'notes: saved, trimmed, kept through edits, removed when emptied, still editable after a return',
      (t) async {
        await signUpNewUser('notes');
        final id = await repo.create(_input());
        await repo.setNotes(id, '  Call before delivery ');
        expect(
          (await waitFor(id, (p) => p.notes != null)).notes,
          'Call before delivery',
        );
        await expectLater(
          repo.setNotes(id, 'x' * 501),
          throwsA(isA<AppFailure>()),
        );
        await repo.update(id, _input(charge: 20000));
        expect(
          (await waitFor(id, (p) => p.deliveryChargePaisa == 20000)).notes,
          'Call before delivery',
        );
        await repo.markReturned(id, date: today());
        await repo.setNotes(id, 'Returned by the customer');
        expect(
          (await waitFor(
            id,
            (p) => p.notes == 'Returned by the customer',
          )).status,
          ParcelStatus.returned,
        );
        await repo.setNotes(id, '   ');
        expect((await waitFor(id, (p) => p.notes == null)).notes, isNull);
      },
    );

    testWidgets(
      'Pay Later date: changed, cleared, refused in the past, refused on other types and when nothing is owed',
      (t) async {
        await signUpNewUser('paydate');
        final id = await repo.create(
          _input(
            reference: 'VPL 12121',
            method: CollectionMethod.payLater,
            service: PostalService.vpl,
            payDate: '2031-01-01',
          ),
        );
        await repo.setPayLaterDate(id, '2032-02-02');
        expect(
          (await waitFor(
            id,
            (p) => p.estimatedPaymentDate == '2032-02-02',
          )).estimatedPaymentDate,
          '2032-02-02',
        );
        await expectLater(
          repo.setPayLaterDate(id, '2000-01-01'),
          throwsA(isA<AppFailure>()),
        );
        await repo.setPayLaterDate(id, today());
        await waitFor(id, (p) => p.estimatedPaymentDate == today());
        await repo.setPayLaterDate(id, null);
        expect(
          (await waitFor(
            id,
            (p) => p.estimatedPaymentDate == null,
          )).estimatedPaymentDate,
          isNull,
        );

        final other = await repo.create(_input());
        await expectLater(
          repo.setPayLaterDate(other, '2032-02-02'),
          throwsA(isA<AppFailure>()),
          reason: 'not a Pay Later parcel',
        );
        await repo.recordPayment(
          id,
          amountPaisa: 500000,
          type: PaymentType.customerPayment,
        );
        await expectLater(
          repo.setPayLaterDate(id, '2033-03-03'),
          throwsA(isA<AppFailure>()),
          reason: 'paid in full',
        );
      },
    );

    testWidgets(
      '"received on": today is accepted; a future date or a date before the sending date is refused',
      (t) async {
        await signUpNewUser('recon');
        final id = await repo.create(_input());
        await expectLater(
          repo.recordPayment(
            id,
            amountPaisa: 100,
            type: PaymentType.advance,
            receivedOn: '2999-01-01',
          ),
          throwsA(isA<AppFailure>()),
        );
        await expectLater(
          repo.recordPayment(
            id,
            amountPaisa: 100,
            type: PaymentType.advance,
            receivedOn: '2000-01-01',
          ),
          throwsA(isA<AppFailure>()),
        );
        await repo.recordPayment(
          id,
          amountPaisa: 100000,
          type: PaymentType.advance,
          receivedOn: today(),
        );
        expect(
          (await waitFor(id, (p) => p.receivedPaisa == 100000)).paymentStatus,
          PaymentStatus.partial,
        );
        final history = await repo.watchPayments(id).first;
        expect(pakistanDate(history.single.receivedAt), today());
      },
    );

    testWidgets(
      'correcting a payment: reversal + replacement keep the history; totals follow; a payment is corrected once',
      (t) async {
        await signUpNewUser('cor');
        final id = await repo.create(_input());
        await repo.recordPayment(
          id,
          amountPaisa: 200000,
          type: PaymentType.advance,
          note: 'first',
        );
        final original = await firstPaymentId(id);

        await expectLater(
          repo.correctPayment(
            id,
            original,
            correctedAmountPaisa: 300000,
            reason: 'oops',
          ),
          throwsA(isA<AppFailure>()),
          reason: 'reason too short',
        );
        await expectLater(
          repo.correctPayment(
            id,
            original,
            correctedAmountPaisa: 200000,
            reason: 'Wrong amount',
          ),
          throwsA(isA<AppFailure>()),
          reason: 'unchanged',
        );
        await expectLater(
          repo.correctPayment(
            id,
            original,
            correctedAmountPaisa: 600000,
            reason: 'Wrong amount',
          ),
          throwsA(isA<AppFailure>()),
          reason: 'above the total',
        );
        await repo.correctPayment(
          id,
          original,
          correctedAmountPaisa: 300000,
          reason: 'Wrong amount entered',
        );

        final parcel = await waitFor(id, (p) => p.receivedPaisa == 300000);
        expect(parcel.outstandingPaisa, 200000);
        expect(parcel.paymentStatus, PaymentStatus.partial);
        final history = await repo
            .watchPayments(id)
            .firstWhere((l) => l.length == 3)
            .timeout(const Duration(seconds: 10));
        expect(history.map((p) => p.amountPaisa).toSet(), {
          200000,
          -200000,
          300000,
        });
        expect(
          history.where((p) => p.isReversal).single.correctionReason,
          'Wrong amount entered',
        );
        expect(
          history.where((p) => p.correctionOfPaymentId == original),
          hasLength(1),
        );

        await expectLater(
          repo.correctPayment(
            id,
            original,
            correctedAmountPaisa: 100000,
            reason: 'Second try',
          ),
          throwsA(isA<AppFailure>()),
          reason: 'already corrected',
        );
        await expectLater(
          repo.correctPayment(
            id,
            'rev_$original',
            correctedAmountPaisa: 100000,
            reason: 'Correct a reversal',
          ),
          throwsA(isA<AppFailure>()),
          reason: 'reversals are final',
        );
      },
    );

    testWidgets(
      'a correction to 0 only cancels the payment; two corrections at once: one wins',
      (t) async {
        await signUpNewUser('corzero');
        final id = await repo.create(_input());
        await repo.recordPayment(
          id,
          amountPaisa: 200000,
          type: PaymentType.advance,
        );
        final original = await firstPaymentId(id);
        final results = await Future.wait([
          for (var i = 0; i < 2; i++)
            repo
                .correctPayment(
                  id,
                  original,
                  correctedAmountPaisa: 0,
                  reason: 'Entered by mistake',
                )
                .then((_) => true, onError: (_) => false),
        ]);
        expect(results.where((ok) => ok), hasLength(1));
        final parcel = await waitFor(id, (p) => p.receivedPaisa == 0);
        expect(parcel.paymentStatus, PaymentStatus.pending);
        expect(parcel.outstandingPaisa, 500000);
        expect(
          await repo
              .watchPayments(id)
              .firstWhere((l) => l.length == 2)
              .timeout(const Duration(seconds: 10)),
          hasLength(2),
          reason: 'the payment and its reversal',
        );
      },
    );

    testWidgets(
      "another user cannot return, annotate or correct this user's parcel",
      (t) async {
        await signUpNewUser('own');
        final id = await repo.create(_input());
        await repo.recordPayment(
          id,
          amountPaisa: 100000,
          type: PaymentType.advance,
        );
        final payment = await firstPaymentId(id);
        await signUpNewUser('intruder');
        await expectLater(
          repo.markReturned(id, date: today()),
          throwsA(isA<AppFailure>()),
        );
        await expectLater(
          repo.setNotes(id, 'hello'),
          throwsA(isA<AppFailure>()),
        );
        await expectLater(
          repo.correctPayment(
            id,
            payment,
            correctedAmountPaisa: 0,
            reason: 'Not yours',
          ),
          throwsA(isA<AppFailure>()),
        );
      },
    );
  });

  group('payment date correction (DT-008)', () {
    testWidgets(
      'date-only and dated corrections: the original and the reversal stay, money moves only with the amount',
      (t) async {
        await signUpNewUser('datefix');
        final uid = FirebaseAuth.instance.currentUser!.uid;
        final id = await repo.create(_input(reference: 'VPP 40001'));
        final now = DateTime.now().toUtc();
        final twoDaysAgo = pakistanDate(now.subtract(const Duration(days: 2)));
        final yesterday = pakistanDate(now.subtract(const Duration(days: 1)));
        // the parcel was sent three days ago (changed with the admin token, as old data would be)
        await writeRaw(
          'users/$uid/parcels/$id',
          {
            'sendingDateLocal': {
              'stringValue': pakistanDate(
                now.subtract(const Duration(days: 3)),
              ),
            },
          },
          mask: ['sendingDateLocal'],
        );
        await repo.recordPayment(
          id,
          amountPaisa: 200000,
          type: PaymentType.customerPayment,
        );
        final original = (await repo.watchPayments(id).first).single;

        await expectLater(
          repo.correctPayment(
            id,
            original.id,
            correctedAmountPaisa: 200000,
            reason: 'Same everything',
          ),
          throwsA(isA<AppFailure>()),
          reason: 'nothing changes',
        );
        await expectLater(
          repo.correctPayment(
            id,
            original.id,
            correctedAmountPaisa: 200000,
            reason: 'Wrong day',
            receivedOn: '2999-01-01',
          ),
          throwsA(isA<AppFailure>()),
          reason: 'future',
        );
        await expectLater(
          repo.correctPayment(
            id,
            original.id,
            correctedAmountPaisa: 200000,
            reason: 'Wrong day',
            receivedOn: '2000-01-01',
          ),
          throwsA(isA<AppFailure>()),
          reason: 'before the sending date',
        );
        await expectLater(
          repo.correctPayment(
            id,
            original.id,
            correctedAmountPaisa: 200000,
            reason: 'abc',
            receivedOn: yesterday,
          ),
          throwsA(isA<AppFailure>()),
          reason: 'reason',
        );

        // date only
        await repo.correctPayment(
          id,
          original.id,
          correctedAmountPaisa: 200000,
          reason: 'Money came in two days ago',
          receivedOn: twoDaysAgo,
        );
        final first = await repo
            .watchPayments(id)
            .firstWhere((l) => l.length == 3)
            .timeout(const Duration(seconds: 10));
        final replacement = first.firstWhere(
          (p) => p.correctionOfPaymentId == original.id,
        );
        expect(replacement.amountPaisa, 200000);
        expect(
          pakistanDate(replacement.receivedAt),
          twoDaysAgo,
          reason: 'the corrected day',
        );
        final reversal = first.firstWhere(
          (p) => p.reversalOfPaymentId == original.id,
        );
        expect(reversal.correctionReason, 'Money came in two days ago');
        expect(
          first.any((p) => p.id == original.id && p.amountPaisa == 200000),
          isTrue,
          reason: 'the original stays',
        );
        expect(
          (await read(repo, id)).receivedPaisa,
          200000,
          reason: 'a date-only correction does not move money',
        );
        expect((await repo.paymentDates([id]))[id], {
          twoDaysAgo,
        }, reason: 'the corrected day is the effective payment date');

        // amount only: keeps the corrected day
        await repo.correctPayment(
          id,
          replacement.id,
          correctedAmountPaisa: 250000,
          reason: 'Amount was wrong',
        );
        final second = await repo
            .watchPayments(id)
            .firstWhere((l) => l.length == 5)
            .timeout(const Duration(seconds: 10));
        final again = second.firstWhere(
          (p) => p.correctionOfPaymentId == replacement.id,
        );
        expect(
          pakistanDate(again.receivedAt),
          twoDaysAgo,
          reason: 'an amount-only correction keeps the day',
        );
        await repo
            .watch(id)
            .firstWhere((p) => p?.receivedPaisa == 250000)
            .timeout(const Duration(seconds: 10));

        // another user cannot correct this payment
        await signUpNewUser('datefixother');
        await expectLater(
          repo.correctPayment(
            id,
            again.id,
            correctedAmountPaisa: 100000,
            reason: 'Not my payment',
          ),
          throwsA(isA<AppFailure>()),
        );
      },
    );
  });

  group('account switching (DT-014)', () {
    testWidgets(
      'account B never sees account A\'s data after A logs out, not even from the local cache; A gets it back on login',
      (t) async {
        await signUpNewUser('swa');
        final emailA = FirebaseAuth.instance.currentUser!.email!;
        final a = await repo.create(_input(reference: 'VPP 60001'));
        await repo.recordPayment(
          a,
          amountPaisa: 100000,
          type: PaymentType.advance,
        );
        await repo.archive(
          await repo.create(
            _input(reference: '', charge: null, status: ParcelStatus.draft),
          ),
        );
        // A's list is in the local cache now
        expect(
          (await repo
                  .watchAll()
                  .firstWhere((l) => l.isNotEmpty)
                  .timeout(const Duration(seconds: 10)))
              .single
              .id,
          a,
        );

        await signUpNewUser('swb'); // signs A out and B in
        final first = await repo.watchAll().first.timeout(
          const Duration(seconds: 10),
        );
        expect(
          first,
          isEmpty,
          reason: 'B\'s very first list (possibly served from the cache) holds nothing of A\'s',
        );
        expect(
          await repo.watchArchived().first.timeout(const Duration(seconds: 10)),
          isEmpty,
        );
        expect(
          await repo.watchUnreadable().first.timeout(
            const Duration(seconds: 10),
          ),
          isEmpty,
        );
        expect(
          await repo.paymentsFor([a]),
          isEmpty,
          reason:
              'A\'s payments are not readable through B\'s repository calls',
        );
        final denied = Stopwatch()..start();
        await expectLater(
          repo.recordPayment(a, amountPaisa: 1000, type: PaymentType.advance),
          throwsA(isA<AppFailure>()),
          reason: 'B cannot write to a parcel id of A',
        );
        expect(
          denied.elapsedMilliseconds,
          lessThan(4000),
          reason:
              'a genuine denial is reported after a few quick retries (DT-022)',
        );
        // B's own first parcel starts at number 1 again
        final b = await repo.create(_input(reference: 'VPP 60001'));
        expect(
          (await read(repo, b)).orderNumber,
          'ADT-000001',
          reason:
              'independent order sequence, and the same reference is allowed',
        );

        await FirebaseAuth.instance.signOut();
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: emailA,
          password: 'secret123',
        );
        final back = await repo
            .watchAll()
            .firstWhere((l) => l.isNotEmpty)
            .timeout(const Duration(seconds: 10));
        expect(back.single.id, a, reason: 'A sees only A\'s parcel again');
        expect(back.single.receivedPaisa, 100000);
      },
    );
  });

  group('load and payment reads (DT-012)', () {
    testWidgets(
      '600 parcels, 200 with payments: the payment history is read once per parcel, then served from the cache until a payment changes it',
      (t) async {
        await signUpNewUser('load');
        final uid = FirebaseAuth.instance.currentUser!.uid;
        const total = 600;
        const withPayments = 200;
        final docs = <String, Map<String, Object?>>{};
        for (var i = 1; i <= total; i++) {
          final paid = i <= withPayments;
          docs['users/$uid/parcels/load$i'] = _loadParcel(
            i,
            received: paid ? 100000 : 0,
            lastPaymentId: paid ? 'pay1' : null,
          );
          if (paid) {
            docs['users/$uid/parcels/load$i/payments/pay1'] = {
              'amountPaisa': 100000,
              'paymentType': 'customer_payment',
              'receivedAt': DateTime.now().toUtc(),
              'recordedAt': DateTime.now().toUtc(),
            };
          }
        }
        final writing = Stopwatch()..start();
        await writeManyRaw(docs);
        // ignore: avoid_print
        print(
          'LOAD: wrote ${docs.length} documents in ${writing.elapsedMilliseconds} ms',
        );

        final first = Stopwatch()..start();
        final list = await repo
            .watchAll()
            .firstWhere((l) => l.length == total)
            .timeout(const Duration(seconds: 60));
        // ignore: avoid_print
        print(
          'LOAD: first list of ${list.length} parcels after ${first.elapsedMilliseconds} ms',
        );

        final ids = [for (final parcel in list) parcel.id];
        final before = repo.paymentQueries;
        final cold = Stopwatch()..start();
        final payments = await repo.paymentsFor(ids);
        final coldMs = cold.elapsedMilliseconds;
        final coldQueries = repo.paymentQueries - before;
        expect(payments.length, withPayments);
        expect(
          coldQueries,
          total,
          reason: 'one query per parcel the first time',
        );

        final warm = Stopwatch()..start();
        final again = await repo.paymentsFor(ids);
        final warmMs = warm.elapsedMilliseconds;
        expect(again.length, withPayments);
        expect(
          repo.paymentQueries - before,
          coldQueries,
          reason: 'nothing changed, so nothing was read again',
        );
        // ignore: avoid_print
        print(
          'LOAD: payments for $total parcels: first $coldMs ms ($coldQueries queries), second $warmMs ms (${repo.paymentQueries - before - coldQueries} queries)',
        );

        // one real payment on one parcel changes its signature: only that parcel is read again
        final target = list.firstWhere((p) => p.receivedPaisa == 0);
        await repo.recordPayment(
          target.id,
          amountPaisa: 50000,
          type: PaymentType.customerPayment,
        );
        await repo
            .watchAll()
            .firstWhere(
              (l) =>
                  l.any((p) => p.id == target.id && p.receivedPaisa == 50000),
            )
            .timeout(const Duration(seconds: 10));
        final afterPayment = await repo.paymentsFor(ids);
        expect(
          repo.paymentQueries - before,
          coldQueries + 1,
          reason: 'only the changed parcel was read again',
        );
        expect(
          afterPayment[target.id]!.single.amountPaisa,
          50000,
          reason: 'and the new payment is there',
        );
        expect(afterPayment.length, withPayments + 1);

        // a correction (even date-only) changes the signature too
        await repo.correctPayment(
          target.id,
          afterPayment[target.id]!.single.id,
          correctedAmountPaisa: 70000,
          reason: 'Amount was wrong',
        );
        await repo
            .watchAll()
            .firstWhere(
              (l) =>
                  l.any((p) => p.id == target.id && p.receivedPaisa == 70000),
            )
            .timeout(const Duration(seconds: 10));
        final afterCorrection = await repo.paymentsFor(ids);
        expect(repo.paymentQueries - before, coldQueries + 2);
        expect(
          afterCorrection[target.id]!.length,
          3,
          reason: 'payment, reversal and replacement',
        );
      },
    );
  });

  group('archived parcels keep their money (DT-010)', () {
    testWidgets(
      'watchAll(includeArchived) still carries an archived paid parcel; restoring does not duplicate it',
      (t) async {
        await signUpNewUser('arcmoney');
        final id = await repo.create(_input(reference: 'VPP 30001'));
        await repo.recordPayment(
          id,
          amountPaisa: 500000,
          type: PaymentType.customerPayment,
        );
        await repo.archive(id);
        final all = await repo
            .watchAll(includeArchived: true)
            .firstWhere((l) => l.any((p) => p.isArchived))
            .timeout(const Duration(seconds: 10));
        expect(all.map((p) => p.id), [id]);
        expect(all.single.receivedPaisa, 500000);
        expect(
          await repo.watchAll().first,
          isEmpty,
          reason: 'active lists do not include it',
        );
        expect(
          (await repo.watchPayments(id).first).length,
          1,
          reason: 'payment history is untouched by archiving',
        );
        await repo.restore(id);
        final restored = await repo
            .watchAll(includeArchived: true)
            .firstWhere((l) => l.any((p) => !p.isArchived))
            .timeout(const Duration(seconds: 10));
        expect(restored.length, 1, reason: 'one parcel, not two');
        expect(restored.single.receivedPaisa, 500000);
      },
    );
  });

  group('damaged documents (DT-009)', () {
    testWidgets(
      'one damaged parcel and one damaged payment do not break the lists; they are reported / skipped',
      (t) async {
        await signUpNewUser('dmg');
        final uid = FirebaseAuth.instance.currentUser!.uid;
        final good1 = await repo.create(_input(reference: 'VPP 10001'));
        final good2 = await repo.create(_input(reference: 'VPP 10002'));
        await repo.recordPayment(
          good1,
          amountPaisa: 100000,
          type: PaymentType.advance,
        );
        await writeRaw('users/$uid/parcels/damaged1', {
          'orderNumber': {'stringValue': 'ADT-000099'},
          'parcelStatus': {'stringValue': 'on_hold'},
        });
        await writeRaw('users/$uid/parcels/$good1/payments/badpay', {
          'amountPaisa': {'stringValue': 'lots'},
          'paymentType': {'stringValue': 'customer_payment'},
        });

        final list = await repo
            .watchAll()
            .firstWhere((l) => l.length >= 2)
            .timeout(const Duration(seconds: 10));
        expect(list.map((p) => p.id).toSet(), {
          good1,
          good2,
        }, reason: 'the damaged parcel is left out, the others stay');
        final unreadable = await repo
            .watchUnreadable()
            .firstWhere((l) => l.isNotEmpty)
            .timeout(const Duration(seconds: 10));
        expect(unreadable, ['damaged1']);
        final payments = await repo.watchPayments(good1).first;
        expect(
          payments.length,
          1,
          reason: 'the damaged payment counts for nothing',
        );
        expect(payments.single.amountPaisa, 100000);
        final byParcel = await repo.paymentsFor([good1, good2]);
        expect(byParcel[good1]!.length, 1);
      },
    );
  });

  group('postal reference guards (DT-006)', () {
    testWidgets(
      'three saves of the same reference at once: exactly one parcel; moving the reference releases the old one',
      (t) async {
        await signUpNewUser('refrace');
        final results = await Future.wait([
          for (var i = 0; i < 3; i++)
            repo
                .create(_input(reference: 'VPP 24680'))
                .then<Object>((id) => id, onError: (Object e) => e),
        ]);
        expect(results.whereType<String>().length, 1, reason: '$results');
        expect(results.whereType<AppFailure>().length, 2);
        final id = results.whereType<String>().single;
        await expectLater(
          repo.create(_input(reference: 'vpp 24680')),
          throwsA(isA<AppFailure>()),
          reason: 'normalised duplicate',
        );
        // move the parcel to another reference: the old one becomes free again
        final current = await read(repo, id);
        await repo.update(
          id,
          ParcelInput(
            customer: _customer,
            items: current.items,
            method: current.method,
            service: current.service,
            postalReference: 'VPP 13579',
            deliveryChargePaisa: current.deliveryChargePaisa,
            status: ParcelStatus.sent,
          ),
        );
        final reused = await repo.create(_input(reference: 'VPP 24680'));
        expect(
          reused,
          isNot(id),
          reason: 'the released reference can be used by another parcel',
        );
        await expectLater(
          repo.create(_input(reference: 'VPP 13579')),
          throwsA(isA<AppFailure>()),
          reason: 'the new reference is now reserved',
        );
      },
    );
  });

  group('handover to the post office', () {
    testWidgets(
      'a draft is handed over (becomes Sent) with its reference reserved; a duplicate reference is refused; edits release the old one',
      (t) async {
        await signUpNewUser('handover');
        final draft = await repo.create(
          _input(reference: '', charge: null, status: ParcelStatus.draft),
        );
        final other = await repo.create(
          _input(reference: '', charge: null, status: ParcelStatus.draft),
        );
        expect((await read(repo, draft)).status, ParcelStatus.draft);

        // validation happens before anything is written
        await expectLater(
          repo.saveHandover(
            draft,
            const ParcelHandover(
              service: PostalService.vpp,
              postalReference: 'AB',
              deliveryChargePaisa: 15000,
            ),
          ),
          throwsA(isA<AppFailure>()),
        );
        await repo.saveHandover(
          draft,
          const ParcelHandover(
            service: PostalService.vpp,
            postalReference: 'vpp 70001',
            deliveryChargePaisa: 15000,
            packedWeightGrams: 1250,
          ),
        );
        final sent = await repo
            .watch(draft)
            .firstWhere((p) => p?.status == ParcelStatus.sent)
            .timeout(const Duration(seconds: 10));
        expect(sent!.postalReference, 'vpp 70001');
        expect(sent.deliveryChargePaisa, 15000);
        expect(sent.packedWeightGrams, 1250);
        expect(sent.service, PostalService.vpp);

        // the same reference on another parcel is refused whatever the spaces or case
        await expectLater(
          repo.saveHandover(
            other,
            const ParcelHandover(
              service: PostalService.vpp,
              postalReference: 'VPP70001',
              deliveryChargePaisa: 100,
            ),
          ),
          throwsA(isA<AppFailure>()),
          reason: 'spaces and case do not make a new reference',
        );
        expect(
          (await read(repo, other)).status,
          ParcelStatus.draft,
          reason: 'nothing changed on the refused parcel',
        );

        // another service may use the same number
        await repo.saveHandover(
          other,
          const ParcelHandover(
            service: PostalService.vpl,
            postalReference: 'VPP 70001',
            deliveryChargePaisa: 100,
          ),
        );

        // Edit handover: a new reference releases the old one, which another parcel can then use
        await repo.saveHandover(
          draft,
          const ParcelHandover(
            service: PostalService.vpp,
            postalReference: 'VPP 70002',
            deliveryChargePaisa: 17000,
          ),
        );
        final edited = await repo
            .watch(draft)
            .firstWhere((p) => p?.postalReference == 'VPP 70002')
            .timeout(const Duration(seconds: 10));
        expect(
          edited!.status,
          ParcelStatus.sent,
          reason: 'editing keeps it Sent',
        );
        expect(edited.deliveryChargePaisa, 17000);
        expect(
          edited.packedWeightGrams,
          isNull,
          reason: 'the optional weight was cleared',
        );
        final third = await repo.create(_input(reference: 'VPP 70001'));
        expect(
          third,
          isNot(draft),
          reason: 'the released reference is free again',
        );

        // a returned parcel cannot be handed over
        final returned = await repo.create(_input(reference: 'VPP 70003'));
        await repo.markReturned(
          returned,
          date: pakistanDate(DateTime.now().toUtc()),
        );
        await expectLater(
          repo.saveHandover(
            returned,
            const ParcelHandover(
              service: PostalService.vpp,
              postalReference: 'VPP 70004',
              deliveryChargePaisa: 1,
            ),
          ),
          throwsA(isA<AppFailure>()),
        );

        // another user cannot hand over this parcel
        await signUpNewUser('handoverintruder');
        await expectLater(
          repo.saveHandover(
            draft,
            const ParcelHandover(
              service: PostalService.vpp,
              postalReference: 'VPP 99999',
              deliveryChargePaisa: 1,
            ),
          ),
          throwsA(isA<AppFailure>()),
        );
      },
    );

    testWidgets(
      'two handovers of the same reference at once: exactly one wins',
      (t) async {
        await signUpNewUser('handoverrace');
        final a = await repo.create(
          _input(reference: '', charge: null, status: ParcelStatus.draft),
        );
        final b = await repo.create(
          _input(reference: '', charge: null, status: ParcelStatus.draft),
        );
        const handover = ParcelHandover(
          service: PostalService.vpp,
          postalReference: 'VPP 80808',
          deliveryChargePaisa: 100,
        );
        final results = await Future.wait([
          for (final id in [a, b])
            repo
                .saveHandover(id, handover)
                .then<Object>((_) => 'ok', onError: (Object e) => e),
        ]);
        expect(results.where((r) => r == 'ok').length, 1, reason: '$results');
        expect(results.whereType<AppFailure>().length, 1);
      },
    );
  });

  group('payment review (DT-011)', () {
    Future<Parcel> waitFor(String id, bool Function(Parcel) test) => repo
        .watch(id)
        .firstWhere((p) => p != null && test(p))
        .timeout(const Duration(seconds: 10))
        .then((p) => p!);

    testWidgets(
      'completing the review records the decision, keeps the money and payments, and allows archiving',
      (t) async {
        await signUpNewUser('rev');
        final id = await repo.create(_input(reference: 'VPP 66666'));
        await repo.recordPayment(
          id,
          amountPaisa: 100000,
          type: PaymentType.advance,
        );
        final today = pakistanDate(DateTime.now().toUtc());
        await repo.markReturned(id, date: today);
        await waitFor(id, (p) => p.status == ParcelStatus.returned);
        await expectLater(
          repo.archive(id),
          throwsA(isA<AppFailure>()),
          reason: 'review still open',
        );

        await expectLater(
          repo.completePaymentReview(
            id,
            resolution: ReviewResolution.refundGiven,
            note: 'abc',
            date: today,
          ),
          throwsA(isA<AppFailure>()),
        );
        await expectLater(
          repo.completePaymentReview(
            id,
            resolution: ReviewResolution.refundGiven,
            note: 'Refund sent',
            date: '2999-01-01',
          ),
          throwsA(isA<AppFailure>()),
        );
        await repo.completePaymentReview(
          id,
          resolution: ReviewResolution.refundGiven,
          note: 'Refund sent by bank',
          date: today,
        );
        final done = await waitFor(id, (p) => !p.paymentReviewRequired);
        expect(done.reviewResolution, ReviewResolution.refundGiven);
        expect(done.reviewNote, 'Refund sent by bank');
        expect(done.reviewDate, today);
        expect(
          done.receivedPaisa,
          100000,
          reason: 'completing a review never changes the money',
        );
        expect(
          (await repo.watchPayments(id).first).length,
          1,
          reason: 'payment history untouched',
        );
        await expectLater(
          repo.completePaymentReview(
            id,
            resolution: ReviewResolution.other,
            note: 'Again please',
            date: today,
          ),
          throwsA(isA<AppFailure>()),
          reason: 'only once',
        );

        await repo.archive(id);
        expect(
          (await repo
                  .watchArchived()
                  .firstWhere((l) => l.isNotEmpty)
                  .timeout(const Duration(seconds: 10)))
              .map((p) => p.id),
          [id],
        );

        await signUpNewUser('revintruder');
        await expectLater(
          repo.completePaymentReview(
            id,
            resolution: ReviewResolution.other,
            note: 'Not yours here',
            date: today,
          ),
          throwsA(isA<AppFailure>()),
        );
      },
    );
  });

  group('archiving', () {
    Future<Parcel> waitFor(String id, bool Function(Parcel) test) => repo
        .watch(id)
        .firstWhere((p) => p != null && test(p))
        .timeout(const Duration(seconds: 10))
        .then((p) => p!);

    testWidgets(
      'only a parcel with nothing to chase is archived; it leaves the list, stays readable, is locked, and restores',
      (t) async {
        await signUpNewUser('arch');
        final owing = await repo.create(_input(reference: 'VPP 11111'));
        final paid = await repo.create(_input(reference: 'VPP 22222'));
        await repo.recordPayment(
          paid,
          amountPaisa: 500000,
          type: PaymentType.customerPayment,
        );
        await waitFor(paid, (p) => p.paymentStatus == PaymentStatus.received);

        await expectLater(
          repo.archive(owing),
          throwsA(isA<AppFailure>()),
          reason: 'Rs. 5,000 still owed',
        );
        await repo.archive(paid);
        await waitFor(paid, (p) => p.isArchived);
        expect(
          (await repo
                  .watchAll()
                  .firstWhere((l) => l.length == 1)
                  .timeout(const Duration(seconds: 10)))
              .map((p) => p.id),
          [owing],
          reason: 'gone from the lists',
        );
        expect(
          (await repo
                  .watchArchived()
                  .firstWhere((l) => l.isNotEmpty)
                  .timeout(const Duration(seconds: 10)))
              .map((p) => p.id),
          [paid],
        );
        expect(
          (await repo.watch(paid).first)!.orderNumber,
          'ADT-000002',
          reason: 'still readable by its address',
        );

        await expectLater(
          repo.update(paid, _input(reference: 'VPP 22222', charge: 20000)),
          throwsA(isA<AppFailure>()),
          reason: 'locked: edit',
        );
        await expectLater(
          repo.setNotes(paid, 'x'),
          throwsA(isA<AppFailure>()),
          reason: 'locked: notes',
        );
        await expectLater(
          repo.markReturned(paid, date: pakistanDate(DateTime.now().toUtc())),
          throwsA(isA<AppFailure>()),
          reason: 'locked: return',
        );

        final next = await repo.create(_input(reference: 'VPP 33333'));
        expect(
          (await repo.watch(next).first)!.orderNumber,
          'ADT-000003',
          reason: 'an archived number is never reused (AT-03)',
        );

        await repo.restore(paid);
        await waitFor(paid, (p) => !p.isArchived);
        expect(
          (await repo
                  .watchAll()
                  .firstWhere((l) => l.length == 3)
                  .timeout(const Duration(seconds: 10)))
              .map((p) => p.id)
              .toSet(),
          {owing, paid, next},
        );
        await repo.setNotes(paid, 'editable again');
        expect(
          (await waitFor(paid, (p) => p.notes != null)).notes,
          'editable again',
        );
      },
    );

    testWidgets(
      'a draft and a returned parcel can be archived; another user cannot archive or restore it',
      (t) async {
        await signUpNewUser('arch2');
        final draft = await repo.create(
          _input(reference: '', charge: null, status: ParcelStatus.draft),
        );
        final sent = await repo.create(_input(reference: 'VPP 44444'));
        await repo.markReturned(
          sent,
          date: pakistanDate(DateTime.now().toUtc()),
        );
        await waitFor(sent, (p) => p.status == ParcelStatus.returned);
        await repo.archive(draft);
        // DT-003: this returned parcel still owes money, so its payment review is open and it cannot be archived
        await expectLater(repo.archive(sent), throwsA(isA<AppFailure>()));
        expect((await read(repo, sent)).isArchived, isFalse);
        // a returned Gift / Free parcel has nothing to review and can be archived
        final gift = await repo.create(
          _input(reference: 'VPP 55555', method: CollectionMethod.giftFree),
        );
        await repo.markReturned(
          gift,
          date: pakistanDate(DateTime.now().toUtc()),
        );
        await repo.archive(gift);
        expect(
          (await repo
                  .watchArchived()
                  .firstWhere((l) => l.length == 2)
                  .timeout(const Duration(seconds: 10)))
              .map((p) => p.id)
              .toSet(),
          {draft, gift},
        );
        await signUpNewUser('intruder2');
        await expectLater(repo.restore(draft), throwsA(isA<AppFailure>()));
        expect(
          await repo.watchArchived().first,
          isEmpty,
          reason: "another user's archive is not visible",
        );
      },
    );
  });
}
