import 'package:deliv_track/core/errors/app_failure.dart';
import 'package:deliv_track/features/products/domain/product.dart';
import 'package:deliv_track/features/products/viewmodel/product_list_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/fake_product_repository.dart';

Product _p(String id, String name, {bool active = true, SaleUnit unit = SaleUnit.perPiece}) =>
    Product(id: id, name: name, saleUnit: unit, isActive: active);

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('starts loading, then shows products of the Active segment sorted by name', () async {
    final repo = FakeProductRepository(initial: [_p('1', 'Mango'), _p('2', 'Apple'), _p('3', 'Old', active: false)]);
    final vm = ProductListViewModel(repo);
    expect(vm.isLoading, isTrue);
    await _settle();
    expect(vm.isLoading, isFalse);
    expect(vm.visible.map((p) => p.name), ['Apple', 'Mango']);
    vm.dispose();
  });

  test('segment switch shows archived products', () async {
    final vm = ProductListViewModel(FakeProductRepository(initial: [_p('1', 'Mango'), _p('3', 'Old', active: false)]));
    await _settle();
    vm.setSegment(ProductSegment.archived);
    expect(vm.visible.map((p) => p.name), ['Old']);
    vm.dispose();
  });

  test('search matches anywhere in the name, case-insensitively, within the segment', () async {
    final vm = ProductListViewModel(FakeProductRepository(initial: [
      _p('1', 'Raw Mango'),
      _p('2', 'Mango Pickle'),
      _p('3', 'Apple'),
      _p('4', 'Mango Old', active: false),
    ]));
    await _settle();
    vm.setQuery('  mANgo ');
    expect(vm.visible.map((p) => p.name), ['Mango Pickle', 'Raw Mango']);
    vm.setQuery('zzz');
    expect(vm.visible, isEmpty);
    expect(vm.hasNoItems, isFalse, reason: 'no matches is not the same as no products');
    vm.dispose();
  });

  test('empty account reports hasNoItems', () async {
    final vm = ProductListViewModel(FakeProductRepository());
    await _settle();
    expect(vm.hasNoItems, isTrue);
    expect(vm.visible, isEmpty);
    vm.dispose();
  });

  test('live updates arrive without reloading', () async {
    final repo = FakeProductRepository();
    final vm = ProductListViewModel(repo);
    await _settle();
    await repo.add(name: 'Mango', saleUnit: SaleUnit.perKg);
    await _settle();
    expect(vm.visible.single.name, 'Mango');
    vm.dispose();
  });

  test('stream error shows a message; retry resubscribes and recovers', () async {
    final repo = FakeProductRepository(initial: [_p('1', 'Mango')]);
    final vm = ProductListViewModel(repo);
    await _settle();
    repo.emitError(const AppFailure('No internet connection.'));
    await _settle();
    expect(vm.errorMessage, 'No internet connection.');
    vm.retry();
    expect(vm.isLoading, isTrue);
    await _settle();
    expect(vm.errorMessage, isNull);
    expect(vm.visible.single.name, 'Mango');
    vm.dispose();
  });

  test('unknown stream errors get a generic message (no raw exception text)', () async {
    final repo = FakeProductRepository();
    final vm = ProductListViewModel(repo);
    await _settle();
    repo.emitError(StateError('boom internal'));
    await _settle();
    expect(vm.errorMessage, isNot(contains('boom')));
    expect(vm.errorMessage, isNotNull);
    vm.dispose();
  });

  test('setActive archives and restores; failure returns the message', () async {
    final repo = FakeProductRepository(initial: [_p('1', 'Mango')]);
    final vm = ProductListViewModel(repo);
    await _settle();
    expect(await vm.setActive(vm.visible.single, false), isNull);
    await _settle();
    expect(vm.visible, isEmpty);
    vm.setSegment(ProductSegment.archived);
    expect(await vm.setActive(vm.visible.single, true), isNull);

    repo.failure = const AppFailure('No internet connection.');
    expect(await vm.setActive(_p('1', 'Mango'), false), 'No internet connection.');
    vm.dispose();
  });

  test('dispose cancels the subscription (no updates after dispose)', () async {
    final repo = FakeProductRepository();
    final vm = ProductListViewModel(repo);
    await _settle();
    vm.dispose();
    await repo.add(name: 'Late', saleUnit: SaleUnit.perPiece); // would throw if notifying a disposed VM
    await _settle();
  });
}
