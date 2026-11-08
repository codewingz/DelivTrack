import 'package:deliv_track/core/errors/app_failure.dart';
import 'package:deliv_track/features/customers/domain/customer.dart';
import 'package:deliv_track/features/customers/viewmodel/customer_list_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_customer_repository.dart';
import 'helpers/fake_parcel_repository.dart';

Customer _c(String id, String name, String phone) =>
    Customer(id: id, name: name, phone: phone, address: 'Some address 1');

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('loading, then customers sorted by name', () async {
    final vm = CustomerListViewModel(
      FakeCustomerRepository(
        initial: [
          _c('1', 'Zara', '03001111111'),
          _c('2', 'Ali', '03002222222'),
        ],
      ),
      FakeParcelRepository(),
    );
    expect(vm.isLoading, isTrue);
    await _settle();
    expect(vm.isLoading, isFalse);
    expect(vm.visible.map((c) => c.name), ['Ali', 'Zara']);
    vm.dispose();
  });

  test('search matches names anywhere, case-insensitively', () async {
    final vm = CustomerListViewModel(
      FakeCustomerRepository(
        initial: [
          _c('1', 'Muhammad Ali', '03001111111'),
          _c('2', 'Sara', '03002222222'),
        ],
      ),
      FakeParcelRepository(),
    );
    await _settle();
    vm.setQuery('  aLI ');
    expect(vm.visible.map((c) => c.name), ['Muhammad Ali']);
    vm.dispose();
  });

  test(
    'search matches phone digits typed in any format, including +92',
    () async {
      final vm = CustomerListViewModel(
        FakeCustomerRepository(
          initial: [
            _c('1', 'Ali', '+92 300 1111111'),
            _c('2', 'Sara', '0300-2222222'),
          ],
        ),
        FakeParcelRepository(),
      );
      await _settle();
      vm.setQuery('1111');
      expect(vm.visible.map((c) => c.name), ['Ali']);
      vm.setQuery('0300 222');
      expect(vm.visible.map((c) => c.name), ['Sara']);
      vm.setQuery('03001111111');
      expect(vm.visible.map((c) => c.name), ['Ali']);
      vm.setQuery(
        '+92 300 111',
      ); // regression: country-code search must match stored 0300… numbers
      expect(vm.visible.map((c) => c.name), ['Ali']);
      vm.setQuery('+92 300 22');
      expect(vm.visible.map((c) => c.name), ['Sara']);
      vm.setQuery('zzz');
      expect(vm.visible, isEmpty);
      expect(
        vm.hasNoItems,
        isFalse,
        reason: 'no matches is not the same as no customers',
      );
      vm.dispose();
    },
  );

  test('letters in the query never match phone numbers by accident', () async {
    final vm = CustomerListViewModel(
      FakeCustomerRepository(initial: [_c('1', 'Ali', '03001111111')]),
      FakeParcelRepository(),
    );
    await _settle();
    vm.setQuery('abc');
    expect(vm.visible, isEmpty);
    vm.dispose();
  });

  test('empty account', () async {
    final vm = CustomerListViewModel(
      FakeCustomerRepository(),
      FakeParcelRepository(),
    );
    await _settle();
    expect(vm.hasNoItems, isTrue);
    vm.dispose();
  });

  test('live updates, error message and retry', () async {
    final repo = FakeCustomerRepository();
    final vm = CustomerListViewModel(repo, FakeParcelRepository());
    await _settle();
    await repo.add(
      name: 'New One',
      phone: '03003333333',
      address: 'Address one',
    );
    await _settle();
    expect(vm.visible.single.name, 'New One');

    repo.emitError(const AppFailure('No internet connection.'));
    await _settle();
    expect(vm.errorMessage, 'No internet connection.');
    vm.retry();
    await _settle();
    expect(vm.errorMessage, isNull);
    expect(vm.visible, hasLength(1));
    vm.dispose();
  });
}
