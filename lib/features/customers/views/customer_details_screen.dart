import '../../../common_widgets/app_snack_bar.dart';

import '../../../common_widgets/confirm_dialog.dart';
import '../../../core/errors/app_failure.dart';
import '../../../design_system/foundations/radius/app_radius.dart';

import 'package:flutter/material.dart';

import '../../../common_widgets/app_3d_decorations.dart';
import '../../../common_widgets/empty_state.dart';
import '../../../common_widgets/initial_avatar.dart';
import '../../../common_widgets/liquid_glass.dart';
import '../../../common_widgets/list_skeleton.dart';
import '../../../constants/app_colors.dart';
import '../../../core/money/money.dart';
import '../../../design_system/foundations/spacing/app_spacing.dart';
import '../../../core/time/pakistan_time.dart';
import '../../parcels/data/parcel_repository.dart';
import '../../reminders/domain/reminder_rules.dart';
import '../../parcels/domain/parcel.dart';
import '../../parcels/views/parcels_screen.dart';
import '../../payments/domain/payment_tabs.dart';
import '../data/customer_repository.dart';
import '../data/phone_dialer.dart';
import '../domain/customer.dart';

/// One customer: contact details (the phone number dials), what they owe, and their parcel history.
class CustomerDetailsScreen extends StatefulWidget {
  const CustomerDetailsScreen({
    super.key,
    required this.customerRepository,
    required this.parcelRepository,
    required this.customerId,
    required this.onEdit,
    required this.onOpenParcel,
    this.dialer = const UrlLauncherDialer(),
    this.clock = const Clock(),
  });
  final CustomerRepository customerRepository;
  final ParcelRepository parcelRepository;
  final String customerId;
  final Future<String?> Function(Customer customer) onEdit;
  final void Function(Parcel parcel) onOpenParcel;
  final PhoneDialer dialer;
  final Clock clock;

  @override
  State<CustomerDetailsScreen> createState() => _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends State<CustomerDetailsScreen> {
  late final Stream<List<Customer>> _customers = widget.customerRepository
      .watchAll();
  late final Stream<List<Parcel>> _parcels = widget.parcelRepository.watchAll(
    includeArchived: true,
  );

  Future<void> _call(Customer customer) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!await widget.dialer.dial(customer.phone)) {
      messenger.showSnackBar(appSnackBar("Couldn't open the phone app."));
    }
  }

  Future<void> _edit(Customer customer) async {
    final messenger = ScaffoldMessenger.of(context);
    if (await widget.onEdit(customer) != null) {
      messenger.showSnackBar(appSnackBar('Customer updated.'));
    }
  }

  Future<void> _delete(Customer customer) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete ${customer.name}?',
      message: 'Only the customer is deleted. Their parcels and payments stay in your records. This action cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.customerRepository.delete(customer.id);
      messenger.showSnackBar(appSnackBar('Customer deleted.'));
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } on AppFailure catch (e) {
      messenger.showSnackBar(appSnackBar(e.message));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Customer>>(
      stream: _customers,
      builder: (context, customerSnapshot) {
        final customer = customerSnapshot.data
            ?.where((c) => c.id == widget.customerId)
            .firstOrNull;
        return Scaffold(
          // The backdrop continues behind the header's curve.
          extendBodyBehindAppBar: true,
          appBar: appCurvedAppBar(
            toolbarHeight: customer == null
                ? kToolbarHeight
                : AppBarTitle.heightFor(context),
            title: customer == null
                ? const Text('Customer')
                : AppBarTitle(customer.name, subtitle: customer.phone),
            actions: [
              if (customer != null)
                IconButton(
                  tooltip: 'Edit customer',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _edit(customer),
                ),
            ],
          ),
          body: LiquidBackground(
            child: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: _body(customerSnapshot, customer),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _body(AsyncSnapshot<List<Customer>> snapshot, Customer? customer) {
    if (snapshot.hasError) {
      return const EmptyState(
        icon: Icons.error_outline_rounded,
        title: "Couldn't load this customer",
        message: 'Please go back and try again.',
      );
    }
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const SingleChildScrollView(child: ListSkeleton());
    }
    if (customer == null) {
      return const EmptyState(
        icon: Icons.search_off_rounded,
        title: 'This customer was not found',
      );
    }
    return StreamBuilder<List<Parcel>>(
      stream: _parcels,
      builder: (context, parcelSnapshot) {
        // Archived parcels stay in the money figures (lifetime), but not in the history list or the count.
        final parcels = [
          for (final parcel in parcelSnapshot.data ?? const <Parcel>[])
            if (parcel.customerId == customer.id) parcel,
        ];
        final active = [
          for (final parcel in parcels)
            if (!parcel.isArchived) parcel,
        ];
        final contact = _Contact(
          customer: customer,
          onCall: () => _call(customer),
        );
        // The contact card stays in place while the rest scrolls; on a short
        // screen or with large text it scrolls too, so the list keeps room.
        final pinContact =
            MediaQuery.heightOf(context) /
                MediaQuery.textScalerOf(context).scale(1) >=
            600;
        final list = CustomScrollView(
          slivers: [
            if (!pinContact) SliverToBoxAdapter(child: contact),
            if (parcelSnapshot.hasError)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsetsDirectional.all(AppSpacing.lg),
                  child: Text("Couldn't load this customer's parcels."),
                ),
              )
            else if (parcelSnapshot.connectionState == ConnectionState.waiting)
              const SliverToBoxAdapter(child: ListSkeleton())
            else ...[
              SliverToBoxAdapter(
                child: _Totals(parcels: parcels, parcelCount: active.length),
              ),
              SliverToBoxAdapter(
                child: _PayLaterReminders(
                  parcels: active,
                  today: pakistanDate(widget.clock.nowUtc()),
                  onOpen: widget.onOpenParcel,
                ),
              ),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  child: Text(
                    'PARCEL HISTORY',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: AppColors.label,
                    ),
                  ),
                ),
              ),
              if (active.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsetsDirectional.all(AppSpacing.lg),
                    child: Text(
                      'No parcels for this customer yet.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  sliver: SliverList.builder(
                    itemCount: active.length,
                    itemBuilder: (context, index) => ParcelTile(
                      parcel: active[index],
                      onTap: () => widget.onOpenParcel(active[index]),
                    ),
                  ),
                ),
              // Deletes the customer only; their parcels and payments stay.
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        foregroundColor: AppColors.error,
                        backgroundColor: AppColors.error.withValues(
                          alpha: 0.08,
                        ),
                        side: BorderSide(
                          color: AppColors.error.withValues(alpha: 0.4),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppRadius.control,
                          ),
                        ),
                      ),
                      onPressed: () => _delete(customer),
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text(
                        'Delete Customer',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ),
              const SliverPadding(
                padding: EdgeInsetsDirectional.only(bottom: AppSpacing.xxl),
              ),
            ],
          ],
        );
        if (!pinContact) return list;
        return Column(
          children: [
            contact,
            Expanded(child: list),
          ],
        );
      },
    );
  }
}

