import 'package:deliv_track/features/customers/domain/customer.dart';
import 'package:deliv_track/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_auth_repository.dart';
import 'helpers/fake_customer_repository.dart';
import 'helpers/fake_parcel_repository.dart';
import 'helpers/fake_product_repository.dart';
import 'helpers/tab_finders.dart';

void main() {
  // Regression: Parcels and Customers both have an "Add" button and both tabs stay alive. With the default
  // hero tag, pushing any screen after visiting both tabs threw "multiple heroes share the same tag".
  testWidgets(
    'visiting two tabs with an Add button and then opening a screen does not throw',
    (t) async {
      t.view.physicalSize = const Size(393, 1400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        DelivTrackApp(
          repository: FakeAuthRepository(signedIn: true, name: 'Ali'),
          productRepository: FakeProductRepository(),
          customerRepository: FakeCustomerRepository(
            initial: [
              const Customer(
                id: 'c1',
                name: 'Ali Raza',
                phone: '03001111111',
                address: 'House 5, Sahiwal',
              ),
            ],
          ),
          parcelRepository: FakeParcelRepository(
            initial: [testParcel(id: 'a')],
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 2000));
      await t.pumpAndSettle();
      Finder tab(String label) => tabButton(label);
      await t.tap(tab('Parcels'));
      await t.pumpAndSettle();
      await t.tap(tab('Customers'));
      await t.pumpAndSettle();
      await t.tap(find.text('Ali Raza'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.text('Parcel history'), findsOneWidget);
      await t.pageBack();
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FloatingActionButton, 'Add Customer'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.widgetWithText(AppBar, 'Add customer'), findsOneWidget);
    },
  );
}
