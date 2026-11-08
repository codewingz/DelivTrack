import 'dart:async';

import 'package:deliv_track/common_widgets/list_skeleton.dart';
import 'package:deliv_track/core/errors/app_failure.dart';
import 'package:deliv_track/features/customers/domain/customer.dart';
import 'package:deliv_track/features/parcels/data/parcel_repository.dart';
import 'package:deliv_track/features/parcels/domain/parcel.dart';
import 'package:deliv_track/features/parcels/domain/parcel_enums.dart';
import 'package:deliv_track/features/parcels/domain/parcel_item.dart';
import 'package:deliv_track/features/parcels/domain/parcel_input.dart';
import 'package:deliv_track/features/parcels/domain/payment.dart';
import 'package:deliv_track/features/parcels/views/parcel_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_parcel_repository.dart';

Future<void> _open(
  WidgetTester t,
  ParcelRepository repo,
  String id, {
  Size size = const Size(393, 852),
  double scale = 1,
  Future<String?> Function(Parcel)? onEdit,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  t.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  await t.pumpWidget(
    MaterialApp(
      home: ParcelDetailsScreen(
        repository: repo,
        parcelId: id,
        onEdit: onEdit ?? (_) async => null,
      ),
    ),
  );
  await t.pump();
  await t.pump();
}

void main() {
  testWidgets('a sent parcel shows every section with its data', (t) async {
    final repo = FakeParcelRepository(
      initial: [
        testParcel(
          id: 'a',
          sequence: 12,
          packedGrams: 3200,
          sendingDate: '2026-11-07',
          items: [
            ParcelItem.pieces(
              productId: 'x',
              productName: 'Mango Box',
              quantity: 2,
              unitPricePaisa: 250000,
            ),
            ParcelItem.weight(
              productId: 'y',
              productName: 'Dry Fruits',
              weightGrams: 1250,
              unitPricePaisa: 80000,
            ),
          ],
        ),
      ],
    );
    await _open(t, repo, 'a');
    expect(find.widgetWithText(AppBar, 'ADT-000012'), findsOneWidget);
    for (final text in [
      'Sent',
      'Pending',
      '7 Nov 2026',
      'Post office collection',
      'Ali Raza',
      '0300 1111111',
      'House 5, Street 2, Sahiwal',
      'Mango Box',
      '2 pieces × Rs. 2,500 each = Rs. 5,000',
      'Dry Fruits',
      '1.25 kg × Rs. 800 per kg = Rs. 1,000',
      'VPP',
      'VPP 12345',
      'Rs. 150.50',
      '3.2 kg',
      'Rs. 6,000',
    ]) {
      expect(find.text(text), findsWidgets, reason: text);
    }
    expect(find.text('Rs. 0'), findsOneWidget, reason: 'received');
    expect(find.textContaining('Estimated payment date'), findsNothing);
  });

  testWidgets('a draft says what is still missing; no packed weight row', (
    t,
  ) async {
    final repo = FakeParcelRepository(
      initial: [
        testParcel(
          id: 'd',
          status: ParcelStatus.draft,
          reference: '',
          charge: null,
        ),
      ],
    );
    await _open(t, repo, 'd');
    expect(find.text('Draft'), findsOneWidget);
    expect(
      find.text('Awaiting handover'),
      findsNWidgets(2),
      reason: 'reference and delivery charge',
    );
    expect(find.text('Packed parcel weight'), findsNothing);
  });

  testWidgets('a gift parcel shows no payment expected and no prices', (
    t,
  ) async {
    final repo = FakeParcelRepository(
      initial: [
        testParcel(
          id: 'g',
          method: CollectionMethod.giftFree,
          service: PostalService.vpl,
          reference: 'VPL 99999',
          items: [
            ParcelItem.pieces(
              productId: 'x',
              productName: 'Mango Box',
              quantity: 3,
              unitPricePaisa: 0,
            ),
          ],
        ),
      ],
    );
    await _open(t, repo, 'g');
    expect(find.text('Gift / Free'), findsOneWidget);
    expect(find.text('Not required'), findsOneWidget);
    expect(find.text('None (Gift / Free)'), findsOneWidget);
    expect(find.text('3 pieces'), findsOneWidget);
    expect(find.textContaining('×'), findsNothing);
  });

  testWidgets(
    'Pay Later shows the estimated payment date; "Other" shows the typed service name',
    (t) async {
      final repo = FakeParcelRepository(
        initial: [
          testParcel(
            id: 'p',
            method: CollectionMethod.payLater,
            service: PostalService.other,
            otherName: 'Fast Courier',
            reference: 'ABC 12345',
            payDate: '2026-12-25',
          ),
        ],
      );
      await _open(t, repo, 'p');
      expect(find.text('Pay Later'), findsOneWidget);
      expect(find.text('25 Dec 2026'), findsOneWidget);
      expect(find.text('Fast Courier'), findsOneWidget);
    },
  );

  testWidgets('skeleton first; an unknown id says not found', (t) async {
    final repo = FakeParcelRepository();
    t.view.physicalSize = const Size(393, 852);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        home: ParcelDetailsScreen(
          repository: repo,
          parcelId: 'nope',
          onEdit: (_) async => null,
        ),
      ),
    );
    expect(find.byType(ListSkeleton), findsOneWidget);
    await t.pump();
    await t.pump();
    expect(find.text('This parcel was not found'), findsOneWidget);
  });

  testWidgets('a load failure shows the message and Retry loads it', (t) async {
    final repo = _FlakyRepository(testParcel(id: 'a', sequence: 3));
    await _open(t, repo, 'a');
    expect(find.text("Couldn't load this parcel"), findsOneWidget);
    expect(find.text('No internet connection.'), findsOneWidget);
    await t.tap(find.widgetWithText(FilledButton, 'Retry'));
    await t.pump();
    await t.pump();
    expect(find.widgetWithText(AppBar, 'ADT-000003'), findsOneWidget);
  });

  testWidgets('a parcel created through the repository can be opened', (
    t,
  ) async {
    final repo = FakeParcelRepository();
    await repo.create(
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
            productName: 'Box',
            quantity: 1,
            unitPricePaisa: 1000,
          ),
        ],
        method: CollectionMethod.advance,
        service: PostalService.vpl,
        status: ParcelStatus.draft,
      ),
    );
    await _open(t, repo, 'parcel-1');
    expect(find.text('Draft'), findsOneWidget);
  });

  group('responsive', () {
    const sizes = [
      Size(320, 568),
      Size(393, 852),
      Size(700, 900),
      Size(1100, 800),
      Size(640, 300),
    ];
    for (final size in sizes) {
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets('does not overflow at $size text x$scale', (t) async {
          final repo = FakeParcelRepository(
            initial: [
              testParcel(
                id: 'a',
                customerName: 'Muhammad Afzaal Khan Niazi Son Of Abdul Rehman',
                customerAddress: 'House 123, Street 45, Block C, Model Town Extension, Near Main Market, Sahiwal, Punjab',
                service: PostalService.other,
                otherName: 'A Very Long Courier Service Name',
                method: CollectionMethod.payLater,
                payDate: '2026-12-25',
                packedGrams: 9999999,
                items: [
                  ParcelItem.pieces(
                    productId: 'x',
                    productName:
                        'Premium Gift Hamper With A Very Long Descriptive Name',
                    quantity: 99999,
                    unitPricePaisa: 9999999900,
                  ),
                  ParcelItem.weight(
                    productId: 'y',
                    productName: 'Dry Fruits',
                    weightGrams: 9999999,
                    unitPricePaisa: 123456789,
                  ),
                ],
              ),
            ],
          );
          await _open(t, repo, 'a', size: size, scale: scale);
          expect(t.takeException(), isNull);
          await t.drag(
            find.byType(SingleChildScrollView),
            const Offset(0, -2000),
          );
          await t.pump();
          expect(t.takeException(), isNull);
        });
      }
    }
  });

  testWidgets(
    'Edit opens the form for this parcel and shows a snackbar once saved',
    (t) async {
      Parcel? opened;
      await _open(
        t,
        FakeParcelRepository(initial: [testParcel(id: 'a')]),
        'a',
        onEdit: (p) async {
          opened = p;
          return p.id;
        },
      );
      await t.tap(find.byTooltip('Edit parcel'));
      await t.pump();
      expect(opened?.id, 'a');
      expect(find.text('Parcel updated.'), findsOneWidget);
    },
  );

  testWidgets('a cancelled edit shows no snackbar', (t) async {
    await _open(t, FakeParcelRepository(initial: [testParcel(id: 'a')]), 'a');
    await t.tap(find.byTooltip('Edit parcel'));
    await t.pump();
    expect(find.text('Parcel updated.'), findsNothing);
  });

  testWidgets('a returned parcel has no Edit action', (t) async {
    await _open(
      t,
      FakeParcelRepository(
        initial: [testParcel(id: 'b', status: ParcelStatus.returned)],
      ),
      'b',
    );
    expect(find.byTooltip('Edit parcel'), findsNothing);
  });

  group('payments', () {
    Finder receive = find.widgetWithText(FilledButton, 'Mark Payment Received');

    testWidgets(
      'an unpaid sent parcel offers Mark Payment Received and shows no payments yet',
      (t) async {
        await _open(
          t,
          FakeParcelRepository(initial: [testParcel(id: 'a')]),
          'a',
        );
        expect(receive, findsOneWidget);
        expect(find.text('Payment history'), findsOneWidget);
        expect(find.text('No payments received yet'), findsOneWidget);
      },
    );

    testWidgets(
      'no button for a Gift / Free, a returned or a fully paid parcel; Gift / Free has no history',
      (t) async {
        for (final parcel in [
          testParcel(id: 'a', method: CollectionMethod.giftFree),
          testParcel(id: 'a', status: ParcelStatus.returned),
          testParcel(id: 'a', received: 500000),
        ]) {
          await _open(t, FakeParcelRepository(initial: [parcel]), 'a');
          expect(
            receive,
            findsNothing,
            reason: '${parcel.method} ${parcel.status} ${parcel.receivedPaisa}',
          );
          if (parcel.method == CollectionMethod.giftFree) {
            expect(find.text('Payment history'), findsNothing);
          }
          await t.pumpWidget(const SizedBox());
        }
      },
    );

    testWidgets(
      'a returned parcel with an open payment review explains why it cannot be archived',
      (t) async {
        await _open(
          t,
          FakeParcelRepository(
            initial: [
              testParcel(
                id: 'a',
                status: ParcelStatus.returned,
                paymentReviewRequired: true,
              ),
            ],
          ),
          'a',
        );
        await t.scrollUntilVisible(
          find.textContaining('payment review is completed'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          find.textContaining(
            "can't be archived until its payment review is completed",
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'recording a payment updates the amounts, adds a history row and confirms with a snackbar',
      (t) async {
        await _open(
          t,
          FakeParcelRepository(initial: [testParcel(id: 'a')]),
          'a',
        );
        await t.ensureVisible(receive);
        await t.tap(receive);
        await t.pumpAndSettle();
        await t.tap(find.widgetWithText(ChoiceChip, 'Advance'));
        await t.enterText(find.byType(TextFormField).first, '2000');
        await t.pump();
        await t.tap(find.widgetWithText(FilledButton, 'Confirm Payment'));
        await t.pumpAndSettle();
        expect(find.text('Payment recorded.'), findsOneWidget);
        expect(find.text('Rs. 2,000 — '), findsNothing);
        expect(find.text('Rs. 2,000'), findsWidgets);
        expect(
          find.text('Rs. 3,000'),
          findsWidgets,
          reason: 'outstanding after the payment',
        );
        expect(find.text('No payments received yet'), findsNothing);
        expect(find.text('Partially paid'), findsOneWidget);
      },
    );
  });

  group('handover', () {
    Finder primary(String label) => find.widgetWithText(FilledButton, label);
    Finder outlined(String label) => find.widgetWithText(OutlinedButton, label);

    testWidgets(
      'a draft shows what is missing and a prominent "Hand over to post office"',
      (t) async {
        await _open(
          t,
          FakeParcelRepository(
            initial: [
              testParcel(
                id: 'a',
                status: ParcelStatus.draft,
                reference: '',
                charge: null,
              ),
            ],
          ),
          'a',
        );
        await t.ensureVisible(primary('Hand over to post office'));
        expect(primary('Hand over to post office'), findsOneWidget);
        expect(
          find.text('Awaiting handover'),
          findsNWidgets(2),
          reason: 'reference and delivery charge',
        );
        expect(outlined('Edit handover'), findsNothing);
      },
    );

    testWidgets(
      'handing it over from the details makes it Sent and swaps the button for Edit handover',
      (t) async {
        final repo = FakeParcelRepository(
          initial: [
            testParcel(
              id: 'a',
              status: ParcelStatus.draft,
              reference: '',
              charge: null,
            ),
          ],
        );
        await _open(t, repo, 'a');
        await t.ensureVisible(primary('Hand over to post office'));
        await t.pump();
        await t.tap(primary('Hand over to post office'));
        await t.pumpAndSettle();
        await t.enterText(
          find.widgetWithText(
            TextFormField,
            'Enter VPP / VPL / VPR reference from slip',
          ),
          'VPP 40404',
        );
        await t.enterText(
          find.widgetWithText(TextFormField, 'Amount on slip'),
          '120',
        );
        await t.pump();
        await t.tap(primary('Hand Over'));
        await t.pumpAndSettle();
        expect(find.text('Parcel handed over.'), findsOneWidget);
        expect(find.text('VPP 40404'), findsOneWidget);
        expect(primary('Hand over to post office'), findsNothing);
        await t.ensureVisible(outlined('Edit handover'));
        expect(outlined('Edit handover'), findsOneWidget);
        expect(repo.handovers.single.handover.deliveryChargePaisa, 12000);
      },
    );

    testWidgets(
      'a sent parcel offers Edit handover; returned and archived parcels offer neither button',
      (t) async {
        for (final (parcel, hand, edit) in [
          (testParcel(id: 'a'), false, true),
          (testParcel(id: 'a', status: ParcelStatus.returned), false, false),
          (
            testParcel(id: 'a', received: 500000, isArchived: true),
            false,
            false,
          ),
          (
            testParcel(
              id: 'a',
              status: ParcelStatus.draft,
              reference: '',
              charge: null,
              isArchived: true,
            ),
            false,
            false,
          ),
          (
            testParcel(
              id: 'a',
              status: ParcelStatus.draft,
              reference: '',
              charge: null,
            ),
            true,
            false,
          ),
        ]) {
          await _open(t, FakeParcelRepository(initial: [parcel]), 'a');
          expect(
            primary('Hand over to post office'),
            hand ? findsOneWidget : findsNothing,
            reason: '${parcel.status} archived=${parcel.isArchived}',
          );
          expect(
            outlined('Edit handover'),
            edit ? findsOneWidget : findsNothing,
            reason: '${parcel.status} archived=${parcel.isArchived}',
          );
          await t.pumpWidget(const SizedBox());
        }
      },
    );
  });

  group('actions', () {
    Finder button(String label) => find.widgetWithText(OutlinedButton, label);

    testWidgets(
      'a sent parcel offers Add Notes and Mark Returned (not the Pay Later date)',
      (t) async {
        await _open(
          t,
          FakeParcelRepository(initial: [testParcel(id: 'a')]),
          'a',
        );
        expect(find.text('No notes yet'), findsOneWidget);
        expect(button('Add Notes'), findsOneWidget);
        expect(button('Mark Returned'), findsOneWidget);
        expect(button('Change Pay Later Date'), findsNothing);
      },
    );

    testWidgets(
      'Pay Later with something outstanding offers the date change; with notes the button says Edit Notes',
      (t) async {
        await _open(
          t,
          FakeParcelRepository(
            initial: [
              testParcel(
                id: 'a',
                method: CollectionMethod.payLater,
                service: PostalService.vpl,
                payDate: '2031-02-03',
                notes: 'Call first',
              ),
            ],
          ),
          'a',
        );
        expect(button('Change Pay Later Date'), findsOneWidget);
        expect(button('Edit Notes'), findsOneWidget);
        expect(find.text('Call first'), findsOneWidget);
      },
    );

    testWidgets('a draft cannot be returned', (t) async {
      await _open(
        t,
        FakeParcelRepository(
          initial: [
            testParcel(
              id: 'a',
              status: ParcelStatus.draft,
              reference: '',
              charge: null,
            ),
          ],
        ),
        'a',
      );
      expect(button('Mark Returned'), findsNothing);
    });

    testWidgets(
      'Mark Returned: confirms, shows the Return section and the review flag, and removes the actions',
      (t) async {
        await _open(
          t,
          FakeParcelRepository(
            initial: [testParcel(id: 'a', received: 100000)],
          ),
          'a',
        );
        await t.ensureVisible(button('Mark Returned'));
        await t.pump();
        await t.tap(button('Mark Returned'));
        await t.pumpAndSettle();
        await t.enterText(find.byType(TextFormField).last, 'Customer refused');
        await t.pump();
        await t.tap(find.widgetWithText(FilledButton, 'Mark Returned'));
        await t.pumpAndSettle();
        expect(find.text('Parcel marked as returned.'), findsOneWidget);
        expect(find.text('Returned'), findsOneWidget);
        expect(find.text('Requires payment review'), findsOneWidget);
        expect(find.text('Customer refused'), findsOneWidget);
        expect(button('Mark Returned'), findsNothing);
        expect(
          find.widgetWithText(FilledButton, 'Mark Payment Received'),
          findsNothing,
        );
        expect(find.text('Correct'), findsNothing);
      },
    );

    testWidgets(
      'a payment can be corrected: the row is marked Corrected and a Reversal row appears',
      (t) async {
        final payment = Payment(
          id: 'pay-1',
          amountPaisa: 200000,
          type: PaymentType.advance,
          note: null,
          receivedAt: DateTime.utc(2026, 11, 8, 6),
        );
        final repo = FakeParcelRepository(
          initial: [testParcel(id: 'a', received: 200000)],
        )..payments['a'] = [payment];
        await _open(t, repo, 'a');
        await t.ensureVisible(find.text('Correct'));
        await t.pump();
        await t.tap(find.text('Correct'));
        await t.pumpAndSettle();
        await t.enterText(find.byType(TextFormField).first, '3000');
        await t.enterText(
          find.byType(TextFormField).last,
          'Wrong amount entered',
        );
        await t.pump();
        await t.tap(find.widgetWithText(FilledButton, 'Save Correction'));
        await t.pumpAndSettle();
        expect(find.text('Payment corrected.'), findsOneWidget);
        expect(find.textContaining('Corrected'), findsOneWidget);
        expect(find.textContaining('Reversal'), findsOneWidget);
        expect(find.textContaining('Wrong amount entered'), findsOneWidget);
        expect(
          find.text('Rs. 2,000 cancelled — Wrong amount entered'),
          findsOneWidget,
        );
        expect(
          find.text('Correct'),
          findsOneWidget,
          reason: 'only the replacement can be corrected again',
        );
      },
    );
  });

  group('payment review', () {
    Finder button(String label) => find.widgetWithText(OutlinedButton, label);
    final flagged = testParcel(
      id: 'a',
      status: ParcelStatus.returned,
      returnedDate: '2026-11-08',
      received: 100000,
      paymentReviewRequired: true,
    );

    Future<void> openSheet(WidgetTester t, FakeParcelRepository repo) async {
      await _open(t, repo, 'a');
      await t.ensureVisible(button('Mark Review Completed'));
      await t.pump();
      await t.tap(button('Mark Review Completed'));
      await t.pumpAndSettle();
    }

    testWidgets(
      'only a returned parcel with an open review offers Mark Review Completed',
      (t) async {
        for (final (parcel, offered) in [
          (flagged, true),
          (
            testParcel(
              id: 'a',
              status: ParcelStatus.returned,
              returnedDate: '2026-11-08',
            ),
            false,
          ),
          (testParcel(id: 'a', received: 100000), false),
          (
            testParcel(
              id: 'a',
              status: ParcelStatus.returned,
              returnedDate: '2026-11-08',
              reviewResolution: ReviewResolution.moneyKept,
              reviewNote: 'Kept',
              reviewDate: '2026-11-08',
            ),
            false,
          ),
        ]) {
          await _open(t, FakeParcelRepository(initial: [parcel]), 'a');
          expect(
            button('Mark Review Completed'),
            offered ? findsOneWidget : findsNothing,
          );
          await t.pumpWidget(const SizedBox());
        }
      },
    );

    testWidgets(
      'the reason and a note are required; nothing is saved until both are given',
      (t) async {
        final repo = FakeParcelRepository(initial: [flagged]);
        await openSheet(t, repo);
        await t.tap(find.widgetWithText(FilledButton, 'Mark Review Completed'));
        await t.pumpAndSettle();
        expect(find.text('Select how the review was settled'), findsOneWidget);
        expect(find.text('Note is required'), findsOneWidget);
        expect(repo.reviewsCompleted, isEmpty);
        await t.tap(find.text('Money kept'));
        await t.enterText(find.byType(TextFormField).last, 'abc');
        await t.tap(find.widgetWithText(FilledButton, 'Mark Review Completed'));
        await t.pumpAndSettle();
        expect(
          find.text('Write at least 5 characters'),
          findsOneWidget,
          reason: 'too short',
        );
        expect(repo.reviewsCompleted, isEmpty);
      },
    );

    testWidgets(
      'completing the review records it, leaves the money alone and shows the decision',
      (t) async {
        final repo = FakeParcelRepository(initial: [flagged]);
        await openSheet(t, repo);
        await t.tap(find.text('Refund given'));
        await t.enterText(
          find.byType(TextFormField).last,
          'Refund sent by bank transfer',
        );
        await t.tap(find.widgetWithText(FilledButton, 'Mark Review Completed'));
        await t.pumpAndSettle();
        expect(find.text('Payment review completed.'), findsOneWidget);
        expect(
          repo.reviewsCompleted.single.resolution,
          ReviewResolution.refundGiven,
        );
        expect(
          repo.reviewsCompleted.single.note,
          'Refund sent by bank transfer',
        );
        final after = (await repo.watchAll().first).single;
        expect(after.paymentReviewRequired, isFalse);
        expect(
          after.receivedPaisa,
          100000,
          reason: 'completing a review never changes the money',
        );
        expect(find.textContaining('Completed on'), findsOneWidget);
        expect(find.text('Refund sent by bank transfer'), findsOneWidget);
        expect(button('Mark Review Completed'), findsNothing);
        expect(
          button('Archive Parcel'),
          findsOneWidget,
          reason: 'archiving is possible once the review is done',
        );
      },
    );

    testWidgets('a refusal from the repository is shown instead of crashing', (
      t,
    ) async {
      final repo = FakeParcelRepository(initial: [flagged]);
      await openSheet(t, repo);
      repo.failure = const AppFailure('No connection.');
      await t.tap(find.text('Money kept'));
      await t.enterText(
        find.byType(TextFormField).last,
        'Advance kept as agreed',
      );
      await t.tap(find.widgetWithText(FilledButton, 'Mark Review Completed'));
      await t.pumpAndSettle();
      expect(find.text('No connection.'), findsOneWidget);
    });
  });

  group('responsive with every section', () {
    final payment = Payment(
      id: 'pay-1',
      amountPaisa: 200000,
      type: PaymentType.advance,
      note: 'First part of the money',
      receivedAt: DateTime.utc(2026, 11, 8, 6),
    );
    for (final size in const [
      Size(320, 568),
      Size(393, 852),
      Size(700, 900),
      Size(1100, 800),
      Size(640, 300),
    ]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets(
          'no overflow at $size text x$scale (returned, with notes, payments and a reversal)',
          (t) async {
            final reversal = Payment(
              id: 'rev_pay-1',
              amountPaisa: -200000,
              type: PaymentType.advance,
              note: null,
              receivedAt: DateTime.utc(2026, 11, 9, 6),
              reversalOfPaymentId: 'pay-1',
              correctionReason: 'Entered the wrong amount by mistake',
            );
            final repo = FakeParcelRepository(
              initial: [
                testParcel(
                  id: 'a',
                  status: ParcelStatus.returned,
                  received: 0,
                  notes: 'Customer asked us to call before delivery. ' * 3,
                  returnedDate: '2026-11-09',
                  returnReason: 'Refused at the door',
                  paymentReviewRequired: true,
                ),
              ],
            )..payments['a'] = [reversal, payment];
            await _open(t, repo, 'a', size: size, scale: scale);
            expect(t.takeException(), isNull);
            await t.drag(
              find.byType(SingleChildScrollView),
              const Offset(0, -3000),
            );
            await t.pump();
            expect(t.takeException(), isNull);
          },
        );
      }
    }
  });

  group('archiving', () {
    Finder button(String label) => find.widgetWithText(OutlinedButton, label);

    testWidgets(
      'a parcel that still owes money offers no Archive; a paid one, a draft, a returned one and a Gift / Free one do',
      (t) async {
        for (final (parcel, canArchive) in [
          (testParcel(id: 'a'), false),
          (testParcel(id: 'a', received: 100000), false),
          (testParcel(id: 'a', received: 500000), true),
          (
            testParcel(
              id: 'a',
              status: ParcelStatus.draft,
              reference: '',
              charge: null,
            ),
            true,
          ),
          (
            testParcel(
              id: 'a',
              status: ParcelStatus.returned,
              paymentReviewRequired: true,
            ),
            false,
          ),
          (testParcel(id: 'a', status: ParcelStatus.returned), true),
          (testParcel(id: 'a', method: CollectionMethod.giftFree), true),
        ]) {
          await _open(t, FakeParcelRepository(initial: [parcel]), 'a');
          expect(
            button('Archive Parcel'),
            canArchive ? findsOneWidget : findsNothing,
            reason: '${parcel.status} ${parcel.method} ${parcel.receivedPaisa}',
          );
          await t.pumpWidget(const SizedBox());
        }
      },
    );

    testWidgets(
      'Archive asks first; Cancel keeps the parcel; Archive hides it and shows the Restore banner',
      (t) async {
        final repo = FakeParcelRepository(
          initial: [testParcel(id: 'a', received: 500000)],
        );
        await _open(t, repo, 'a');
        await t.ensureVisible(button('Archive Parcel'));
        await t.pump();
        await t.tap(button('Archive Parcel'));
        await t.pumpAndSettle();
        expect(find.text('Archive this parcel?'), findsOneWidget);
        await t.tap(find.widgetWithText(TextButton, 'Cancel'));
        await t.pumpAndSettle();
        expect(repo.archivedIds, isEmpty);

        await t.tap(button('Archive Parcel'));
        await t.pumpAndSettle();
        await t.tap(find.widgetWithText(TextButton, 'Archive'));
        await t.pumpAndSettle();
        expect(repo.archivedIds, ['a']);
        expect(find.text('Parcel archived.'), findsOneWidget);
        expect(find.text('Archived'), findsWidgets);
        expect(
          find.widgetWithText(FilledButton, 'Restore Parcel'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'an archived parcel is read-only: no Edit, Receive, Correct or action buttons; Restore brings it back',
      (t) async {
        final payment = Payment(
          id: 'p1',
          amountPaisa: 100000,
          type: PaymentType.advance,
          note: null,
          receivedAt: DateTime.utc(2026, 11, 8, 6),
        );
        final repo = FakeParcelRepository(
          initial: [testParcel(id: 'a', received: 100000, isArchived: true)],
        )..payments['a'] = [payment];
        await _open(t, repo, 'a');
        expect(find.byTooltip('Edit parcel'), findsNothing);
        expect(
          find.widgetWithText(FilledButton, 'Mark Payment Received'),
          findsNothing,
        );
        expect(find.text('Correct'), findsNothing);
        expect(find.text('Actions'), findsNothing);
        await t.ensureVisible(
          find.widgetWithText(FilledButton, 'Restore Parcel'),
        );
        await t.pump();
        await t.tap(find.widgetWithText(FilledButton, 'Restore Parcel'));
        await t.pumpAndSettle();
        expect(find.text('Parcel restored.'), findsOneWidget);
        expect(find.byTooltip('Edit parcel'), findsOneWidget);
        expect(
          find.widgetWithText(FilledButton, 'Restore Parcel'),
          findsNothing,
        );
      },
    );

    testWidgets('a refusal from the repository is shown instead of crashing', (
      t,
    ) async {
      final repo = FakeParcelRepository(
        initial: [testParcel(id: 'a', received: 500000, isArchived: true)],
      )..failure = const AppFailure('No internet connection.');
      await _open(t, repo, 'a');
      await t.ensureVisible(
        find.widgetWithText(FilledButton, 'Restore Parcel'),
      );
      await t.pump();
      await t.tap(find.widgetWithText(FilledButton, 'Restore Parcel'));
      await t.pumpAndSettle();
      expect(find.text('No internet connection.'), findsOneWidget);
    });
  });
}

/// First load fails, the next one works.
class _FlakyRepository extends FakeParcelRepository {
  _FlakyRepository(this._parcel);
  final Parcel _parcel;
  int calls = 0;

  @override
  Stream<Parcel?> watch(String id) {
    calls++;
    if (calls == 1) {
      return Stream<Parcel?>.error(const AppFailure('No internet connection.'));
    }
    return Stream.value(_parcel);
  }
}
