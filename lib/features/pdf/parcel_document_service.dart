import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/money/money.dart';
import '../../utils/phone.dart';
import '../parcels/domain/parcel.dart';
import '../settings/domain/sender_profile.dart';
import 'invoice_pdf_builder.dart';
import 'shipping_label_pdf_builder.dart';

abstract class ParcelDocumentService {
  Future<bool> shareInvoice({
    required Parcel parcel,
    required SenderProfile sender,
  });

  Future<bool> openWhatsApp({
    required Parcel parcel,
    required SenderProfile sender,
  });

  Future<bool> printInvoice({
    required Parcel parcel,
    required SenderProfile sender,
  });

  Future<bool> printShippingLabel({
    required Parcel parcel,
    required SenderProfile sender,
  });

  Future<bool> openTrackingWhatsApp({
    required Parcel parcel,
    required SenderProfile sender,
    String? trackingNumber,
  });
}

class PrintingParcelDocumentService implements ParcelDocumentService {
  const PrintingParcelDocumentService({
    this.invoiceBuilder = const InvoicePdfBuilder(),
    this.labelBuilder = const ShippingLabelPdfBuilder(),
  });

  final InvoicePdfBuilder invoiceBuilder;
  final ShippingLabelPdfBuilder labelBuilder;

  static const _channel = MethodChannel('com.codewingz.delivtrack/whatsapp');

  static String buildInvoiceMessage({
    required Parcel parcel,
    required SenderProfile sender,
  }) {
    final senderName = sender.name.isNotEmpty ? sender.name : 'our store';
    final totalExpected = parcel.expectedPaisa + (parcel.deliveryChargePaisa ?? 0);
    final itemsSummary = parcel.items.map((i) => i.productName).join(', ');

    final balanceLine = parcel.outstandingPaisa > 0
        ? '💵 Cash on Delivery (COD) to pay: ${formatRupees(parcel.outstandingPaisa)}'
        : '✅ Payment Status: Paid in full';

    return 'Assalam-o-Alaikum ${parcel.customerName},\n\n'
        'Thank you for your order with $senderName!\n\n'
        '📦 Order: #${parcel.orderNumber}\n'
        '📋 Items: $itemsSummary\n'
        '💰 Total Amount: ${formatRupees(totalExpected)}\n'
        '$balanceLine\n\n'
        'Please find your official invoice attached.';
  }

  @override
  Future<bool> shareInvoice({
    required Parcel parcel,
    required SenderProfile sender,
  }) async {
    final bytes = await invoiceBuilder.build(parcel: parcel, sender: sender);
    final message = buildInvoiceMessage(parcel: parcel, sender: sender);
    final rawPhone = parcel.customerPhone;
    final digits = normalizePhone(rawPhone);
    final waPhone = digits.startsWith('03') && digits.length == 11
        ? '92${digits.substring(1)}'
        : digits;

    try {
      final ok = await _channel.invokeMethod<bool>('sharePdfToWhatsApp', {
        'bytes': bytes,
        'fileName': 'Invoice_${parcel.orderNumber}.pdf',
        'phone': waPhone,
        'message': message,
      });
      if (ok == true) return true;
    } catch (_) {
      // Fallback below
    }

    return Printing.sharePdf(
      bytes: bytes,
      filename: 'Invoice_${parcel.orderNumber}.pdf',
      subject: 'Invoice #${parcel.orderNumber} - ${parcel.customerName}',
      body: message,
    );
  }

