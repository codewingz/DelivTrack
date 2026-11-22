import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../design_system/foundations/radius/app_radius.dart';
import '../../design_system/foundations/spacing/app_spacing.dart';
import '../parcels/domain/parcel.dart';
import '../settings/data/sender_profile_repository.dart';
import '../settings/domain/sender_profile.dart';
import 'parcel_document_service.dart';

/// Opens the Invoice & Slips options bottom sheet for [parcel].
Future<void> showParcelDocumentSheet({
  required BuildContext context,
  required Parcel parcel,
  required SenderProfileRepository senderRepo,
  ParcelDocumentService service = const PrintingParcelDocumentService(),
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (ctx) => _ParcelDocumentSheet(
      parcel: parcel,
      senderRepo: senderRepo,
      service: service,
    ),
  );
}

class _ParcelDocumentSheet extends StatefulWidget {
  const _ParcelDocumentSheet({
    required this.parcel,
    required this.senderRepo,
    required this.service,
  });

  final Parcel parcel;
  final SenderProfileRepository senderRepo;
  final ParcelDocumentService service;

  @override
  State<_ParcelDocumentSheet> createState() => _ParcelDocumentSheetState();
}

class _ParcelDocumentSheetState extends State<_ParcelDocumentSheet> {
  bool _busy = false;

  Future<void> _handleAction(
    Future<bool> Function(SenderProfile sender) action,
    String successMessage,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final sender = await widget.senderRepo.getProfile() ??
          const SenderProfile(name: '', phone: '', address: '');
      final ok = await action(sender);
      if (mounted) {
        Navigator.of(context).pop();
        if (ok) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(successMessage),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Could not complete document action. Please try again.'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: AppSpacing.lg,
        end: AppSpacing.lg,
        bottom: AppSpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.all(Radius.circular(AppRadius.chip)),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Invoice & Slips',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Order #${widget.parcel.orderNumber} • ${widget.parcel.customerName}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.label,
                      ),
                    ),
                  ],
                ),
              ),
              if (_busy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _ActionTile(
            icon: Icons.share_rounded,
            title: 'Send Invoice via WhatsApp',
            subtitle: 'Attaches PDF invoice with order details ready to send',
            enabled: !_busy,
            isPrimary: true,
            onTap: () => _handleAction(
              (sender) => widget.service.shareInvoice(
                parcel: widget.parcel,
                sender: sender,
              ),
              'Invoice shared.',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _ActionTile(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Open WhatsApp Chat',
            subtitle: 'Direct chat with ${widget.parcel.customerPhone} with prefilled greeting',
            enabled: !_busy,
            onTap: () => _handleAction(
              (sender) => widget.service.openWhatsApp(
                parcel: widget.parcel,
                sender: sender,
              ),
              'Opening WhatsApp chat...',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _ActionTile(
            icon: Icons.print_outlined,
            title: 'Print / Preview Invoice',
            subtitle: 'A4 customer invoice for record keeping or packaging',
            enabled: !_busy,
            onTap: () => _handleAction(
              (sender) => widget.service.printInvoice(
                parcel: widget.parcel,
                sender: sender,
              ),
              'Opening invoice print preview...',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _ActionTile(
            icon: Icons.local_shipping_outlined,
            title: 'Print Box Shipping Label',
            subtitle: 'A6 label with barcode & COD amount for parcel box/flyer',
            enabled: !_busy,
            onTap: () => _handleAction(
              (sender) => widget.service.printShippingLabel(
                parcel: widget.parcel,
                sender: sender,
              ),
              'Opening shipping label print preview...',
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
    this.isPrimary = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isPrimary ? AppColors.background : AppColors.surface,
      borderRadius: const BorderRadius.all(Radius.circular(AppRadius.control)),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.control)),
        child: Container(
          padding: const EdgeInsetsDirectional.all(AppSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(
              color: isPrimary ? AppColors.primary : AppColors.border,
              width: isPrimary ? 1.5 : 1.0,
            ),
            borderRadius: const BorderRadius.all(Radius.circular(AppRadius.control)),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isPrimary ? AppColors.primary : AppColors.label,
                size: 24,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isPrimary ? AppColors.primary : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.label,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isPrimary ? AppColors.primary : AppColors.textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
