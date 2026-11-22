import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/money/money.dart';
import '../parcels/domain/parcel.dart';
import '../settings/domain/sender_profile.dart';

/// Builds a professional customer invoice PDF document.
class InvoicePdfBuilder {
  const InvoicePdfBuilder();

  static const PdfColor _primary = PdfColor.fromInt(0xFF0F766E); // Emerald #0F766E
  static const PdfColor _darkText = PdfColor.fromInt(0xFF1E293B);
  static const PdfColor _lightGrey = PdfColor.fromInt(0xFFF1F5F9);
  static const PdfColor _borderGrey = PdfColor.fromInt(0xFFCBD5E1);
  static const PdfColor _mutedText = PdfColor.fromInt(0xFF64748B);

  Future<Uint8List> build({
    required Parcel parcel,
    required SenderProfile sender,
  }) async {
    final doc = pw.Document(title: 'Invoice #${parcel.orderNumber}');

    final merchantName = sender.name.isNotEmpty ? sender.name : 'DelivTrack Merchant';
    final merchantPhone = sender.phone;
    final merchantAddress = sender.address;

    final deliveryPaisa = parcel.deliveryChargePaisa ?? 0;
    final totalExpectedPaisa = parcel.expectedPaisa + deliveryPaisa;
    final receivedPaisa = parcel.receivedPaisa;
    final balancePaisa = parcel.outstandingPaisa;

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          merchantName,
                          style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            color: _primary,
                          ),
                        ),
                        if (merchantPhone.isNotEmpty) ...[
                          pw.SizedBox(height: 3),
                          pw.Text(
                            'Phone: $merchantPhone',
                            style: const pw.TextStyle(fontSize: 10, color: _darkText),
                          ),
                        ],
                        if (merchantAddress.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(
                            merchantAddress,
                            style: const pw.TextStyle(fontSize: 10, color: _mutedText),
                          ),
                        ],
                      ],
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'INVOICE',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: _primary,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Order: #${parcel.orderNumber}',
                        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        'Date: ${parcel.sendingDate}',
                        style: const pw.TextStyle(fontSize: 10, color: _mutedText),
                      ),
                      if (parcel.postalReference.isNotEmpty)
                        pw.Text(
                          'Tracking: ${parcel.postalReference}',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _primary),
                        ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 16),
              pw.Divider(color: _borderGrey, thickness: 1),
              pw.SizedBox(height: 12),

              // Customer / Bill To
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: _lightGrey,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'BILL TO / RECIPIENT',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: _mutedText,
                              letterSpacing: 0.5,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            parcel.customerName,
                            style: pw.TextStyle(
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold,
                              color: _darkText,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Phone: ${parcel.customerPhone}',
                            style: const pw.TextStyle(fontSize: 11, color: _darkText),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            parcel.customerAddress,
                            style: const pw.TextStyle(fontSize: 10, color: _darkText),
                          ),
                        ],
                      ),
                    ),
                    if (parcel.packedWeightGrams != null && parcel.packedWeightGrams! > 0)
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'WEIGHT',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: _mutedText,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            formatKg(parcel.packedWeightGrams!),
                            style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: _darkText,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              pw.SizedBox(height: 16),

              // Items Table
              pw.Text(
                'ORDER ITEMS',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: _mutedText,
                  letterSpacing: 0.5,
                ),
              ),
              pw.SizedBox(height: 6),

              pw.Table(
                border: pw.TableBorder(
                  horizontalInside: const pw.BorderSide(color: _borderGrey, width: 0.5),
                  bottom: const pw.BorderSide(color: _borderGrey, width: 1),
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(4),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: _lightGrey),
                    children: [
                      _th('Item Description'),
                      _th('Quantity / Unit', align: pw.TextAlign.center),
                      _th('Unit Price', align: pw.TextAlign.right),
                      _th('Total', align: pw.TextAlign.right),
                    ],
                  ),
                  for (final item in parcel.items)
                    pw.TableRow(
                      children: [
                        _td(item.productName),
                        _td(
                          item.quantity != null
                              ? '${item.quantity} ${item.saleUnit.label}'
                              : (item.weightGrams != null ? formatKg(item.weightGrams!) : '-'),
                          align: pw.TextAlign.center,
                        ),
                        _td(formatRupees(item.unitPricePaisa), align: pw.TextAlign.right),
                        _td(formatRupees(item.lineTotalPaisa), align: pw.TextAlign.right, isBold: true),
                      ],
                    ),
                ],
              ),

              pw.SizedBox(height: 16),

              // Financial Summary
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // Left side: Payment Status badge and notes
                  pw.Expanded(
                    flex: 5,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: pw.BoxDecoration(
                            color: balancePaisa == 0 ? const PdfColor(0.85, 0.95, 0.88) : const PdfColor(1.0, 0.94, 0.84),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                            border: pw.Border.all(
                              color: balancePaisa == 0 ? const PdfColor(0.3, 0.7, 0.4) : const PdfColor(0.9, 0.6, 0.2),
                              width: 1,
                            ),
                          ),
                          child: pw.Text(
                            balancePaisa == 0
                                ? 'STATUS: PAID IN FULL'
                                : 'STATUS: CASH ON DELIVERY (COD)',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: balancePaisa == 0 ? const PdfColor(0.1, 0.5, 0.2) : const PdfColor(0.7, 0.4, 0.0),
                            ),
                          ),
                        ),
                        if (parcel.notes != null && parcel.notes!.isNotEmpty) ...[
                          pw.SizedBox(height: 8),
                          pw.Text(
                            'Special Instructions / Notes:',
                            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _mutedText),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            parcel.notes!,
                            style: const pw.TextStyle(fontSize: 9, color: _darkText),
                          ),
                        ],
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 24),

                  // Right side: Totals
                  pw.Expanded(
                    flex: 5,
                    child: pw.Column(
                      children: [
                        _summaryRow('Products Subtotal', formatRupees(parcel.expectedPaisa)),
                        if (parcel.deliveryChargePaisa != null)
                          _summaryRow('Delivery Charge', formatRupees(parcel.deliveryChargePaisa!)),
                        pw.Divider(color: _borderGrey, thickness: 0.5),
                        _summaryRow('Total Expected', formatRupees(totalExpectedPaisa), isBold: true),
                        if (receivedPaisa > 0)
                          _summaryRow('Advance Received', '-${formatRupees(receivedPaisa)}'),
                        pw.SizedBox(height: 4),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: const pw.BoxDecoration(
                            color: _lightGrey,
                            borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                          ),
                          child: _summaryRow(
                            'Balance Due (COD)',
                            formatRupees(balancePaisa),
                            isBold: true,
                            textColor: _primary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.Spacer(),

              // Footer
              pw.Divider(color: _borderGrey, thickness: 0.5),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Thank you for your order!',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _primary),
                  ),
                  pw.Text(
                    'Generated via DelivTrack',
                    style: const pw.TextStyle(fontSize: 8, color: _mutedText),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  static pw.Widget _th(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _darkText),
      ),
    );
  }

  static pw.Widget _td(String text, {pw.TextAlign align = pw.TextAlign.left, bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: _darkText,
        ),
      ),
    );
  }

  static pw.Widget _summaryRow(
    String label,
    String value, {
    bool isBold = false,
    PdfColor? textColor,
    double fontSize = 10,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: textColor ?? _darkText,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: textColor ?? _darkText,
            ),
          ),
        ],
      ),
    );
  }
}
