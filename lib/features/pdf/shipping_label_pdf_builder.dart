import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/money/money.dart';
import '../parcels/domain/parcel.dart';
import '../settings/domain/sender_profile.dart';

/// Builds a shipping label PDF formatted for parcel box/flyer pouch printing (A6 format).
class ShippingLabelPdfBuilder {
  const ShippingLabelPdfBuilder();

  static const PdfColor _dark = PdfColor.fromInt(0xFF000000);
  static const PdfColor _greyBg = PdfColor.fromInt(0xFFF1F5F9);
  static const PdfColor _border = PdfColor.fromInt(0xFF000000);

  Future<Uint8List> build({
    required Parcel parcel,
    required SenderProfile sender,
  }) async {
    final doc = pw.Document(title: 'Shipping Label #${parcel.orderNumber}');

    final senderName = sender.name.isNotEmpty ? sender.name : 'Merchant (Sender)';
    final senderPhone = sender.phone;
    final senderAddress = sender.address;

    final codAmountPaisa = parcel.outstandingPaisa;
    final isCod = codAmountPaisa > 0;
    final barcodeData = parcel.postalReference.isNotEmpty
        ? parcel.postalReference
        : parcel.orderNumber;

    final weightGrams = parcel.packedWeightGrams ?? 0;

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a6,
        margin: const pw.EdgeInsets.all(12),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: _border, width: 1.5)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'PAKISTAN POST',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'DELIVTRACK',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: const PdfColor(0.2, 0.2, 0.2),
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 6),

              // Barcode & Tracking
              pw.Center(
                child: pw.SizedBox(
                  height: 38,
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.code128(),
                    data: barcodeData,
                    drawText: false,
                  ),
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Center(
                child: pw.Text(
                  parcel.postalReference.isNotEmpty
                      ? 'TRACKING: ${parcel.postalReference}'
                      : 'ORDER: #${parcel.orderNumber}',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),

              pw.SizedBox(height: 6),

              // COD / Cash Collection Box (High visibility for couriers)
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                decoration: pw.BoxDecoration(
                  color: isCod ? _greyBg : const PdfColor(0.9, 0.95, 0.9),
                  border: pw.Border.all(color: _border, width: 2),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          isCod ? 'COLLECT CASH ON DELIVERY (COD)' : 'PREPAID - DO NOT COLLECT CASH',
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: _dark,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          isCod ? formatRupees(codAmountPaisa) : 'PAID IN FULL',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: _dark,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'WEIGHT',
                          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          weightGrams > 0 ? formatKg(weightGrams) : '-',
                          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 8),

              // Deliver To (Recipient) - Primary focus
              pw.Container(
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _border, width: 1.2),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'DELIVER TO (CUSTOMER):',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: const PdfColor(0.3, 0.3, 0.3),
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            parcel.customerName,
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        pw.Text(
                          parcel.customerPhone,
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      parcel.customerAddress,
                      style: const pw.TextStyle(fontSize: 9),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 6),

              // Return To (Sender) - Secondary focus
              pw.Container(
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: const PdfColor(0.5, 0.5, 0.5), width: 0.8),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'RETURN TO (IF UNDELIVERED):',
                      style: pw.TextStyle(
                        fontSize: 7.5,
                        fontWeight: pw.FontWeight.bold,
                        color: const PdfColor(0.3, 0.3, 0.3),
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            senderName,
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        if (senderPhone.isNotEmpty)
                          pw.Text(
                            senderPhone,
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                    if (senderAddress.isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        senderAddress,
                        style: const pw.TextStyle(fontSize: 8, color: PdfColor(0.2, 0.2, 0.2)),
                        maxLines: 2,
                      ),
                    ],
                  ],
                ),
              ),

              pw.Spacer(),

              // Items summary & date
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 6),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(top: pw.BorderSide(color: PdfColor(0.7, 0.7, 0.7), width: 0.5)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        'Items: ${parcel.items.map((i) => i.productName).join(', ')}',
                        style: const pw.TextStyle(fontSize: 7.5, color: PdfColor(0.3, 0.3, 0.3)),
                        maxLines: 1,
                      ),
                    ),
                    pw.Text(
                      'Date: ${parcel.sendingDate}',
                      style: const pw.TextStyle(fontSize: 7.5, color: PdfColor(0.3, 0.3, 0.3)),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }
}
