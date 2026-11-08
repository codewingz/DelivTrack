import 'package:deliv_track/features/customers/domain/customer.dart';
import 'package:deliv_track/features/customers/views/customers_screen.dart';
import 'package:deliv_track/features/dashboard/views/dashboard_screen.dart';
import 'package:deliv_track/features/parcels/domain/parcel_enums.dart';
import 'package:deliv_track/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_auth_repository.dart';
import 'helpers/fake_customer_repository.dart';
import 'helpers/fake_parcel_repository.dart';
import 'helpers/fake_product_repository.dart';
import 'helpers/tab_finders.dart';

Finder get _customersTab => tabButton('Customers');
Finder get _anyCustomersScreen =>
    find.byType(CustomersScreen, skipOffstage: false);

void main() {
  // Data isolation: nothing from one user's session may survive on screen (or in memory) for the next user.
  testWidgets(
    'logging out destroys every screen of the session; the next user gets fresh screens',
    (t) async {
      t.view.physicalSize = const Size(393, 852);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final auth = FakeAuthRepository(signedIn: true, name: 'Owner One');
      final customers = FakeCustomerRepository(
        initial: [
          const Customer(
            id: 'c1',
            name: 'Private Customer',
            phone: '03001111111',
            address: 'Owner one street 1',
          ),
        ],
      );
      await t.pumpWidget(
        DelivTrackApp(
          repository: auth,
          productRepository: FakeProductRepository(),
          customerRepository: customers,
          parcelRepository: FakeParcelRepository(),
        ),
      );
      await t.pump(const Duration(milliseconds: 2000));
      await t.pumpAndSettle();

      await t.tap(_customersTab);
      await t.pumpAndSettle();
      expect(find.text('Private Customer'), findsOneWidget);
      // Visit a pushed screen and come back, like a real session.
      await t.tap(find.widgetWithText(FloatingActionButton, 'Add Customer'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextFormField).first, 'Half typed');
      await t.pump();
      await t.pageBack();
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(TextButton, 'Discard'));
      await t.pumpAndSettle();
      await t.enterText(
        find.byType(TextFormField).first,
        'private',
      ); // leftover UI state
      await t.pump();
      final stateBefore = identityHashCode(
        (find.byType(CustomersScreen).evaluate().single as StatefulElement)
            .state,
      );

      auth.emitSignedIn(false);
      await t.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);
      expect(
        _anyCustomersScreen,
        findsNothing,
        reason:
            'no screen of the previous session may stay alive, even offstage',
      );

      customers
        ..removeAll()
        ..resetSubscriptions();
      auth.emitSignedIn(true, name: 'Owner Two');
      await t.pumpAndSettle();
      expect(
        _anyCustomersScreen,
        findsNothing,
        reason: 'tabs are only built when opened',
      );

      await t.tap(_customersTab);
      await t.pumpAndSettle();
      final stateAfter = identityHashCode(
        (find.byType(CustomersScreen).evaluate().single as StatefulElement)
            .state,
      );
      expect(
        stateAfter,
        isNot(stateBefore),
        reason: 'the new session must not reuse the previous session\'s screen state',
      );
      expect(
        customers.subscriptions,
        1,
        reason: 'the list subscribes again for the new session',
      );
      expect(find.text('Private Customer'), findsNothing);
      expect(find.text('No customers yet'), findsOneWidget);
      expect(
        t
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        isEmpty,
      );
    },
  );

  testWidgets(
    "the Home bell never carries one user's reminders over to the next user",
    (t) async {
      t.view.physicalSize = const Size(393, 852);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final auth = FakeAuthRepository(signedIn: true, name: 'Owner One');
      final parcels = FakeParcelRepository(
        initial: [
          testParcel(
            id: 'a',
            method: CollectionMethod.payLater,
            service: PostalService.vpl,
            payDate: '2000-01-01',
          ),
        ],
      );
      await t.pumpWidget(
        DelivTrackApp(
          repository: auth,
          productRepository: FakeProductRepository(),
          customerRepository: FakeCustomerRepository(),
          parcelRepository: parcels,
        ),
      );
      await t.pump(const Duration(milliseconds: 2000));
      await t.pumpAndSettle();
      expect(find.byTooltip('Reminders, 1 due'), findsOneWidget);
      final before = identityHashCode(
        (find.byType(DashboardScreen).evaluate().single as StatefulElement)
            .state,
      );

      auth.emitSignedIn(false);
      await t.pumpAndSettle();
      expect(
        find.byType(DashboardScreen, skipOffstage: false),
        findsNothing,
        reason: 'the whole session is destroyed',
      );

      parcels.removeAll();
      auth.emitSignedIn(true, name: 'Owner Two');
      await t.pumpAndSettle();
      final after = identityHashCode(
        (find.byType(DashboardScreen).evaluate().single as StatefulElement)
            .state,
      );
      expect(after, isNot(before));
      expect(find.byTooltip('Reminders'), findsOneWidget);
      expect(find.byTooltip('Reminders, 1 due'), findsNothing);
    },
  );
}
