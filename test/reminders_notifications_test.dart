import 'package:deliv_track/features/customers/domain/customer.dart';
import 'package:deliv_track/features/parcels/domain/parcel_enums.dart';
import 'package:deliv_track/features/parcels/domain/parcel_input.dart';
import 'package:deliv_track/features/parcels/domain/parcel_item.dart';
import 'package:deliv_track/features/reminders/views/reminders_screen.dart';
import 'package:deliv_track/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_auth_repository.dart';
import 'helpers/fake_customer_repository.dart';
import 'helpers/fake_parcel_repository.dart';
import 'helpers/fake_product_repository.dart';
import 'helpers/fake_reminder_scheduler.dart';

Future<void> _launch(
  WidgetTester t,
  FakeAuthRepository auth,
  FakeParcelRepository parcels,
  FakeReminderScheduler scheduler,
) async {
  t.view.physicalSize = const Size(393, 852);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    DelivTrackApp(
      repository: auth,
      productRepository: FakeProductRepository(),
      customerRepository: FakeCustomerRepository(),
      parcelRepository: parcels,
      reminderScheduler: scheduler,
    ),
  );
  await t.pump(const Duration(milliseconds: 2000));
  await t.pumpAndSettle();
}

ParcelInput _payLater(String date, {String reference = 'VPL 99999'}) =>
    ParcelInput(
      customer: const Customer(
        id: 'c1',
        name: 'Ali Raza',
        phone: '03001111111',
        address: 'House 5, Sahiwal',
      ),
      items: [
        ParcelItem.pieces(
          productId: 'p',
          productName: 'Mango Box',
          quantity: 1,
          unitPricePaisa: 100000,
        ),
      ],
      method: CollectionMethod.payLater,
      postalReference: reference,
      deliveryChargePaisa: 15000,
      estimatedPaymentDate: date,
      status: ParcelStatus.sent,
    );

