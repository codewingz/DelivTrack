// Firestore security-rules tests (REST against the Auth + Firestore emulators, real ID tokens).
// Run:  firebase emulators:exec --only auth,firestore --project delivtrack-codewingz \
//         "flutter test test/rules"
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
}

Future<DateTime> _readCreatedAt(EmulatorClient emu, String token, String uid, String pid) async =>
    emu.createdAt(token, 'users/$uid/products/$pid');
