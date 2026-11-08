// Firestore security-rules tests (REST against the Auth + Firestore emulators, real ID tokens).
// Run:  firebase emulators:exec --only auth,firestore --project delivtrack-codewingz \
//         "flutter test test/rules"
import 'package:deliv_track/core/time/pakistan_time.dart';
import 'package:flutter_test/flutter_test.dart';

import 'emulator_client.dart';

Map<String, Object?> _product({
  String name = 'Mango Box',
  String? nameLower,
  String unit = 'per_piece',
  Object? active = true,
}) => {
  'name': name,
  'nameLower': nameLower ?? name.toLowerCase(),
  'saleUnit': unit,
  'isActive': active,
};

Map<String, Object?> _customer({
  String name = 'Ali Khan',
  String? nameLower,
  String phone = '0300 1234567',
  String phoneNormalized = '03001234567',
  String address = 'House 5, Street 2, Sahiwal',
}) => {
  'displayName': name,
  'displayNameLower': nameLower ?? name.toLowerCase(),
  'phone': phone,
  'phoneNormalized': phoneNormalized,
  'address': address,
};

String _today() => pakistanDate(DateTime.now().toUtc());

/// The customer record that `_parcel`'s snapshot is a copy of (parcels must match their customer).
Future<void> _ensureCustomer(
  EmulatorClient emu,
  ({String uid, String token}) user,
) async {
  if (await emu.get(user.token, 'users/${user.uid}/customers/cust1') == 200) {
    return;
  }
  final status = await emu.set(
    user.token,
    'users/${user.uid}/customers/cust1',
    {
      ..._customer(
        name: 'Ali Raza',
        phone: '0300 1234567',
        phoneNormalized: '03001234567',
        address: 'House 5, Sahiwal',
      ),
    },
    serverTimes: const ['createdAt', 'updatedAt'],
  );
  expect(status, 200, reason: 'customer fixture');
}

/// A real payment: the parcel's received amount moves together with one new payment document.
Future<int> _payOn(
  EmulatorClient emu,
  ({String uid, String token}) user,
  String pid,
  DateTime created,
  int amount, {
  String payId = 'pay1',
  int before = 0,
  int expected = 500000,
  Map<String, Object?> overrides = const {},
}) {
  final to = before + amount;
  final out = expected > to ? expected - to : 0;
  return emu.commit(user.token, [
    DocWrite(
      'users/${user.uid}/parcels/$pid',
      {
        ..._parcel(
          seq: 1,
          overrides: {
            'receivedPaisa': to,
            'outstandingPaisa': out,
            'paymentStatus': out == 0 ? 'received' : 'partial',
            'lastPaymentId': payId,
            ...overrides,
          },
        ),
        'createdAt': created,
      },
      serverTimes: const ['updatedAt'],
    ),
    DocWrite(
      'users/${user.uid}/parcels/$pid/payments/$payId',
      {'amountPaisa': amount, 'paymentType': 'customer_payment'},
      serverTimes: const ['receivedAt', 'recordedAt'],
    ),
  ]);
}

/// The fields a returned parcel carries (an unpaid Rs. 5,000 parcel, so payment review is needed).
Map<String, Object?> _returned({
  String? date,
  bool review = true,
  Map<String, Object?> extra = const {},
}) => {
  'parcelStatus': 'returned',
  'returnedDateLocal': date ?? _today(),
  'paymentReviewRequired': review,
  ...extra,
};

/// A valid parcel document (without server-time fields). Override fields to make it invalid.
Map<String, Object?> _parcel({
  int seq = 1,
  String? orderNumber,
  Map<String, Object?> overrides = const {},
  List<String> remove = const [],
}) {
  final base = <String, Object?>{
    'orderNumber': orderNumber ?? 'ADT-${seq.toString().padLeft(6, '0')}',
    'orderSequence': seq,
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
    // one reference per order number, so parcels of the same user never share a reference guard
    'postalReference': 'VPP ${12344 + seq}',
    'postalReferenceNormalized': 'VPP${12344 + seq}',
    'deliveryChargePaisa': 15000,
    'productAmountExpectedPaisa': 500000,
    'receivedPaisa': 0,
    'outstandingPaisa': 500000,
    'paymentStatus': 'pending',
    'parcelStatus': 'sent',
    'sendingDateLocal': _today(),
  };
  base.addAll(overrides);
  for (final key in remove) {
    base.remove(key);
  }
  final normalized = base['postalReferenceNormalized'] as String? ?? '';
  if (normalized.isNotEmpty && !base.containsKey('postalGuardId')) {
    final service = base['postalServiceType'] as String;
    final serviceKey = service == 'Other'
        ? 'Other-${(base['otherPostalServiceName'] as String? ?? '').toLowerCase()}'
        : service;
    base['postalGuardId'] =
        '${Uri.encodeComponent(serviceKey)}__${Uri.encodeComponent(normalized)}';
  }
  return base;
}

/// The reference-guard document the app writes in the same commit as a parcel that has a reference.
List<DocWrite> _guardFor(
  String uid,
  String parcelId,
  Map<String, Object?> parcel,
) => [
  if (parcel['postalGuardId'] != null)
    DocWrite('users/$uid/postal_refs/${parcel['postalGuardId']}', {
      'parcelId': parcelId,
      'orderNumber': parcel['orderNumber'],
    }),
];