void main() {
  testWidgets(
    'the first load schedules every dated Pay Later parcel and does not ask for permission at launch',
    (t) async {
      final scheduler = FakeReminderScheduler(enabled: false);
      final parcels = FakeParcelRepository();
      await parcels.create(_payLater('2999-01-01'));
      await _launch(
        t,
        FakeAuthRepository(signedIn: true, name: 'Ali'),
        parcels,
        scheduler,
      );
      expect(scheduler.lastPlanned.single.title, 'Payment due: ADT-000001');
      expect(find.text('Get payment reminders?'), findsNothing);
      expect(scheduler.permissionRequests, 0);
    },
  );

  testWidgets(
    'adding a reminder while using the app explains and asks once; later additions do not ask again',
    (t) async {
      final scheduler = FakeReminderScheduler(enabled: false);
      final parcels = FakeParcelRepository();
      await _launch(
        t,
        FakeAuthRepository(signedIn: true, name: 'Ali'),
        parcels,
        scheduler,
      );
      expect(find.text('Get payment reminders?'), findsNothing);

      await parcels.create(_payLater('2999-01-01'));
      await t.pumpAndSettle();
      expect(find.text('Get payment reminders?'), findsOneWidget);
      expect(find.textContaining('9:00 AM'), findsOneWidget);
      await t.tap(find.widgetWithText(TextButton, 'Allow'));
      await t.pumpAndSettle();
      expect(scheduler.permissionRequests, 1);

      scheduler.enabled = false;
      await parcels.create(_payLater('2999-02-02', reference: 'VPL 88888'));
      await t.pumpAndSettle();
      expect(
        find.text('Get payment reminders?'),
        findsNothing,
        reason: 'asked once per session',
      );
      expect(scheduler.lastPlanned, hasLength(2));
    },
  );

  testWidgets('declining the explanation does not request the permission', (
    t,
  ) async {
    final scheduler = FakeReminderScheduler(enabled: false);
    final parcels = FakeParcelRepository();
    await _launch(
      t,
      FakeAuthRepository(signedIn: true, name: 'Ali'),
      parcels,
      scheduler,
    );
    await parcels.create(_payLater('2999-01-01'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(TextButton, 'Cancel'));
    await t.pumpAndSettle();
    expect(scheduler.permissionRequests, 0);
  });

  testWidgets('no prompt when notifications are already allowed', (t) async {
    final scheduler = FakeReminderScheduler();
    final parcels = FakeParcelRepository();
    await _launch(
      t,
      FakeAuthRepository(signedIn: true, name: 'Ali'),
      parcels,
      scheduler,
    );
    await parcels.create(_payLater('2999-01-01'));
    await t.pumpAndSettle();
    expect(find.text('Get payment reminders?'), findsNothing);
    expect(scheduler.lastPlanned, hasLength(1));
  });

  testWidgets('signing out clears every scheduled reminder from the phone', (
    t,
  ) async {
    final scheduler = FakeReminderScheduler();
    final auth = FakeAuthRepository(signedIn: true, name: 'Ali');
    await _launch(t, auth, FakeParcelRepository(), scheduler);
    expect(scheduler.cancelAlls, 0);
    auth.emitSignedIn(false);
    await t.pumpAndSettle();
    expect(scheduler.cancelAlls, 1);
  });

  testWidgets('tapping a reminder notification opens that parcel', (t) async {
    final scheduler = FakeReminderScheduler();
    final parcels = FakeParcelRepository();
    final id = await parcels.create(_payLater('2999-01-01'));
    await _launch(
      t,
      FakeAuthRepository(signedIn: true, name: 'Ali'),
      parcels,
      scheduler,
    );
    scheduler.tapController.add(id);
    await t.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'ADT-000001'), findsOneWidget);
  });

  testWidgets(
    'a notification that started the app opens its parcel once Home is up',
    (t) async {
      final parcels = FakeParcelRepository();
      final id = await parcels.create(_payLater('2999-01-01'));
      await _launch(
        t,
        FakeAuthRepository(signedIn: true, name: 'Ali'),
        parcels,
        FakeReminderScheduler(launchParcelId: id),
      );
      expect(find.widgetWithText(AppBar, 'ADT-000001'), findsOneWidget);
    },
  );

  group('banner on the Reminders screen', () {
    Future<void> openReminders(
      WidgetTester t,
      FakeReminderScheduler scheduler,
      FakeParcelRepository parcels,
    ) async {
      await t.pumpWidget(
        MaterialApp(
          home: RemindersScreen(
            repository: parcels,
            scheduler: scheduler,
            onOpen: (_) {},
          ),
        ),
      );
      await t.pump();
      await t.pump();
    }

    testWidgets(
      'shown when notifications are off and a dated reminder exists; Turn On asks, then falls back to settings when refused',
      (t) async {
        final scheduler = FakeReminderScheduler(enabled: false)
          ..allowWhenAsked = false;
        final parcels = FakeParcelRepository();
        await parcels.create(_payLater('2999-01-01'));
        await openReminders(t, scheduler, parcels);
        expect(find.text('Phone notifications are off'), findsOneWidget);
        await t.tap(find.text('Turn On Notifications'));
        await t.pump();
        await t.pump();
        expect(scheduler.permissionRequests, 1);
        expect(scheduler.settingsOpened, 1);
        expect(find.text('Phone notifications are off'), findsOneWidget);
      },
    );

    testWidgets('granting the permission removes the banner', (t) async {
      final scheduler = FakeReminderScheduler(enabled: false);
      final parcels = FakeParcelRepository();
      await parcels.create(_payLater('2999-01-01'));
      await openReminders(t, scheduler, parcels);
      await t.tap(find.text('Turn On Notifications'));
      await t.pump();
      await t.pump();
      expect(find.text('Phone notifications are off'), findsNothing);
      expect(scheduler.settingsOpened, 0);
    });

    testWidgets(
      'not shown when notifications are on, or when no reminder has a date',
      (t) async {
        final parcels = FakeParcelRepository();
        await parcels.create(_payLater('2999-01-01'));
        await openReminders(t, FakeReminderScheduler(), parcels);
        expect(find.text('Phone notifications are off'), findsNothing);

        final undated = FakeParcelRepository(
          initial: [testParcel(method: CollectionMethod.payLater)],
        );
        await openReminders(t, FakeReminderScheduler(enabled: false), undated);
        expect(find.text('Phone notifications are off'), findsNothing);
      },
    );
  });
}
