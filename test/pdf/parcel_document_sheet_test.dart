import 'package:deliv_track/features/parcels/domain/parcel.dart';
import 'package:deliv_track/features/parcels/domain/parcel_enums.dart';
import 'package:deliv_track/features/parcels/domain/parcel_item.dart';
import 'package:deliv_track/features/pdf/parcel_document_service.dart';
import 'package:deliv_track/features/pdf/parcel_document_sheet.dart';
import 'package:deliv_track/features/settings/domain/sender_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_sender_profile_repository.dart';

class _FakeDocumentService implements ParcelDocumentService {
  int shareCount = 0;
  int whatsAppCount = 0;
  int trackingCount = 0;
  int printInvoiceCount = 0;
  int printLabelCount = 0;

  @override
  Future<bool> shareInvoice({
    required Parcel parcel,
    required SenderProfile sender,
  }) async {
    shareCount++;
    return true;
  }

  @override
  Future<bool> openWhatsApp({
    required Parcel parcel,
    required SenderProfile sender,
  }) async {
    whatsAppCount++;
    return true;
  }

  @override
  Future<bool> openTrackingWhatsApp({
    required Parcel parcel,
    required SenderProfile sender,
    String? trackingNumber,
  }) async {
    trackingCount++;
    return true;
  }

  @override
  Future<bool> printInvoice({
    required Parcel parcel,
    required SenderProfile sender,
  }) async {
    printInvoiceCount++;
    return true;
  }

  @override
  Future<bool> printShippingLabel({
    required Parcel parcel,
    required SenderProfile sender,
  }) async {
    printLabelCount++;
    return true;
  }
}

