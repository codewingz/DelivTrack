import 'package:flutter/material.dart';

import '../../../common_widgets/status_chip.dart';
import '../../../constants/app_colors.dart';
import '../domain/parcel_enums.dart';

/// Parcel status and payment status as chips (shared by the list and the details screen).
class ParcelStatusChips extends StatelessWidget {
  const ParcelStatusChips({
    super.key,
    required this.status,
    required this.payment,
    this.reviewRequired = false,
  });
  final ParcelStatus status;
  final PaymentStatus payment;

  /// A returned parcel with money received or owed.
  final bool reviewRequired;

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
        if (reviewRequired)
          const StatusChip(
            label: 'Requires payment review',
            color: AppColors.error,
          ),
      ],
    );
  }
}
