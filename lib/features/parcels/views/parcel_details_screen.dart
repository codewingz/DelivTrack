import '../../../common_widgets/app_snack_bar.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../common_widgets/app_3d_decorations.dart';
import '../../../common_widgets/confirm_dialog.dart';
import '../../../core/errors/app_failure.dart';
import '../../../common_widgets/empty_state.dart';
import '../../../common_widgets/liquid_glass.dart';
import '../../../common_widgets/list_skeleton.dart';
import '../../../common_widgets/primary_button.dart';
import '../../../constants/app_colors.dart';
import '../../../core/money/money.dart';
import '../../../core/time/pakistan_time.dart';
import '../../../design_system/foundations/radius/app_radius.dart';
import '../../../design_system/foundations/spacing/app_spacing.dart';
import '../data/parcel_repository.dart';
import '../domain/parcel.dart';
import '../domain/parcel_enums.dart';
import '../domain/parcel_handover.dart';
import '../domain/payment.dart';
import '../../pdf/parcel_document_service.dart';
import '../../settings/data/sender_profile_repository.dart';
import '../../settings/domain/sender_profile.dart';
import 'parcel_action_sheets.dart';
import 'payment_sheet.dart';
import 'parcel_status_chips.dart';

/// One parcel's details with an Edit action. Payment and return actions are added by their own features.
class ParcelDetailsScreen extends StatefulWidget {
  const ParcelDetailsScreen({
    super.key,
    required this.repository,
    required this.parcelId,
    required this.onEdit,
    this.senderProfileRepository = const NoSenderProfileRepository(),
    this.documentService = const PrintingParcelDocumentService(),
  });
  final ParcelRepository repository;
  final String parcelId;

  /// Opens the edit form; completes with the parcel id once saved, or null if cancelled.
  final Future<String?> Function(Parcel parcel) onEdit;
  final SenderProfileRepository senderProfileRepository;
  final ParcelDocumentService documentService;

  @override
  State<ParcelDetailsScreen> createState() => _ParcelDetailsScreenState();
}

class _ParcelDetailsScreenState extends State<ParcelDetailsScreen> {
  late Stream<Parcel?> _stream = widget.repository.watch(widget.parcelId);

  Future<void> _edit(Parcel parcel) async {
    final messenger = ScaffoldMessenger.of(context);
    final saved = await widget.onEdit(parcel);
    if (saved != null) {
      messenger.showSnackBar(appSnackBar('Parcel updated.'));
    }
  }

