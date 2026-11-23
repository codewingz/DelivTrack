import 'package:flutter/material.dart';

import '../../../common_widgets/app_3d_decorations.dart';
import '../../../common_widgets/app_dropdown_field.dart';
import '../../../common_widgets/app_date_field.dart';
import '../../../common_widgets/app_select_field.dart';
import '../../../common_widgets/app_text_field.dart';
import '../../../common_widgets/confirm_dialog.dart';
import '../../../common_widgets/liquid_glass.dart';
import '../../../common_widgets/primary_button.dart';
import '../../../constants/app_colors.dart';
import '../../../core/money/money.dart';
import '../../../core/time/pakistan_time.dart';
import '../../../core/view_models/action_view_model.dart';
import '../../../design_system/foundations/radius/app_radius.dart';
import '../../../design_system/foundations/spacing/app_spacing.dart';
import '../../customers/data/customer_repository.dart';
import '../../customers/domain/customer.dart';
import '../../customers/views/customer_picker_screen.dart';
import '../../products/data/product_repository.dart';
import '../../products/domain/product.dart';
import '../../products/views/product_picker_screen.dart';
import '../data/parcel_repository.dart';
import '../domain/parcel.dart';
import '../domain/parcel_enums.dart';
import '../viewmodel/parcel_form_view_model.dart';

/// Add a parcel. Pops with the new parcel's id. The order number and sending date are never
/// entered: the order number is reserved on save and the date is the server's Pakistan date.
class ParcelFormScreen extends StatefulWidget {
  const ParcelFormScreen({
    super.key,
    required this.parcelRepository,
    required this.customerRepository,
    required this.productRepository,
    required this.onAddCustomer,
    this.parcel,
    this.clock = const Clock(),
  });

  final ParcelRepository parcelRepository;
  final CustomerRepository customerRepository;
  final ProductRepository productRepository;

  /// Opens the full-screen Add Customer form; returns the new customer's id or null.
  final Future<String?> Function() onAddCustomer;

  /// The parcel to edit; null when adding.
  final Parcel? parcel;
  final Clock clock;

  @override
  State<ParcelFormScreen> createState() => _ParcelFormScreenState();
}

