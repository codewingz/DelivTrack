import 'package:deliv_track/features/customers/domain/customer.dart';
import 'package:deliv_track/features/parcels/domain/parcel_enums.dart';
import 'package:deliv_track/features/parcels/viewmodel/parcel_form_view_model.dart';
import 'package:deliv_track/features/products/domain/product.dart';
import 'package:flutter_test/flutter_test.dart';

const _ali = Customer(
  id: 'c1',
  name: 'Ali Raza',
  phone: '03001111111',
  address: 'House 5, Sahiwal',
);
const _mango = Product(
  id: 'p1',
  name: 'Mango Box',
  saleUnit: SaleUnit.perPiece,
  isActive: true,
);
const _fruits = Product(
  id: 'p2',
  name: 'Dry Fruits',
  saleUnit: SaleUnit.perKg,
  isActive: true,
);

void main() {
  test('starts with one empty row, nothing chosen, clean and a draft', () {
    final vm = ParcelFormViewModel();
    expect(vm.items, hasLength(1));
    expect(vm.isDirty, isFalse);
    expect(vm.status, ParcelStatus.draft);
    expect(vm.totalPaisa, 0);
    expect(vm.method, isNull);
    expect(vm.service, isNull);
  });

  group('postal service', () {
    test('defaults from the parcel type until the user picks one', () {
      final vm = ParcelFormViewModel();
      vm.setMethod(CollectionMethod.postalCollection);
      expect(vm.service, PostalService.vpp);
      vm.setMethod(CollectionMethod.advance);
      expect(vm.service, PostalService.vpl);
      vm.setService(PostalService.vpr);
      vm.setMethod(CollectionMethod.postalCollection);
      expect(vm.service, PostalService.vpr, reason: 'the user chose it');
    });

    test('leaving "Other" forgets the typed name', () {
      final vm = ParcelFormViewModel();
      vm.setService(PostalService.other);
      vm.setOtherServiceName('Fast Courier');
      vm.setService(PostalService.vpl);
      expect(vm.otherServiceName, isEmpty);
    });
  });

  group('Pay Later date', () {
    test('is dropped when the type is not Pay Later', () {
      final vm = ParcelFormViewModel();
      vm.setMethod(CollectionMethod.payLater);
      vm.setPayDate('2030-01-01');
      vm.setMethod(CollectionMethod.advance);
      expect(vm.payDate, isNull);
    });
  });

  group('status', () {
    test('sent only with a valid reference AND a delivery charge', () {
      final vm = ParcelFormViewModel();
      vm.setReference('VPP 12345');
      expect(vm.status, ParcelStatus.draft);
      vm.setCharge(0);
      expect(vm.status, ParcelStatus.sent);
      vm.setReference('AB');
      expect(
        vm.status,
        ParcelStatus.draft,
        reason: 'an invalid reference does not count',
      );
      vm.setReference('VPP 12345');
      vm.setCharge(null);
      expect(vm.status, ParcelStatus.draft);
    });
  });

  group('rows and totals', () {
    ParcelFormViewModel withTwoRows() {
      final vm = ParcelFormViewModel()
        ..setMethod(CollectionMethod.postalCollection);
      vm.setProduct(vm.items[0], _mango);
      vm.setQuantity(vm.items[0], 3);
      vm.setPrice(vm.items[0], 250000);
      vm.addItem();
      vm.setProduct(vm.items[1], _fruits);
      vm.setWeight(vm.items[1], 1250);
      vm.setPrice(vm.items[1], 80000);
      return vm;
    }

    test(
      'lines add up, incomplete lines are ignored, free parcels total zero',
      () {
        final vm = withTwoRows();
        expect(vm.lineTotalPaisa(vm.items[0]), 750000);
        expect(vm.lineTotalPaisa(vm.items[1]), 100000);
        expect(vm.totalPaisa, 850000);
        vm.setPrice(vm.items[1], null);
        expect(vm.totalPaisa, 750000);
        vm.setMethod(CollectionMethod.giftFree);
        expect(vm.totalPaisa, 0);
        expect(vm.lineTotalPaisa(vm.items[0]), isNull);
      },
    );

    test(
      'rows have stable keys, the last row cannot be removed, at most 20 rows',
      () {
        final vm = ParcelFormViewModel();
        final first = vm.items.first;
        vm.removeItem(first);
        expect(vm.items, hasLength(1));
        for (var i = 0; i < 25; i++) {
          vm.addItem();
        }
        expect(vm.items, hasLength(20));
        expect(vm.canAddItem, isFalse);
        expect(vm.items.map((i) => i.key).toSet(), hasLength(20));
        vm.removeItem(vm.items[5]);
        expect(vm.canAddItem, isTrue);
        expect(vm.items.first, same(first));
      },
    );

    test('only the repeat of a product is flagged as duplicate', () {
      final vm = ParcelFormViewModel();
      vm.addItem();
      vm.setProduct(vm.items[0], _mango);
      expect(vm.isDuplicate(vm.items[0]), isFalse);
      vm.setProduct(vm.items[1], _mango);
      expect(vm.isDuplicate(vm.items[0]), isFalse);
      expect(vm.isDuplicate(vm.items[1]), isTrue);
      vm.setProduct(vm.items[1], _fruits);
      expect(vm.isDuplicate(vm.items[1]), isFalse);
    });

    test('changing to a product with another unit discards the typed amount, same unit keeps it', () {
      final vm = ParcelFormViewModel();
      vm.setProduct(vm.items[0], _mango);
      vm.setQuantity(vm.items[0], 4);
      vm.setProduct(
        vm.items[0],
        const Product(
          id: 'p9',
          name: 'Honey',
          saleUnit: SaleUnit.perPiece,
          isActive: true,
        ),
      );
      expect(vm.items[0].quantity, 4);
      vm.setProduct(vm.items[0], _fruits);
      expect(vm.items[0].quantity, isNull);
      expect(vm.items[0].weightGrams, isNull);
    });
  });

  test('isDirty becomes true as soon as anything is entered', () {
    final vm = ParcelFormViewModel();
    expect(vm.isDirty, isFalse);
    vm.setReference('V');
    expect(vm.isDirty, isTrue);
    expect((ParcelFormViewModel()..addItem()).isDirty, isTrue);
    expect((ParcelFormViewModel()..setCustomer(_ali)).isDirty, isTrue);
  });

  group('buildInput', () {
    test('turns the form into a ParcelInput; free parcels get zero prices; "Other" carries the name', () {
      final vm = ParcelFormViewModel()
        ..setCustomer(_ali)
        ..setMethod(CollectionMethod.giftFree)
        ..setService(PostalService.other)
        ..setOtherServiceName('Fast Courier')
        ..setReference('XYZ 99999')
        ..setCharge(12000)
        ..setPackedWeight(2500);
      vm.setProduct(vm.items[0], _mango);
      vm.setQuantity(vm.items[0], 2);
      vm.setPrice(vm.items[0], 99999);
      final input = vm.buildInput();
      expect(input.customer.id, 'c1');
      expect(input.method, CollectionMethod.giftFree);
      expect(input.service, PostalService.other);
      expect(input.otherServiceName, 'Fast Courier');
      expect(input.deliveryChargePaisa, 12000);
      expect(input.packedWeightGrams, 2500);
      expect(input.status, ParcelStatus.sent);
      expect(input.items.single.unitPricePaisa, 0);
      expect(input.expectedPaisa, 0);
      expect(input.problems(), isEmpty);
    });

    test('a per-kg line uses grams', () {
      final vm = ParcelFormViewModel()
        ..setCustomer(_ali)
        ..setMethod(CollectionMethod.advance);
      vm.setProduct(vm.items[0], _fruits);
      vm.setWeight(vm.items[0], 333);
      vm.setPrice(vm.items[0], 10010);
      final input = vm.buildInput();
      expect(input.items.single.weightGrams, 333);
      expect(input.items.single.lineTotalPaisa, 3333);
      expect(input.service, PostalService.vpl);
      expect(input.otherServiceName, isNull);
    });
  });
}