void main() {
  final emu = EmulatorClient();
  final skip = emu.available
      ? null
      : 'Needs Firebase emulators (use firebase emulators:exec)';

  late ({String uid, String token}) alice;
  late ({String uid, String token}) bob;
  var n = 0;
  String id() => 'p${DateTime.now().microsecondsSinceEpoch}_${n++}';

  setUpAll(() async {
    if (!emu.available) return;
    final stamp = DateTime.now().microsecondsSinceEpoch;
    alice = await emu.signUp('alice$stamp@x.com');
    bob = await emu.signUp('bob$stamp@x.com');
  });

  Future<int> createProduct(
    String? token,
    String uid,
    String pid,
    Map<String, Object?> fields, {
    List<String> serverTimes = const ['createdAt', 'updatedAt'],
  }) => emu.set(token, 'users/$uid/products/$pid', {
    ...fields,
  }, serverTimes: serverTimes);

  group('isolation between users', () {
    test('owner can create, read and list own products', () async {
      final pid = id();
      expect(await createProduct(alice.token, alice.uid, pid, _product()), 200);
      expect(
        await emu.get(alice.token, 'users/${alice.uid}/products/$pid'),
        200,
      );
      final list = await emu.list(alice.token, 'users/${alice.uid}/products');
      expect(list.status, 200);
      expect(list.count, greaterThanOrEqualTo(1));
    }, skip: skip);

    test('another user cannot read, list, create, update or delete in someone else\'s data', () async {
      final pid = id();
      expect(
        await createProduct(
          alice.token,
          alice.uid,
          pid,
          _product(name: 'Private Item'),
        ),
        200,
      );

      expect(
        await emu.get(bob.token, 'users/${alice.uid}/products/$pid'),
        403,
        reason: 'read',
      );
      expect(
        (await emu.list(bob.token, 'users/${alice.uid}/products')).status,
        403,
        reason: 'list',
      );
      expect(
        await createProduct(
          bob.token,
          alice.uid,
          id(),
          _product(name: 'Injected'),
        ),
        403,
        reason: 'create',
      );
      expect(
        await createProduct(
          bob.token,
          alice.uid,
          pid,
          _product(name: 'Hijacked'),
          serverTimes: const ['updatedAt'],
        ),
        403,
        reason: 'update',
      );
      expect(
        await emu.delete(bob.token, 'users/${alice.uid}/products/$pid'),
        403,
        reason: 'delete',
      );
      expect(
        await emu.get(alice.token, 'users/${alice.uid}/products/$pid'),
        200,
        reason: 'alice data untouched',
      );
    }, skip: skip);

    test('each user only lists their own data', () async {
      await createProduct(bob.token, bob.uid, id(), _product(name: 'Bob Only'));
      final alices = await emu.list(alice.token, 'users/${alice.uid}/products');
      final bobs = await emu.list(bob.token, 'users/${bob.uid}/products');
      expect(alices.status, 200);
      expect(bobs.status, 200);
      expect(
        (await emu.list(alice.token, 'users/${bob.uid}/products')).status,
        403,
      );
      expect(
        (await emu.list(bob.token, 'users/${alice.uid}/products')).status,
        403,
      );
    }, skip: skip);

    test('signed-out requests are denied', () async {
      final pid = id();
      await createProduct(alice.token, alice.uid, pid, _product());
      expect(await emu.get(null, 'users/${alice.uid}/products/$pid'), 403);
      expect(await createProduct(null, alice.uid, id(), _product()), 403);
    }, skip: skip);

    test('product-name guards are isolated too', () async {
      expect(
        await emu.set(alice.token, 'users/${alice.uid}/product_names/n_mango', {
          'productId': 'x',
        }),
        200,
      );
      expect(
        await emu.get(bob.token, 'users/${alice.uid}/product_names/n_mango'),
        403,
      );
      expect(
        await emu.set(bob.token, 'users/${alice.uid}/product_names/n_other', {
          'productId': 'x',
        }),
        403,
      );
    }, skip: skip);
  });

  group('data validation', () {
    Future<void> denied(
      Map<String, Object?> fields, {
      List<String> serverTimes = const ['createdAt', 'updatedAt'],
    }) async => expect(
      await createProduct(
        alice.token,
        alice.uid,
        id(),
        fields,
        serverTimes: serverTimes,
      ),
      403,
    );

    test(
      'rejects 1-char and 61-char names, padded names, wrong nameLower',
      () async {
        await denied(_product(name: 'A'));
        await denied(_product(name: 'A' * 61));
        await denied(_product(name: ' Mango'));
        await denied(_product(name: 'Mango '));
        await denied(_product(name: 'Mango', nameLower: 'MANGO'));
        expect(
          await createProduct(
            alice.token,
            alice.uid,
            id(),
            _product(name: 'A' * 60),
          ),
          200,
          reason: '60 is allowed',
        );
        expect(
          await createProduct(
            alice.token,
            alice.uid,
            id(),
            _product(name: 'Ab'),
          ),
          200,
          reason: '2 is allowed',
        );
      },
      skip: skip,
    );

    test('every selling unit of the dropdown is accepted', () async {
      for (final unit in const [
        'per_piece',
        'per_kg',
        'per_litre',
        'per_dozen',
        'per_pack',
        'per_box',
        'per_carton',
        'per_bag',
        'per_bottle',
        'per_jar',
        'per_tin',
      ]) {
        expect(
          await createProduct(
            alice.token,
            alice.uid,
            id(),
            _product(unit: unit),
          ),
          200,
          reason: unit,
        );
      }
    }, skip: skip);

    test(
      'rejects bad unit, non-bool isActive, extra and missing fields',
      () async {
        await denied(_product(unit: 'per_ton'));
        await denied(_product(unit: 'Per Box'));
        await denied(_product(active: 'yes'));
        await denied({..._product(), 'price': 5});
        final missing = _product()..remove('saleUnit');
        await denied(missing);
      },
      skip: skip,
    );

    test('createdAt/updatedAt must be server time, not client time', () async {
      await denied({
        ..._product(),
        'createdAt': DateTime.utc(2000),
        'updatedAt': DateTime.utc(2000),
      }, serverTimes: const []);
      await denied(
        {..._product(), 'createdAt': DateTime.utc(2000)},
        serverTimes: const ['updatedAt'],
      );
    }, skip: skip);

    test('createdAt cannot be changed later; archive (isActive=false) works; delete is never allowed', () async {
      final pid = id();
      expect(await createProduct(alice.token, alice.uid, pid, _product()), 200);
      // Changing createdAt on update is rejected.
      expect(
        await createProduct(
          alice.token,
          alice.uid,
          pid,
          _product(),
          serverTimes: const ['createdAt', 'updatedAt'],
        ),
        403,
      );
      // Archiving: keep the stored createdAt untouched (REST update needs the original value, so read it).
      final original = await _readCreatedAt(emu, alice.token, alice.uid, pid);
      expect(
        await emu.set(
          alice.token,
          'users/${alice.uid}/products/$pid',
          {..._product(active: false), 'createdAt': original},
          serverTimes: const ['updatedAt'],
        ),
        200,
      );
      expect(
        await emu.delete(alice.token, 'users/${alice.uid}/products/$pid'),
        403,
      );
    }, skip: skip);

    test('product-name guard rejects extra fields', () async {
      expect(
        await emu.set(alice.token, 'users/${alice.uid}/product_names/n_bad', {
          'productId': 'x',
          'extra': 'y',
        }),
        403,
      );
      expect(
        await emu.set(alice.token, 'users/${alice.uid}/product_names/n_bad2', {
          'productId': 5,
        }),
        403,
      );
    }, skip: skip);
  });

  group('default deny', () {
    test(
      'user root doc, other collections and top-level collections are closed',
      () async {
        expect(
          await emu.set(alice.token, 'users/${alice.uid}', {'name': 'x'}),
          403,
        );
        expect(await emu.get(alice.token, 'users/${alice.uid}'), 403);
        expect(
          await emu.set(alice.token, 'users/${alice.uid}/parcels/p1', {
            'a': 'b',
          }),
          403,
        );
        expect(await emu.set(alice.token, 'products/p1', {'a': 'b'}), 403);
        expect(await emu.get(alice.token, 'app_settings/main'), 403);
      },
      skip: skip,
    );
  });

  group('customers', () {
    Future<int> create(
      String? token,
      String uid,
      String id,
      Map<String, Object?> fields, {
      List<String> serverTimes = const ['createdAt', 'updatedAt'],
    }) => emu.set(
      token,
      'users/$uid/customers/$id',
      fields,
      serverTimes: serverTimes,
    );

    test(
      'owner can create, read, list and update; others are denied everything',
      () async {
        final cid = id();
        expect(await create(alice.token, alice.uid, cid, _customer()), 200);
        expect(
          await emu.get(alice.token, 'users/${alice.uid}/customers/$cid'),
          200,
        );
        expect(
          (await emu.list(alice.token, 'users/${alice.uid}/customers')).status,
          200,
        );

        expect(
          await emu.get(bob.token, 'users/${alice.uid}/customers/$cid'),
          403,
          reason: 'read',
        );
        expect(
          (await emu.list(bob.token, 'users/${alice.uid}/customers')).status,
          403,
          reason: 'list',
        );
        expect(
          await create(bob.token, alice.uid, id(), _customer(name: 'Injected')),
          403,
          reason: 'create',
        );
        expect(
          await create(
            bob.token,
            alice.uid,
            cid,
            _customer(name: 'Hijacked'),
            serverTimes: const ['updatedAt'],
          ),
          403,
          reason: 'update',
        );
        expect(
          await emu.delete(bob.token, 'users/${alice.uid}/customers/$cid'),
          403,
          reason: 'delete',
        );
        expect(
          await create(null, alice.uid, id(), _customer()),
          403,
          reason: 'signed out create',
        );
        expect(
          await emu.get(null, 'users/${alice.uid}/customers/$cid'),
          403,
          reason: 'signed out read',
        );
      },
      skip: skip,
    );

    test(
      'two users keep separate customer lists even with identical data',
      () async {
        expect(await create(bob.token, bob.uid, id(), _customer()), 200);
        expect(
          (await emu.list(bob.token, 'users/${bob.uid}/customers')).status,
          200,
        );
        expect(
          (await emu.list(alice.token, 'users/${bob.uid}/customers')).status,
          403,
        );
      },
      skip: skip,
    );

    test('name, phone and address are mandatory and length-checked', () async {
      Future<void> denied(Map<String, Object?> fields) async => expect(
        await create(alice.token, alice.uid, id(), fields),
        403,
        reason: '$fields',
      );
      await denied(_customer(name: 'A'));
      await denied(_customer(name: 'A' * 61));
      await denied(_customer(name: ' Ali'));
      await denied(_customer(name: 'Ali', nameLower: 'ALI'));
      await denied(_customer(phone: '12345'));
      await denied(_customer(phone: '0300 1234567 '));
      await denied(_customer(phoneNormalized: '0300-1234567'));
      await denied(_customer(phoneNormalized: '123456789'));
      await denied(_customer(phoneNormalized: '1' * 16));
      await denied(_customer(address: 'abcd'));
      await denied(_customer(address: 'x' * 201));
      await denied(_customer(address: ' padded address'));
      await denied(_customer()..remove('address'));
      await denied({..._customer(), 'email': 'a@b.c'});

      expect(
        await create(
          alice.token,
          alice.uid,
          id(),
          _customer(
            name: 'Al',
            phone: '1234567890',
            phoneNormalized: '1234567890',
            address: '12345',
          ),
        ),
        200,
        reason: 'minimums are allowed',
      );
      expect(
        await create(
          alice.token,
          alice.uid,
          id(),
          _customer(
            name: 'A' * 60,
            address: 'x' * 200,
            phone: '+92 300 1234567',
            phoneNormalized: '03001234567',
          ),
        ),
        200,
        reason: 'maximums are allowed',
      );
    }, skip: skip);

    test('second phone and business details are optional, shape-checked, and removable', () async {
      Future<int> create1(
        Map<String, Object?> fields, {
        String? as,
        String? uid,
      }) => create(as ?? alice.token, uid ?? alice.uid, id(), fields);

      expect(
        await create1({
          ..._customer(),
          'phone2': '+971 50 123 4567',
          'businessDetails': 'Animate Dairy Farm, buyer of high protein',
        }),
        200,
        reason: 'both optional fields together',
      );
      expect(await create1({..._customer(), 'phone2': '0321 7654321'}), 200);
      expect(
        await create1({..._customer(), 'businessDetails': 'x' * 200}),
        200,
      );
      expect(
        await create1({..._customer(), 'phone2': '1234567890'}),
        200,
        reason: 'minimum',
      );
      expect(
        await create1(_customer()),
        200,
        reason: 'still fine without them',
      );

      Future<void> denied(Map<String, Object?> extra) async => expect(
        await create1({..._customer(), ...extra}),
        403,
        reason: '$extra',
      );
      await denied({'phone2': '12345'});
      await denied({'phone2': '0321 7654321 '});
      await denied({'phone2': '3' * 21});
      await denied({'phone2': 12345678901});
      await denied({'phone2': ''});
      await denied({'businessDetails': ''});
      await denied({'businessDetails': ' padded'});
      await denied({'businessDetails': 'x' * 201});
      await denied({'businessDetails': 'two\nlines'});
      await denied({'businessDetails': 42});
      await denied({'phone3': '0321 7654321'});
      expect(
        await create1({
          ..._customer(),
          'phone2': '0321 7654321',
        }, as: bob.token),
        403,
        reason: "another user cannot write into Alice's customers",
      );

      final cid = id();
      expect(
        await create(alice.token, alice.uid, cid, {
          ..._customer(),
          'phone2': '0321 7654321',
          'businessDetails': 'Dairy buyer',
        }),
        200,
      );
      final original = await emu.createdAt(
        alice.token,
        'users/${alice.uid}/customers/$cid',
      );
      expect(
        await emu.set(
          alice.token,
          'users/${alice.uid}/customers/$cid',
          {..._customer(), 'createdAt': original},
          serverTimes: const ['updatedAt'],
        ),
        200,
        reason: 'clearing both fields (the app deletes them)',
      );
    }, skip: skip);

    test('createdAt/updatedAt must be server time; createdAt cannot change; delete never allowed', () async {
      expect(
        await create(alice.token, alice.uid, id(), {
          ..._customer(),
          'createdAt': DateTime.utc(2000),
          'updatedAt': DateTime.utc(2000),
        }, serverTimes: const []),
        403,
      );
      final cid = id();
      expect(await create(alice.token, alice.uid, cid, _customer()), 200);
      expect(
        await create(alice.token, alice.uid, cid, _customer(name: 'Renamed')),
        403,
        reason: 'createdAt would change',
      );
      final original = await emu.createdAt(
        alice.token,
        'users/${alice.uid}/customers/$cid',
      );
      expect(
        await emu.set(
          alice.token,
          'users/${alice.uid}/customers/$cid',
          {..._customer(name: 'Renamed Ali'), 'createdAt': original},
          serverTimes: const ['updatedAt'],
        ),
        200,
      );
      expect(
        await emu.delete(alice.token, 'users/${alice.uid}/customers/$cid'),
        403,
      );
    }, skip: skip);
  });

  group('parcels', () {
    String ppath(String uid, String id) => 'users/$uid/parcels/$id';
    String cpath(String uid) => 'users/$uid/counters/orders';

    /// Creates a parcel together with its counter, the way the app's transaction does.
    Future<int> createParcel(
      ({String uid, String token}) user,
      String id,
      Map<String, Object?> parcel, {
      int? counterTo,
      String? asUid,
    }) => _ensureCustomer(emu, user).then(
      (_) => emu.commit(user.token, [
        DocWrite(cpath(asUid ?? user.uid), {
          'lastSequence': counterTo ?? parcel['orderSequence'] as int,
        }),
        DocWrite(
          ppath(asUid ?? user.uid, id),
          parcel,
          serverTimes: const ['createdAt', 'updatedAt'],
        ),
        ..._guardFor(asUid ?? user.uid, id, parcel),
      ]),
    );

    test('order numbers: only the next number is accepted, counter and parcel move together', () async {
      final u = await emu.signUp(
        'seq${DateTime.now().microsecondsSinceEpoch}@x.com',
      );
      expect(
        await createParcel(u, id(), _parcel(seq: 2)),
        403,
        reason: 'first parcel must be number 1',
      );
      expect(
        await createParcel(u, id(), _parcel(seq: 1)),
        200,
        reason: 'first parcel',
      );
      expect(
        await createParcel(u, id(), _parcel(seq: 1)),
        403,
        reason: 'number 1 cannot be reused',
      );
      expect(
        await createParcel(u, id(), _parcel(seq: 3)),
        403,
        reason: 'cannot skip ahead',
      );
      expect(
        await createParcel(u, id(), _parcel(seq: 2), counterTo: 3),
        403,
        reason: 'counter must equal the parcel number',
      );
      expect(
        await createParcel(u, id(), _parcel(seq: 2)),
        200,
        reason: 'second parcel',
      );
      expect(
        await createParcel(u, id(), _parcel(seq: 3)),
        200,
        reason: 'third parcel',
      );
      // parcel without bumping the counter in the same commit
      expect(
        await emu.set(
          u.token,
          ppath(u.uid, id()),
          _parcel(seq: 4),
          serverTimes: const ['createdAt', 'updatedAt'],
        ),
        403,
      );
    }, skip: skip);

    test(
      'the counter can only grow by one and can never be deleted or rewritten',
      () async {
        final u = await emu.signUp(
          'cnt${DateTime.now().microsecondsSinceEpoch}@x.com',
        );
        expect(
          await emu.set(u.token, cpath(u.uid), {'lastSequence': 5}),
          403,
          reason: 'starts at 1',
        );
        expect(await emu.set(u.token, cpath(u.uid), {'lastSequence': 1}), 200);
        expect(
          await emu.set(u.token, cpath(u.uid), {'lastSequence': 3}),
          403,
          reason: 'no jumps',
        );
        expect(
          await emu.set(u.token, cpath(u.uid), {'lastSequence': 1}),
          403,
          reason: 'no going back / same',
        );
        expect(
          await emu.set(u.token, cpath(u.uid), {'lastSequence': 2}),
          200,
          reason: 'gaps are allowed, +1 only',
        );
        expect(
          await emu.set(u.token, cpath(u.uid), {'lastSequence': 3, 'extra': 1}),
          403,
        );
        expect(await emu.delete(u.token, cpath(u.uid)), 403);
      },
      skip: skip,
    );

    test('users are isolated: B cannot read or write A\'s parcels, counter or reference guards', () async {
      final a = await emu.signUp(
        'pa${DateTime.now().microsecondsSinceEpoch}@x.com',
      );
      final b = await emu.signUp(
        'pb${DateTime.now().microsecondsSinceEpoch}@x.com',
      );
      final pid = id();
      expect(await createParcel(a, pid, _parcel(seq: 1)), 200);
      expect(
        await emu.get(a.token, 'users/${a.uid}/postal_refs/VPP__VPP12345'),
        200,
        reason: 'A\'s own guard (written with the parcel)',
      );

      expect(
        await emu.get(b.token, ppath(a.uid, pid)),
        403,
        reason: 'read parcel',
      );
      expect(
        (await emu.list(b.token, 'users/${a.uid}/parcels')).status,
        403,
        reason: 'list parcels',
      );
      expect(await emu.get(b.token, cpath(a.uid)), 403, reason: 'read counter');
      expect(
        await emu.get(b.token, 'users/${a.uid}/postal_refs/VPP__VPP12345'),
        403,
        reason: 'read guard',
      );
      expect(
        await createParcel(b, id(), _parcel(seq: 2), asUid: a.uid),
        403,
        reason: 'write into A\'s data',
      );
      expect(
        await emu.set(b.token, 'users/${a.uid}/postal_refs/VPP__OTHER', {
          'parcelId': 'x',
          'orderNumber': 'ADT-000009',
        }),
        403,
      );
      expect(await emu.delete(b.token, ppath(a.uid, pid)), 403);
      expect(await emu.get(null, ppath(a.uid, pid)), 403, reason: 'signed out');
      // B has their own, independent numbering starting at 1.
      expect(await createParcel(b, id(), _parcel(seq: 1)), 200);
    }, skip: skip);

    test('sending date must be the server\'s Pakistan date', () async {
      final u = await emu.signUp(
        'date${DateTime.now().microsecondsSinceEpoch}@x.com',
      );
      final today = _today();
      final other = today == '2026-01-01' ? '2026-01-02' : '2026-01-01';
      expect(
        await createParcel(
          u,
          id(),
          _parcel(seq: 1, overrides: {'sendingDateLocal': other}),
        ),
        403,
        reason: 'wrong day',
      );
      expect(
        await createParcel(
          u,
          id(),
          _parcel(seq: 1, overrides: {'sendingDateLocal': 'yesterday'}),
        ),
        403,
        reason: 'bad format',
      );
      expect(
        await createParcel(u, id(), _parcel(seq: 1)),
        200,
        reason: 'today',
      );
    }, skip: skip);

    test('invalid parcels are rejected', () async {
      final u = await emu.signUp(
        'bad${DateTime.now().microsecondsSinceEpoch}@x.com',
      );
      var seq = 0;
      Future<void> denied(String reason, Map<String, Object?> parcel) async =>
          expect(await createParcel(u, id(), parcel), 403, reason: reason);

      await denied(
        'unknown method',
        _parcel(seq: 1, overrides: {'collectionMethod': 'barter'}),
      );
      await denied(
        'unknown service',
        _parcel(seq: 1, overrides: {'postalServiceType': 'TCS'}),
      );
      await denied(
        'Other needs a name',
        _parcel(seq: 1, overrides: {'postalServiceType': 'Other'}),
      );
      await denied(
        'name only for Other',
        _parcel(seq: 1, overrides: {'otherPostalServiceName': 'Courier X'}),
      );
      await denied(
        'sent needs a charge',
        _parcel(seq: 1, remove: ['deliveryChargePaisa']),
      );
      await denied(
        'sent needs a reference',
        _parcel(
          seq: 1,
          overrides: {'postalReference': '', 'postalReferenceNormalized': ''},
        ),
      );
      await denied(
        'normalized reference malformed',
        _parcel(seq: 1, overrides: {'postalReferenceNormalized': 'vpp 123'}),
      );
      await denied(
        'negative charge',
        _parcel(seq: 1, overrides: {'deliveryChargePaisa': -1}),
      );
      await denied(
        'zero packed weight',
        _parcel(seq: 1, overrides: {'actualPackedWeightGrams': 0}),
      );
      await denied(
        'payment date on a non Pay Later parcel',
        _parcel(seq: 1, overrides: {'estimatedPaymentDateLocal': '2030-01-01'}),
      );
      await denied(
        'bad payment date',
        _parcel(
          seq: 1,
          overrides: {
            'collectionMethod': 'credit',
            'estimatedPaymentDateLocal': 'soon',
          },
        ),
      );
      await denied(
        'outstanding does not match',
        _parcel(seq: 1, overrides: {'outstandingPaisa': 1}),
      );
      await denied(
        'free parcel with an amount',
        _parcel(seq: 1, overrides: {'collectionMethod': 'free_gift'}),
      );
      await denied(
        'already received on create',
        _parcel(
          seq: 1,
          overrides: {'receivedPaisa': 100, 'outstandingPaisa': 499900},
        ),
      );
      await denied(
        'returned on create',
        _parcel(seq: 1, overrides: {'parcelStatus': 'returned'}),
      );
      await denied(
        'archived on create',
        _parcel(
          seq: 1,
          overrides: {
            'parcelStatus': 'draft',
            'postalReference': '',
            'postalReferenceNormalized': '',
            'isArchived': true,
          },
          remove: ['deliveryChargePaisa'],
        ),
      );
      await denied(
        'no items',
        _parcel(seq: 1, overrides: {'items': <Object?>[]}),
      );
      await denied(
        '21 items',
        _parcel(
          seq: 1,
          overrides: {
            'items': List.generate(21, (i) => {'productId': 'p$i'}),
          },
        ),
      );
      await denied(
        'order number does not match the sequence',
        _parcel(seq: 1, orderNumber: 'ADT-000002'),
      );
      await denied(
        'order number malformed',
        _parcel(seq: 1, orderNumber: 'ADT-1'),
      );
      await denied(
        'customer snapshot invalid',
        _parcel(
          seq: 1,
          overrides: {
            'customerSnapshot': {'name': 'A', 'phone': '1', 'address': 'x'},
          },
        ),
      );
      await denied(
        'customer snapshot with extra field',
        _parcel(
          seq: 1,
          overrides: {
            'customerSnapshot': {
              'name': 'Ali Raza',
              'phone': '0300 1234567',
              'address': 'House 5, Sahiwal',
              'email': 'a@b.c',
            },
          },
        ),
      );
      await denied('extra field', _parcel(seq: 1, overrides: {'discount': 5}));
      await denied('missing field', _parcel(seq: 1, remove: ['paymentStatus']));
      await denied(
        'bad payment status',
        _parcel(seq: 1, overrides: {'paymentStatus': 'paid'}),
      );
      seq++;

      // Valid variants are accepted: draft without a slip, Other service, free parcel, Pay Later with a date.
      expect(
        await createParcel(
          u,
          id(),
          _parcel(
            seq: 1,
            overrides: {
              'parcelStatus': 'draft',
              'postalReference': '',
              'postalReferenceNormalized': '',
            },
            remove: ['deliveryChargePaisa'],
          ),
        ),
        200,
        reason: 'draft',
      );
      expect(
        await createParcel(
          u,
          id(),
          _parcel(
            seq: 2,
            overrides: {
              'postalServiceType': 'Other',
              'otherPostalServiceName': 'Fast Courier',
            },
          ),
        ),
        200,
        reason: 'Other',
      );
      expect(
        await createParcel(
          u,
          id(),
          _parcel(
            seq: 3,
            overrides: {
              'collectionMethod': 'free_gift',
              'productAmountExpectedPaisa': 0,
              'outstandingPaisa': 0,
              'paymentStatus': 'not_required',
            },
          ),
        ),
        200,
        reason: 'free',
      );
      expect(
        await createParcel(
          u,
          id(),
          _parcel(
            seq: 4,
            overrides: {
              'collectionMethod': 'credit',
              'estimatedPaymentDateLocal': '2031-02-03',
              'actualPackedWeightGrams': 1500,
            },
          ),
        ),
        200,
        reason: 'Pay Later with a date and packed weight',
      );
      expect(seq, 1);
    }, skip: skip);

    test('updates: mutable fields change; order number, number sequence, created and sending date are locked; no delete', () async {
      final u = await emu.signUp(
        'upd${DateTime.now().microsecondsSinceEpoch}@x.com',
      );
      final pid = id();
      expect(
        await createParcel(
          u,
          pid,
          _parcel(
            seq: 1,
            overrides: {
              'parcelStatus': 'draft',
              'postalReference': '',
              'postalReferenceNormalized': '',
            },
            remove: ['deliveryChargePaisa'],
          ),
        ),
        200,
      );
      final created = await emu.createdAt(u.token, ppath(u.uid, pid));
      Future<int> update(Map<String, Object?> parcel) => emu.set(
        u.token,
        ppath(u.uid, pid),
        {...parcel, 'createdAt': created},
        serverTimes: const ['updatedAt'],
      );

      expect(
        await emu.commit(u.token, [
          DocWrite(
            ppath(u.uid, pid),
            {..._parcel(seq: 1), 'createdAt': created},
            serverTimes: const ['updatedAt'],
          ),
          ..._guardFor(u.uid, pid, _parcel(seq: 1)),
        ]),
        200,
        reason: 'draft -> sent with a reference (its guard is created in the same commit) and charge',
      );
      expect(
        await update(
          _parcel(
            seq: 1,
            overrides: {'orderNumber': 'ADT-000009', 'orderSequence': 9},
          ),
        ),
        403,
        reason: 'order number locked',
      );
      expect(
        await update(
          _parcel(seq: 1, overrides: {'sendingDateLocal': '2020-01-01'}),
        ),
        403,
        reason: 'sending date locked',
      );
      expect(
        await emu.set(
          u.token,
          ppath(u.uid, pid),
          {..._parcel(seq: 1)},
          serverTimes: const ['createdAt', 'updatedAt'],
        ),
        403,
        reason: 'created time locked',
      );
      expect(
        await update(_parcel(seq: 1, overrides: _returned())),
        200,
        reason: 'Sent -> Returned with its return fields',
      );
      expect(
        await update(_parcel(seq: 1, overrides: {'outstandingPaisa': 5})),
        403,
        reason: 'amounts must stay consistent',
      );
      expect(await emu.delete(u.token, ppath(u.uid, pid)), 403);
    }, skip: skip);
  });

  group('postal reference guards (DT-006)', () {
    String ppath(String uid, String id) => 'users/$uid/parcels/$id';
    String gpath(String uid, String key) => 'users/$uid/postal_refs/$key';

    Future<int> create(
      ({String uid, String token}) user,
      String pid,
      Map<String, Object?> parcel, {
      bool guard = true,
      int? counterTo,
    }) async {
      await _ensureCustomer(emu, user);
      return emu.commit(user.token, [
        DocWrite('users/${user.uid}/counters/orders', {
          'lastSequence': counterTo ?? parcel['orderSequence'] as int,
        }),
        DocWrite(
          ppath(user.uid, pid),
          parcel,
          serverTimes: const ['createdAt', 'updatedAt'],
        ),
        if (guard) ..._guardFor(user.uid, pid, parcel),
      ]);
    }

    Future<int> change(
      ({String uid, String token}) user,
      String pid,
      DateTime created,
      Map<String, Object?> parcel, {
      List<DocWrite> extra = const [],
    }) => emu.commit(user.token, [
      DocWrite(
        ppath(user.uid, pid),
        {...parcel, 'createdAt': created},
        serverTimes: const ['updatedAt'],
      ),
      ...extra,
    ]);

    test('the same user cannot reuse a reference: with no guard, with the existing guard, or with a made-up guard id', () async {
      final u = await emu.signUp(
        'dup${DateTime.now().microsecondsSinceEpoch}@x.com',
      );
      expect(
        await create(
          u,
          id(),
          _parcel(
            seq: 1,
            overrides: {
              'postalReference': 'VPP 55555',
              'postalReferenceNormalized': 'VPP55555',
            },
          ),
        ),
        200,
      );
      final second = _parcel(
        seq: 2,
        overrides: {
          'postalReference': 'VPP 55555',
          'postalReferenceNormalized': 'VPP55555',
        },
      );
      expect(
        await create(u, id(), second, guard: false),
        403,
        reason: 'no guard written: the pointer names a guard that belongs to the first parcel',
      );
      expect(
        await create(u, id(), second),
        403,
        reason: 'the guard already exists',
      );
      final made = {...second, 'postalGuardId': 'VPP__SOMETHING-ELSE'};
      expect(
        await create(u, id(), made),
        403,
        reason: 'guard id is not the one derived from the reference',
      );
      expect(
        await create(u, id(), _parcel(seq: 2)),
        200,
        reason: 'a different reference is fine',
      );
    }, skip: skip);

    test('a reference with a slash uses the encoded guard id', () async {
      final u = await emu.signUp(
        'slash${DateTime.now().microsecondsSinceEpoch}@x.com',
      );
      final p = _parcel(
        seq: 1,
        overrides: {
          'postalReference': 'VPP 55/66',
          'postalReferenceNormalized': 'VPP55/66',
        },
      );
      expect(p['postalGuardId'], 'VPP__VPP55%2F66');
      expect(await create(u, id(), p), 200);
      expect(
        await create(
          u,
          id(),
          _parcel(
            seq: 2,
            overrides: {
              'postalReference': 'VPP 55/66',
              'postalReferenceNormalized': 'VPP55/66',
            },
          ),
        ),
        403,
      );
    }, skip: skip);

    test('different users may use the same reference', () async {
      final a = await emu.signUp(
        'sa${DateTime.now().microsecondsSinceEpoch}@x.com',
      );
      final b = await emu.signUp(
        'sb${DateTime.now().microsecondsSinceEpoch}@x.com',
      );
      final p = _parcel(
        seq: 1,
        overrides: {
          'postalReference': 'VPP 77777',
          'postalReferenceNormalized': 'VPP77777',
        },
      );
      expect(await create(a, id(), p), 200);
      expect(await create(b, id(), p), 200);
    }, skip: skip);

    test(
      'two saves of the same reference at the same moment: only one succeeds',
      () async {
        final u = await emu.signUp(
          'race${DateTime.now().microsecondsSinceEpoch}@x.com',
        );
        await _ensureCustomer(emu, u);
        final results = await Future.wait([
          for (var i = 0; i < 4; i++)
            create(
              u,
              id(),
              _parcel(
                seq: 1,
                overrides: {
                  'postalReference': 'VPP 99999',
                  'postalReferenceNormalized': 'VPP99999',
                },
              ),
            ),
        ]);
        expect(
          results.where((status) => status == 200).length,
          1,
          reason: '$results',
        );
      },
      skip: skip,
    );

    test('a guard cannot be created alone, for another parcel, or deleted on its own', () async {
      final u = await emu.signUp(
        'g${DateTime.now().microsecondsSinceEpoch}@x.com',
      );
      final other = await emu.signUp(
        'go${DateTime.now().microsecondsSinceEpoch}@x.com',
      );
      final pid = id();
      expect(await create(u, pid, _parcel(seq: 1)), 200);
      final key = _parcel(seq: 1)['postalGuardId'] as String;
      expect(
        await emu.set(u.token, gpath(u.uid, 'VPP__LONE1'), {
          'parcelId': pid,
          'orderNumber': 'ADT-000001',
        }),
        403,
        reason: 'no parcel points at it',
      );
      expect(
        await emu.set(u.token, gpath(u.uid, key), {
          'parcelId': pid,
          'orderNumber': 'ADT-000001',
        }),
        403,
        reason: 'cannot be rewritten',
      );
      expect(
        await emu.delete(u.token, gpath(u.uid, key)),
        403,
        reason: 'the parcel still uses it',
      );
      expect(
        await emu.delete(other.token, gpath(u.uid, key)),
        403,
        reason: 'another user',
      );
      expect(
        await emu.get(u.token, gpath(u.uid, key)),
        200,
        reason: 'still there',
      );
    }, skip: skip);

    test('changing a reference: the new guard comes with it and the old one is released in the same commit', () async {
      final u = await emu.signUp(
        'chg${DateTime.now().microsecondsSinceEpoch}@x.com',
      );
      final pid = id();
      final first = _parcel(seq: 1);
      expect(await create(u, pid, first), 200);
      final created = await emu.createdAt(u.token, ppath(u.uid, pid));
      final changed = _parcel(
        seq: 1,
        overrides: {
          'postalReference': 'VPP 88888',
          'postalReferenceNormalized': 'VPP88888',
        },
      );
      expect(
        await change(u, pid, created, changed),
        403,
        reason: 'new reference without its guard',
      );
      expect(
        await change(
          u,
          pid,
          created,
          changed,
          extra: _guardFor(u.uid, pid, changed),
        ),
        200,
        reason: 'new guard, old one kept',
      );
      expect(
        await emu.delete(
          u.token,
          gpath(u.uid, first['postalGuardId'] as String),
        ),
        403,
        reason: 'cannot be released on its own, even when stale',
      );
      final back = _parcel(
        seq: 1,
        overrides: {
          'postalReference': 'VPP 12345',
          'postalReferenceNormalized': 'VPP12345',
        },
      );
      expect(
        await change(
          u,
          pid,
          created,
          back,
          extra: [..._guardFor(u.uid, pid, back)],
        ),
        403,
        reason: 'the old guard still exists',
      );
      final third = _parcel(
        seq: 1,
        overrides: {
          'postalReference': 'VPP 31313',
          'postalReferenceNormalized': 'VPP31313',
        },
      );
      expect(
        await change(
          u,
          pid,
          created,
          third,
          extra: [
            DocWrite.delete(gpath(u.uid, changed['postalGuardId'] as String)),
            ..._guardFor(u.uid, pid, third),
          ],
        ),
        200,
        reason: 'move on and release the previous guard',
      );
      expect(
        await emu.get(
          u.token,
          gpath(u.uid, changed['postalGuardId'] as String),
        ),
        404,
        reason: 'released',
      );
      // an unrelated edit keeps the guard as it is
      expect(await change(u, pid, created, {...third, 'notes': 'edited'}), 200);
      expect(
        await change(u, pid, created, {
          ...third,
          'postalGuardId': 'VPP__VPP12345',
        }),
        403,
        reason: 'the pointer cannot be moved without a new reference',
      );
    }, skip: skip);

    test('a draft has no reference and no guard; releasing it frees the reference for another parcel', () async {
      final u = await emu.signUp(
        'drf${DateTime.now().microsecondsSinceEpoch}@x.com',
      );
      final pid = id();
      final draft = _parcel(
        seq: 1,
        overrides: {
          'parcelStatus': 'draft',
          'postalReference': '',
          'postalReferenceNormalized': '',
        },
        remove: ['deliveryChargePaisa'],
      );
      expect(draft.containsKey('postalGuardId'), isFalse);
      expect(await create(u, pid, draft), 200);
      expect(
        await create(u, id(), {
          ...draft,
          'orderNumber': 'ADT-000002',
          'orderSequence': 2,
          'postalGuardId': 'VPP__X1234',
        }),
        403,
        reason: 'a pointer without a reference',
      );
    }, skip: skip);

    test('records created before guards were enforced stay editable', () async {
      final u = await emu.signUp(
        'leg${DateTime.now().microsecondsSinceEpoch}@x.com',
      );
      await _ensureCustomer(emu, u);
      final pid = id();
      final legacy = _parcel(seq: 1)..remove('postalGuardId');
      // written with the emulator's admin token, which bypasses the rules (as the old rules allowed it)
      expect(
        await emu.set('owner', 'users/${u.uid}/counters/orders', {
          'lastSequence': 1,
        }),
        200,
      );
      expect(
        await emu.set(
          'owner',
          ppath(u.uid, pid),
          legacy,
          serverTimes: const ['createdAt', 'updatedAt'],
        ),
        200,
      );
      expect(
        await emu.set('owner', gpath(u.uid, 'VPP__VPP12345'), {
          'parcelId': pid,
          'orderNumber': 'ADT-000001',
        }),
        200,
      );
      final created = await emu.createdAt(u.token, ppath(u.uid, pid));
      expect(
        await emu.get(u.token, ppath(u.uid, pid)),
        200,
        reason: 'readable',
      );
      expect(
        await change(u, pid, created, {...legacy, 'notes': 'still editable'}),
        200,
        reason: 'same reference, no pointer needed',
      );
      expect(
        await emu.delete(u.token, gpath(u.uid, 'VPP__VPP12345')),
        403,
        reason: 'the old guard cannot be dropped on its own',
      );
      final changed = _parcel(
        seq: 1,
        overrides: {
          'postalReference': 'VPP 42424',
          'postalReferenceNormalized': 'VPP42424',
        },
      );
      expect(
        await change(
          u,
          pid,
          created,
          {...changed, 'notes': 'still editable'},
          extra: [
            DocWrite.delete(gpath(u.uid, 'VPP__VPP12345')),
            ..._guardFor(u.uid, pid, changed),
          ],
        ),
        200,
        reason: 'moving to a new reference releases the old guard',
      );
    }, skip: skip);

    test('"Other" services: a guard linked to the parcel is required (the service-name part is app-enforced)', () async {
      final u = await emu.signUp(
        'oth${DateTime.now().microsecondsSinceEpoch}@x.com',
      );
      final other = _parcel(
        seq: 1,
        overrides: {
          'postalServiceType': 'Other',
          'otherPostalServiceName': 'Courier X',
          'postalReference': 'CX 1234',
          'postalReferenceNormalized': 'CX1234',
        },
      );
      expect(other['postalGuardId'], 'Other-courier%20x__CX1234');
      expect(
        await create(u, id(), other, guard: false),
        403,
        reason: 'no guard',
      );
      expect(
        await create(u, id(), {...other, 'postalGuardId': 'Courier-x__CX1234'}),
        403,
        reason: 'wrong shape',
      );
      expect(
        await create(u, id(), {
          ...other,
          'postalGuardId': 'Other-courier%20x__WRONG',
        }),
        403,
        reason: 'wrong reference part',
      );
      expect(await create(u, id(), other), 200);
      expect(
        await create(u, id(), {
          ...other,
          'orderNumber': 'ADT-000002',
          'orderSequence': 2,
        }),
        403,
        reason: 'same Other service and reference',
      );
    }, skip: skip);
  });

  group('audit log', () {
    String ppath(String uid, String id) => 'users/$uid/parcels/$id';
    String apath(String uid, String id) => 'users/$uid/audit_logs/$id';

    /// A user with one parcel, and a way to edit it (notes) together with an audit entry in one commit.
    Future<
      ({
        ({String uid, String token}) user,
        String pid,
        DateTime created,
        int Function() edits,
      })
    >
    setup() async {
      final u = await emu.signUp(
        'aud${DateTime.now().microsecondsSinceEpoch}_${n++}@x.com',
      );
      final pid = id();
      await _ensureCustomer(emu, u);
      final parcel = _parcel(seq: 1);
      expect(
        await emu.commit(u.token, [
          DocWrite('users/${u.uid}/counters/orders', {'lastSequence': 1}),
          DocWrite(
            ppath(u.uid, pid),
            parcel,
            serverTimes: const ['createdAt', 'updatedAt'],
          ),
          ..._guardFor(u.uid, pid, parcel),
        ]),
        200,
      );
      var edits = 0;
      return (
        user: u,
        pid: pid,
        created: await emu.createdAt(u.token, ppath(u.uid, pid)),
        edits: () => edits++,
      );
    }

    Map<String, Object?> entry(
      String pid, {
      Map<String, Object?> overrides = const {},
      List<String> remove = const [],
    }) {
      final base = <String, Object?>{
        'entityType': 'parcel',
        'entityId': pid,
        'action': 'update',
        'orderNumber': 'ADT-000001',
        'changedFields': ['notes'],
      };
      base.addAll(overrides);
      for (final k in remove) {
        base.remove(k);
      }
      return base;
    }

    /// The real edit (a new note) plus the given audit entry, in one commit.
    Future<int> edit(
      ({
        ({String uid, String token}) user,
        String pid,
        DateTime created,
        int Function() edits,
      })
      s,
      Map<String, Object?> audit, {
      Map<String, Object?> parcelOverrides = const {'notes': 'a note'},
      String? token,
      String? logId,
      List<String> times = const ['createdAt'],
    }) {
      return emu.commit(token ?? s.user.token, [
        DocWrite(
          ppath(s.user.uid, s.pid),
          {
            ..._parcel(seq: 1, overrides: parcelOverrides),
            'createdAt': s.created,
          },
          serverTimes: const ['updatedAt'],
        ),
        DocWrite(apath(s.user.uid, logId ?? id()), audit, serverTimes: times),
      ]);
    }

    test('an entry that describes a real edit made in the same commit is accepted, readable by the owner only, and never changes', () async {
      final s = await setup();
      final b = await emu.signUp(
        'av${DateTime.now().microsecondsSinceEpoch}@x.com',
      );
      final lid = id();
      expect(await edit(s, entry(s.pid), logId: lid), 200);
      expect(await emu.get(s.user.token, apath(s.user.uid, lid)), 200);
      expect(
        await emu.get(b.token, apath(s.user.uid, lid)),
        403,
        reason: 'read',
      );
      expect(
        (await emu.list(b.token, 'users/${s.user.uid}/audit_logs')).status,
        403,
        reason: 'list',
      );
      expect(
        await emu.set(
          s.user.token,
          apath(s.user.uid, lid),
          entry(
            s.pid,
            overrides: {
              'changedFields': ['x'],
            },
          ),
          serverTimes: const ['createdAt'],
        ),
        403,
        reason: 'no rewriting',
      );
      expect(
        await emu.delete(s.user.token, apath(s.user.uid, lid)),
        403,
        reason: 'no deleting',
      );
      expect(
        await emu.get(null, apath(s.user.uid, lid)),
        403,
        reason: 'signed out',
      );
    }, skip: skip);

    test('a forged entry is refused: nothing was edited, other fields were claimed, or it names someone else\'s parcel', () async {
      final s = await setup();
      final other = await emu.signUp(
        'aw${DateTime.now().microsecondsSinceEpoch}@x.com',
      );
      expect(
        await emu.set(
          s.user.token,
          apath(s.user.uid, id()),
          entry(s.pid),
          serverTimes: const ['createdAt'],
        ),
        403,
        reason: 'no edit at all in this commit',
      );
      expect(
        await edit(
          s,
          entry(
            s.pid,
            overrides: {
              'changedFields': ['postalReference'],
            },
          ),
        ),
        403,
        reason: 'claims a field that did not change',
      );
      expect(
        await edit(
          s,
          entry(
            s.pid,
            overrides: {
              'changedFields': ['notes', 'receivedPaisa'],
            },
          ),
        ),
        403,
        reason: 'claims one real and one invented change',
      );
      expect(
        await edit(s, entry(s.pid, overrides: {'orderNumber': 'ADT-000099'})),
        403,
        reason: 'another order number',
      );
      expect(
        await edit(s, entry('ghost')),
        403,
        reason: 'a parcel that does not exist',
      );
      expect(
        await emu.set(
          other.token,
          apath(other.uid, id()),
          entry(s.pid),
          serverTimes: const ['createdAt'],
        ),
        403,
        reason: 'another user\'s parcel',
      );
      expect(
        await emu.set(
          other.token,
          apath(s.user.uid, id()),
          entry(s.pid),
          serverTimes: const ['createdAt'],
        ),
        403,
        reason: 'written into someone else\'s log',
      );
    }, skip: skip);

    test('the action must match what happened', () async {
      final s = await setup();
      for (final action in [
        'archive',
        'restore',
        'return',
        'resolve_review',
        'correct_payment',
      ]) {
        expect(
          await edit(s, entry(s.pid, overrides: {'action': action})),
          403,
          reason: 'a plain edit is not "$action"',
        );
      }
      expect(
        await edit(s, entry(s.pid, overrides: {'action': 'delete'})),
        403,
        reason: 'unknown action',
      );
    }, skip: skip);

    test('malformed entries are refused even next to a real edit', () async {
      final s = await setup();
      Future<void> denied(
        String why,
        Map<String, Object?> data, {
        List<String> times = const ['createdAt'],
      }) async => expect(await edit(s, data, times: times), 403, reason: why);
      await denied(
        'unknown entity',
        entry(s.pid, overrides: {'entityType': 'customer'}),
      );
      await denied(
        'no changed fields',
        entry(s.pid, overrides: {'changedFields': <Object?>[]}),
      );
      await denied(
        '31 changed fields',
        entry(
          s.pid,
          overrides: {'changedFields': List.generate(31, (i) => 'f$i')},
        ),
      );
      await denied(
        'changedFields not a list',
        entry(s.pid, overrides: {'changedFields': 'notes'}),
      );
      await denied('missing entityId', entry(s.pid, remove: ['entityId']));
      await denied('empty entityId', entry(s.pid, overrides: {'entityId': ''}));
      await denied(
        'missing order number',
        entry(s.pid, remove: ['orderNumber']),
      );
      await denied(
        'bad order number',
        entry(s.pid, overrides: {'orderNumber': 'order 1'}),
      );
      await denied('extra field', entry(s.pid, overrides: {'note': 'hi'}));
      await denied('client-supplied time', {
        ...entry(s.pid),
        'createdAt': DateTime.utc(2000),
      }, times: const []);
      await denied('no time', entry(s.pid), times: const []);
      expect(
        await edit(s, entry(s.pid)),
        200,
        reason: 'and the proper entry works',
      );
    }, skip: skip);
  });

  group('returns, notes and Pay Later dates', () {
    String ppath(String uid, String id) => 'users/$uid/parcels/$id';

    Future<({({String uid, String token}) user, String pid, DateTime created})>
    setup({
      Map<String, Object?> overrides = const {},
      bool counter = true,
    }) async {
      final u = await emu.signUp(
        'ret${DateTime.now().microsecondsSinceEpoch}_${n++}@x.com',
      );
      final pid = id();
      await _ensureCustomer(emu, u);
      expect(
        await emu.commit(u.token, [
          DocWrite('users/${u.uid}/counters/orders', {'lastSequence': 1}),
          DocWrite(
            ppath(u.uid, pid),
            _parcel(seq: 1, overrides: overrides),
            serverTimes: const ['createdAt', 'updatedAt'],
          ),
          ..._guardFor(u.uid, pid, _parcel(seq: 1, overrides: overrides)),
        ]),
        200,
      );
      return (
        user: u,
        pid: pid,
        created: await emu.createdAt(u.token, ppath(u.uid, pid)),
      );
    }

    Future<int> replace(
      ({({String uid, String token}) user, String pid, DateTime created}) s,
      Map<String, Object?> parcel, {
      String? token,
    }) => emu.set(
      token ?? s.user.token,
      ppath(s.user.uid, s.pid),
      {...parcel, 'createdAt': s.created},
      serverTimes: const ['updatedAt'],
    );

    test('Sent -> Returned needs the return fields, a sensible date and the review flag', () async {
      final s = await setup();
      expect(
        await replace(
          s,
          _parcel(seq: 1, overrides: {'parcelStatus': 'returned'}),
        ),
        403,
        reason: 'no return date',
      );
      expect(
        await replace(
          s,
          _parcel(seq: 1, overrides: _returned(date: '2999-01-01')),
        ),
        403,
        reason: 'future date',
      );
      expect(
        await replace(
          s,
          _parcel(seq: 1, overrides: _returned(date: '2000-01-01')),
        ),
        403,
        reason: 'before the sending date',
      );
      expect(
        await replace(s, _parcel(seq: 1, overrides: _returned(review: false))),
        403,
        reason: 'unpaid parcel needs review',
      );
      expect(
        await replace(
          s,
          _parcel(seq: 1, overrides: _returned(extra: {'returnReason': ''})),
        ),
        403,
        reason: 'empty reason',
      );
      expect(
        await replace(
          s,
          _parcel(
            seq: 1,
            overrides: _returned(extra: {'returnReason': 'x' * 201}),
          ),
        ),
        403,
        reason: 'long reason',
      );
      expect(
        await replace(
          s,
          _parcel(
            seq: 1,
            overrides: _returned(extra: {'returnReason': 'Customer refused'}),
          ),
        ),
        200,
      );
    }, skip: skip);

    test('a returned parcel cannot be changed except for notes, and cannot come back', () async {
      final s = await setup();
      final returned = _parcel(seq: 1, overrides: _returned());
      expect(await replace(s, returned), 200);
      expect(
        await replace(s, {...returned, 'notes': 'Customer called'}),
        200,
        reason: 'notes can still be edited',
      );
      expect(
        await replace(s, _parcel(seq: 1)),
        403,
        reason: 'not back to sent',
      );
      expect(
        await replace(s, {
          ...returned,
          'postalReference': 'VPP 99999',
          'postalReferenceNormalized': 'VPP99999',
        }),
        403,
        reason: 'other fields are locked',
      );
      expect(
        await replace(s, {...returned, 'returnedDateLocal': '2000-01-01'}),
        403,
        reason: 'return date is locked',
      );
    }, skip: skip);

    test('a draft cannot be marked returned; return fields only exist on returned parcels', () async {
      final d = await setup(
        overrides: {'parcelStatus': 'draft'},
      ); // a draft that already has its slip details
      expect(
        await replace(d, _parcel(seq: 1, overrides: _returned())),
        403,
        reason: 'draft -> returned',
      );
      final s = await setup();
      expect(
        await replace(s, _parcel(seq: 1, overrides: {'returnReason': 'x'})),
        403,
        reason: 'return reason on a sent parcel',
      );
      expect(
        await replace(
          s,
          _parcel(seq: 1, overrides: {'paymentReviewRequired': false}),
        ),
        403,
      );
    }, skip: skip);

    test('returning a parcel that is paid in full still flags it for review; a Gift / Free return does not', () async {
      final paid = await setup();
      final base = {
        'receivedPaisa': 500000,
        'outstandingPaisa': 0,
        'paymentStatus': 'received',
        'lastPaymentId': 'pay1',
      };
      expect(
        await _payOn(emu, paid.user, paid.pid, paid.created, 500000),
        200,
        reason: 'fully paid',
      );
      expect(
        await replace(
          paid,
          _parcel(seq: 1, overrides: {...base, ..._returned(review: false)}),
        ),
        403,
      );
      expect(
        await replace(
          paid,
          _parcel(seq: 1, overrides: {...base, ..._returned()}),
        ),
        200,
      );
      final free = await setup(
        overrides: {
          'collectionMethod': 'free_gift',
          'productAmountExpectedPaisa': 0,
          'outstandingPaisa': 0,
          'paymentStatus': 'not_required',
        },
      );
      final freeBase = {
        'collectionMethod': 'free_gift',
        'productAmountExpectedPaisa': 0,
        'outstandingPaisa': 0,
        'paymentStatus': 'not_required',
      };
      expect(
        await replace(
          free,
          _parcel(seq: 1, overrides: {...freeBase, ..._returned()}),
        ),
        403,
        reason: 'nothing to review',
      );
      expect(
        await replace(
          free,
          _parcel(
            seq: 1,
            overrides: {...freeBase, ..._returned(review: false)},
          ),
        ),
        200,
      );
    }, skip: skip);

    test(
      'notes: 1-500 characters, removable; another user cannot write them',
      () async {
        final s = await setup();
        expect(
          await replace(
            s,
            _parcel(seq: 1, overrides: {'notes': 'Call before delivery'}),
          ),
          200,
        );
        expect(
          await replace(s, _parcel(seq: 1, overrides: {'notes': ''})),
          403,
          reason: 'empty note must be removed instead',
        );
        expect(
          await replace(s, _parcel(seq: 1, overrides: {'notes': 'x' * 501})),
          403,
        );
        expect(
          await replace(s, _parcel(seq: 1, overrides: {'notes': 'x' * 500})),
          200,
        );
        expect(await replace(s, _parcel(seq: 1)), 200, reason: 'removed');
        final other = await emu.signUp(
          'notesother${DateTime.now().microsecondsSinceEpoch}@x.com',
        );
        expect(
          await replace(
            s,
            _parcel(seq: 1, overrides: {'notes': 'hacked'}),
            token: other.token,
          ),
          403,
        );
      },
      skip: skip,
    );

    test('Pay Later date: a changed date must be today or later; leaving it unchanged is fine; clearing is fine', () async {
      final s = await setup(
        overrides: {
          'collectionMethod': 'credit',
          'estimatedPaymentDateLocal': '2031-02-03',
        },
      );
      expect(
        await replace(
          s,
          _parcel(
            seq: 1,
            overrides: {
              'collectionMethod': 'credit',
              'estimatedPaymentDateLocal': '2000-01-01',
            },
          ),
        ),
        403,
        reason: 'past',
      );
      expect(
        await replace(
          s,
          _parcel(
            seq: 1,
            overrides: {
              'collectionMethod': 'credit',
              'estimatedPaymentDateLocal': _today(),
            },
          ),
        ),
        200,
        reason: 'today',
      );
      expect(
        await replace(
          s,
          _parcel(
            seq: 1,
            overrides: {
              'collectionMethod': 'credit',
              'estimatedPaymentDateLocal': '2032-05-06',
            },
          ),
        ),
        200,
        reason: 'later',
      );
      expect(
        await replace(
          s,
          _parcel(seq: 1, overrides: {'collectionMethod': 'credit'}),
        ),
        200,
        reason: 'cleared',
      );
      expect(
        await replace(
          s,
          _parcel(
            seq: 1,
            overrides: {'collectionMethod': 'credit', 'notes': 'x'},
          ),
        ),
        200,
        reason: 'other edits are not blocked',
      );
    }, skip: skip);
    group('completing a payment review (DT-011)', () {
      Map<String, Object?> done({
        Map<String, Object?> extra = const {},
        List<String> remove = const [],
      }) {
        final m = <String, Object?>{
          ..._returned(review: false),
          'paymentReviewReason': 'refund_given',
          'paymentReviewNote': 'Refund sent by bank transfer',
          'paymentReviewDateLocal': _today(),
          ...extra,
        };
        for (final key in remove) {
          m.remove(key);
        }
        return m;
      }

      Future<int> resolve(
        ({({String uid, String token}) user, String pid, DateTime created}) s,
        Map<String, Object?> overrides, {
        String? token,
        bool serverTime = true,
        Map<String, Object?> parcelExtra = const {},
      }) => emu.set(
        token ?? s.user.token,
        ppath(s.user.uid, s.pid),
        {
          ..._parcel(seq: 1, overrides: {...overrides, ...parcelExtra}),
          'createdAt': s.created,
          if (!serverTime) 'paymentReviewResolvedAt': DateTime.now().toUtc(),
        },
        serverTimes: serverTime
            ? const ['updatedAt', 'paymentReviewResolvedAt']
            : const ['updatedAt'],
      );

      /// A returned parcel with an open review (Rs. 5,000 still owed).
      Future<
        ({({String uid, String token}) user, String pid, DateTime created})
      >
      returnedParcel() async {
        final s = await setup();
        expect(await replace(s, _parcel(seq: 1, overrides: _returned())), 200);
        return s;
      }

      test(
        'a valid completion is accepted; the money and payments are untouched',
        () async {
          final s = await returnedParcel();
          expect(await resolve(s, done()), 200);
          for (final reason in [
            'refund_given',
            'money_kept',
            'balance_waived',
            'other',
          ]) {
            final t = await returnedParcel();
            expect(
              await resolve(t, done(extra: {'paymentReviewReason': reason})),
              200,
              reason: reason,
            );
          }
        },
        skip: skip,
      );

      test('reason, note and date are required and checked; the time is the server\'s', () async {
        final s = await returnedParcel();
        expect(
          await resolve(s, done(remove: ['paymentReviewReason'])),
          403,
          reason: 'no reason',
        );
        expect(
          await resolve(s, done(extra: {'paymentReviewReason': 'nonsense'})),
          403,
          reason: 'unknown reason',
        );
        expect(
          await resolve(s, done(remove: ['paymentReviewNote'])),
          403,
          reason: 'no note',
        );
        expect(
          await resolve(s, done(extra: {'paymentReviewNote': 'abc'})),
          403,
          reason: 'note too short',
        );
        expect(
          await resolve(s, done(extra: {'paymentReviewNote': 'x' * 201})),
          403,
          reason: 'note too long',
        );
        expect(
          await resolve(s, done(remove: ['paymentReviewDateLocal'])),
          403,
          reason: 'no date',
        );
        expect(
          await resolve(
            s,
            done(extra: {'paymentReviewDateLocal': '2999-01-01'}),
          ),
          403,
          reason: 'future date',
        );
        expect(
          await resolve(
            s,
            done(extra: {'paymentReviewDateLocal': '2000-01-01'}),
          ),
          403,
          reason: 'before the return',
        );
        expect(
          await resolve(s, done(), serverTime: false),
          403,
          reason: 'client time',
        );
        expect(
          await resolve(s, _returned(review: false)),
          403,
          reason: 'just clearing the flag',
        );
      }, skip: skip);

      test('only the review fields may change, once', () async {
        final s = await returnedParcel();
        expect(
          await resolve(s, done(extra: {'notes': 'sneaky'})),
          403,
          reason: 'notes ride along',
        );
        expect(
          await resolve(
            s,
            done(
              extra: {
                'receivedPaisa': 0,
                'outstandingPaisa': 0,
                'paymentStatus': 'received',
              },
            ),
          ),
          403,
          reason: 'money changed',
        );
        expect(await resolve(s, done()), 200);
        expect(
          await resolve(
            s,
            done(extra: {'paymentReviewNote': 'A different note'}),
          ),
          403,
          reason: 'cannot be rewritten',
        );
        expect(
          await resolve(s, _returned()),
          403,
          reason: 'cannot be re-opened',
        );
      }, skip: skip);

      test('only a returned parcel with money involved and an open review can be completed', () async {
        final sent = await setup();
        expect(
          await resolve(
            sent,
            done(
              extra: {'parcelStatus': 'sent'},
              remove: ['returnedDateLocal'],
            ),
          ),
          403,
          reason: 'not returned',
        );
        final free = await setup(
          overrides: {
            'collectionMethod': 'free_gift',
            'productAmountExpectedPaisa': 0,
            'outstandingPaisa': 0,
            'paymentStatus': 'not_required',
          },
        );
        final freeBase = {
          'collectionMethod': 'free_gift',
          'productAmountExpectedPaisa': 0,
          'outstandingPaisa': 0,
          'paymentStatus': 'not_required',
        };
        expect(
          await replace(
            free,
            _parcel(
              seq: 1,
              overrides: {...freeBase, ..._returned(review: false)},
            ),
          ),
          200,
        );
        expect(
          await resolve(free, done(extra: freeBase)),
          403,
          reason: 'nothing to review',
        );
      }, skip: skip);

      test('after completion the parcel can be archived and keeps its notes editable; nobody else can complete it', () async {
        final s = await returnedParcel();
        final other = await emu.signUp(
          'revother${DateTime.now().microsecondsSinceEpoch}@x.com',
        );
        expect(await resolve(s, done(), token: other.token), 403);
        expect(await resolve(s, done()), 200);
        final at = await emu.timestampOf(
          s.user.token,
          ppath(s.user.uid, s.pid),
          'paymentReviewResolvedAt',
        );
        final kept = {...done(), 'paymentReviewResolvedAt': at};
        expect(
          await replace(
            s,
            _parcel(
              seq: 1,
              overrides: {...kept, 'notes': 'Called the customer'},
            ),
          ),
          200,
          reason: 'notes still editable',
        );
        expect(
          await replace(
            s,
            _parcel(
              seq: 1,
              overrides: {
                ...kept,
                'notes': 'Called the customer',
                'isArchived': true,
              },
            ),
          ),
          200,
          reason: 'archivable now',
        );
      }, skip: skip);

      test('an archived parcel cannot be completed', () async {
        final s = await returnedParcel();
        expect(await resolve(s, done()), 200);
        final at = await emu.timestampOf(
          s.user.token,
          ppath(s.user.uid, s.pid),
          'paymentReviewResolvedAt',
        );
        final kept = {...done(), 'paymentReviewResolvedAt': at};
        expect(
          await replace(
            s,
            _parcel(seq: 1, overrides: {...kept, 'isArchived': true}),
          ),
          200,
        );
        expect(
          await replace(
            s,
            _parcel(
              seq: 1,
              overrides: {
                ...kept,
                'isArchived': true,
                'paymentReviewNote': 'Changed after archive',
              },
            ),
          ),
          403,
        );
      }, skip: skip);
    });

    group('archiving', () {
      Map<String, Object?> archived(Map<String, Object?> overrides) =>
          _parcel(seq: 1, overrides: {...overrides, 'isArchived': true});

      test('only a parcel with nothing left to chase can be archived: draft, returned, nothing owed, Gift / Free', () async {
        final unpaid = await setup();
        expect(
          await replace(unpaid, archived({})),
          403,
          reason: 'Rs. 5,000 is still owed',
        );
        final partial = await setup();
        final partOverrides = {
          'receivedPaisa': 200000,
          'outstandingPaisa': 300000,
          'paymentStatus': 'partial',
          'lastPaymentId': 'pay1',
        };
        expect(
          await _payOn(emu, partial.user, partial.pid, partial.created, 200000),
          200,
        );
        expect(
          await replace(partial, archived(partOverrides)),
          403,
          reason: 'part paid',
        );

        final draft = await setup(overrides: {'parcelStatus': 'draft'});
        expect(
          await replace(draft, archived({'parcelStatus': 'draft'})),
          200,
          reason: 'a draft',
        );

        final paid = await setup();
        const paidOverrides = {
          'receivedPaisa': 500000,
          'outstandingPaisa': 0,
          'paymentStatus': 'received',
          'lastPaymentId': 'pay1',
        };
        expect(
          await _payOn(emu, paid.user, paid.pid, paid.created, 500000),
          200,
        );
        expect(
          await replace(paid, archived(paidOverrides)),
          200,
          reason: 'paid in full',
        );

        final returned = await setup();
        expect(
          await replace(returned, _parcel(seq: 1, overrides: _returned())),
          200,
        );
        expect(
          await replace(returned, archived(_returned())),
          403,
          reason: 'returned, but its payment review is still open (DT-003)',
        );
        expect(
          await replace(returned, archived(_returned(review: false))),
          403,
          reason: 'the review flag cannot be dropped while archiving',
        );

        const freeOverrides = {
          'collectionMethod': 'free_gift',
          'productAmountExpectedPaisa': 0,
          'outstandingPaisa': 0,
          'paymentStatus': 'not_required',
        };
        final free = await setup(overrides: freeOverrides);
        expect(
          await replace(free, archived(freeOverrides)),
          200,
          reason: 'Gift / Free',
        );

        final freeReturned = await setup(overrides: freeOverrides);
        expect(
          await replace(
            freeReturned,
            _parcel(
              seq: 1,
              overrides: {...freeOverrides, ..._returned(review: false)},
            ),
          ),
          200,
        );
        expect(
          await replace(
            freeReturned,
            archived({...freeOverrides, ..._returned(review: false)}),
          ),
          200,
          reason: 'returned with nothing to review',
        );
      }, skip: skip);

      test(
        'archiving changes nothing else, and only `true` is ever stored',
        () async {
          final s = await setup(overrides: {'parcelStatus': 'draft'});
          const draft = {'parcelStatus': 'draft'};
          expect(
            await replace(
              s,
              archived({
                ...draft,
                'postalReference': 'VPP 99999',
                'postalReferenceNormalized': 'VPP99999',
              }),
            ),
            403,
            reason: 'archive + edit',
          );
          expect(
            await replace(s, archived({...draft, 'notes': 'sneaky'})),
            403,
          );
          expect(
            await replace(
              s,
              _parcel(seq: 1, overrides: {...draft, 'isArchived': false}),
            ),
            403,
            reason: 'false is not stored',
          );
          expect(await replace(s, archived(draft)), 200);
        },
        skip: skip,
      );

      test('an archived parcel is locked: no edits, no notes, no payments, no corrections; restoring is the only change', () async {
        final s = await setup(overrides: {'parcelStatus': 'draft'});
        const draft = {'parcelStatus': 'draft'};
        expect(await replace(s, archived(draft)), 200);
        expect(
          await replace(
            s,
            archived({...draft, 'notes': 'edit while archived'}),
          ),
          403,
          reason: 'notes',
        );
        expect(
          await replace(
            s,
            _parcel(
              seq: 1,
              overrides: {
                ...draft,
                'postalReference': 'VPP 99999',
                'postalReferenceNormalized': 'VPP99999',
              },
            ),
          ),
          403,
          reason: 'edit + restore together',
        );
        expect(
          await replace(s, _parcel(seq: 1, overrides: draft)),
          200,
          reason: 'restore (field removed)',
        );
        expect(
          await replace(
            s,
            _parcel(
              seq: 1,
              overrides: {...draft, 'notes': 'edit after restore'},
            ),
          ),
          200,
          reason: 'editable again',
        );
      }, skip: skip);

      test('an archived parcel takes no payment', () async {
        final s = await setup();
        const paidOverrides = {
          'receivedPaisa': 500000,
          'outstandingPaisa': 0,
          'paymentStatus': 'received',
          'lastPaymentId': 'pay1',
        };
        expect(await _payOn(emu, s.user, s.pid, s.created, 500000), 200);
        expect(await replace(s, archived(paidOverrides)), 200);
        // a payment would need outstanding money anyway; the rule also names archived parcels explicitly
        expect(
          await emu.commit(s.user.token, [
            DocWrite(
              ppath(s.user.uid, s.pid),
              {
                ..._parcel(
                  seq: 1,
                  overrides: {...paidOverrides, 'receivedPaisa': 500100},
                ),
                'isArchived': true,
                'createdAt': s.created,
              },
              serverTimes: const ['updatedAt'],
            ),
            DocWrite(
              'users/${s.user.uid}/parcels/${s.pid}/payments/p1',
              {'amountPaisa': 100, 'paymentType': 'advance'},
              serverTimes: const ['receivedAt', 'recordedAt'],
            ),
          ]),
          403,
        );
      }, skip: skip);

      test('another user cannot archive or restore', () async {
        final s = await setup(overrides: {'parcelStatus': 'draft'});
        final other = await emu.signUp(
          'archother${DateTime.now().microsecondsSinceEpoch}@x.com',
        );
        expect(
          await replace(
            s,
            archived({'parcelStatus': 'draft'}),
            token: other.token,
          ),
          403,
        );
      }, skip: skip);

      test('archive and restore are logged with a matching entry in the same commit', () async {
        final s = await setup(overrides: {'parcelStatus': 'draft'});
        const draft = {'parcelStatus': 'draft'};
        Future<int> change(
          Map<String, Object?> overrides,
          String action,
          List<String> fields,
        ) => emu.commit(s.user.token, [
          DocWrite(
            ppath(s.user.uid, s.pid),
            {..._parcel(seq: 1, overrides: overrides), 'createdAt': s.created},
            serverTimes: const ['updatedAt'],
          ),
          DocWrite(
            'users/${s.user.uid}/audit_logs/${id()}',
            {
              'entityType': 'parcel',
              'entityId': s.pid,
              'action': action,
              'orderNumber': 'ADT-000001',
              'changedFields': fields,
            },
            serverTimes: const ['createdAt'],
          ),
        ]);
        expect(
          await change(
            {...draft, 'isArchived': true},
            'restore',
            ['isArchived'],
          ),
          403,
          reason: 'archiving is not a restore',
        );
        expect(
          await change(
            {...draft, 'isArchived': true},
            'archive',
            ['isArchived'],
          ),
          200,
        );
        expect(
          await change(draft, 'archive', ['isArchived']),
          403,
          reason: 'restoring is not an archive',
        );
        expect(await change(draft, 'restore', ['isArchived']), 200);
      }, skip: skip);
    });
  });

  group('payments', () {
    String ppath(String uid, String id) => 'users/$uid/parcels/$id';
    String paypath(String uid, String id, String pay) =>
        'users/$uid/parcels/$id/payments/$pay';

    Map<String, Object?> payment({
      int amount = 100000,
      String type = 'customer_payment',
      Map<String, Object?> extra = const {},
    }) => {'amountPaisa': amount, 'paymentType': type, ...extra};

    /// A signed-up user with one parcel (expected Rs. 5,000) ready to take payments.
    Future<({({String uid, String token}) user, String pid, DateTime created})>
    setup({Map<String, Object?> overrides = const {}}) async {
      final u = await emu.signUp(
        'pay${DateTime.now().microsecondsSinceEpoch}_${n++}@x.com',
      );
      final pid = id();
      await _ensureCustomer(emu, u);
      expect(
        await emu.commit(u.token, [
          DocWrite('users/${u.uid}/counters/orders', {'lastSequence': 1}),
          DocWrite(
            ppath(u.uid, pid),
            _parcel(seq: 1, overrides: overrides),
            serverTimes: const ['createdAt', 'updatedAt'],
          ),
          ..._guardFor(u.uid, pid, _parcel(seq: 1, overrides: overrides)),
        ]),
        200,
      );
      return (
        user: u,
        pid: pid,
        created: await emu.createdAt(u.token, ppath(u.uid, pid)),
      );
    }

    /// The app's transaction: the parcel's received/outstanding move together with the new payment.
    Future<int> receive(
      ({({String uid, String token}) user, String pid, DateTime created}) s,
      Map<String, Object?> pay, {
      int? receivedTo,
      int? outstandingTo,
      String? asUid,
      String? token,
      int expected = 500000,
      int receivedBefore = 0,
      Map<String, Object?> overrides = const {},
    }) {
      final payId = 'pay${DateTime.now().microsecondsSinceEpoch}_${n++}';
      final to = receivedTo ?? receivedBefore + (pay['amountPaisa'] as int);
      final out = outstandingTo ?? (expected > to ? expected - to : 0);
      return emu.commit(token ?? s.user.token, [
        DocWrite(
          ppath(asUid ?? s.user.uid, s.pid),
          {
            ..._parcel(
              seq: 1,
              overrides: {
                'receivedPaisa': to,
                'outstandingPaisa': out,
                'paymentStatus': out == 0 ? 'received' : 'partial',
                'lastPaymentId': payId,
                ...overrides,
              },
            ),
            'createdAt': s.created,
          },
          serverTimes: const ['updatedAt'],
        ),
        DocWrite(
          'users/${asUid ?? s.user.uid}/parcels/${s.pid}/payments/$payId',
          {...pay, 'receivedAt': null, 'recordedAt': null}
            ..removeWhere((k, v) => v == null),
          serverTimes: const ['receivedAt', 'recordedAt'],
        ),
      ]);
    }

    test('a partial and then the final payment are accepted; the parcel moves with each', () async {
      final s = await setup();
      expect(await receive(s, payment(amount: 200000)), 200);
      expect(
        await receive(s, payment(amount: 300000), receivedBefore: 200000),
        200,
      );
    }, skip: skip);

    test('a payment above the outstanding balance is refused', () async {
      final s = await setup();
      expect(await receive(s, payment(amount: 500100), outstandingTo: 0), 403);
      expect(await receive(s, payment(amount: 200000)), 200);
      expect(
        await receive(
          s,
          payment(amount: 300100),
          receivedBefore: 200000,
          outstandingTo: 0,
        ),
        403,
      );
    }, skip: skip);

    test('the parcel must move by exactly the payment (no silent changes, no payment without the parcel)', () async {
      final s = await setup();
      expect(
        await receive(
          s,
          payment(amount: 100000),
          receivedTo: 200000,
          outstandingTo: 300000,
        ),
        403,
        reason: 'received moved too far',
      );
      expect(
        await receive(
          s,
          payment(amount: 100000),
          receivedTo: 50000,
          outstandingTo: 450000,
        ),
        403,
        reason: 'received moved too little',
      );
      expect(
        await emu.set(
          s.user.token,
          paypath(s.user.uid, s.pid, 'orphan'),
          payment(),
          serverTimes: const ['receivedAt', 'recordedAt'],
        ),
        403,
        reason: 'payment without the parcel update',
      );
    }, skip: skip);

    test(
      'amount, type and note are validated; times are server time',
      () async {
        final s = await setup();
        for (final bad in [
          payment(amount: 0),
          payment(amount: -100),
          payment(type: 'cash'),
          payment(extra: {'note': 'x' * 201}),
          payment(extra: {'note': 5}),
          payment(extra: {'extra': 'field'}),
        ]) {
          expect(
            await receive(s, bad, receivedTo: 100000, outstandingTo: 400000),
            403,
            reason: '$bad',
          );
        }
        // a client-chosen receivedAt is refused (no backdating)
        expect(
          await emu.commit(s.user.token, [
            DocWrite(
              ppath(s.user.uid, s.pid),
              {
                ..._parcel(
                  seq: 1,
                  overrides: {
                    'receivedPaisa': 100000,
                    'outstandingPaisa': 400000,
                    'paymentStatus': 'partial',
                  },
                ),
                'createdAt': s.created,
              },
              serverTimes: const ['updatedAt'],
            ),
            DocWrite(
              paypath(s.user.uid, s.pid, 'late'),
              {...payment(amount: 100000), 'receivedAt': DateTime.utc(2020)},
              serverTimes: const ['recordedAt'],
            ),
          ]),
          403,
        );
        expect(
          await receive(s, payment(amount: 100000, extra: {'note': 'x' * 200})),
          200,
        );
      },
      skip: skip,
    );

    test('no payment on a Gift / Free or a returned parcel', () async {
      final free = await setup(
        overrides: {
          'collectionMethod': 'free_gift',
          'productAmountExpectedPaisa': 0,
          'outstandingPaisa': 0,
          'paymentStatus': 'not_required',
        },
      );
      expect(
        await receive(
          free,
          payment(amount: 100),
          expected: 0,
          outstandingTo: 0,
          overrides: {
            'collectionMethod': 'free_gift',
            'productAmountExpectedPaisa': 0,
          },
        ),
        403,
      );
      final returned = await setup();
      expect(
        await emu.set(
          returned.user.token,
          ppath(returned.user.uid, returned.pid),
          {
            ..._parcel(seq: 1, overrides: _returned()),
            'createdAt': returned.created,
          },
          serverTimes: const ['updatedAt'],
        ),
        200,
      );
      expect(
        await receive(
          returned,
          payment(amount: 100000),
          overrides: _returned(),
        ),
        403,
      );
    }, skip: skip);

    test(
      'payments are append-only; another user cannot read or write them',
      () async {
        final s = await setup();
        final other = await emu.signUp(
          'payother${DateTime.now().microsecondsSinceEpoch}@x.com',
        );
        expect(await receive(s, payment(amount: 100000)), 200);
        final list = await emu.list(
          s.user.token,
          'users/${s.user.uid}/parcels/${s.pid}/payments',
        );
        expect(list.status, 200);
        expect(list.count, 1);
        expect(
          (await emu.list(
            other.token,
            'users/${s.user.uid}/parcels/${s.pid}/payments',
          )).status,
          403,
        );
        expect(
          await receive(
            s,
            payment(amount: 100000),
            token: other.token,
            receivedBefore: 100000,
          ),
          403,
          reason: "B cannot pay A's parcel",
        );
        // existing payment cannot be changed or removed
        final first = await emu.list(
          s.user.token,
          'users/${s.user.uid}/parcels/${s.pid}/payments',
        );
        expect(first.count, 1);
      },
      skip: skip,
    );
    test('"received on": an earlier date is accepted; a future date or one before the sending date is not', () async {
      final s = await setup();
      Future<int> receiveOn(DateTime when) {
        final payId = id();
        return emu.commit(s.user.token, [
          DocWrite(
            ppath(s.user.uid, s.pid),
            {
              ..._parcel(
                seq: 1,
                overrides: {
                  'receivedPaisa': 100000,
                  'outstandingPaisa': 400000,
                  'paymentStatus': 'partial',
                  'lastPaymentId': payId,
                },
              ),
              'createdAt': s.created,
            },
            serverTimes: const ['updatedAt'],
          ),
          DocWrite(
            paypath(s.user.uid, s.pid, payId),
            {...payment(amount: 100000), 'receivedAt': when},
            serverTimes: const ['recordedAt'],
          ),
        ]);
      }

      expect(
        await receiveOn(DateTime.now().toUtc().add(const Duration(days: 1))),
        403,
        reason: 'future',
      );
      expect(
        await receiveOn(DateTime.utc(2000)),
        403,
        reason: 'before the parcel was sent',
      );
      expect(
        await receiveOn(
          DateTime.now().toUtc().subtract(const Duration(seconds: 5)),
        ),
        200,
        reason: 'earlier today',
      );
    }, skip: skip);

    group('corrections', () {
      Future<int> correct(
        ({({String uid, String token}) user, String pid, DateTime created}) s, {
        int original = 200000,
        int replacement = 300000,
        int receivedTo = 300000,
        String reason = 'Wrong amount entered',
        String originalId = 'pay1',
        String? token,
        Map<String, Object?> parcelOverrides = const {},
        bool withReplacementDoc = true,
        Map<String, Object?> reversalExtra = const {},
        String? type,
      }) {
        final out = 500000 > receivedTo ? 500000 - receivedTo : 0;
        return emu.commit(token ?? s.user.token, [
          DocWrite(
            ppath(s.user.uid, s.pid),
            {
              ..._parcel(
                seq: 1,
                overrides: {
                  'receivedPaisa': receivedTo,
                  'outstandingPaisa': out,
                  'paymentStatus': receivedTo == 0
                      ? 'pending'
                      : out == 0
                      ? 'received'
                      : 'partial',
                  'lastPaymentId': 'rev_$originalId',
                  ...parcelOverrides,
                },
              ),
              'createdAt': s.created,
            },
            serverTimes: const ['updatedAt'],
          ),
          DocWrite(
            paypath(s.user.uid, s.pid, 'rev_$originalId'),
            {
              'amountPaisa': -original,
              'paymentType': type ?? 'customer_payment',
              'reversalOfPaymentId': originalId,
              'correctionReason': reason,
              'replacementPaisa': replacement,
              ...reversalExtra,
            },
            serverTimes: const ['receivedAt', 'recordedAt'],
          ),
          if (withReplacementDoc && replacement > 0)
            DocWrite(
              paypath(s.user.uid, s.pid, 'cor_$originalId'),
              {
                'amountPaisa': replacement,
                'paymentType': 'customer_payment',
                'correctionOfPaymentId': originalId,
              },
              serverTimes: const ['receivedAt', 'recordedAt'],
            ),
        ]);
      }

      /// A parcel that has received Rs. 2,000 as payment "pay1".
      Future<
        ({({String uid, String token}) user, String pid, DateTime created})
      >
      withPay1() async {
        final s = await setup();
        expect(
          await emu.commit(s.user.token, [
            DocWrite(
              ppath(s.user.uid, s.pid),
              {
                ..._parcel(
                  seq: 1,
                  overrides: {
                    'receivedPaisa': 200000,
                    'outstandingPaisa': 300000,
                    'paymentStatus': 'partial',
                    'lastPaymentId': 'pay1',
                  },
                ),
                'createdAt': s.created,
              },
              serverTimes: const ['updatedAt'],
            ),
            DocWrite(
              paypath(s.user.uid, s.pid, 'pay1'),
              payment(amount: 200000),
              serverTimes: const ['receivedAt', 'recordedAt'],
            ),
          ]),
          200,
        );
        return s;
      }

      group('date corrections (DT-008)', () {
        /// A date-only / dated correction: the parcel's money may not move, the pointer follows the reversal.
        Future<int> fix(
          ({({String uid, String token}) user, String pid, DateTime created})
          s, {
          int replacement = 200000,
          int receivedTo = 200000,
          Object? replacementAt = 'server',
          String reason = 'Money was received a day earlier',
          String? token,
          Map<String, Object?> reversalExtra = const {},
        }) {
          final out = 500000 > receivedTo ? 500000 - receivedTo : 0;
          return emu.commit(token ?? s.user.token, [
            DocWrite(
              ppath(s.user.uid, s.pid),
              {
                ..._parcel(
                  seq: 1,
                  overrides: {
                    'receivedPaisa': receivedTo,
                    'outstandingPaisa': out,
                    'paymentStatus': receivedTo == 0
                        ? 'pending'
                        : out == 0
                        ? 'received'
                        : 'partial',
                    'lastPaymentId': 'rev_pay1',
                  },
                ),
                'createdAt': s.created,
              },
              serverTimes: const ['updatedAt'],
            ),
            DocWrite(
              paypath(s.user.uid, s.pid, 'rev_pay1'),
              {
                'amountPaisa': -200000,
                'paymentType': 'customer_payment',
                'reversalOfPaymentId': 'pay1',
                'correctionReason': reason,
                'replacementPaisa': replacement,
                ...reversalExtra,
              },
              serverTimes: const ['receivedAt', 'recordedAt'],
            ),
            if (replacement > 0)
              DocWrite(
                paypath(s.user.uid, s.pid, 'cor_pay1'),
                {
                  'amountPaisa': replacement,
                  'paymentType': 'customer_payment',
                  'correctionOfPaymentId': 'pay1',
                  if (replacementAt is DateTime) 'receivedAt': replacementAt,
                },
                serverTimes: replacementAt == 'server'
                    ? const ['receivedAt', 'recordedAt']
                    : const ['recordedAt'],
              ),
          ]);
        }

        test('a date-only correction (same amount, earlier day) is accepted: no money moves, the original stays', () async {
          final s = await withPay1();
          final earlier = DateTime.now().toUtc().subtract(
            const Duration(seconds: 30),
          );
          expect(await fix(s, replacementAt: earlier), 200);
          expect(
            await emu.get(s.user.token, paypath(s.user.uid, s.pid, 'pay1')),
            200,
            reason: 'the original payment is still there',
          );
          expect(
            await emu.get(s.user.token, paypath(s.user.uid, s.pid, 'rev_pay1')),
            200,
          );
          expect(
            await emu.get(s.user.token, paypath(s.user.uid, s.pid, 'cor_pay1')),
            200,
          );
        }, skip: skip);

        test('the corrected day cannot be in the future or before the parcel was sent', () async {
          final s = await withPay1();
          expect(
            await fix(
              s,
              replacementAt: DateTime.now().toUtc().add(
                const Duration(days: 1),
              ),
            ),
            403,
            reason: 'future',
          );
          expect(
            await fix(s, replacementAt: DateTime.utc(2000)),
            403,
            reason: 'before the sending date',
          );
          expect(
            await fix(
              s,
              replacementAt: DateTime.now().toUtc().subtract(
                const Duration(seconds: 5),
              ),
            ),
            200,
            reason: 'a valid earlier time',
          );
        }, skip: skip);

        test('a date-only correction still needs a reason, and the money must not move', () async {
          final s = await withPay1();
          final earlier = DateTime.now().toUtc().subtract(
            const Duration(seconds: 30),
          );
          expect(
            await fix(s, replacementAt: earlier, reason: 'oops'),
            403,
            reason: 'reason too short',
          );
          expect(
            await fix(s, replacementAt: earlier, receivedTo: 300000),
            403,
            reason: 'money moved on a date-only correction',
          );
          expect(
            await fix(
              s,
              replacementAt: earlier,
              replacement: 250000,
              receivedTo: 250000,
            ),
            200,
            reason: 'a different amount is also fine, with the date',
          );
        }, skip: skip);

        test(
          'the person who made the correction is recorded and cannot be faked',
          () async {
            final s = await withPay1();
            final earlier = DateTime.now().toUtc().subtract(
              const Duration(seconds: 30),
            );
            expect(
              await fix(
                s,
                replacementAt: earlier,
                reversalExtra: {'correctedBy': 'someone-else'},
              ),
              403,
            );
            expect(
              await fix(
                s,
                replacementAt: earlier,
                reversalExtra: {'correctedBy': s.user.uid},
              ),
              200,
            );
          },
          skip: skip,
        );

        test(
          'another user cannot correct the date of this user\'s payment',
          () async {
            final s = await withPay1();
            final other = await emu.signUp(
              'datother${DateTime.now().microsecondsSinceEpoch}@x.com',
            );
            expect(
              await fix(
                s,
                replacementAt: DateTime.now().toUtc().subtract(
                  const Duration(seconds: 30),
                ),
                token: other.token,
              ),
              403,
            );
          },
          skip: skip,
        );

        test(
          'a pointer change without a new payment document is still refused',
          () async {
            final s = await withPay1();
            expect(
              await emu.set(
                s.user.token,
                ppath(s.user.uid, s.pid),
                {
                  ..._parcel(
                    seq: 1,
                    overrides: {
                      'receivedPaisa': 200000,
                      'outstandingPaisa': 300000,
                      'paymentStatus': 'partial',
                      'lastPaymentId': 'pay9',
                    },
                  ),
                  'createdAt': s.created,
                },
                serverTimes: const ['updatedAt'],
              ),
              403,
            );
          },
          skip: skip,
        );
      });

      test('a reversal with a replacement moves the parcel by the difference and is accepted', () async {
        final s = await withPay1();
        expect(await correct(s), 200);
      }, skip: skip);

      test(
        'a plain reversal (no replacement) takes the money off the parcel',
        () async {
          final s = await withPay1();
          expect(await correct(s, replacement: 0, receivedTo: 0), 200);
        },
        skip: skip,
      );

      test('the parcel must move by exactly reversal + replacement', () async {
        final s = await withPay1();
        expect(
          await correct(s, receivedTo: 250000),
          403,
          reason: 'wrong total',
        );
        expect(
          await correct(s, replacement: 0, receivedTo: 200000),
          403,
          reason: 'reversal left the parcel unchanged',
        );
      }, skip: skip);

      test('the reversal must mirror the original payment; a payment can be reversed only once', () async {
        final s = await withPay1();
        expect(
          await correct(s, original: 150000, receivedTo: 350000),
          403,
          reason: 'amount differs from the original',
        );
        expect(
          await correct(s, type: 'advance'),
          403,
          reason: 'type differs from the original',
        );
        expect(
          await correct(s, originalId: 'ghost'),
          403,
          reason: 'no such payment',
        );
        expect(await correct(s), 200);
        expect(
          await correct(s, receivedTo: 400000, replacement: 300000),
          403,
          reason: 'second reversal of the same payment',
        );
      }, skip: skip);

      test('reason is required (5-200 characters); no stray fields; the replacement must match', () async {
        final s = await withPay1();
        expect(await correct(s, reason: 'oops'), 403, reason: 'too short');
        expect(await correct(s, reason: 'x' * 201), 403, reason: 'too long');
        expect(
          await correct(s, reversalExtra: {'extra': 1}),
          403,
          reason: 'extra field',
        );
        expect(
          await correct(s, withReplacementDoc: false),
          403,
          reason: 'replacement missing',
        );
        expect(
          await correct(s, replacement: 600000, receivedTo: 600000),
          403,
          reason: 'more than the order total',
        );
      }, skip: skip);

      test(
        'no correction on a returned parcel; another user cannot correct',
        () async {
          final s = await withPay1();
          final other = await emu.signUp(
            'corother${DateTime.now().microsecondsSinceEpoch}@x.com',
          );
          expect(await correct(s, token: other.token), 403);
          expect(
            await emu.set(
              s.user.token,
              ppath(s.user.uid, s.pid),
              {
                ..._parcel(
                  seq: 1,
                  overrides: {
                    'receivedPaisa': 200000,
                    'outstandingPaisa': 300000,
                    'paymentStatus': 'partial',
                    'lastPaymentId': 'pay1',
                    ..._returned(),
                  },
                ),
                'createdAt': s.created,
              },
              serverTimes: const ['updatedAt'],
            ),
            200,
          );
          expect(await correct(s, parcelOverrides: _returned()), 403);
        },
        skip: skip,
      );

      test('a replacement without its reversal is refused', () async {
        final s = await withPay1();
        expect(
          await emu.commit(s.user.token, [
            DocWrite(
              ppath(s.user.uid, s.pid),
              {
                ..._parcel(
                  seq: 1,
                  overrides: {
                    'receivedPaisa': 500000,
                    'outstandingPaisa': 0,
                    'paymentStatus': 'received',
                  },
                ),
                'createdAt': s.created,
              },
              serverTimes: const ['updatedAt'],
            ),
            DocWrite(
              paypath(s.user.uid, s.pid, 'cor_pay1'),
              {
                'amountPaisa': 300000,
                'paymentType': 'customer_payment',
                'correctionOfPaymentId': 'pay1',
              },
              serverTimes: const ['receivedAt', 'recordedAt'],
            ),
          ]),
          403,
        );
      }, skip: skip);
    });
  });

  group('financial integrity (DT-002)', () {
    String ppath(String uid, String id) => 'users/$uid/parcels/$id';

    Future<({({String uid, String token}) user, String pid, DateTime created})>
    setup() async {
      final u = await emu.signUp(
        'fin${DateTime.now().microsecondsSinceEpoch}_${n++}@x.com',
      );
      final pid = id();
      await _ensureCustomer(emu, u);
      expect(
        await emu.commit(u.token, [
          DocWrite('users/${u.uid}/counters/orders', {'lastSequence': 1}),
          DocWrite(
            ppath(u.uid, pid),
            _parcel(seq: 1),
            serverTimes: const ['createdAt', 'updatedAt'],
          ),
          ..._guardFor(u.uid, pid, _parcel(seq: 1)),
        ]),
        200,
      );
      return (
        user: u,
        pid: pid,
        created: await emu.createdAt(u.token, ppath(u.uid, pid)),
      );
    }

    Future<int> replace(
      ({({String uid, String token}) user, String pid, DateTime created}) s,
      Map<String, Object?> parcel, {
      String? token,
    }) => emu.set(
      token ?? s.user.token,
      ppath(s.user.uid, s.pid),
      {...parcel, 'createdAt': s.created},
      serverTimes: const ['updatedAt'],
    );

    final paid = {
      'receivedPaisa': 500000,
      'outstandingPaisa': 0,
      'paymentStatus': 'received',
    };

    test(
      'received money cannot be set on the parcel without a payment record',
      () async {
        final s = await setup();
        expect(
          await replace(s, _parcel(seq: 1, overrides: paid)),
          403,
          reason: 'no payment, no lastPaymentId',
        );
        expect(
          await replace(
            s,
            _parcel(seq: 1, overrides: {...paid, 'lastPaymentId': 'ghost'}),
          ),
          403,
          reason: 'the named payment does not exist',
        );
        expect(
          await _payOn(emu, s.user, s.pid, s.created, 500000),
          200,
          reason: 'the same change through a real payment',
        );
      },
      skip: skip,
    );

    test('lastPaymentId can only name a new payment, and only moves with the money', () async {
      final s = await setup();
      expect(await _payOn(emu, s.user, s.pid, s.created, 200000), 200);
      const part = {
        'receivedPaisa': 200000,
        'outstandingPaisa': 300000,
        'paymentStatus': 'partial',
      };
      expect(
        await replace(
          s,
          _parcel(seq: 1, overrides: {...part, 'lastPaymentId': 'other'}),
        ),
        403,
        reason: 'pointer changed without money moving',
      );
      expect(
        await replace(
          s,
          _parcel(
            seq: 1,
            overrides: {...part, 'lastPaymentId': 'pay1', 'notes': 'x'},
          ),
        ),
        200,
        reason: 'unchanged pointer, other edit',
      );
      expect(
        await _payOn(emu, s.user, s.pid, s.created, 300000, before: 200000),
        403,
        reason: 'pay1 already exists, it cannot be reused',
      );
      expect(
        await _payOn(
          emu,
          s.user,
          s.pid,
          s.created,
          300000,
          before: 200000,
          payId: 'pay2',
          overrides: {'notes': 'x'},
        ),
        200,
      );
    }, skip: skip);

    test('a payment document cannot be replaced, and the parcel cannot be set to a different amount than the payment', () async {
      final s = await setup();
      expect(await _payOn(emu, s.user, s.pid, s.created, 100000), 200);
      expect(
        await emu.set(
          s.user.token,
          'users/${s.user.uid}/parcels/${s.pid}/payments/pay1',
          {'amountPaisa': 1, 'paymentType': 'customer_payment'},
          serverTimes: const ['receivedAt', 'recordedAt'],
        ),
        403,
        reason: 'overwriting a payment',
      );
      // the payment says Rs. 1,000 but the parcel claims Rs. 4,000 received
      final forged = {
        'receivedPaisa': 400000,
        'outstandingPaisa': 100000,
        'paymentStatus': 'partial',
        'lastPaymentId': 'pay2',
      };
      expect(
        await emu.commit(s.user.token, [
          DocWrite(
            ppath(s.user.uid, s.pid),
            {..._parcel(seq: 1, overrides: forged), 'createdAt': s.created},
            serverTimes: const ['updatedAt'],
          ),
          DocWrite(
            'users/${s.user.uid}/parcels/${s.pid}/payments/pay2',
            {'amountPaisa': 100000, 'paymentType': 'customer_payment'},
            serverTimes: const ['receivedAt', 'recordedAt'],
          ),
        ]),
        403,
      );
    }, skip: skip);

    test('the payment status must follow from the amounts', () async {
      final s = await setup();
      expect(
        await replace(
          s,
          _parcel(seq: 1, overrides: {'paymentStatus': 'received'}),
        ),
        403,
        reason: 'nothing received',
      );
      expect(
        await replace(
          s,
          _parcel(seq: 1, overrides: {'paymentStatus': 'partial'}),
        ),
        403,
      );
      expect(
        await replace(
          s,
          _parcel(seq: 1, overrides: {'paymentStatus': 'not_required'}),
        ),
        403,
        reason: 'only Gift / Free is not_required',
      );
      expect(
        await replace(s, _parcel(seq: 1)),
        200,
        reason: 'unchanged is fine',
      );
    }, skip: skip);

    test('the expected amount cannot change on its own; it moves with the item lines', () async {
      final s = await setup();
      expect(
        await replace(
          s,
          _parcel(
            seq: 1,
            overrides: {
              'productAmountExpectedPaisa': 100,
              'outstandingPaisa': 100,
            },
          ),
        ),
        403,
        reason: 'Rs. 1 while the lines still total Rs. 5,000',
      );
      final cheaper = [
        {
          'productId': 'p1',
          'productName': 'Mango Box',
          'saleUnit': 'per_piece',
          'quantity': 2,
          'unitPricePaisa': 100000,
          'lineTotalPaisa': 200000,
        },
      ];
      expect(
        await replace(
          s,
          _parcel(
            seq: 1,
            overrides: {
              'items': cheaper,
              'productAmountExpectedPaisa': 200000,
              'outstandingPaisa': 200000,
            },
          ),
        ),
        200,
        reason: 'a real price edit',
      );
    }, skip: skip);

    test(
      'the customer snapshot must be a copy of the customer record',
      () async {
        final s = await setup();
        final other = {
          'name': 'Someone Else',
          'phone': '0311 7654321',
          'address': 'Another Street, Lahore',
        };
        expect(
          await replace(
            s,
            _parcel(seq: 1, overrides: {'customerSnapshot': other}),
          ),
          403,
          reason: 'snapshot swapped, same customer id',
        );
        expect(
          await replace(
            s,
            _parcel(
              seq: 1,
              overrides: {'customerId': 'ghost', 'customerSnapshot': other},
            ),
          ),
          403,
          reason: 'customer record does not exist',
        );
        expect(
          await emu.set(
            s.user.token,
            'users/${s.user.uid}/customers/cust2',
            _customer(
              name: 'Someone Else',
              phone: '0311 7654321',
              phoneNormalized: '03117654321',
              address: 'Another Street, Lahore',
            ),
            serverTimes: const ['createdAt', 'updatedAt'],
          ),
          200,
        );
        expect(
          await replace(
            s,
            _parcel(
              seq: 1,
              overrides: {'customerId': 'cust2', 'customerSnapshot': other},
            ),
          ),
          200,
          reason: 'moved to another real customer',
        );
        expect(
          await replace(
            s,
            _parcel(
              seq: 1,
              overrides: {
                'customerId': 'cust2',
                'customerSnapshot': other,
                'notes': 'edit',
              },
            ),
          ),
          200,
          reason: 'unchanged snapshot stays valid',
        );
        // creating a parcel with a snapshot that matches no customer record
        final u = await emu.signUp(
          'snap${DateTime.now().microsecondsSinceEpoch}@x.com',
        );
        await _ensureCustomer(emu, u);
        expect(
          await emu.commit(u.token, [
            DocWrite('users/${u.uid}/counters/orders', {'lastSequence': 1}),
            DocWrite(
              ppath(u.uid, 'snapparcel'),
              _parcel(seq: 1, overrides: {'customerSnapshot': other}),
              serverTimes: const ['createdAt', 'updatedAt'],
            ),
            ..._guardFor(
              u.uid,
              'snapparcel',
              _parcel(seq: 1, overrides: {'customerSnapshot': other}),
            ),
          ]),
          403,
        );
      },
      skip: skip,
    );

    test('another user cannot change the money, status or customer of this user\'s parcel', () async {
      final s = await setup();
      final intruder = await emu.signUp(
        'intr${DateTime.now().microsecondsSinceEpoch}@x.com',
      );
      expect(
        await replace(
          s,
          _parcel(seq: 1, overrides: paid),
          token: intruder.token,
        ),
        403,
      );
      expect(
        await replace(
          s,
          _parcel(
            seq: 1,
            overrides: {'productAmountExpectedPaisa': 1, 'outstandingPaisa': 1},
          ),
          token: intruder.token,
        ),
        403,
      );
    }, skip: skip);
  });

  group('parcel edits', () {
    String ppath(String uid, String id) => 'users/$uid/parcels/$id';

    test('an edit may remove optional fields and change status; amounts must stay consistent', () async {
      final u = await emu.signUp(
        'pe${DateTime.now().microsecondsSinceEpoch}@x.com',
      );
      final pid = id();
      await _ensureCustomer(emu, u);
      expect(
        await emu.commit(u.token, [
          DocWrite('users/${u.uid}/counters/orders', {'lastSequence': 1}),
          DocWrite(
            ppath(u.uid, pid),
            _parcel(seq: 1, overrides: {'actualPackedWeightGrams': 1500}),
            serverTimes: const ['createdAt', 'updatedAt'],
          ),
          ..._guardFor(
            u.uid,
            pid,
            _parcel(seq: 1, overrides: {'actualPackedWeightGrams': 1500}),
          ),
        ]),
        200,
      );
      final created = await emu.createdAt(u.token, ppath(u.uid, pid));
      Future<int> replace(Map<String, Object?> parcel) => emu.set(
        u.token,
        ppath(u.uid, pid),
        {...parcel, 'createdAt': created},
        serverTimes: const ['updatedAt'],
      );

      // back to a draft: no reference, no charge, no packed weight
      final draftAgain = _parcel(
        seq: 1,
        overrides: {
          'parcelStatus': 'draft',
          'postalReference': '',
          'postalReferenceNormalized': '',
        },
        remove: ['deliveryChargePaisa', 'actualPackedWeightGrams'],
      );
      expect(
        await emu.commit(u.token, [
          DocWrite(
            ppath(u.uid, pid),
            {...draftAgain, 'createdAt': created},
            serverTimes: const ['updatedAt'],
          ),
          DocWrite.delete(
            'users/${u.uid}/postal_refs/${_parcel(seq: 1)['postalGuardId']}',
          ),
        ]),
        200,
      );
      // bigger order: expected and outstanding move together
      final bigger = [
        {
          'productId': 'p1',
          'productName': 'Mango Box',
          'saleUnit': 'per_piece',
          'quantity': 2,
          'unitPricePaisa': 450000,
          'lineTotalPaisa': 900000,
        },
      ];
      final biggerParcel = _parcel(
        seq: 1,
        overrides: {
          'items': bigger,
          'productAmountExpectedPaisa': 900000,
          'outstandingPaisa': 900000,
        },
      );
      expect(
        await emu.commit(u.token, [
          DocWrite(
            ppath(u.uid, pid),
            {...biggerParcel, 'createdAt': created},
            serverTimes: const ['updatedAt'],
          ),
          ..._guardFor(
            u.uid,
            pid,
            biggerParcel,
          ), // back from a draft: the reference is reserved again
        ]),
        200,
      );
      expect(
        await replace(
          _parcel(
            seq: 1,
            overrides: {
              'items': bigger,
              'productAmountExpectedPaisa': 900000,
              'outstandingPaisa': 100,
            },
          ),
        ),
        403,
      );
      // switching to a Pay Later parcel with a date
      expect(
        await replace(
          _parcel(
            seq: 1,
            overrides: {
              'collectionMethod': 'credit',
              'estimatedPaymentDateLocal': '2031-02-03',
            },
          ),
        ),
        200,
      );
      // ... but a date on a non Pay Later parcel is refused
      expect(
        await replace(
          _parcel(
            seq: 1,
            overrides: {'estimatedPaymentDateLocal': '2031-02-03'},
          ),
        ),
        403,
      );
    }, skip: skip);
  });
}

Future<DateTime> _readCreatedAt(
  EmulatorClient emu,
  String token,
  String uid,
  String pid,
) async => emu.createdAt(token, 'users/$uid/products/$pid');
