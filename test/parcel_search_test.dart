import 'package:deliv_track/features/parcels/domain/parcel_enums.dart';
import 'package:deliv_track/features/parcels/domain/parcel_item.dart';
import 'package:deliv_track/features/parcels/domain/parcel_search.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/fake_parcel_repository.dart';

const _today = '2026-11-10';

void main() {
  group('parcelMatchesQuery', () {
    final parcel = testParcel(
      sequence: 42,
      customerName: 'Ali Raza',
      customerPhone: '+92 300 1111111',
      reference: 'VPP 12345',
      items: [
        ParcelItem.pieces(productId: 'p1', productName: 'Mango Box', quantity: 1, unitPricePaisa: 100000),
        ParcelItem.pieces(productId: 'p2', productName: 'Dry Fruits', quantity: 1, unitPricePaisa: 100000),
      ],
    );

    test('empty text matches everything', () {
      expect(parcelMatchesQuery(parcel, ''), isTrue);
      expect(parcelMatchesQuery(parcel, '   '), isTrue);
    });

    test('order number: whole, partial and just the digits', () {
      for (final query in ['ADT-000042', 'adt-000042', 'adt', '000042', '42', 'T-0000']) {
        expect(parcelMatchesQuery(parcel, query), isTrue, reason: query);
      }
      expect(parcelMatchesQuery(parcel, 'ADT-000043'), isFalse);
    });

    test('postal reference: any part, spaces and case ignored', () {
      for (final query in ['VPP 12345', 'vpp12345', '12345', 'pp 123', '2345']) {
        expect(parcelMatchesQuery(parcel, query), isTrue, reason: query);
      }
      expect(parcelMatchesQuery(parcel, 'VPL 12345'), isFalse);
    });

    test('customer name: any part, any case, extra spaces', () {
      for (final query in ['Ali', 'raza', 'ali raza', '  ALI   RAZA ', 'i Ra']) {
        expect(parcelMatchesQuery(parcel, query), isTrue, reason: query);
      }
      expect(parcelMatchesQuery(parcel, 'Sara'), isFalse);
    });

    test('product name on any line of the parcel', () {
      expect(parcelMatchesQuery(parcel, 'mango'), isTrue);
      expect(parcelMatchesQuery(parcel, 'FRUITS'), isTrue);
      expect(parcelMatchesQuery(parcel, 'honey'), isFalse);
    });

    test('phone number in any written form; short digit strings do not match phones', () {
      for (final query in ['0300 1111111', '+92 300 1111111', '03001111111', '300111']) {
        expect(parcelMatchesQuery(parcel, query), isTrue, reason: query);
      }
      expect(parcelMatchesQuery(parcel, '0399'), isFalse);
      expect(parcelMatchesQuery(testParcel(customerPhone: '0300 1299567', reference: 'ZZ 11111'), '99'), isFalse, reason: 'two digits are too few for a phone search');
    });

    test('the address is not searched', () {
      expect(parcelMatchesQuery(parcel, 'Sahiwal'), isFalse);
    });
  });

  group('ParcelFilters', () {
    test('no filters match everything and count as zero', () {
      expect(ParcelFilters.none.isEmpty, isTrue);
      expect(ParcelFilters.none.matches(testParcel(), _today), isTrue);
    });

    test('sending date range is inclusive on both ends and may be open', () {
      final p = testParcel(sendingDate: '2026-11-05');
      bool ok(String? from, String? to) => ParcelFilters(sendingFrom: from, sendingTo: to).matches(p, _today);
      expect(ok('2026-11-05', '2026-11-05'), isTrue);
      expect(ok('2026-11-06', null), isFalse);
      expect(ok(null, '2026-11-04'), isFalse);
      expect(ok('2026-11-01', '2026-11-30'), isTrue);
      expect(ok(null, null), isTrue);
    });

    test('payment received dates use the dates the parcel received money on', () {
      final p = testParcel();
      bool ok(String? from, String? to, Set<String> dates) => ParcelFilters(receivedFrom: from, receivedTo: to).matches(p, _today, paymentDates: dates);
      expect(ok('2026-11-08', '2026-11-09', {'2026-11-09'}), isTrue);
      expect(ok('2026-11-08', '2026-11-09', {'2026-11-10'}), isFalse);
      expect(ok('2026-11-08', null, {'2026-11-01', '2026-11-12'}), isTrue, reason: 'any one date inside the range is enough');
      expect(ok('2026-11-08', null, {}), isFalse, reason: 'a parcel that never received money cannot match');
    });

    test('product by id, on any line', () {
      final p = testParcel(items: [
        ParcelItem.pieces(productId: 'p1', productName: 'Mango Box', quantity: 1, unitPricePaisa: 100000),
        ParcelItem.pieces(productId: 'p2', productName: 'Honey', quantity: 1, unitPricePaisa: 100000),
      ]);
      expect(const ParcelFilters(productId: 'p2').matches(p, _today), isTrue);
      expect(const ParcelFilters(productId: 'p3').matches(p, _today), isFalse);
    });

    test('choices inside a group are alternatives; different groups all have to match', () {
      final p = testParcel(method: CollectionMethod.advance, status: ParcelStatus.sent, received: 100000);
      expect(ParcelFilters(methods: {CollectionMethod.advance, CollectionMethod.payLater}).matches(p, _today), isTrue);
      expect(ParcelFilters(methods: {CollectionMethod.payLater}).matches(p, _today), isFalse);
      expect(ParcelFilters(payments: {PaymentFilter.pending, PaymentFilter.partial}).matches(p, _today), isTrue);
      expect(ParcelFilters(statuses: {ParcelStatus.returned}).matches(p, _today), isFalse);
      expect(ParcelFilters(methods: {CollectionMethod.advance}, payments: {PaymentFilter.partial}, statuses: {ParcelStatus.sent}).matches(p, _today), isTrue);
      expect(ParcelFilters(methods: {CollectionMethod.advance}, payments: {PaymentFilter.received}).matches(p, _today), isFalse);
    });

    test('Overdue is a payment state of its own: Pay Later, owing, past date, not returned', () {
      const overdue = ParcelFilters(payments: {PaymentFilter.overdue});
      expect(overdue.matches(testParcel(method: CollectionMethod.payLater, payDate: '2026-11-09'), _today), isTrue);
      expect(overdue.matches(testParcel(method: CollectionMethod.payLater, payDate: '2026-11-10'), _today), isFalse, reason: 'due today');
      expect(overdue.matches(testParcel(method: CollectionMethod.payLater), _today), isFalse, reason: 'no date');
      expect(overdue.matches(testParcel(method: CollectionMethod.payLater, payDate: '2026-11-01', received: 500000), _today), isFalse);
      expect(overdue.matches(testParcel(method: CollectionMethod.payLater, payDate: '2026-11-01', status: ParcelStatus.returned), _today), isFalse);
      expect(overdue.matches(testParcel(method: CollectionMethod.postalCollection, payDate: '2026-11-01'), _today), isFalse);
    });

    test('Not required matches Gift / Free parcels', () {
      expect(const ParcelFilters(payments: {PaymentFilter.notRequired}).matches(testParcel(method: CollectionMethod.giftFree), _today), isTrue);
    });

    test('activeCount counts groups, not choices; copyWith can clear a value', () {
      const f = ParcelFilters(
        sendingFrom: '2026-11-01',
        sendingTo: '2026-11-30',
        productId: 'p1',
        productName: 'Mango Box',
        methods: {CollectionMethod.advance, CollectionMethod.payLater},
      );
      expect(f.activeCount, 3);
      final cleared = f.copyWith(sendingFrom: null, sendingTo: null, productId: null, productName: null);
      expect(cleared.activeCount, 1);
      expect(cleared.hasSendingDates, isFalse);
      expect(f.copyWith(methods: {}).activeCount, 2);
    });

    test('a range that ends before it starts is a problem', () {
      expect(const ParcelFilters(sendingFrom: '2026-11-10', sendingTo: '2026-11-01').problem, isNotNull);
      expect(const ParcelFilters(receivedFrom: '2026-11-10', receivedTo: '2026-11-01').problem, isNotNull);
      expect(const ParcelFilters(sendingFrom: '2026-11-01', sendingTo: '2026-11-10').problem, isNull);
      expect(const ParcelFilters(sendingFrom: '2026-11-10').problem, isNull);
    });
  });
}