  Future<void> _deleteDraft(Parcel parcel) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete this draft parcel?',
      message: 'This will permanently delete this draft order. This action cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.repository.deleteDraft(parcel.id);
      messenger.showSnackBar(appSnackBar('Draft parcel deleted.'));
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } on AppFailure catch (e) {
      if (mounted) {
        messenger.showSnackBar(appSnackBar(e.message));
      }
    }
  }

  Future<void> _sendTrackingWhatsApp(
    Parcel parcel, {
    String? trackingNumber,
  }) async {
    final sender =
        await widget.senderProfileRepository.getProfile() ??
        const SenderProfile(name: '', phone: '', address: '');
    final ok = await widget.documentService.openTrackingWhatsApp(
      parcel: parcel,
      sender: sender,
      trackingNumber: trackingNumber,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar('Could not open WhatsApp. Please check the phone number.'),
      );
    }
  }

  Future<void> _handover(Parcel parcel) async {
    final messenger = ScaffoldMessenger.of(context);
    final isDraft = parcel.status == ParcelStatus.draft;
    ParcelHandover? savedHandover;

    try {
      final done = await showHandoverSheet(
        context,
        widget.repository,
        parcel,
        onHandoverSaved: (h) => savedHandover = h,
      );
      if (!done || !mounted) return;

      messenger.showSnackBar(
        appSnackBar(
          isDraft ? 'Parcel handed over.' : 'Handover saved.',
          actionLabel: 'WhatsApp',
          onAction: () => _sendTrackingWhatsApp(
            parcel,
            trackingNumber: savedHandover?.postalReference,
          ),
        ),
      );

      final sendNow = await showConfirmDialog(
        context,
        title: 'Send tracking update?',
        icon: Icons.send_rounded,
        message:
            'Open WhatsApp with ${parcel.customerName} (${parcel.customerPhone}) to send Pakistan Post tracking details${savedHandover == null ? '' : ' (${savedHandover!.postalReference})'}?',
        confirmLabel: 'Open WhatsApp',
      );
      if (sendNow && mounted) {
        await _sendTrackingWhatsApp(
          parcel,
          trackingNumber: savedHandover?.postalReference,
        );
      }
    } on AppFailure catch (e) {
      if (mounted) {
        messenger.showSnackBar(appSnackBar(e.message));
      }
    }
  }

  Future<void> _shareInvoice(Parcel parcel) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final sender =
          await widget.senderProfileRepository.getProfile() ??
          const SenderProfile.empty();
      final ok = await widget.documentService.shareInvoice(
        parcel: parcel,
        sender: sender,
      );
      if (mounted && !ok) {
        messenger.showSnackBar(
          appSnackBar('Could not share invoice to WhatsApp'),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(appSnackBar('Could not share invoice: $e'));
      }
    }
  }

  Future<void> _printShippingLabel(Parcel parcel) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final sender =
          await widget.senderProfileRepository.getProfile() ??
          const SenderProfile.empty();
      await widget.documentService.printShippingLabel(
        parcel: parcel,
        sender: sender,
      );
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          appSnackBar('Could not print shipping label: $e'),
        );
      }
    }
  }

  /// Opens one of the action sheets; a snackbar confirms when it was submitted.
  Future<void> _act(Future<bool> Function() open, String done) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (await open()) messenger.showSnackBar(appSnackBar(done));
    } on AppFailure catch (e) {
      messenger.showSnackBar(appSnackBar(e.message));
    }
  }

  void _retry() =>
      setState(() => _stream = widget.repository.watch(widget.parcelId));

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Parcel?>(
      stream: _stream,
      builder: (context, snapshot) {
        final parcel = snapshot.data;
        return Scaffold(
          // The backdrop continues behind the header's curve.
          extendBodyBehindAppBar: true,
          appBar: appCurvedAppBar(
            toolbarHeight: parcel == null
                ? kToolbarHeight
                : AppBarTitle.heightFor(context),
            title: parcel == null
                ? const Text('Parcel')
                : AppBarTitle(
                    parcel.orderNumber,
                    subtitle:
                        '${parcel.sendingDateLabel} · ${parcel.method.label}',
                  ),
            actions: [
              // Owner's rule: only a draft that received no money is deleted.
              if (parcel != null && parcel.canArchive)
                IconButton(
                  tooltip: 'Delete draft',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => _deleteDraft(parcel),
                ),
              // Owner's rule: a parcel is edited only before the handover.
              if (parcel != null && parcel.canEdit)
                IconButton(
                  tooltip: 'Edit parcel',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _edit(parcel),
                ),
            ],
          ),
          body: LiquidBackground(
            child: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: _body(snapshot, parcel),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _body(AsyncSnapshot<Parcel?> snapshot, Parcel? parcel) {
    if (snapshot.hasError) {
      return EmptyState(
        icon: Icons.error_outline_rounded,
        title: "Couldn't load this parcel",
        message: snapshot.error is Exception
            ? snapshot.error.toString()
            : 'Please try again.',
        actionLabel: 'Retry',
        onAction: _retry,
      );
    }
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const SingleChildScrollView(child: ListSkeleton());
    }
    if (parcel == null) {
      return const EmptyState(
        icon: Icons.search_off_rounded,
        title: 'This parcel was not found',
      );
    }
    return _ParcelView(
      parcel: parcel,
      repository: widget.repository,
      senderProfileRepository: widget.senderProfileRepository,
      documentService: widget.documentService,
      onAction: _act,
      onHandover: _handover,
      onSendTrackingWhatsApp: _sendTrackingWhatsApp,
      onPrint: _printShippingLabel,
      onShareInvoice: _shareInvoice,
    );
  }
}

class _ParcelView extends StatelessWidget {
  const _ParcelView({
    required this.parcel,
    required this.repository,
    required this.senderProfileRepository,
    required this.documentService,
    required this.onAction,
    required this.onHandover,
    required this.onSendTrackingWhatsApp,
    required this.onPrint,
    required this.onShareInvoice,
  });
  final Parcel parcel;
  final ParcelRepository repository;
  final SenderProfileRepository senderProfileRepository;
  final ParcelDocumentService documentService;
  final Future<void> Function(Future<bool> Function() open, String done)
  onAction;
  final Future<void> Function(Parcel parcel) onHandover;
  final Future<void> Function(Parcel parcel, {String? trackingNumber})
  onSendTrackingWhatsApp;
  final Future<void> Function(Parcel parcel) onPrint;
  final Future<void> Function(Parcel parcel) onShareInvoice;

  @override
  Widget build(BuildContext context) {
    final isFree = parcel.method == CollectionMethod.giftFree;
    final isReturned = parcel.status == ParcelStatus.returned;
    // Owner's rule: money is recorded only after the handover (a sent
    // parcel). A payment that arrives before it is an advance: the parcel
    // type is changed to Advance paid instead.
    final canReceive =
        !isFree &&
        parcel.status == ParcelStatus.sent &&
        !parcel.isArchived &&
        parcel.outstandingPaisa > 0;
    final canChangeDate =
        parcel.method == CollectionMethod.payLater &&
        !isReturned &&
        !parcel.isArchived &&
        parcel.outstandingPaisa > 0;
    // Owner's rule: a parcel paid in full is finished, so it offers neither
    // Mark Returned nor Archive Parcel.
    final isPaidInFull = parcel.paymentStatus == PaymentStatus.received;
    // Room for two or three things side by side: not with large text or on a
    // narrow screen.
    final roomy =
        MediaQuery.widthOf(context) /
            MediaQuery.textScalerOf(context).scale(1) >=
        360;
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (parcel.isArchived)
            _Section(
              title: 'Archived',
              children: [
                const _Info(
                  'Status',
                  'This parcel is archived. It is hidden from the lists and totals, and its order number stays reserved.',
                ),
                PrimaryButton(
                  label: 'Restore Parcel',
                  onPressed: () => onAction(() async {
                    await repository.restore(parcel.id);
                    return true;
                  }, 'Parcel restored.'),
                ),
              ],
            ),
          App3DCard(
            glass: true,
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.sm,
                  children: [
                    ParcelStatusChips(
                      status: parcel.status,
                      payment: parcel.paymentStatus,
                      reviewRequired: parcel.paymentReviewRequired,
                    ),
                    Semantics(
                      label: isFree
                          ? 'Gift / Free'
                          : 'Parcel amount: ${formatRupees(parcel.expectedPaisa)}',
                      excludeSemantics: true,
                      child: Text(
                        isFree
                            ? 'Gift / Free'
                            : formatRupees(parcel.expectedPaisa),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: AppSpacing.xxl, color: AppColors.border),
                if (roomy)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _Info('Customer', parcel.customerName)),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: _Info('Phone', parcel.customerPhone)),
                    ],
                  )
                else ...[
                  _Info('Customer', parcel.customerName),
                  const SizedBox(height: AppSpacing.md),
                  _Info('Phone', parcel.customerPhone),
                ],
                const SizedBox(height: AppSpacing.md),
                _Info('Address', parcel.customerAddress),
              ],
            ),
          ),
          _Section(
            title: 'Products',
            children: [
              for (final item in parcel.items)
                // The line total moves under the product when both do not fit.
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.sm,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.productName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          isFree
                              ? item.amountLabel
                              : '${item.amountLabel} × ${formatRupees(item.unitPricePaisa)} ${item.priceLabel}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    if (!isFree)
                      Semantics(
                        label:
                            '${item.productName} total: ${formatRupees(item.lineTotalPaisa)}',
                        excludeSemantics: true,
                        child: Text(
                          formatRupees(item.lineTotalPaisa),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              if (!parcel.isArchived)
                Builder(
                  builder: (context) {
                    final printBtn = OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        backgroundColor: AppColors.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.card),
                        ),
                        side: const BorderSide(color: AppColors.borderLight),
                      ),
                      icon: const Icon(Icons.print_outlined, size: 20),
                      label: const Text(
                        'Print',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      onPressed: () => onPrint(parcel),
                    );
                    final shareBtn = PrimaryButton(
                      label: 'Share Invoice',
                      icon: Icons.chat_outlined,
                      onPressed: () => onShareInvoice(parcel),
                    );
                    if (!roomy) {
                      return Column(
                        children: [
                          printBtn,
                          const SizedBox(height: AppSpacing.sm),
                          shareBtn,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(flex: 4, child: printBtn),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(flex: 5, child: shareBtn),
                      ],
                    );
                  },
                ),
            ],
          ),
          _Section(
            title: 'Postal details',
            action: !parcel.isArchived && parcel.status == ParcelStatus.sent
                ? OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide.none,
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                    ),
                    onPressed: () => onHandover(parcel),
                    child: const Text(
                      'Edit handover',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  )
                : null,
            children: [
              if (parcel.postalReference.isEmpty)
                _Box(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (label, value) in [
                        ('Tracking number:', 'Awaiting handover'),
                        (
                          'Delivery charges:',
                          parcel.deliveryChargePaisa == null
                              ? 'Awaiting handover'
                              : formatRupees(parcel.deliveryChargePaisa!),
                        ),
                      ])
                        Wrap(
                          spacing: AppSpacing.xs,
                          children: [
                            Text(
                              label,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              value,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                )
              else
                _StatBox(
                  roomy: roomy,
                  stats: [
                    (
                      label: 'Tracking #',
                      value: parcel.postalReference,
                      color: AppColors.textPrimary,
                      trailing: IconButton(
                        tooltip: 'Copy tracking number',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          await Clipboard.setData(
                            ClipboardData(text: parcel.postalReference),
                          );
                          messenger.showSnackBar(
                            appSnackBar('Tracking number copied.'),
                          );
                        },
                      ),
                    ),
                    (
                      label: 'Charges',
                      value: parcel.deliveryChargePaisa == null
                          ? 'Not set'
                          : formatRupees(parcel.deliveryChargePaisa!),
                      color: AppColors.textPrimary,
                      trailing: null,
                    ),
                    if (parcel.packedWeightGrams != null)
                      (
                        label: 'Packed wt.',
                        value: formatKg(parcel.packedWeightGrams!),
                        color: AppColors.textPrimary,
                        trailing: null,
                      ),
                  ],
                ),
              if (!parcel.isArchived && parcel.status == ParcelStatus.draft)
                PrimaryButton(
                  label: 'Hand over parcel',
                  onPressed: () => onHandover(parcel),
                ),
              if (!parcel.isArchived && parcel.status == ParcelStatus.sent)
                PrimaryButton(
                  label: 'Send Tracking',
                  icon: Icons.send_rounded,
                  onPressed: () => onSendTrackingWhatsApp(parcel),
                ),
            ],
          ),
          _Section(
            title: 'Payment',
            children: [
              _StatBox(
                roomy: roomy,
                stats: [
                  (
                    label: 'Expected',
                    value: isFree
                        ? 'None (Gift / Free)'
                        : formatRupees(parcel.expectedPaisa),
                    color: AppColors.textPrimary,
                    trailing: null,
                  ),
                  (
                    label: 'Received',
                    value: formatRupees(parcel.receivedPaisa),
                    color: AppColors.primary,
                    trailing: null,
                  ),
                  (
                    label: 'Outstanding',
                    value: formatRupees(parcel.outstandingPaisa),
                    color: parcel.outstandingPaisa > 0
                        ? AppColors.pending
                        : AppColors.primary,
                    trailing: null,
                  ),
                ],
              ),
              if (parcel.estimatedPaymentDate != null)
                _Info(
                  'Estimated payment date',
                  formatDate(parcel.estimatedPaymentDate!),
                ),
              if (canReceive)
                PrimaryButton(
                  label: 'Mark Payment Received',
                  onPressed: () => onAction(
                    () => showPaymentSheet(context, repository, parcel),
                    'Payment recorded.',
                  ),
                ),
            ],
          ),
          if (!isFree)
            _PaymentHistory(
              repository: repository,
              parcel: parcel,
              onAction: onAction,
            ),
          if (isReturned)
            _Section(
              title: 'Return',
              children: [
                if (parcel.returnedDate != null)
                  _Info('Returned on', formatDate(parcel.returnedDate!)),
                _Info('Reason', parcel.returnReason ?? 'Not given'),
                if (parcel.paymentReviewRequired)
                  const _Info(
                    'Payment review',
                    'Requires payment review: money was received or is still owed. Nothing is refunded automatically.',
                  ),
                if (parcel.reviewResolution != null) ...[
                  _Info(
                    'Payment review',
                    'Completed on ${formatDate(parcel.reviewDate!)}: ${parcel.reviewResolution!.label}',
                  ),
                  _Info('Review note', parcel.reviewNote ?? ''),
                ],
              ],
            ),
          _Section(
            title: 'Notes',
            children: [_Info('Notes', parcel.notes ?? 'No notes yet')],
          ),
          if (!parcel.isArchived)
            _Section(
              title: 'Actions',
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    OutlinedButton(
                      style: _actionStyle(),
                      onPressed: () => onAction(
                        () => showNotesSheet(context, repository, parcel),
                        'Notes saved.',
                      ),
                      child: Text(
                        parcel.notes == null ? 'Add Notes' : 'Edit Notes',
                      ),
                    ),
                    if (canChangeDate)
                      OutlinedButton(
                        style: _actionStyle(),
                        onPressed: () => onAction(
                          () => showPayLaterDateSheet(
                            context,
                            repository,
                            parcel,
                          ),
                          'Pay Later date saved.',
                        ),
                        child: const Text('Change Pay Later Date'),
                      ),
                    if (parcel.status == ParcelStatus.sent && !isPaidInFull)
                      OutlinedButton(
                        style: _actionStyle(tint: AppColors.pending),
                        onPressed: () => onAction(
                          () => showReturnSheet(context, repository, parcel),
                          'Parcel marked as returned.',
                        ),
                        child: const Text('Mark Returned'),
                      ),
                    if (parcel.paymentReviewRequired)
                      OutlinedButton(
                        style: _actionStyle(),
                        onPressed: () => onAction(
                          () => showReviewSheet(context, repository, parcel),
                          'Payment review completed.',
                        ),
                        child: const Text('Mark Review Completed'),
                      ),
                    if (parcel.canArchive && !isPaidInFull)
                      OutlinedButton(
                        style: _actionStyle(),
                        onPressed: () => onAction(() async {
                          final confirmed = await showConfirmDialog(
                            context,
                            title: 'Archive this parcel?',
                            message: 'It will be hidden from the lists and totals. Its order number stays reserved and you can restore it any time.',
                            confirmLabel: 'Archive',
                          );
                          if (!confirmed) return false;
                          await repository.archive(parcel.id);
                          return true;
                        }, 'Parcel archived.'),
                        child: const Text('Archive Parcel'),
                      ),
                    if (parcel.canArchive)
                      OutlinedButton.icon(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.error,
                        ),
                        label: const Text(
                          'Delete Draft Parcel',
                          style: TextStyle(color: AppColors.error),
                        ),
                        style: _actionStyle(tint: AppColors.error),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final confirmed = await showConfirmDialog(
                            context,
                            title: 'Delete this draft parcel?',
                            message: 'This will permanently delete this draft order. This action cannot be undone.',
                            confirmLabel: 'Delete',
                            destructive: true,
                          );
                          if (!confirmed) return;
                          try {
                            await repository.deleteDraft(parcel.id);
                            messenger.showSnackBar(
                              appSnackBar('Draft parcel deleted.'),
                            );
                            if (context.mounted &&
                                Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            }
                          } on AppFailure catch (e) {
                            messenger.showSnackBar(appSnackBar(e.message));
                          }
                        },
                      ),
                  ],
                ),
                if (parcel.paymentReviewRequired)
                  const _Info(
                    'Archive',
                    "This parcel can't be archived until its payment review is completed.",
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Rounded outline for the buttons in "Actions"; [tint] colours a risky one.
ButtonStyle _actionStyle({Color? tint}) => OutlinedButton.styleFrom(
  minimumSize: const Size(48, 48),
  foregroundColor: tint ?? AppColors.primary,
  backgroundColor: tint?.withValues(alpha: 0.08),
  side: BorderSide(
    color: tint?.withValues(alpha: 0.4) ?? AppColors.borderLight,
  ),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.control),
  ),
);

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.action});
  final String title;
  final List<Widget> children;

  /// A small control at the end of the title row.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return App3DCard(
      glass: true,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The action moves under the title when both do not fit.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: AppColors.primary,
                  ),
                ),
              ),
              ?action,
            ],
          ),
          for (final child in children) ...[
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ],
      ),
    );
  }
}

