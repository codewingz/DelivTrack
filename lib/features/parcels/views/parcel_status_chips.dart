import 'package:flutter/material.dart';
import '../../../common_widgets/status_chip.dart';
import '../../../constants/app_colors.dart';
import '../domain/parcel_enums.dart';

/// Parcel status and payment status as chips (shared by the list and the details screen).
class ParcelStatusChips extends StatelessWidget {
  const ParcelStatusChips({super.key, required this.status, required this.payment});
  final ParcelStatus status;
  final PaymentStatus payment;

  static Color _statusColor(ParcelStatus s) => switch (s) {
        ParcelStatus.draft => AppColors.pending,
        ParcelStatus.sent => AppColors.primary,
        ParcelStatus.returned => AppColors.credit,
      };

  static Color _paymentColor(PaymentStatus p) => switch (p) {
        PaymentStatus.notRequired => AppColors.freeGift,
        PaymentStatus.pending => AppColors.pending,
        PaymentStatus.partial => AppColors.advance,
        PaymentStatus.received => AppColors.success,
      };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        StatusChip(label: status.label, color: _statusColor(status)),
        StatusChip(label: payment.label, color: _paymentColor(payment)),
      ],
    );
  }
}
