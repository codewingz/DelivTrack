import 'dart:typed_data';

import 'package:deliv_track/features/parcels/domain/parcel.dart';
import 'package:deliv_track/features/parcels/domain/parcel_enums.dart';
import 'package:deliv_track/features/parcels/domain/parcel_item.dart';
import 'package:deliv_track/features/pdf/invoice_pdf_builder.dart';
import 'package:deliv_track/features/products/domain/product.dart';
import 'package:deliv_track/features/settings/domain/sender_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InvoicePdfBuilder', () {
    const builder = InvoicePdfBuilder();

    final testParcel = Parcel(
      id: 'p1',
      orderNumber: 'DT-1001',
      orderSequence: 1001,
      customerId: 'c1',
      customerName: 'Muhammad Usman',
      customerPhone: '0300 1234567',
      customerAddress: 'House 14, Street 3, G-9/2, Islamabad',
      items: [
        ParcelItem.pieces(
          productId: 'prod1',
          productName: 'Embroidered Kurta',
          quantity: 2,
          unitPricePaisa: 250000,
          saleUnit: SaleUnit.perPiece,
        ),
        ParcelItem.weight(
          productId: 'prod2',
          productName: 'Organic Dry Fruits',
          weightGrams: 1500,
          unitPricePaisa: 120000,
          saleUnit: SaleUnit.perKg,
        ),
      ],
      method: CollectionMethod.postalCollection,
      postalReference: 'EP123456789PK',
      deliveryChargePaisa: 30000,
      packedWeightGrams: 2000,
      sendingDate: '2026-11-22',
      estimatedPaymentDate: '2026-11-26',
      expectedPaisa: 680000,
      receivedPaisa: 100000,
      outstandingPaisa: 580000,
      paymentStatus: PaymentStatus.partial,
      status: ParcelStatus.sent,
      notes: 'Deliver after 3 PM',
    );

    const testSender = SenderProfile(
      name: 'Zara Collection',
      phone: '0321 9876543',
      address: 'Shop # 12, Liberty Market, Gulberg, Lahore',
    );

    test('builds valid PDF bytes with standard parcel and sender profile', () async {
      final bytes = await builder.build(parcel: testParcel, sender: testSender);

      expect(bytes, isA<Uint8List>());
      expect(bytes.isNotEmpty, isTrue);

      // Verify PDF header magic bytes: %PDF-
      final header = String.fromCharCodes(bytes.take(5));
      expect(header, '%PDF-');
    });

    test('builds valid PDF bytes when parcel is paid in full (0 COD)', () async {
      final paidParcel = Parcel(
        id: 'p2',
        orderNumber: 'DT-1002',
        orderSequence: 1002,
        customerId: 'c1',
        customerName: 'Ayesha Khan',
        customerPhone: '0333 5556677',
        customerAddress: 'Flat 4B, Clifton, Karachi',
        items: [
          ParcelItem.pieces(
            productId: 'prod1',
            productName: 'Silk Scarf',
            quantity: 1,
            unitPricePaisa: 150000,
          ),
        ],
        method: CollectionMethod.advance,
        postalReference: '',
        deliveryChargePaisa: null,
        packedWeightGrams: 300,
        sendingDate: '2026-11-22',
        estimatedPaymentDate: null,
        expectedPaisa: 150000,
        receivedPaisa: 150000,
        outstandingPaisa: 0,
        paymentStatus: PaymentStatus.received,
        status: ParcelStatus.draft,
      );

      final bytes = await builder.build(parcel: paidParcel, sender: testSender);

      expect(bytes, isA<Uint8List>());
      expect(bytes.isNotEmpty, isTrue);
      final header = String.fromCharCodes(bytes.take(5));
      expect(header, '%PDF-');
    });

    test('builds valid PDF bytes with empty sender profile fallback', () async {
      const emptySender = SenderProfile(name: '', phone: '', address: '');

      final bytes = await builder.build(parcel: testParcel, sender: emptySender);

      expect(bytes, isA<Uint8List>());
      expect(bytes.isNotEmpty, isTrue);
      final header = String.fromCharCodes(bytes.take(5));
      expect(header, '%PDF-');
    });
  });
}
