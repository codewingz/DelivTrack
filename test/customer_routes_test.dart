import 'package:deliv_track/features/customers/domain/customer.dart';
import 'package:deliv_track/main.dart';
import 'package:deliv_track/routes/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'helpers/fake_auth_repository.dart';
import 'helpers/fake_customer_repository.dart';
import 'helpers/fake_parcel_repository.dart';
import 'helpers/fake_product_repository.dart';

Future<GoRouter> _launch(WidgetTester t) async {
  await t.pumpWidget(DelivTrackApp(
    repository: FakeAuthRepository(signedIn: true, name: 'Ali'),
    productRepository: FakeProductRepository(),
    customerRepository: FakeCustomerRepository(),
    parcelRepository: FakeParcelRepository(),
  ));
  await t.pump(const Duration(milliseconds: 2000));
  await t.pumpAndSettle();
  return GoRouter.of(t.element(find.byType(Scaffold).first));
}

void main() {
  testWidgets('/customers/new opens the full-screen Add customer form; back returns', (t) async {
    final router = await _launch(t);
    router.push(AppRoutes.customerNew);
    await t.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Add customer'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing, reason: 'full screen hides the tabs');
    await t.pageBack();
    await t.pumpAndSettle();
    expect(find.text('Welcome, Ali'), findsOneWidget);
  });

  testWidgets('/customers/edit with a customer opens the prefilled Edit form', (t) async {
    final router = await _launch(t);
    router.push(
      AppRoutes.customerEdit,
      extra: const Customer(id: 'c1', name: 'Sara Khan', phone: '03001234567', address: 'Street 1, Sahiwal'),
    );
    await t.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Edit customer'), findsOneWidget);
    expect(t.widget<TextFormField>(find.byType(TextFormField).first).controller!.text, 'Sara Khan');
  });

  testWidgets('/customers/edit without a customer falls back to the Customers list instead of crashing', (t) async {
    final router = await _launch(t);
    router.go(AppRoutes.customerEdit);
    await t.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Customers'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('/parcels/new opens the full-screen Add parcel form; New Customer from the picker opens the customer form', (t) async {
    final router = await _launch(t);
    router.push(AppRoutes.parcelNew);
    await t.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Add parcel'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await t.tap(find.widgetWithText(TextFormField, 'Select a customer').first);
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FloatingActionButton, 'New Customer'));
    await t.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Add customer'), findsOneWidget, reason: 'a full screen, not a dialog');
  });
}
