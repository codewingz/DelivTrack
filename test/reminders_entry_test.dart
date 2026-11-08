import 'package:deliv_track/features/parcels/domain/parcel.dart';
import 'package:deliv_track/features/parcels/domain/parcel_enums.dart';
import 'package:deliv_track/features/reminders/views/reminders_screen.dart';
import 'package:deliv_track/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_auth_repository.dart';
import 'helpers/fake_customer_repository.dart';
import 'helpers/fake_parcel_repository.dart';
import 'helpers/fake_product_repository.dart';

Future<void> _launch(WidgetTester t, FakeParcelRepository parcels) async {
  t.view.physicalSize = const Size(393, 852);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    DelivTrackApp(
      repository: FakeAuthRepository(signedIn: true, name: 'Ali'),
      productRepository: FakeProductRepository(),
      customerRepository: FakeCustomerRepository(),
      parcelRepository: parcels,
    ),
  );
  await t.pump(const Duration(milliseconds: 2000));
  await t.pumpAndSettle();
}

// 2000 dates are always in the past; 2999 is always in the future.
Parcel testParcelLater(String id, int sequence, String? date) => testParcel(
  id: id,
  sequence: sequence,
  method: CollectionMethod.payLater,
  service: PostalService.vpl,
  payDate: date,
);

void main() {
  testWidgets(
    'the bell counts overdue and due-today reminders and opens the Reminders screen',
    (t) async {
      await _launch(
        t,
        FakeParcelRepository(
          initial: [
            testParcelLater('a', 1, '2000-01-01'),
            testParcelLater('b', 2, '2000-06-01'),
            testParcelLater('c', 3, '2999-01-01'),
            testParcelLater('d', 4, null),
          ],
        ),
      );
      expect(
        find.descendant(of: find.byType(Badge), matching: find.text('2')),
        findsOneWidget,
        reason: 'two are overdue; upcoming and undated do not count',
      );
      await t.tap(find.byTooltip('Reminders, 2 due'));
      await t.pumpAndSettle();
      expect(find.byType(RemindersScreen), findsOneWidget);
      expect(find.text('Overdue (2)'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);

      await t.tap(find.text('ADT-000001'));
      await t.pumpAndSettle();
      expect(
        find.widgetWithText(AppBar, 'ADT-000001'),
        findsOneWidget,
        reason: 'a row opens the parcel',
      );
    },
  );

  testWidgets('no badge when nothing is due; the bell still opens the screen', (
    t,
  ) async {
    await _launch(
      t,
      FakeParcelRepository(initial: [testParcelLater('c', 3, '2999-01-01')]),
    );
    expect(find.byTooltip('Reminders'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(Badge), matching: find.byType(Text)),
      findsNothing,
    );
    await t.tap(find.byTooltip('Reminders'));
    await t.pumpAndSettle();
    expect(find.text('Upcoming (1)'), findsOneWidget);
  });
}
