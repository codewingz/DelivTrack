import 'package:deliv_track/features/customers/domain/customer.dart';
import 'package:deliv_track/features/parcels/domain/parcel_enums.dart';
import 'package:deliv_track/features/parcels/domain/parcel_input.dart';
import 'package:deliv_track/features/parcels/domain/parcel_item.dart';
import 'package:deliv_track/utils/postal_reference.dart';
import 'package:deliv_track/features/products/domain/product.dart';
import 'package:flutter_test/flutter_test.dart';

const _customer = Customer(
  id: 'c1',
  name: 'Ali Raza',
  phone: '03001234567',
  address: 'House 5, Sahiwal',
);

ParcelItem _pieces({String id = 'p1', int qty = 2, int price = 250000}) =>
    ParcelItem.pieces(
      productId: id,
      productName: 'Mango Box',
      quantity: qty,
      unitPricePaisa: price,
    );

ParcelInput _input({
  List<ParcelItem>? items,
  CollectionMethod method = CollectionMethod.postalCollection,
  String reference = 'VPP 12345',
  int? charge = 15000,
  String? payDate,
  ParcelStatus status = ParcelStatus.sent,
}) => ParcelInput(
  customer: _customer,
  items: items ?? [_pieces()],
  method: method,
  postalReference: reference,
  deliveryChargePaisa: charge,
  estimatedPaymentDate: payDate,
  status: status,
);

