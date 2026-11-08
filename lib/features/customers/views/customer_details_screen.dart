import 'package:flutter/material.dart';

import '../../../common_widgets/empty_state.dart';
import '../../../common_widgets/list_skeleton.dart';
import '../../../constants/app_colors.dart';
import '../../../core/money/money.dart';
import '../../../design_system/foundations/radius/app_radius.dart';
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
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't open the phone app.")),
      );
    }
  }

  Future<void> _edit(Customer customer) async {
    final messenger = ScaffoldMessenger.of(context);
    if (await widget.onEdit(customer) != null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Customer updated.')),
      );
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
          appBar: AppBar(
            title: Text(
              customer?.name ?? 'Customer',
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              if (customer != null)
                IconButton(
                  tooltip: 'Edit customer',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _edit(customer),
                ),
            ],
          ),
          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: _body(customerSnapshot, customer),
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
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _Contact(
                customer: customer,
                onCall: () => _call(customer),
              ),
            ),
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
                    'Parcel history',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
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
                SliverList.separated(
                  itemCount: active.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) => ParcelTile(
                    parcel: active[index],
                    onTap: () => widget.onOpenParcel(active[index]),
                  ),
                ),
              const SliverPadding(
                padding: EdgeInsetsDirectional.only(bottom: AppSpacing.xxl),
              ),
            ],
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
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                customer.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              InkWell(
                onTap: onCall,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Row(
                    children: [
                      const Icon(Icons.call_outlined, color: AppColors.primary),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          customer.phone,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                customer.address,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
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
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.lg),
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        children: [
          _Stat(label: 'Parcels', value: '$parcelCount'),
          _Stat(
            label: 'Outstanding',
            value: formatRupees(totals.outstandingPaisa),
          ),
          _Stat(
            label: 'Pay Later balance',
            value: formatRupees(totals.payLaterPaisa),
          ),
          _Stat(
            label: 'Advance received',
            value: formatRupees(totals.advancePaisa),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 150),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
          ),
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
            'Pay Later reminders',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
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
