import 'package:deliv_track/features/parcels/domain/parcel.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _doc({int seq = 1}) => {
  'orderNumber': 'ADT-${seq.toString().padLeft(6, '0')}',
  'orderSequence': seq,
  'customerId': 'c1',
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
  'postalReference': 'VPP 12345',
  'deliveryChargePaisa': 15000,
  'sendingDateLocal': '2026-11-08',
  'productAmountExpectedPaisa': 500000,
  'receivedPaisa': 0,
  'outstandingPaisa': 500000,
  'paymentStatus': 'pending',
  'parcelStatus': 'sent',
};

void main() {
  group(
    'Parcel.readAll: one damaged document never hides the others (DT-009)',
    () {
      test('three valid documents are all read', () {
        final result = Parcel.readAll(
          {'a': _doc(seq: 3), 'b': _doc(seq: 2), 'c': _doc()}.entries,
        );
        expect(result.parcels.map((p) => p.id), ['a', 'b', 'c']);
        expect(result.unreadableIds, isEmpty);
      });

      test('two valid plus one with an unknown status: the valid ones stay, the bad one is reported by id', () {
        final result = Parcel.readAll(
          {
            'a': _doc(seq: 2),
            'bad': _doc()..['parcelStatus'] = 'on_hold',
            'c': _doc(seq: 3),
          }.entries,
        );
        expect(result.parcels.map((p) => p.id), ['a', 'c']);
        expect(result.unreadableIds, ['bad']);
      });

      for (final (name, change)
          in <(String, void Function(Map<String, dynamic>))>[
            ('missing items', (d) => d.remove('items')),
            ('items not a list', (d) => d['items'] = 'oops'),
            (
              'unknown collection method',
              (d) => d['collectionMethod'] = 'barter',
            ),
            ('unknown parcel status', (d) => d['parcelStatus'] = 'on_hold'),
            ('unknown payment status', (d) => d['paymentStatus'] = 'maybe'),
            ('missing customer snapshot', (d) => d.remove('customerSnapshot')),
            (
              'missing payment fields',
              (d) => d
                ..remove('receivedPaisa')
                ..remove('outstandingPaisa'),
            ),
            ('money as text', (d) => d['receivedPaisa'] = '100'),
            (
              'money with a fraction',
              (d) => d['productAmountExpectedPaisa'] = 500000.5,
            ),
            ('negative received money', (d) => d['receivedPaisa'] = -100),
            (
              'outstanding that does not follow from the amounts',
              (d) => d['outstandingPaisa'] = 5,
            ),
            (
              'order number of the wrong type',
              (d) => d['orderSequence'] = 'one',
            ),
          ]) {
        test('$name: not read, not turned into a valid amount', () {
          final doc = _doc();
          change(doc);
          expect(Parcel.tryFromMap('x', doc), isNull);
          final result = Parcel.readAll({'ok': _doc(), 'x': doc}.entries);
          expect(result.parcels.map((p) => p.id), ['ok']);
          expect(result.unreadableIds, ['x']);
        });
      }

      test(
        'documents from before the review/archive fields existed still read',
        () {
          final parcel = Parcel.tryFromMap('old', _doc());
          expect(parcel, isNotNull);
          expect(parcel!.isArchived, isFalse);
          expect(parcel.paymentReviewRequired, isFalse);
          expect(parcel.reviewResolution, isNull);
        },
      );
    },
  );
}