class _ParcelFormScreenState extends State<ParcelFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _form = widget.parcel == null
      ? ParcelFormViewModel()
      : ParcelFormViewModel.fromParcel(widget.parcel!);
  final _action = ActionViewModel();
  bool _saved = false;

  @override
  void dispose() {
    _form.dispose();
    _action.dispose();
    super.dispose();
  }

  Future<void> _pickCustomer() async {
    final picked = await Navigator.of(context).push<Customer>(
      MaterialPageRoute(
        builder: (_) => CustomerPickerScreen(
          repository: widget.customerRepository,
          onAdd: widget.onAddCustomer,
        ),
      ),
    );
    if (!mounted || picked == null) return;
    _form.setCustomer(picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final input = _form.buildInput();
    final problems = input.problems(today: pakistanDate(widget.clock.nowUtc()));
    if (problems.isNotEmpty) return _action.fail(problems.first);

    final existing = widget.parcel;
    String? savedId;
    final ok = await _action.run(() async {
      if (existing == null) {
        savedId = await widget.parcelRepository.create(input);
      } else {
        await widget.parcelRepository.update(existing.id, input);
        savedId = existing.id;
      }
    });
    if (!mounted || !ok) return;
    _saved = true;
    Navigator.of(context).pop(savedId);
  }

  Future<void> _confirmDiscard() async {
    final discard = await showConfirmDialog(
      context,
      title: widget.parcel == null
          ? 'Discard this parcel?'
          : 'Discard your changes?',
      message: widget.parcel == null
          ? 'What you entered will be lost.'
          : 'Your changes to this parcel will be lost.',
      confirmLabel: 'Discard',
      destructive: true,
    );
    if (!mounted || !discard) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_form, _action]),
      builder: (context, _) {
        final busy = _action.isLoading;
        final today = pakistanDate(widget.clock.nowUtc());
        return PopScope(
          canPop: _saved || !_form.isDirty,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _confirmDiscard();
          },
          child: Scaffold(
            // The backdrop continues behind the header's curve.
            extendBodyBehindAppBar: true,
            appBar: appCurvedAppBar(
              toolbarHeight: AppBarTitle.heightFor(context),
              title: AppBarTitle(
                widget.parcel == null ? 'Add parcel' : 'Edit parcel',
                subtitle: widget.parcel == null
                    ? 'Order # auto-assigned on save'
                    : 'Order ${widget.parcel!.orderNumber}',
              ),
              actions: [
                _StatusPill(widget.parcel?.status ?? ParcelStatus.draft),
              ],
            ),
            body: LiquidBackground(
              child: SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            App3DCard(
                              glass: true,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  AppSelectField(
                                    label: 'Customer',
                                    hint: 'Select a customer',
                                    displayText: _form.customer?.name,
                                    isRequired: true,
                                    enabled: !busy,
                                    icon: Icons.person_search_outlined,
                                    onTap: _pickCustomer,
                                    validator: () => _form.customer == null
                                        ? 'Select a customer'
                                        : null,
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  AppDropdownField<CollectionMethod>(
                                    label: 'Parcel type',
                                    hint: 'Select parcel type',
                                    isRequired: true,
                                    enabled: !busy,
                                    value: _form.method,
                                    options: [
                                      for (final m in CollectionMethod.values)
                                        (value: m, label: m.label),
                                    ],
                                    onChanged: _form.setMethod,
                                    validator: (value) => value == null
                                        ? 'Select a parcel type'
                                        : null,
                                  ),
                                  if (_form.method ==
                                      CollectionMethod.payLater) ...[
                                    const SizedBox(height: AppSpacing.lg),
                                    AppDateField(
                                      label:
                                          'Estimated payment date (optional)',
                                      hint: 'Leave empty if the customer gave no date',
                                      value: _form.payDate,
                                      enabled: !busy,
                                      firstDate: today,
                                      lastDate:
                                          '${int.parse(today.substring(0, 4)) + 5}${today.substring(4)}',
                                      onChanged: _form.setPayDate,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            _ProductsHeading(count: _form.items.length),
                            const SizedBox(height: AppSpacing.sm),
                            for (var i = 0; i < _form.items.length; i++) ...[
                              _ItemCard(
                                key: ValueKey(_form.items[i].key),
                                index: i,
                                item: _form.items[i],
                                form: _form,
                                productRepository: widget.productRepository,
                                enabled: !busy,
                              ),
                              const SizedBox(height: AppSpacing.md),
                            ],
                            if (_form.canAddItem)
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(52),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.card,
                                    ),
                                  ),
                                  side: const BorderSide(
                                    color: AppColors.glassEdge,
                                  ),
                                  backgroundColor: AppColors.glassFill,
                                ),
                                onPressed: busy ? null : _form.addItem,
                                icon: const Icon(Icons.add),
                                label: const Text(
                                  'Add another product',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            const SizedBox(height: AppSpacing.lg),
                            App3DCard(
                              glass: true,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _TotalLine(form: _form),
                                  if (_action.errorMessage != null) ...[
                                    const SizedBox(height: AppSpacing.md),
                                    Semantics(
                                      liveRegion: true,
                                      child: Text(
                                        _action.errorMessage!,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.error,
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: AppSpacing.lg),
                                  PrimaryButton(
                                    label: widget.parcel != null
                                        ? 'Save Changes'
                                        : 'Save Parcel',
                                    isLoading: busy,
                                    onPressed: _save,
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  Text(
                                    widget.parcel == null
                                        ? 'The parcel is saved as a Draft. Open it and tap "Hand over parcel" once you have the slip.'
                                        : widget.parcel!.status ==
                                              ParcelStatus.draft
                                        ? 'This parcel is still a Draft. Hand it over from its details once you have the slip.'
                                        : 'Handover details are changed with "Edit handover" on the parcel details.',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.label,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The parcel's status in the header ("Draft" while adding).
class _StatusPill extends StatelessWidget {
  const _StatusPill(this.status);
  final ParcelStatus status;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: AppSpacing.lg),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.mint.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.mint.withValues(alpha: 0.3)),
        ),
        child: Text(
          status.label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.mint,
          ),
        ),
      ),
    );
  }
}

/// "PRODUCTS" with how many lines the parcel has.
class _ProductsHeading extends StatelessWidget {
  const _ProductsHeading({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: const Text(
              'PRODUCTS',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        Text(
          '$count ${count == 1 ? 'item' : 'items'}',
          style: const TextStyle(fontSize: 13, color: AppColors.label),
        ),
      ],
    );
  }
}

class _TotalLine extends StatelessWidget {
  const _TotalLine({required this.form});
  final ParcelFormViewModel form;

  @override
  Widget build(BuildContext context) {
    if (form.isFree) {
      return Semantics(
        liveRegion: true,
        child: const Text(
          'No payment expected (Gift / Free)',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      );
    }
    final amount = formatRupees(form.totalPaisa);
    return Semantics(
      liveRegion: true,
      label: 'Products total: $amount',
      excludeSemantics: true,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.md,
        children: [
          const Text(
            'Products total',
            style: TextStyle(fontSize: 14, color: AppColors.label),
          ),
          Text(
            amount,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// One product line: product, amount (pieces or kg), agreed price and the line total.
class _ItemCard extends StatefulWidget {
  const _ItemCard({
    super.key,
    required this.index,
    required this.item,
    required this.form,
    required this.productRepository,
    required this.enabled,
  });

  final int index;
  final ItemDraft item;
  final ParcelFormViewModel form;
  final ProductRepository productRepository;
  final bool enabled;

  @override
  State<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<_ItemCard> {
  late final _quantity = TextEditingController(
    text: widget.item.quantity?.toString(),
  );
  late final _weight = TextEditingController(
    text: widget.item.weightGrams == null
        ? null
        : plainKg(widget.item.weightGrams!),
  );
  late final _price = TextEditingController(
    text: widget.item.pricePaisa == null
        ? null
        : plainRupees(widget.item.pricePaisa!),
  );

  @override
  void dispose() {
    _quantity.dispose();
    _weight.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _pickProduct() async {
    final picked = await Navigator.of(context).push<Product>(
      MaterialPageRoute(
        builder: (_) =>
            ProductPickerScreen(repository: widget.productRepository),
      ),
    );
    if (!mounted || picked == null) return;
    if (widget.item.product?.saleUnit != picked.saleUnit) {
      _quantity.clear();
      _weight.clear();
    }
    widget.form.setProduct(widget.item, picked);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final form = widget.form;
    final number = widget.index + 1;
    final lineTotal = form.lineTotalPaisa(item);
    return App3DCard(
      glass: true,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Product $number',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
              if (form.items.length > 1)
                IconButton(
                  tooltip: 'Remove product $number',
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.error,
                  ),
                  onPressed: widget.enabled
                      ? () => form.removeItem(item)
                      : null,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AppSelectField(
            label: 'Product',
            hint: 'Select a product',
            displayText: item.product?.name,
            isRequired: true,
            enabled: widget.enabled,
            icon: Icons.inventory_2_outlined,
            onTap: _pickProduct,
            validator: () {
              if (item.product == null) return 'Select a product';
              return form.isDuplicate(item)
                  ? 'This product is already added'
                  : null;
            },
          ),
          if (item.product != null) ...[
            const SizedBox(height: AppSpacing.lg),
            if (item.isMeasured)
              AppTextField.weight(
                controller: _weight,
                label: item.product!.saleUnit == SaleUnit.perKg
                    ? 'Weight (kg)'
                    : 'Volume (${item.product!.saleUnit.plural})',
                fieldName: item.product!.saleUnit == SaleUnit.perKg
                    ? 'Weight'
                    : 'Volume',
                unit: item.product!.saleUnit.plural,
                hint:
                    'Enter ${item.product!.saleUnit == SaleUnit.perKg ? 'weight' : 'volume'}',
                isRequired: true,
                enabled: widget.enabled,
                onChanged: (value) =>
                    form.setWeight(item, parseKgToGrams(value)),
              )
            else
              AppTextField.integer(
                controller: _quantity,
                label: 'Quantity (${item.product!.saleUnit.plural})',
                unit: item.product!.saleUnit.plural,
                enabled: widget.enabled,
                onChanged: (value) =>
                    form.setQuantity(item, int.tryParse(value.trim())),
              ),
            if (!form.isFree) ...[
              const SizedBox(height: AppSpacing.lg),
              AppTextField.amount(
                controller: _price,
                label: 'Price per ${item.product!.saleUnit.singular} (Rs.)',
                hint: 'Enter agreed price',
                minPaisa: 1,
                enabled: widget.enabled,
                textInputAction: TextInputAction.done,
                onChanged: (value) =>
                    form.setPrice(item, parseRupeesToPaisa(value)),
              ),
              if (lineTotal != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Line total: ${formatRupees(lineTotal)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ],
        ],
      ),
    );
  }
}
