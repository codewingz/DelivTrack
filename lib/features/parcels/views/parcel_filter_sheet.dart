import 'package:flutter/material.dart';

import '../../../common_widgets/app_date_field.dart';
import '../../../common_widgets/app_field_label.dart';
import '../../../common_widgets/app_form_sheet.dart';
import '../../../common_widgets/app_select_field.dart';
import '../../../core/errors/app_failure.dart';
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
}) async {
  ParcelFilters? result;
  final applied = await showFormSheet(
    context,
    (_) => _FilterSheet(
      current: current,
      products: products,
      today: today,
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
  });
  final ParcelFilters current;
  final List<({String id, String name})> products;
  final String today;
  final ValueChanged<ParcelFilters> onApply;

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
    return AppFormSheet(
      title: 'Filter parcels',
      submitLabel: 'Apply Filters',
      onSubmit: () async {
        final problem = _filters.problem;
        if (problem != null) throw AppFailure(problem);
        widget.onApply(_filters);
      },
      fields: (busy) => [
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton(
            onPressed: busy
                ? null
                : () => setState(() => _filters = ParcelFilters.none),
            child: const Text('Reset all'),
          ),
        ),
        _DateRange(
          title: 'Sending date',
          from: _filters.sendingFrom,
          to: _filters.sendingTo,
          lastDate: widget.today,
          onFrom: (date) =>
              setState(() => _filters = _filters.copyWith(sendingFrom: date)),
          onTo: (date) =>
              setState(() => _filters = _filters.copyWith(sendingTo: date)),
        ),
        _DateRange(
          title: 'Payment received date',
          from: _filters.receivedFrom,
          to: _filters.receivedTo,
          lastDate: widget.today,
          onFrom: (date) =>
              setState(() => _filters = _filters.copyWith(receivedFrom: date)),
          onTo: (date) =>
              setState(() => _filters = _filters.copyWith(receivedTo: date)),
        ),
        AppSelectField(
          label: 'Product',
          hint: 'Any product',
          displayText: _filters.productName,
          onTap: _pickProduct,
        ),
        _Choices<CollectionMethod>(
          title: 'Parcel type',
          values: CollectionMethod.values,
          labelOf: (method) => method.label,
          selected: _filters.methods,
          onChanged: (selected) =>
              setState(() => _filters = _filters.copyWith(methods: selected)),
        ),
        _Choices<PaymentFilter>(
          title: 'Payment status',
          values: PaymentFilter.values,
          labelOf: (filter) => filter.label,
          selected: _filters.payments,
          onChanged: (selected) =>
              setState(() => _filters = _filters.copyWith(payments: selected)),
        ),
        _Choices<ParcelStatus>(
          title: 'Parcel status',
          values: ParcelStatus.values,
          labelOf: (status) => status.label,
          selected: _filters.statuses,
          onChanged: (selected) =>
              setState(() => _filters = _filters.copyWith(statuses: selected)),
        ),
      ],
    );
  }
}

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppDateField(
          label: '$title from',
          hint: 'Any day',
          value: from,
          firstDate: _firstDate,
          lastDate: lastDate,
          onChanged: onFrom,
        ),
        const SizedBox(height: AppSpacing.md),
        AppDateField(
          label: '$title to',
          hint: 'Any day',
          value: to,
          firstDate: _firstDate,
          lastDate: lastDate,
          onChanged: onTo,
        ),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppFieldLabel(title),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final value in values)
              FilterChip(
                label: Text(labelOf(value)),
                selected: selected.contains(value),
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