  @override
  Future<bool> openWhatsApp({
    required Parcel parcel,
    required SenderProfile sender,
  }) async {
    final rawPhone = parcel.customerPhone;
    final digits = normalizePhone(rawPhone);
    final waPhone = digits.startsWith('03') && digits.length == 11
        ? '92${digits.substring(1)}'
        : digits;
    final message = buildInvoiceMessage(parcel: parcel, sender: sender);

    try {
      final ok = await _channel.invokeMethod<bool>('openWhatsAppChat', {
        'phone': waPhone,
        'message': message,
      });
      if (ok == true) return true;
    } catch (_) {
      // Fallback to url scheme
    }

    final nativeUrl = Uri.parse(
      'whatsapp://send?phone=$waPhone&text=${Uri.encodeComponent(message)}',
    );
    try {
      if (await canLaunchUrl(nativeUrl)) {
        return await launchUrl(nativeUrl, mode: LaunchMode.externalApplication);
      }
      final webUrl = Uri.parse(
        'https://wa.me/$waPhone?text=${Uri.encodeComponent(message)}',
      );
      return await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> printInvoice({
    required Parcel parcel,
    required SenderProfile sender,
  }) async {
    return Printing.layoutPdf(
      name: 'Invoice_${parcel.orderNumber}',
      onLayout: (format) async => invoiceBuilder.build(
        parcel: parcel,
        sender: sender,
      ),
    );
  }

  @override
  Future<bool> printShippingLabel({
    required Parcel parcel,
    required SenderProfile sender,
  }) async {
    return Printing.layoutPdf(
      name: 'Label_${parcel.orderNumber}',
      onLayout: (format) async => labelBuilder.build(
        parcel: parcel,
        sender: sender,
      ),
    );
  }

  static String buildTrackingMessage({
    required Parcel parcel,
    required SenderProfile sender,
    String? trackingNumber,
  }) {
    final senderName = sender.name.isNotEmpty ? sender.name : 'our store';
    final tracking = (trackingNumber != null && trackingNumber.isNotEmpty)
        ? trackingNumber
        : parcel.postalReference;
    final totalExpected = parcel.expectedPaisa + (parcel.deliveryChargePaisa ?? 0);
    final balanceLine = parcel.outstandingPaisa > 0
        ? '💵 Cash on Delivery (COD) to pay: ${formatRupees(parcel.outstandingPaisa)}'
        : '✅ Payment: Paid in full';

    return 'Assalam-o-Alaikum ${parcel.customerName},\n\n'
        'Your parcel for order #${parcel.orderNumber} has been dispatched via Pakistan Post!\n\n'
        '📦 Tracking Number: $tracking\n'
        '🌐 Track online: https://ep.gov.pk\n'
        '💰 Total Amount: ${formatRupees(totalExpected)}\n'
        '$balanceLine\n\n'
        'Thank you for ordering with $senderName!';
  }

  @override
  Future<bool> openTrackingWhatsApp({
    required Parcel parcel,
    required SenderProfile sender,
    String? trackingNumber,
  }) async {
    final rawPhone = parcel.customerPhone;
    final digits = normalizePhone(rawPhone);
    final waPhone = digits.startsWith('03') && digits.length == 11
        ? '92${digits.substring(1)}'
        : digits;
    final message = buildTrackingMessage(
      parcel: parcel,
      sender: sender,
      trackingNumber: trackingNumber,
    );

    try {
      final ok = await _channel.invokeMethod<bool>('openWhatsAppChat', {
        'phone': waPhone,
        'message': message,
      });
      if (ok == true) return true;
    } catch (_) {
      // Fallback
    }

    final nativeUrl = Uri.parse(
      'whatsapp://send?phone=$waPhone&text=${Uri.encodeComponent(message)}',
    );
    try {
      if (await canLaunchUrl(nativeUrl)) {
        return await launchUrl(nativeUrl, mode: LaunchMode.externalApplication);
      }
      final webUrl = Uri.parse(
        'https://wa.me/$waPhone?text=${Uri.encodeComponent(message)}',
      );
      return await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}

/// Fallback / mock implementation for unit and widget tests.
class NoParcelDocumentService implements ParcelDocumentService {
  const NoParcelDocumentService();

  @override
  Future<bool> shareInvoice({
    required Parcel parcel,
    required SenderProfile sender,
  }) async => true;

  @override
  Future<bool> openWhatsApp({
    required Parcel parcel,
    required SenderProfile sender,
  }) async => true;

  @override
  Future<bool> printInvoice({
    required Parcel parcel,
    required SenderProfile sender,
  }) async => true;

  @override
  Future<bool> printShippingLabel({
    required Parcel parcel,
    required SenderProfile sender,
  }) async => true;

  @override
  Future<bool> openTrackingWhatsApp({
    required Parcel parcel,
    required SenderProfile sender,
    String? trackingNumber,
  }) async => true;
}
