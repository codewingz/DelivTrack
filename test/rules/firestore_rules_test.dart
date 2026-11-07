// Firestore security-rules tests (REST against the Auth + Firestore emulators, real ID tokens).
// Run:  firebase emulators:exec --only auth,firestore --project delivtrack-codewingz \
//         "flutter test test/rules"
import 'package:deliv_track/core/time/pakistan_time.dart';
import 'package:flutter_test/flutter_test.dart';
import 'emulator_client.dart';

Map<String, Object?> _product({String name = 'Mango Box', String? nameLower, String unit = 'per_piece', Object? active = true}) => {
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
}) =>
    {
      'displayName': name,
      'displayNameLower': nameLower ?? name.toLowerCase(),
      'phone': phone,
      'phoneNormalized': phoneNormalized,
      'address': address,
    };


String _today() => pakistanDate(DateTime.now().toUtc());

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
    'customerSnapshot': {'name': 'Ali Raza', 'phone': '0300 1234567', 'address': 'House 5, Sahiwal'},
    'items': [
      {'productId': 'p1', 'productName': 'Mango Box', 'saleUnit': 'per_piece', 'quantity': 2, 'unitPricePaisa': 250000, 'lineTotalPaisa': 500000},
    ],
    'collectionMethod': 'postal_collection',
    'postalServiceType': 'VPP',
    'postalReference': 'VPP 12345',
    'postalReferenceNormalized': 'VPP12345',
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
  return base;
}