void main() {
  group('ParcelItem', () {
    test('per-piece line total is quantity x price', () {
      final item = _pieces(qty: 3, price: 250050);
      expect(item.lineTotalPaisa, 750150);
      expect(item.saleUnit, SaleUnit.perPiece);
      expect(item.amountLabel, '3 pieces');
      expect(_pieces(qty: 1).amountLabel, '1 piece');
    });

    test('other counted units use their own words and a price label', () {
      ParcelItem boxes(int qty) => ParcelItem.pieces(
        productId: 'p4',
        productName: 'Soap Box',
        quantity: qty,
        unitPricePaisa: 10000,
        saleUnit: SaleUnit.perBox,
      );
      expect(boxes(1).amountLabel, '1 box');
      expect(boxes(3).amountLabel, '3 boxes');
      expect(boxes(3).lineTotalPaisa, 30000);
      expect(boxes(3).priceLabel, 'per box');
      expect(boxes(3).toMap()['saleUnit'], 'per_box');
      final dozens = ParcelItem.pieces(
        productId: 'p6',
        productName: 'Eggs',
        quantity: 2,
        unitPricePaisa: 100,
        saleUnit: SaleUnit.perDozen,
      );
      expect(dozens.amountLabel, '2 dozen');
      expect(_pieces().priceLabel, 'each');
      expect(
        ParcelItem.fromMap({...boxes(2).toMap()}).saleUnit,
        SaleUnit.perBox,
      );
    });

    test(
      'litres are measured like kg: thousandths, singular only for exactly one',
      () {
        ParcelItem litres(int thousandths) => ParcelItem.weight(
          productId: 'p5',
          productName: 'Milk',
          weightGrams: thousandths,
          unitPricePaisa: 20000,
          saleUnit: SaleUnit.perLitre,
        );
        expect(litres(1500).amountLabel, '1.5 litres');
        expect(litres(1000).amountLabel, '1 litre');
        expect(litres(250).amountLabel, '0.25 litres');
        expect(litres(1500).lineTotalPaisa, 30000);
        expect(litres(1500).priceLabel, 'per litre');
        expect(litres(1500).toMap()['saleUnit'], 'per_litre');
      },
    );

    test('per-kg line total uses grams and rounds half up', () {
      final item = ParcelItem.weight(
        productId: 'p2',
        productName: 'Dry Fruits',
        weightGrams: 1250,
        unitPricePaisa: 80000,
      );
      expect(item.lineTotalPaisa, 100000);
      expect(item.amountLabel, '1.25 kg');
      expect(item.saleUnit, SaleUnit.perKg);
    });

    test(
      'toMap / fromMap round-trip and omit the unit that does not apply',
      () {
        final pieces = _pieces();
        expect(pieces.toMap().containsKey('weightGrams'), isFalse);
        final kg = ParcelItem.weight(
          productId: 'p2',
          productName: 'Dry Fruits',
          weightGrams: 500,
          unitPricePaisa: 10000,
        );
        expect(kg.toMap().containsKey('quantity'), isFalse);
        for (final item in [pieces, kg]) {
          final back = ParcelItem.fromMap(item.toMap());
          expect(back.productId, item.productId);
          expect(back.saleUnit, item.saleUnit);
          expect(back.quantity, item.quantity);
          expect(back.weightGrams, item.weightGrams);
          expect(back.lineTotalPaisa, item.lineTotalPaisa);
        }
      },
    );
  });

  group('expected amount', () {
    test('sums the lines', () {
      final input = _input(
        items: [
          _pieces(id: 'a'),
          _pieces(id: 'b', qty: 1, price: 100),
        ],
      );
      expect(input.expectedPaisa, 500000 + 100);
    });

    test('free / gift parcels expect nothing whatever the prices say', () {
      expect(_input(method: CollectionMethod.giftFree).expectedPaisa, 0);
    });
  });

  group('postal reference', () {
    test(
      'normalize: no spaces, upper case',
      () => expect(normalizePostalReference(' vpp 123/45-x '), 'VPP123/45-X'),
    );
    test('valid: 5-30 of letters, digits, - and /', () {
      for (final ok in ['VPP12', 'vpp 12345', 'VPL-2026/0042', 'A' * 30]) {
        expect(isValidPostalReference(ok), isTrue, reason: ok);
      }
      for (final bad in [
        '',
        'ABCD',
        'A' * 31,
        'VPP#1234',
        'VPP_1234',
        'وی پی پی 123',
      ]) {
        expect(isValidPostalReference(bad), isFalse, reason: bad);
      }
    });
  });

  group('defaults and enums', () {
    test('Pay Later is stored as "credit" but shown as "Pay Later"', () {
      expect(CollectionMethod.payLater.value, 'credit');
      expect(CollectionMethod.payLater.label, 'Pay Later');
      expect(CollectionMethod.fromValue('credit'), CollectionMethod.payLater);
    });

    test('unknown stored values fail loudly', () {
      expect(() => CollectionMethod.fromValue('x'), throwsStateError);
      expect(() => ParcelStatus.fromValue('x'), throwsStateError);
      expect(() => PaymentStatus.fromValue('x'), throwsStateError);
    });
  });

  group('ParcelInput.problems', () {
    test(
      'a complete sent parcel is valid',
      () => expect(_input().problems(today: '2026-11-07'), isEmpty),
    );

    test('a draft needs neither reference nor charge', () {
      expect(
        _input(
          status: ParcelStatus.draft,
          reference: '',
          charge: null,
        ).problems(),
        isEmpty,
      );
    });

    test('items: at least one, at most 20, no product twice', () {
      expect(
        _input(items: []).problems(),
        contains('Add at least one product.'),
      );
      expect(
        _input(items: [for (var i = 0; i < 21; i++) _pieces(id: 'p$i')])
            .problems(),
        contains('A parcel can have at most 20 products.'),
      );
      expect(
        _input(items: [for (var i = 0; i < 20; i++) _pieces(id: 'p$i')])
            .problems(),
        isEmpty,
      );
      expect(
        _input(items: [_pieces(), _pieces()]).problems(),
        contains('The same product is added twice.'),
      );
    });

    test('prices: every line needs one, unless the parcel is a gift', () {
      expect(
        _input(items: [_pieces(price: 0)]).problems(),
        contains('Every product needs an agreed price.'),
      );
      expect(
        _input(
          items: [_pieces(price: 0)],
          method: CollectionMethod.giftFree,
        ).problems(),
        isEmpty,
      );
    });

    test('a paid parcel whose total rounds to zero is rejected', () {
      final tiny = ParcelItem.weight(
        productId: 'p',
        productName: 'Dust',
        weightGrams: 1,
        unitPricePaisa: 499,
      );
      expect(tiny.lineTotalPaisa, 0);
      expect(
        _input(items: [tiny]).problems(),
        contains('The products total must be above zero.'),
      );
    });

    test('any courier: only the tracking number is needed and checked', () {
      expect(_input().problems(), isEmpty);
      expect(_input(reference: 'TCS 8800 1234').problems(), isEmpty);
      expect(
        _input(reference: 'AB').problems(),
        contains('Tracking number is not valid.'),
      );
      expect(
        _input(reference: '').problems(),
        contains('A sent parcel needs its tracking number.'),
      );
    });

    test('a sent parcel needs reference and charge; an invalid reference is refused', () {
      expect(
        _input(reference: '', charge: 15000).problems(),
        contains('A sent parcel needs its tracking number.'),
      );
      expect(
        _input(charge: null).problems(),
        contains('A sent parcel needs its delivery charge.'),
      );
      expect(
        _input(reference: 'VPP#1').problems(),
        contains('Tracking number is not valid.'),
      );
      expect(
        _input(charge: 0).problems(),
        isEmpty,
        reason: 'a zero charge is a valid charge',
      );
    });

    test('a new parcel cannot start as returned', () {
      expect(
        _input(status: ParcelStatus.returned).problems(),
        contains('A new parcel cannot start as returned.'),
      );
    });

    test('payment date: Pay Later only, not in the past', () {
      expect(
        _input(payDate: '2026-12-01').problems(),
        contains('A payment date is only for Pay Later parcels.'),
      );
      final payLater = _input(
        method: CollectionMethod.payLater,
        payDate: '2026-11-06',
      );
      expect(
        payLater.problems(today: '2026-11-07'),
        contains('The payment date cannot be in the past.'),
      );
      expect(
        _input(
          method: CollectionMethod.payLater,
          payDate: '2026-11-07',
        ).problems(today: '2026-11-07'),
        isEmpty,
      );
      expect(
        _input(method: CollectionMethod.payLater).problems(today: '2026-11-07'),
        isEmpty,
        reason: 'the date is optional',
      );
    });
  });
}
