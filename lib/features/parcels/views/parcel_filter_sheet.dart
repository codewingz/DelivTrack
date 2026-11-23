import 'package:flutter/material.dart';

import '../../../common_widgets/app_date_field.dart';
import '../../../common_widgets/app_form_sheet.dart';
import '../../../common_widgets/app_select_field.dart';
import '../../../constants/app_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../design_system/foundations/radius/app_radius.dart';
import '../../../design_system/foundations/spacing/app_spacing.dart';
import '../domain/parcel_enums.dart';
import '../domain/parcel_search.dart';

/// Opens the filter sheet with the [current] choices. Returns the new filters when Apply is tapped,
/// or null when the sheet is dismissed.
Future<ParcelFilters?> showParcelFilterSheet(
  BuildContext context, {
  required ParcelFilters current,
  required List<({String id, String name})> products,
  required String today,
  int? Function(ParcelFilters filters)? countFor,
}) async {
  ParcelFilters? result;
  final applied = await showFormSheet(
    context,
    (_) => _FilterSheet(
      current: current,
      products: products,
      today: today,
      countFor: countFor,
      onApply: (filters) => result = filters,
    ),
  );
  return applied ? result : null;
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.current,
    required this.products,
    required this.today,
    required this.onApply,
    this.countFor,
  });
  final ParcelFilters current;
  final List<({String id, String name})> products;
  final String today;
  final ValueChanged<ParcelFilters> onApply;

  /// How many parcels [filters] would show, or null when that is not known
  /// yet (the button then has no number).
  final int? Function(ParcelFilters filters)? countFor;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late ParcelFilters _filters = widget.current;

  Future<void> _pickProduct() async {
    // A real value even for "any product", so closing the dialog without choosing changes nothing.
    final chosen = await showDialog<({String? id, String? name})>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Product'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, (id: null, name: null)),
            child: const Text('Any product'),
          ),
          for (final product in widget.products)
            SimpleDialogOption(
              onPressed: () =>
                  Navigator.pop(context, (id: product.id, name: product.name)),
              child: Text(product.name),
            ),
        ],
      ),
    );
    if (chosen == null) return;
    setState(
      () => _filters = _filters.copyWith(
        productId: chosen.id,
        productName: chosen.name,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.countFor?.call(_filters);
    return AppFormSheet(
      title: 'Filter parcels',
      pinFooter: true,
      secondaryLabel: 'Reset',
      onSecondary: () => setState(() => _filters = ParcelFilters.none),
      submitLabel: count == null
          ? 'Show Parcels'
          : 'Show $count ${count == 1 ? 'Parcel' : 'Parcels'}',
      onSubmit: () async {
        final problem = _filters.problem;
        if (problem != null) throw AppFailure(problem);
        widget.onApply(_filters);
      },
      fields: (busy) => [
        _Section(
          children: [
            _DateRange(
              title: 'Sending date',
              from: _filters.sendingFrom,
              to: _filters.sendingTo,
              lastDate: widget.today,
              onFrom: (date) => setState(
                () => _filters = _filters.copyWith(sendingFrom: date),
              ),
              onTo: (date) =>
                  setState(() => _filters = _filters.copyWith(sendingTo: date)),
            ),
            const Divider(height: AppSpacing.xxl, color: AppColors.border),
            _DateRange(
              title: 'Payment received date',
              from: _filters.receivedFrom,
              to: _filters.receivedTo,
              lastDate: widget.today,
              onFrom: (date) => setState(
                () => _filters = _filters.copyWith(receivedFrom: date),
              ),
              onTo: (date) => setState(
                () => _filters = _filters.copyWith(receivedTo: date),
              ),
            ),
          ],
        ),
        _Section(
          children: [
            const _SectionLabel('Product'),
            AppSelectField(
              hint: 'Any product',
              displayText: _filters.productName,
              onTap: _pickProduct,
            ),
          ],
        ),
        _Section(
          children: [
            _Choices<CollectionMethod>(
              title: 'Parcel type',
              values: CollectionMethod.values,
              labelOf: (method) => method.label,
              selected: _filters.methods,
              onChanged: (selected) => setState(
                () => _filters = _filters.copyWith(methods: selected),
              ),
            ),
          ],
        ),
        _Section(
          children: [
            _Choices<PaymentFilter>(
              title: 'Payment status',
              values: PaymentFilter.values,
              labelOf: (filter) => filter.label,
              selected: _filters.payments,
              onChanged: (selected) => setState(
                () => _filters = _filters.copyWith(payments: selected),
              ),
            ),
          ],
        ),
        _Section(
          children: [
            _Choices<ParcelStatus>(
              title: 'Parcel status',
              values: ParcelStatus.values,
              labelOf: (status) => status.label,
              selected: _filters.statuses,
              onChanged: (selected) => setState(
                () => _filters = _filters.copyWith(statuses: selected),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A white card holding one group of filters.
class _Section extends StatelessWidget {
  const _Section({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

/// Small uppercase green heading of a filter group.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: Semantics(
        header: true,
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

/// True when two controls fit side by side: not with large text.
bool _roomForColumns(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(1) <= 1.3;

class _DateRange extends StatelessWidget {
  const _DateRange({
    required this.title,
    required this.from,
    required this.to,
    required this.lastDate,
    required this.onFrom,
    required this.onTo,
  });
  final String title;
  final String? from;
  final String? to;
  final String lastDate;
  final ValueChanged<String?> onFrom;
  final ValueChanged<String?> onTo;

  static const _firstDate = '2020-01-01';

  @override
  Widget build(BuildContext context) {
    final fromField = AppDateField(
      label: 'From',
      hint: 'Any day',
      value: from,
      firstDate: _firstDate,
      lastDate: lastDate,
      onChanged: onFrom,
    );
    final toField = AppDateField(
      label: 'To',
      hint: 'Any day',
      value: to,
      firstDate: _firstDate,
      lastDate: lastDate,
      onChanged: onTo,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(title),
        if (_roomForColumns(context))
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: fromField),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: toField),
            ],
          )
        else ...[
          fromField,
          const SizedBox(height: AppSpacing.md),
          toField,
        ],
      ],
    );
  }
}

class _Choices<T> extends StatelessWidget {
  const _Choices({
    required this.title,
    required this.values,
    required this.labelOf,
    required this.selected,
    required this.onChanged,
  });
  final String title;
  final List<T> values;
  final String Function(T) labelOf;
  final Set<T> selected;
  final ValueChanged<Set<T>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(title),
        // Each choice is as wide as its text and they wrap to the next line
        // on their own.
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final value in values)
              FilterChip(
                label: Text(labelOf(value)),
                selected: selected.contains(value),
                showCheckmark: false,
                backgroundColor: AppColors.inputBackground,
                selectedColor: AppColors.brand100,
                labelStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: selected.contains(value)
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: selected.contains(value)
                      ? AppColors.primaryDark
                      : AppColors.textPrimary,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  side: BorderSide(
                    color: selected.contains(value)
                        ? AppColors.primary
                        : AppColors.borderLight,
                  ),
                ),
                onSelected: (on) => onChanged(
                  on ? {...selected, value} : ({...selected}..remove(value)),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