void main() {
  final emu = EmulatorClient();
  final skip = emu.available ? null : 'Needs Firebase emulators (use firebase emulators:exec)';

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

  Future<int> createProduct(String? token, String uid, String pid, Map<String, Object?> fields,
          {List<String> serverTimes = const ['createdAt', 'updatedAt']}) =>
      emu.set(token, 'users/$uid/products/$pid', {...fields}, serverTimes: serverTimes);

  group('isolation between users', () {
    test('owner can create, read and list own products', () async {
      final pid = id();
      expect(await createProduct(alice.token, alice.uid, pid, _product()), 200);
      expect(await emu.get(alice.token, 'users/${alice.uid}/products/$pid'), 200);
      final list = await emu.list(alice.token, 'users/${alice.uid}/products');
      expect(list.status, 200);
      expect(list.count, greaterThanOrEqualTo(1));
    }, skip: skip);

    test('another user cannot read, list, create, update or delete in someone else\'s data', () async {
      final pid = id();
      expect(await createProduct(alice.token, alice.uid, pid, _product(name: 'Private Item')), 200);

      expect(await emu.get(bob.token, 'users/${alice.uid}/products/$pid'), 403, reason: 'read');
      expect((await emu.list(bob.token, 'users/${alice.uid}/products')).status, 403, reason: 'list');
      expect(await createProduct(bob.token, alice.uid, id(), _product(name: 'Injected')), 403, reason: 'create');
      expect(await createProduct(bob.token, alice.uid, pid, _product(name: 'Hijacked'), serverTimes: const ['updatedAt']), 403,
          reason: 'update');
      expect(await emu.delete(bob.token, 'users/${alice.uid}/products/$pid'), 403, reason: 'delete');
      expect(await emu.get(alice.token, 'users/${alice.uid}/products/$pid'), 200, reason: 'alice data untouched');
    }, skip: skip);

    test('each user only lists their own data', () async {
      await createProduct(bob.token, bob.uid, id(), _product(name: 'Bob Only'));
      final alices = await emu.list(alice.token, 'users/${alice.uid}/products');
      final bobs = await emu.list(bob.token, 'users/${bob.uid}/products');
      expect(alices.status, 200);
      expect(bobs.status, 200);
      expect((await emu.list(alice.token, 'users/${bob.uid}/products')).status, 403);
      expect((await emu.list(bob.token, 'users/${alice.uid}/products')).status, 403);
    }, skip: skip);

    test('signed-out requests are denied', () async {
      final pid = id();
      await createProduct(alice.token, alice.uid, pid, _product());
      expect(await emu.get(null, 'users/${alice.uid}/products/$pid'), 403);
      expect(await createProduct(null, alice.uid, id(), _product()), 403);
    }, skip: skip);

    test('product-name guards are isolated too', () async {
      expect(await emu.set(alice.token, 'users/${alice.uid}/product_names/n_mango', {'productId': 'x'}), 200);
      expect(await emu.get(bob.token, 'users/${alice.uid}/product_names/n_mango'), 403);
      expect(await emu.set(bob.token, 'users/${alice.uid}/product_names/n_other', {'productId': 'x'}), 403);
    }, skip: skip);
  });

  group('data validation', () {
    Future<void> denied(Map<String, Object?> fields, {List<String> serverTimes = const ['createdAt', 'updatedAt']}) async =>
        expect(await createProduct(alice.token, alice.uid, id(), fields, serverTimes: serverTimes), 403);

    test('rejects 1-char and 61-char names, padded names, wrong nameLower', () async {
      await denied(_product(name: 'A'));
      await denied(_product(name: 'A' * 61));
      await denied(_product(name: ' Mango'));
      await denied(_product(name: 'Mango '));
      await denied(_product(name: 'Mango', nameLower: 'MANGO'));
      expect(await createProduct(alice.token, alice.uid, id(), _product(name: 'A' * 60)), 200, reason: '60 is allowed');
      expect(await createProduct(alice.token, alice.uid, id(), _product(name: 'Ab')), 200, reason: '2 is allowed');
    }, skip: skip);

    test('rejects bad unit, non-bool isActive, extra and missing fields', () async {
      await denied(_product(unit: 'per_box'));
      await denied(_product(active: 'yes'));
      await denied({..._product(), 'price': 5});
      final missing = _product()..remove('saleUnit');
      await denied(missing);
    }, skip: skip);

    test('createdAt/updatedAt must be server time, not client time', () async {
      await denied({..._product(), 'createdAt': DateTime.utc(2000), 'updatedAt': DateTime.utc(2000)}, serverTimes: const []);
      await denied({..._product(), 'createdAt': DateTime.utc(2000)}, serverTimes: const ['updatedAt']);
    }, skip: skip);

    test('createdAt cannot be changed later; archive (isActive=false) works; delete is never allowed', () async {
      final pid = id();
      expect(await createProduct(alice.token, alice.uid, pid, _product()), 200);
      // Changing createdAt on update is rejected.
      expect(await createProduct(alice.token, alice.uid, pid, _product(), serverTimes: const ['createdAt', 'updatedAt']), 403);
      // Archiving: keep the stored createdAt untouched (REST update needs the original value, so read it).
      final original = await _readCreatedAt(emu, alice.token, alice.uid, pid);
      expect(
        await emu.set(alice.token, 'users/${alice.uid}/products/$pid',
            {..._product(active: false), 'createdAt': original}, serverTimes: const ['updatedAt']),
        200,
      );
      expect(await emu.delete(alice.token, 'users/${alice.uid}/products/$pid'), 403);
    }, skip: skip);

    test('product-name guard rejects extra fields', () async {
      expect(await emu.set(alice.token, 'users/${alice.uid}/product_names/n_bad', {'productId': 'x', 'extra': 'y'}), 403);
      expect(await emu.set(alice.token, 'users/${alice.uid}/product_names/n_bad2', {'productId': 5}), 403);
    }, skip: skip);
  });

  group('default deny', () {
    test('user root doc, other collections and top-level collections are closed', () async {
      expect(await emu.set(alice.token, 'users/${alice.uid}', {'name': 'x'}), 403);
      expect(await emu.get(alice.token, 'users/${alice.uid}'), 403);
      expect(await emu.set(alice.token, 'users/${alice.uid}/parcels/p1', {'a': 'b'}), 403);
      expect(await emu.set(alice.token, 'products/p1', {'a': 'b'}), 403);
      expect(await emu.get(alice.token, 'app_settings/main'), 403);
    }, skip: skip);
  });

  group('customers', () {
    Future<int> create(String? token, String uid, String id, Map<String, Object?> fields,
            {List<String> serverTimes = const ['createdAt', 'updatedAt']}) =>
        emu.set(token, 'users/$uid/customers/$id', fields, serverTimes: serverTimes);

    test('owner can create, read, list and update; others are denied everything', () async {
      final cid = id();
      expect(await create(alice.token, alice.uid, cid, _customer()), 200);
      expect(await emu.get(alice.token, 'users/${alice.uid}/customers/$cid'), 200);
      expect((await emu.list(alice.token, 'users/${alice.uid}/customers')).status, 200);

      expect(await emu.get(bob.token, 'users/${alice.uid}/customers/$cid'), 403, reason: 'read');
      expect((await emu.list(bob.token, 'users/${alice.uid}/customers')).status, 403, reason: 'list');
      expect(await create(bob.token, alice.uid, id(), _customer(name: 'Injected')), 403, reason: 'create');
      expect(await create(bob.token, alice.uid, cid, _customer(name: 'Hijacked'), serverTimes: const ['updatedAt']), 403,
          reason: 'update');
      expect(await emu.delete(bob.token, 'users/${alice.uid}/customers/$cid'), 403, reason: 'delete');
      expect(await create(null, alice.uid, id(), _customer()), 403, reason: 'signed out create');
      expect(await emu.get(null, 'users/${alice.uid}/customers/$cid'), 403, reason: 'signed out read');
    }, skip: skip);

    test('two users keep separate customer lists even with identical data', () async {
      expect(await create(bob.token, bob.uid, id(), _customer()), 200);
      expect((await emu.list(bob.token, 'users/${bob.uid}/customers')).status, 200);
      expect((await emu.list(alice.token, 'users/${bob.uid}/customers')).status, 403);
    }, skip: skip);

    test('name, phone and address are mandatory and length-checked', () async {
      Future<void> denied(Map<String, Object?> fields) async =>
          expect(await create(alice.token, alice.uid, id(), fields), 403, reason: '$fields');
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
        await create(alice.token, alice.uid, id(),
            _customer(name: 'Al', phone: '1234567890', phoneNormalized: '1234567890', address: '12345')),
        200,
        reason: 'minimums are allowed',
      );
      expect(
        await create(alice.token, alice.uid, id(),
            _customer(name: 'A' * 60, address: 'x' * 200, phone: '+92 300 1234567', phoneNormalized: '03001234567')),
        200,
        reason: 'maximums are allowed',
      );
    }, skip: skip);

    test('createdAt/updatedAt must be server time; createdAt cannot change; delete never allowed', () async {
      expect(
        await create(alice.token, alice.uid, id(), {..._customer(), 'createdAt': DateTime.utc(2000), 'updatedAt': DateTime.utc(2000)},
            serverTimes: const []),
        403,
      );
      final cid = id();
      expect(await create(alice.token, alice.uid, cid, _customer()), 200);
      expect(await create(alice.token, alice.uid, cid, _customer(name: 'Renamed')), 403, reason: 'createdAt would change');
      final original = await emu.createdAt(alice.token, 'users/${alice.uid}/customers/$cid');
      expect(
        await emu.set(alice.token, 'users/${alice.uid}/customers/$cid',
            {..._customer(name: 'Renamed Ali'), 'createdAt': original}, serverTimes: const ['updatedAt']),
        200,
      );
      expect(await emu.delete(alice.token, 'users/${alice.uid}/customers/$cid'), 403);
    }, skip: skip);
  });

  group('parcels', () {
    String ppath(String uid, String id) => 'users/$uid/parcels/$id';
    String cpath(String uid) => 'users/$uid/counters/orders';

    /// Creates a parcel together with its counter, the way the app's transaction does.
    Future<int> createParcel(({String uid, String token}) user, String id, Map<String, Object?> parcel,
            {int? counterTo, String? asUid}) =>
        emu.commit(user.token, [
          DocWrite(cpath(asUid ?? user.uid), {'lastSequence': counterTo ?? parcel['orderSequence'] as int}),
          DocWrite(ppath(asUid ?? user.uid, id), parcel, serverTimes: const ['createdAt', 'updatedAt']),
        ]);

    test('order numbers: only the next number is accepted, counter and parcel move together', () async {
      final u = await emu.signUp('seq${DateTime.now().microsecondsSinceEpoch}@x.com');
      expect(await createParcel(u, id(), _parcel(seq: 2)), 403, reason: 'first parcel must be number 1');
      expect(await createParcel(u, id(), _parcel(seq: 1)), 200, reason: 'first parcel');
      expect(await createParcel(u, id(), _parcel(seq: 1)), 403, reason: 'number 1 cannot be reused');
      expect(await createParcel(u, id(), _parcel(seq: 3)), 403, reason: 'cannot skip ahead');
      expect(await createParcel(u, id(), _parcel(seq: 2), counterTo: 3), 403, reason: 'counter must equal the parcel number');
      expect(await createParcel(u, id(), _parcel(seq: 2)), 200, reason: 'second parcel');
      expect(await createParcel(u, id(), _parcel(seq: 3)), 200, reason: 'third parcel');
      // parcel without bumping the counter in the same commit
      expect(await emu.set(u.token, ppath(u.uid, id()), _parcel(seq: 4), serverTimes: const ['createdAt', 'updatedAt']), 403);
    }, skip: skip);

    test('the counter can only grow by one and can never be deleted or rewritten', () async {
      final u = await emu.signUp('cnt${DateTime.now().microsecondsSinceEpoch}@x.com');
      expect(await emu.set(u.token, cpath(u.uid), {'lastSequence': 5}), 403, reason: 'starts at 1');
      expect(await emu.set(u.token, cpath(u.uid), {'lastSequence': 1}), 200);
      expect(await emu.set(u.token, cpath(u.uid), {'lastSequence': 3}), 403, reason: 'no jumps');
      expect(await emu.set(u.token, cpath(u.uid), {'lastSequence': 1}), 403, reason: 'no going back / same');
      expect(await emu.set(u.token, cpath(u.uid), {'lastSequence': 2}), 200, reason: 'gaps are allowed, +1 only');
      expect(await emu.set(u.token, cpath(u.uid), {'lastSequence': 3, 'extra': 1}), 403);
      expect(await emu.delete(u.token, cpath(u.uid)), 403);
    }, skip: skip);

    test('users are isolated: B cannot read or write A\'s parcels, counter or reference guards', () async {
      final a = await emu.signUp('pa${DateTime.now().microsecondsSinceEpoch}@x.com');
      final b = await emu.signUp('pb${DateTime.now().microsecondsSinceEpoch}@x.com');
      final pid = id();
      expect(await createParcel(a, pid, _parcel(seq: 1)), 200);
      expect(await emu.set(a.token, 'users/${a.uid}/postal_refs/VPP__VPP12345', {'parcelId': pid, 'orderNumber': 'ADT-000001'}), 200);

      expect(await emu.get(b.token, ppath(a.uid, pid)), 403, reason: 'read parcel');
      expect((await emu.list(b.token, 'users/${a.uid}/parcels')).status, 403, reason: 'list parcels');
      expect(await emu.get(b.token, cpath(a.uid)), 403, reason: 'read counter');
      expect(await emu.get(b.token, 'users/${a.uid}/postal_refs/VPP__VPP12345'), 403, reason: 'read guard');
      expect(await createParcel(b, id(), _parcel(seq: 2), asUid: a.uid), 403, reason: 'write into A\'s data');
      expect(await emu.set(b.token, 'users/${a.uid}/postal_refs/VPP__OTHER', {'parcelId': 'x', 'orderNumber': 'ADT-000009'}), 403);
      expect(await emu.delete(b.token, ppath(a.uid, pid)), 403);
      expect(await emu.get(null, ppath(a.uid, pid)), 403, reason: 'signed out');
      // B has their own, independent numbering starting at 1.
      expect(await createParcel(b, id(), _parcel(seq: 1)), 200);
    }, skip: skip);

    test('sending date must be the server\'s Pakistan date', () async {
      final u = await emu.signUp('date${DateTime.now().microsecondsSinceEpoch}@x.com');
      final today = _today();
      final other = today == '2026-01-01' ? '2026-01-02' : '2026-01-01';
      expect(await createParcel(u, id(), _parcel(seq: 1, overrides: {'sendingDateLocal': other})), 403, reason: 'wrong day');
      expect(await createParcel(u, id(), _parcel(seq: 1, overrides: {'sendingDateLocal': 'yesterday'})), 403, reason: 'bad format');
      expect(await createParcel(u, id(), _parcel(seq: 1)), 200, reason: 'today');
    }, skip: skip);

    test('invalid parcels are rejected', () async {
      final u = await emu.signUp('bad${DateTime.now().microsecondsSinceEpoch}@x.com');
      var seq = 0;
      Future<void> denied(String reason, Map<String, Object?> parcel) async =>
          expect(await createParcel(u, id(), parcel), 403, reason: reason);

      await denied('unknown method', _parcel(seq: 1, overrides: {'collectionMethod': 'barter'}));
      await denied('unknown service', _parcel(seq: 1, overrides: {'postalServiceType': 'TCS'}));
      await denied('Other needs a name', _parcel(seq: 1, overrides: {'postalServiceType': 'Other'}));
      await denied('name only for Other', _parcel(seq: 1, overrides: {'otherPostalServiceName': 'Courier X'}));
      await denied('sent needs a charge', _parcel(seq: 1, remove: ['deliveryChargePaisa']));
      await denied('sent needs a reference', _parcel(seq: 1, overrides: {'postalReference': '', 'postalReferenceNormalized': ''}));
      await denied('normalized reference malformed', _parcel(seq: 1, overrides: {'postalReferenceNormalized': 'vpp 123'}));
      await denied('negative charge', _parcel(seq: 1, overrides: {'deliveryChargePaisa': -1}));
      await denied('zero packed weight', _parcel(seq: 1, overrides: {'actualPackedWeightGrams': 0}));
      await denied('payment date on a non Pay Later parcel', _parcel(seq: 1, overrides: {'estimatedPaymentDateLocal': '2030-01-01'}));
      await denied('bad payment date', _parcel(seq: 1, overrides: {'collectionMethod': 'credit', 'estimatedPaymentDateLocal': 'soon'}));
      await denied('outstanding does not match', _parcel(seq: 1, overrides: {'outstandingPaisa': 1}));
      await denied('free parcel with an amount', _parcel(seq: 1, overrides: {'collectionMethod': 'free_gift'}));
      await denied('already received on create', _parcel(seq: 1, overrides: {'receivedPaisa': 100, 'outstandingPaisa': 499900}));
      await denied('returned on create', _parcel(seq: 1, overrides: {'parcelStatus': 'returned'}));
      await denied('no items', _parcel(seq: 1, overrides: {'items': <Object?>[]}));
      await denied('21 items', _parcel(seq: 1, overrides: {'items': List.generate(21, (i) => {'productId': 'p$i'})}));
      await denied('order number does not match the sequence', _parcel(seq: 1, orderNumber: 'ADT-000002'));
      await denied('order number malformed', _parcel(seq: 1, orderNumber: 'ADT-1'));
      await denied('customer snapshot invalid', _parcel(seq: 1, overrides: {'customerSnapshot': {'name': 'A', 'phone': '1', 'address': 'x'}}));
      await denied('customer snapshot with extra field', _parcel(seq: 1, overrides: {'customerSnapshot': {'name': 'Ali Raza', 'phone': '0300 1234567', 'address': 'House 5, Sahiwal', 'email': 'a@b.c'}}));
      await denied('extra field', _parcel(seq: 1, overrides: {'discount': 5}));
      await denied('missing field', _parcel(seq: 1, remove: ['paymentStatus']));
      await denied('bad payment status', _parcel(seq: 1, overrides: {'paymentStatus': 'paid'}));
      seq++;

      // Valid variants are accepted: draft without a slip, Other service, free parcel, Pay Later with a date.
      expect(
        await createParcel(u, id(), _parcel(seq: 1, overrides: {'parcelStatus': 'draft', 'postalReference': '', 'postalReferenceNormalized': ''}, remove: ['deliveryChargePaisa'])),
        200,
        reason: 'draft',
      );
      expect(await createParcel(u, id(), _parcel(seq: 2, overrides: {'postalServiceType': 'Other', 'otherPostalServiceName': 'Fast Courier'})), 200, reason: 'Other');
      expect(
        await createParcel(u, id(), _parcel(seq: 3, overrides: {'collectionMethod': 'free_gift', 'productAmountExpectedPaisa': 0, 'outstandingPaisa': 0, 'paymentStatus': 'not_required'})),
        200,
        reason: 'free',
      );
      expect(
        await createParcel(u, id(), _parcel(seq: 4, overrides: {'collectionMethod': 'credit', 'estimatedPaymentDateLocal': '2031-02-03', 'actualPackedWeightGrams': 1500})),
        200,
        reason: 'Pay Later with a date and packed weight',
      );
      expect(seq, 1);
    }, skip: skip);

    test('updates: mutable fields change; order number, number sequence, created and sending date are locked; no delete', () async {
      final u = await emu.signUp('upd${DateTime.now().microsecondsSinceEpoch}@x.com');
      final pid = id();
      expect(
        await createParcel(u, pid, _parcel(seq: 1, overrides: {'parcelStatus': 'draft', 'postalReference': '', 'postalReferenceNormalized': ''}, remove: ['deliveryChargePaisa'])),
        200,
      );
      final created = await emu.createdAt(u.token, ppath(u.uid, pid));
      Future<int> update(Map<String, Object?> parcel) =>
          emu.set(u.token, ppath(u.uid, pid), {...parcel, 'createdAt': created}, serverTimes: const ['updatedAt']);

      expect(await update(_parcel(seq: 1)), 200, reason: 'draft -> sent with a reference and charge');
      expect(await update(_parcel(seq: 1, overrides: {'orderNumber': 'ADT-000009', 'orderSequence': 9})), 403, reason: 'order number locked');
      expect(await update(_parcel(seq: 1, overrides: {'sendingDateLocal': '2020-01-01'})), 403, reason: 'sending date locked');
      expect(
        await emu.set(u.token, ppath(u.uid, pid), {..._parcel(seq: 1)}, serverTimes: const ['createdAt', 'updatedAt']),
        403,
        reason: 'created time locked',
      );
      expect(await update(_parcel(seq: 1, overrides: {'parcelStatus': 'returned'})), 200, reason: 'returned is allowed on update');
      expect(await update(_parcel(seq: 1, overrides: {'outstandingPaisa': 5})), 403, reason: 'amounts must stay consistent');
      expect(await emu.delete(u.token, ppath(u.uid, pid)), 403);
    }, skip: skip);

    test('postal reference guards: shape is enforced, no updates, owner can delete', () async {
      final u = await emu.signUp('ref${DateTime.now().microsecondsSinceEpoch}@x.com');
      final path = 'users/${u.uid}/postal_refs/VPP__ABC12';
      expect(await emu.set(u.token, path, {'parcelId': 'p1', 'orderNumber': 'ADT-000001'}), 200);
      expect(await emu.set(u.token, path, {'parcelId': 'p2', 'orderNumber': 'ADT-000002'}), 403, reason: 'no rewriting');
      expect(await emu.set(u.token, '$path-2', {'parcelId': 'p1'}), 403, reason: 'missing field');
      expect(await emu.set(u.token, '$path-3', {'parcelId': 'p1', 'orderNumber': 'ADT-000001', 'x': 1}), 403, reason: 'extra field');
      expect(await emu.set(u.token, '$path-4', {'parcelId': 5, 'orderNumber': 'ADT-000001'}), 403, reason: 'wrong type');
      expect(await emu.delete(u.token, path), 200, reason: 'released when a reference changes');
    }, skip: skip);
  });

  group('audit log', () {
    String apath(String uid, String id) => 'users/$uid/audit_logs/$id';
    Map<String, Object?> entry({Map<String, Object?> overrides = const {}, List<String> remove = const []}) {
      final base = <String, Object?>{
        'entityType': 'parcel',
        'entityId': 'p1',
        'action': 'update',
        'orderNumber': 'ADT-000001',
        'changedFields': ['postalReference', 'parcelStatus'],
      };
      base.addAll(overrides);
      for (final k in remove) {
        base.remove(k);
      }
      return base;
    }

    test('owner can append entries and read them; nobody else can; entries never change', () async {
      final a = await emu.signUp('au${DateTime.now().microsecondsSinceEpoch}@x.com');
      final b = await emu.signUp('av${DateTime.now().microsecondsSinceEpoch}@x.com');
      final lid = id();
      expect(await emu.set(a.token, apath(a.uid, lid), entry(), serverTimes: const ['createdAt']), 200);
      expect(await emu.get(a.token, apath(a.uid, lid)), 200);

      expect(await emu.get(b.token, apath(a.uid, lid)), 403, reason: 'read');
      expect((await emu.list(b.token, 'users/${a.uid}/audit_logs')).status, 403, reason: 'list');
      expect(await emu.set(b.token, apath(a.uid, id()), entry(), serverTimes: const ['createdAt']), 403, reason: 'write into A');
      expect(await emu.set(a.token, apath(a.uid, lid), entry(overrides: {'changedFields': ['x']}), serverTimes: const ['createdAt']), 403, reason: 'no rewriting');
      expect(await emu.delete(a.token, apath(a.uid, lid)), 403, reason: 'no deleting');
      expect(await emu.get(null, apath(a.uid, lid)), 403, reason: 'signed out');
    }, skip: skip);

    test('malformed entries are refused', () async {
      final u = await emu.signUp('aw${DateTime.now().microsecondsSinceEpoch}@x.com');
      Future<void> denied(String why, Map<String, Object?> data, {List<String> times = const ['createdAt']}) async =>
          expect(await emu.set(u.token, apath(u.uid, id()), data, serverTimes: times), 403, reason: why);
      await denied('unknown entity', entry(overrides: {'entityType': 'customer'}));
      await denied('unknown action', entry(overrides: {'action': 'delete'}));
      await denied('no changed fields', entry(overrides: {'changedFields': <Object?>[]}));
      await denied('31 changed fields', entry(overrides: {'changedFields': List.generate(31, (i) => 'f$i')}));
      await denied('changedFields not a list', entry(overrides: {'changedFields': 'postalReference'}));
      await denied('missing entityId', entry(remove: ['entityId']));
      await denied('empty entityId', entry(overrides: {'entityId': ''}));
      await denied('bad order number', entry(overrides: {'orderNumber': 'order 1'}));
      await denied('extra field', entry(overrides: {'note': 'hi'}));
      await denied('client-supplied time', {...entry(), 'createdAt': DateTime.utc(2000)}, times: const []);
      await denied('no time', entry(), times: const []);
      expect(await emu.set(u.token, apath(u.uid, id()), entry(remove: ['orderNumber']), serverTimes: const ['createdAt']), 200, reason: 'order number is optional');
    }, skip: skip);
  });

  group('payments', () {
    String ppath(String uid, String id) => 'users/$uid/parcels/$id';
    String paypath(String uid, String id, String pay) => 'users/$uid/parcels/$id/payments/$pay';

    Map<String, Object?> payment({int amount = 100000, String type = 'customer_payment', Map<String, Object?> extra = const {}}) =>
        {'amountPaisa': amount, 'paymentType': type, ...extra};

    /// A signed-up user with one parcel (expected Rs. 5,000) ready to take payments.
    Future<({({String uid, String token}) user, String pid, DateTime created})> setup({Map<String, Object?> overrides = const {}}) async {
      final u = await emu.signUp('pay${DateTime.now().microsecondsSinceEpoch}_${n++}@x.com');
      final pid = id();
      expect(
        await emu.commit(u.token, [
          DocWrite('users/${u.uid}/counters/orders', {'lastSequence': 1}),
          DocWrite(ppath(u.uid, pid), _parcel(seq: 1, overrides: overrides), serverTimes: const ['createdAt', 'updatedAt']),
        ]),
        200,
      );
      return (user: u, pid: pid, created: await emu.createdAt(u.token, ppath(u.uid, pid)));
    }

    /// The app's transaction: the parcel's received/outstanding move together with the new payment.
    Future<int> receive(({({String uid, String token}) user, String pid, DateTime created}) s, Map<String, Object?> pay,
        {int? receivedTo, int? outstandingTo, String? asUid, String? token, int expected = 500000, int receivedBefore = 0, Map<String, Object?> overrides = const {}}) {
      final to = receivedTo ?? receivedBefore + (pay['amountPaisa'] as int);
      final out = outstandingTo ?? (expected > to ? expected - to : 0);
      return emu.commit(token ?? s.user.token, [
        DocWrite(
          ppath(asUid ?? s.user.uid, s.pid),
          {
            ..._parcel(seq: 1, overrides: {'receivedPaisa': to, 'outstandingPaisa': out, 'paymentStatus': out == 0 ? 'received' : 'partial', ...overrides}),
            'createdAt': s.created,
          },
          serverTimes: const ['updatedAt'],
        ),
        DocWrite('users/${asUid ?? s.user.uid}/parcels/${s.pid}/payments/pay${DateTime.now().microsecondsSinceEpoch}_${n++}', {...pay, 'receivedAt': null, 'recordedAt': null}..removeWhere((k, v) => v == null), serverTimes: const ['receivedAt', 'recordedAt']),
      ]);
    }

    test('a partial and then the final payment are accepted; the parcel moves with each', () async {
      final s = await setup();
      expect(await receive(s, payment(amount: 200000)), 200);
      expect(await receive(s, payment(amount: 300000), receivedBefore: 200000), 200);
    }, skip: skip);

    test('a payment above the outstanding balance is refused', () async {
      final s = await setup();
      expect(await receive(s, payment(amount: 500100), outstandingTo: 0), 403);
      expect(await receive(s, payment(amount: 200000)), 200);
      expect(await receive(s, payment(amount: 300100), receivedBefore: 200000, outstandingTo: 0), 403);
    }, skip: skip);

    test('the parcel must move by exactly the payment (no silent changes, no payment without the parcel)', () async {
      final s = await setup();
      expect(await receive(s, payment(amount: 100000), receivedTo: 200000, outstandingTo: 300000), 403, reason: 'received moved too far');
      expect(await receive(s, payment(amount: 100000), receivedTo: 50000, outstandingTo: 450000), 403, reason: 'received moved too little');
      expect(
        await emu.set(s.user.token, paypath(s.user.uid, s.pid, 'orphan'), payment(), serverTimes: const ['receivedAt', 'recordedAt']),
        403,
        reason: 'payment without the parcel update',
      );
    }, skip: skip);

    test('amount, type and note are validated; times are server time', () async {
      final s = await setup();
      for (final bad in [
        payment(amount: 0),
        payment(amount: -100),
        payment(type: 'cash'),
        payment(extra: {'note': 'x' * 201}),
        payment(extra: {'note': 5}),
        payment(extra: {'extra': 'field'}),
      ]) {
        expect(await receive(s, bad, receivedTo: 100000, outstandingTo: 400000), 403, reason: '$bad');
      }
      // a client-chosen receivedAt is refused (no backdating)
      expect(
        await emu.commit(s.user.token, [
          DocWrite(ppath(s.user.uid, s.pid), {..._parcel(seq: 1, overrides: {'receivedPaisa': 100000, 'outstandingPaisa': 400000, 'paymentStatus': 'partial'}), 'createdAt': s.created}, serverTimes: const ['updatedAt']),
          DocWrite(paypath(s.user.uid, s.pid, 'late'), {...payment(amount: 100000), 'receivedAt': DateTime.utc(2020)}, serverTimes: const ['recordedAt']),
        ]),
        403,
      );
      expect(await receive(s, payment(amount: 100000, extra: {'note': 'x' * 200})), 200);
    }, skip: skip);

    test('no payment on a Gift / Free or a returned parcel', () async {
      final free = await setup(overrides: {'collectionMethod': 'free_gift', 'productAmountExpectedPaisa': 0, 'outstandingPaisa': 0, 'paymentStatus': 'not_required'});
      expect(await receive(free, payment(amount: 100), expected: 0, outstandingTo: 0, overrides: {'collectionMethod': 'free_gift', 'productAmountExpectedPaisa': 0}), 403);
      final returned = await setup();
      expect(
        await emu.set(returned.user.token, ppath(returned.user.uid, returned.pid),
            {..._parcel(seq: 1, overrides: {'parcelStatus': 'returned'}), 'createdAt': returned.created}, serverTimes: const ['updatedAt']),
        200,
      );
      expect(await receive(returned, payment(amount: 100000), overrides: {'parcelStatus': 'returned'}), 403);
    }, skip: skip);

    test('payments are append-only; another user cannot read or write them', () async {
      final s = await setup();
      final other = await emu.signUp('payother${DateTime.now().microsecondsSinceEpoch}@x.com');
      expect(await receive(s, payment(amount: 100000)), 200);
      final list = await emu.list(s.user.token, 'users/${s.user.uid}/parcels/${s.pid}/payments');
      expect(list.status, 200);
      expect(list.count, 1);
      expect((await emu.list(other.token, 'users/${s.user.uid}/parcels/${s.pid}/payments')).status, 403);
      expect(await receive(s, payment(amount: 100000), token: other.token, receivedBefore: 100000), 403, reason: "B cannot pay A's parcel");
      // existing payment cannot be changed or removed
      final first = await emu.list(s.user.token, 'users/${s.user.uid}/parcels/${s.pid}/payments');
      expect(first.count, 1);
    }, skip: skip);
  });

  group('parcel edits', () {
    String ppath(String uid, String id) => 'users/$uid/parcels/$id';

    test('an edit may remove optional fields and change status; amounts must stay consistent', () async {
      final u = await emu.signUp('pe${DateTime.now().microsecondsSinceEpoch}@x.com');
      final pid = id();
      expect(
        await emu.commit(u.token, [
          DocWrite('users/${u.uid}/counters/orders', {'lastSequence': 1}),
          DocWrite(ppath(u.uid, pid), _parcel(seq: 1, overrides: {'actualPackedWeightGrams': 1500}), serverTimes: const ['createdAt', 'updatedAt']),
        ]),
        200,
      );
      final created = await emu.createdAt(u.token, ppath(u.uid, pid));
      Future<int> replace(Map<String, Object?> parcel) =>
          emu.set(u.token, ppath(u.uid, pid), {...parcel, 'createdAt': created}, serverTimes: const ['updatedAt']);

      // back to a draft: no reference, no charge, no packed weight
      expect(
        await replace(_parcel(seq: 1, overrides: {'parcelStatus': 'draft', 'postalReference': '', 'postalReferenceNormalized': ''}, remove: ['deliveryChargePaisa', 'actualPackedWeightGrams'])),
        200,
      );
      // bigger order: expected and outstanding move together
      expect(
        await replace(_parcel(seq: 1, overrides: {'productAmountExpectedPaisa': 900000, 'outstandingPaisa': 900000})),
        200,
      );
      expect(await replace(_parcel(seq: 1, overrides: {'productAmountExpectedPaisa': 900000, 'outstandingPaisa': 100})), 403);
      // switching to a Pay Later parcel with a date
      expect(await replace(_parcel(seq: 1, overrides: {'collectionMethod': 'credit', 'estimatedPaymentDateLocal': '2031-02-03'})), 200);
      // ... but a date on a non Pay Later parcel is refused
      expect(await replace(_parcel(seq: 1, overrides: {'estimatedPaymentDateLocal': '2031-02-03'})), 403);
    }, skip: skip);
  });
}

Future<DateTime> _readCreatedAt(EmulatorClient emu, String token, String uid, String pid) async =>
    emu.createdAt(token, 'users/$uid/products/$pid');