/// A light bordered panel inside a section.
class _Box extends StatelessWidget {
  const _Box({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: child,
      ),
    );
  }
}

typedef _Stat = ({String label, String value, Color color, Widget? trailing});

/// Two or three figures in a [_Box]: in columns when [roomy], else as rows.
class _StatBox extends StatelessWidget {
  const _StatBox({required this.stats, required this.roomy});
  final List<_Stat> stats;
  final bool roomy;

  static const _labelStyle = TextStyle(
    fontSize: 12,
    color: AppColors.textSecondary,
  );

  Widget _value(_Stat stat) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        stat.value,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: stat.color,
        ),
      ),
      ?stat.trailing,
    ],
  );

  @override
  Widget build(BuildContext context) {
    return _Box(
      child: roomy
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final stat in stats)
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          stat.label,
                          textAlign: TextAlign.center,
                          style: _labelStyle,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        // A value is never wrapped or cut: a long one shrinks.
                        FittedBox(fit: BoxFit.scaleDown, child: _value(stat)),
                      ],
                    ),
                  ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final stat in stats)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AppSpacing.md,
                      children: [
                        Text(stat.label, style: _labelStyle),
                        FittedBox(fit: BoxFit.scaleDown, child: _value(stat)),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _PaymentHistory extends StatefulWidget {
  const _PaymentHistory({
    required this.repository,
    required this.parcel,
    required this.onAction,
  });
  final ParcelRepository repository;
  final Parcel parcel;
  final Future<void> Function(Future<bool> Function() open, String done)
  onAction;

  @override
  State<_PaymentHistory> createState() => _PaymentHistoryState();
}

class _PaymentHistoryState extends State<_PaymentHistory> {
  late final Stream<List<Payment>> _payments = widget.repository.watchPayments(
    widget.parcel.id,
  );

  @override
  Widget build(BuildContext context) {
    final parcel = widget.parcel;
    return StreamBuilder<List<Payment>>(
      stream: _payments,
      builder: (context, snapshot) {
        final payments = snapshot.data ?? const <Payment>[];
        final reversed = {for (final p in payments) ?p.reversalOfPaymentId};
        return _Section(
          title: 'Payment history',
          children: [
            if (snapshot.hasError)
              const _Info('Payments', "Couldn't load the payments.")
            else if (payments.isEmpty)
              const _Info('Payments', 'No payments received yet')
            else
              for (final payment in payments)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _PaymentRow(
                        payment: payment,
                        corrected: reversed.contains(payment.id),
                      ),
                    ),
                    // Owner's rule: once a parcel is paid in full its
                    // payments are final (no Correct).
                    if (payment.amountPaisa > 0 &&
                        !reversed.contains(payment.id) &&
                        parcel.paymentStatus != PaymentStatus.received &&
                        parcel.status != ParcelStatus.returned &&
                        !parcel.isArchived)
                      TextButton(
                        onPressed: () => widget.onAction(
                          () => showCorrectPaymentSheet(
                            context,
                            widget.repository,
                            parcel,
                            payment,
                          ),
                          'Payment corrected.',
                        ),
                        child: const Text('Correct'),
                      ),
                  ],
                ),
          ],
        );
      },
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment, required this.corrected});
  final Payment payment;
  final bool corrected;

  @override
  Widget build(BuildContext context) {
    final date = formatDate(pakistanDate(payment.receivedAt));
    if (payment.isReversal) {
      return _Info(
        '$date · Reversal',
        '${formatRupees(payment.amountPaisa.abs())} cancelled — ${payment.correctionReason}',
      );
    }
    final replacement = payment.correctionOfPaymentId != null
        ? ' · Correction'
        : '';
    final note = payment.note == null ? '' : ' — ${payment.note}';
    return _Info(
      '$date · ${payment.type.label}$replacement${corrected ? ' · Corrected' : ''}',
      '${formatRupees(payment.amountPaisa)}$note',
    );
  }
}