void main() {
  group('ParcelDocumentSheet', () {
    final parcel = Parcel(
      id: 'p1',
      orderNumber: 'DT-1001',
      orderSequence: 1001,
      customerId: 'c1',
      customerName: 'Muhammad Usman',
      customerPhone: '0300 1234567',
      customerAddress: 'House 14, Islamabad',
      items: [
        ParcelItem.pieces(
          productId: 'prod1',
          productName: 'Leather Wallet',
          quantity: 1,
          unitPricePaisa: 250000,
        ),
      ],
      method: CollectionMethod.postalCollection,
      postalReference: 'EP123456789PK',
      deliveryChargePaisa: 25000,
      packedWeightGrams: 500,
      sendingDate: '2026-11-22',
      estimatedPaymentDate: '2026-11-25',
      expectedPaisa: 250000,
      receivedPaisa: 0,
      outstandingPaisa: 250000,
      paymentStatus: PaymentStatus.pending,
      status: ParcelStatus.sent,
    );

    const sender = SenderProfile(
      name: 'Zara Collection',
      phone: '0321 9876543',
      address: 'Shop 12, Lahore',
    );

    testWidgets('shows all document actions and triggers share invoice', (t) async {
      final fakeService = _FakeDocumentService();
      final senderRepo = FakeSenderProfileRepository(initial: sender);

      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showParcelDocumentSheet(
                  context: context,
                  parcel: parcel,
                  senderRepo: senderRepo,
                  service: fakeService,
                ),
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      await t.tap(find.text('Open Sheet'));
      await t.pumpAndSettle();

      expect(find.text('Invoice & Slips'), findsOneWidget);
      expect(find.text('Order #DT-1001 • Muhammad Usman'), findsOneWidget);
      expect(find.text('Send Invoice via WhatsApp'), findsOneWidget);
      expect(find.text('Open WhatsApp Chat'), findsOneWidget);
      expect(find.text('Print / Preview Invoice'), findsOneWidget);
      expect(find.text('Print Box Shipping Label'), findsOneWidget);

      // Tap Send Invoice via WhatsApp
      await t.tap(find.text('Send Invoice via WhatsApp'));
      await t.pumpAndSettle();

      expect(fakeService.shareCount, 1);
      expect(find.text('Invoice shared.'), findsOneWidget);
    });

    testWidgets('triggers direct WhatsApp chat', (t) async {
      final fakeService = _FakeDocumentService();
      final senderRepo = FakeSenderProfileRepository(initial: sender);

      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showParcelDocumentSheet(
                  context: context,
                  parcel: parcel,
                  senderRepo: senderRepo,
                  service: fakeService,
                ),
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      await t.tap(find.text('Open Sheet'));
      await t.pumpAndSettle();

      await t.tap(find.text('Open WhatsApp Chat'));
      await t.pumpAndSettle();

      expect(fakeService.whatsAppCount, 1);
      expect(find.text('Opening WhatsApp chat...'), findsOneWidget);
    });

    testWidgets('triggers print shipping label', (t) async {
      final fakeService = _FakeDocumentService();
      final senderRepo = FakeSenderProfileRepository(initial: sender);

      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showParcelDocumentSheet(
                  context: context,
                  parcel: parcel,
                  senderRepo: senderRepo,
                  service: fakeService,
                ),
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      await t.tap(find.text('Open Sheet'));
      await t.pumpAndSettle();

      await t.tap(find.text('Print Box Shipping Label'));
      await t.pumpAndSettle();

      expect(fakeService.printLabelCount, 1);
      expect(find.text('Opening shipping label print preview...'), findsOneWidget);
    });

    testWidgets('triggers send post office tracking via WhatsApp', (t) async {
      final fakeService = _FakeDocumentService();
      final senderRepo = FakeSenderProfileRepository(initial: sender);

      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showParcelDocumentSheet(
                  context: context,
                  parcel: parcel,
                  senderRepo: senderRepo,
                  service: fakeService,
                ),
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      await t.tap(find.text('Open Sheet'));
      await t.pumpAndSettle();

      await t.tap(find.text('Send Post Office Tracking'));
      await t.pumpAndSettle();

      expect(fakeService.trackingCount, 1);
      expect(find.text('Opening WhatsApp with tracking details...'), findsOneWidget);
    });
  });

  group('PrintingParcelDocumentService', () {
    test('buildInvoiceMessage generates friendly WhatsApp message', () {
      final parcel = Parcel(
        id: 'p1',
        orderNumber: 'DT-3001',
        orderSequence: 3001,
        customerId: 'c1',
        customerName: 'Ahmad Bilal',
        customerPhone: '0300 7654321',
        customerAddress: 'House 5, Street 1, Rawalpindi',
        items: [
          ParcelItem.pieces(
            productId: 'prod1',
            productName: 'Cotton Kurta',
            quantity: 2,
            unitPricePaisa: 200000,
          ),
        ],
        method: CollectionMethod.postalCollection,
        postalReference: '',
        deliveryChargePaisa: 25000,
        packedWeightGrams: 400,
        sendingDate: '2026-11-22',
        estimatedPaymentDate: null,
        expectedPaisa: 400000,
        receivedPaisa: 100000,
        outstandingPaisa: 300000,
        paymentStatus: PaymentStatus.partial,
        status: ParcelStatus.draft,
      );

      const sender = SenderProfile(
        name: 'Royal Boutique',
        phone: '0300 1122334',
        address: 'Commercial Market, Rawalpindi',
      );

      final msg = PrintingParcelDocumentService.buildInvoiceMessage(
        parcel: parcel,
        sender: sender,
      );

      expect(msg, contains('Assalam-o-Alaikum Ahmad Bilal'));
      expect(msg, contains('Royal Boutique'));
      expect(msg, contains('#DT-3001'));
      expect(msg, contains('Cotton Kurta'));
      expect(msg, contains('Rs. 4,250'));
      expect(msg, contains('Cash on Delivery (COD) to pay: Rs. 3,000'));
    });

    test('buildTrackingMessage generates dispatch message with ep.gov.pk link', () {
      final parcel = Parcel(
        id: 'p1',
        orderNumber: 'DT-4001',
        orderSequence: 4001,
        customerId: 'c1',
        customerName: 'Zainab Bibi',
        customerPhone: '0311 9988776',
        customerAddress: 'Gulberg 3, Lahore',
        items: [
          ParcelItem.pieces(
            productId: 'prod1',
            productName: 'Chiffon Dupatta',
            quantity: 1,
            unitPricePaisa: 150000,
          ),
        ],
        method: CollectionMethod.postalCollection,
        postalReference: 'PK987654321',
        deliveryChargePaisa: 20000,
        packedWeightGrams: 300,
        sendingDate: '2026-11-22',
        estimatedPaymentDate: null,
        expectedPaisa: 150000,
        receivedPaisa: 0,
        outstandingPaisa: 150000,
        paymentStatus: PaymentStatus.pending,
        status: ParcelStatus.sent,
      );

      const sender = SenderProfile(
        name: 'Eastern Threads',
        phone: '0321 0001122',
        address: 'Mall Road, Lahore',
      );

      final msg = PrintingParcelDocumentService.buildTrackingMessage(
        parcel: parcel,
        sender: sender,
      );

      expect(msg, contains('Assalam-o-Alaikum Zainab Bibi'));
      expect(msg, contains('#DT-4001'));
      expect(msg, contains('PK987654321'));
      expect(msg, contains('https://ep.gov.pk'));
      expect(msg, contains('Eastern Threads'));
      expect(msg, contains('Rs. 1,700'));
      expect(msg, contains('Cash on Delivery (COD) to pay: Rs. 1,500'));
    });
  });
}