class _Contact extends StatelessWidget {
  const _Contact({required this.customer, required this.onCall});
  final Customer customer;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: App3DCard(
        glass: true,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                InitialAvatar(name: customer.name),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      // Tap to call.
                      InkWell(
                        onTap: onCall,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.call_outlined,
                                size: 18,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Flexible(
                                child: Text(
                                  customer.phone,
                                  key: const Key('customer-call'),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: AppSpacing.lg, color: AppColors.border),
            Text(
              customer.address,
              style: const TextStyle(fontSize: 14, color: AppColors.label),
            ),
          ],
        ),
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.parcels, required this.parcelCount});

  /// Every parcel of the customer, archived ones included (the money figures are lifetime).
  final List<Parcel> parcels;

  /// Active parcels only.
  final int parcelCount;

  @override
  Widget build(BuildContext context) {
    final totals = PaymentTotals.from(parcels);
    final stats = [
      _Stat(label: 'Parcels', value: '$parcelCount', color: AppColors.primary),
      _Stat(
        label: 'Outstanding',
        value: formatRupees(totals.outstandingPaisa),
        color: totals.outstandingPaisa > 0
            ? AppColors.pending
            : AppColors.primary,
      ),
      _Stat(
        label: 'Pay Later balance',
        value: formatRupees(totals.payLaterPaisa),
        color: AppColors.textPrimary,
      ),
      _Stat(
        label: 'Advance received',
        value: formatRupees(totals.advancePaisa),
        color: AppColors.primary,
      ),
    ];
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.lg),
      // Two across; one per row when large text leaves no room for two.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns =
              constraints.maxWidth /
                      MediaQuery.textScalerOf(context).scale(1) >=
                  300
              ? 2
              : 1;
          final width =
              (constraints.maxWidth - AppSpacing.md * (columns - 1)) / columns;
          return Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              for (final stat in stats) SizedBox(width: width, child: stat),
            ],
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: App3DCard(
        glass: true,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            // An amount is never wrapped or cut: a long one shrinks to fit.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// This customer's Pay Later payments still to collect, each with its own (optional) date.
class _PayLaterReminders extends StatelessWidget {
  const _PayLaterReminders({
    required this.parcels,
    required this.today,
    required this.onOpen,
  });
  final List<Parcel> parcels;
  final String today;
  final void Function(Parcel parcel) onOpen;

  @override
  Widget build(BuildContext context) {
    final reminders = Reminders.from(parcels, today);
    final rows = [
      for (final group in ReminderGroup.values)
        for (final parcel in reminders[group]) (parcel: parcel, group: group),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: AppSpacing.lg,
        top: AppSpacing.lg,
        end: AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PAY LATER REMINDERS',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: AppColors.label,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final (:parcel, :group) in rows)
            InkWell(
              onTap: () => onOpen(parcel),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    vertical: AppSpacing.xs,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${parcel.orderNumber} · ${formatRupees(parcel.outstandingPaisa)} to collect',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        reminderDateText(parcel, group, today),
                        style: TextStyle(
                          fontSize: 13,
                          color: group == ReminderGroup.overdue
                              ? AppColors.error
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
