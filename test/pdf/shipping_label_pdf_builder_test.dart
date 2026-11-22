import 'dart:typed_data';

import 'package:deliv_track/features/parcels/domain/parcel.dart';
import 'package:deliv_track/features/parcels/domain/parcel_enums.dart';
import 'package:deliv_track/features/parcels/domain/parcel_item.dart';
import 'package:deliv_track/features/pdf/shipping_label_pdf_builder.dart';
import 'package:deliv_track/features/settings/domain/sender_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShippingLabelPdfBuilder', () {
    const builder = ShippingLabelPdfBuilder();

    final testParcelWithTracking = Parcel(
      id: 'p1',
      orderNumber: 'DT-2001',
      orderSequence: 2001,
      customerId: 'c1',
      customerName: 'Tariq Mehmood',
      customerPhone: '0301 2345678',
      customerAddress: 'Street 9, Sector I-8/4, Islamabad',
      items: [
        ParcelItem.pieces(
          productId: 'prod1',
          productName: 'Leather Wallet',
          quantity: 1,
          unitPricePaisa: 320000,
        ),
      ],
      method: CollectionMethod.postalCollection,
      postalReference: 'PK123456789',
      deliveryChargePaisa: 25000,
      packedWeightGrams: 450,
      sendingDate: '2026-11-22',
      estimatedPaymentDate: '2026-11-25',
      expectedPaisa: 320000,
      receivedPaisa: 0,
      outstandingPaisa: 320000,
      paymentStatus: PaymentStatus.pending,
      status: ParcelStatus.sent,
    );

    const testSender = SenderProfile(
      name: 'Leather Craft PK',
      phone: '0312 9988776',
      address: 'Industrial Area, Sialkot, Punjab',
    );

    test('builds valid A6 shipping label PDF bytes with tracking barcode', () async {
      final bytes = await builder.build(
        parcel: testParcelWithTracking,
        sender: testSender,
      );

      expect(bytes, isA<Uint8List>());
      expect(bytes.isNotEmpty, isTrue);

      // Verify PDF header magic bytes: %PDF-
      final header = String.fromCharCodes(bytes.take(5));
      expect(header, '%PDF-');
    });

    test('builds valid shipping label PDF bytes when postal reference is empty (order # barcode)', () async {
      final parcelWithoutTracking = Parcel(
        id: 'p2',
        orderNumber: 'DT-2002',
        orderSequence: 2002,
        customerId: 'c2',
        customerName: 'Fatima Noor',
        customerPhone: '0345 6789012',
        customerAddress: 'House 88, DHA Phase 5, Lahore',
        items: [
          ParcelItem.pieces(
            productId: 'prod2',
            productName: 'Cotton Kurti',
            quantity: 3,
            unitPricePaisa: 180000,
          ),
        ],
        method: CollectionMethod.advance,
        postalReference: '',
        deliveryChargePaisa: null,
        packedWeightGrams: null,
        sendingDate: '2026-11-22',
        estimatedPaymentDate: null,
        expectedPaisa: 540000,
        receivedPaisa: 540000,
        outstandingPaisa: 0,
        paymentStatus: PaymentStatus.received,
        status: ParcelStatus.draft,
      );

      final bytes = await builder.build(
        parcel: parcelWithoutTracking,
        sender: testSender,
      );

      expect(bytes, isA<Uint8List>());
      expect(bytes.isNotEmpty, isTrue);
      final header = String.fromCharCodes(bytes.take(5));
      expect(header, '%PDF-');
    });

    test('builds valid shipping label with empty sender profile fallback', () async {
      const emptySender = SenderProfile(name: '', phone: '', address: '');

      final bytes = await builder.build(
        parcel: testParcelWithTracking,
        sender: emptySender,
      );

      expect(bytes, isA<Uint8List>());
      expect(bytes.isNotEmpty, isTrue);
      final header = String.fromCharCodes(bytes.take(5));
      expect(header, '%PDF-');
    });
  });
}
