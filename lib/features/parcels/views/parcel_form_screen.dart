import 'package:flutter/material.dart';

import '../../../common_widgets/app_choice_field.dart';
import '../../../common_widgets/app_date_field.dart';
import '../../../common_widgets/app_select_field.dart';
import '../../../common_widgets/app_text_field.dart';
import '../../../common_widgets/confirm_dialog.dart';
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
            appBar: AppBar(
              title: Text(widget.parcel == null ? 'Add parcel' : 'Edit parcel'),
            ),
            body: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsetsDirectional.all(AppSpacing.xxl),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _OrderNumberNote(
                            orderNumber: widget.parcel?.orderNumber,
                          ),
                          const SizedBox(height: AppSpacing.xl),
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
                          AppChoiceField<CollectionMethod>(
                            label: 'Parcel type',
                            isRequired: true,
                            enabled: !busy,
                            initialValue: _form.method,
                            options: [
                              for (final m in CollectionMethod.values)
                                (value: m, label: m.label),
                            ],
                            onChanged: _form.setMethod,
                            validator: (value) =>
                                value == null ? 'Select a parcel type' : null,
                          ),
                          const SizedBox(height: AppSpacing.xxl),
                          const _SectionTitle('Products'),
                          const SizedBox(height: AppSpacing.md),
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
                                minimumSize: const Size.fromHeight(48),
                              ),
                              onPressed: busy ? null : _form.addItem,
                              icon: const Icon(Icons.add),
                              label: const Text('Add another product'),
                            ),
                          const SizedBox(height: AppSpacing.md),
                          _TotalLine(form: _form),
                          const SizedBox(height: AppSpacing.xxl),
                          if (_form.method == CollectionMethod.payLater) ...[
                            const SizedBox(height: AppSpacing.lg),
                            AppDateField(
                              label: 'Estimated payment date (optional)',
                              hint: 'Leave empty if the customer gave no date',
                              value: _form.payDate,
                              enabled: !busy,
                              firstDate: today,
                              lastDate:
                                  '${int.parse(today.substring(0, 4)) + 5}${today.substring(4)}',
                              onChanged: _form.setPayDate,
                            ),
                          ],
                          if (_action.errorMessage != null) ...[
                            const SizedBox(height: AppSpacing.lg),
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
                          const SizedBox(height: AppSpacing.xxl),
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
                                ? 'The parcel is saved as a Draft. Open it and tap "Hand over to post office" once you have the slip.'
                                : widget.parcel!.status == ParcelStatus.draft
                                ? 'This parcel is still a Draft. Hand it over from its details once you have the slip.'
                                : 'Post-office details are changed with "Edit handover" on the parcel details.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.label,
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
        );
      },
    );
  }
}

class _OrderNumberNote extends StatelessWidget {
  const _OrderNumberNote({this.orderNumber});

  /// The saved parcel's number (edit mode); null while adding.
  final String? orderNumber;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.tag_rounded, size: 20, color: AppColors.label),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            orderNumber == null
                ? 'Order number: assigned automatically when you save'
                : 'Order number: $orderNumber (cannot be changed)',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w800,
      color: AppColors.primaryDark,
    ),
  );
}

class _TotalLine extends StatelessWidget {
  const _TotalLine({required this.form});
  final ParcelFormViewModel form;

  @override
  Widget build(BuildContext context) {
    final text = form.isFree
        ? 'No payment expected (Gift / Free)'
        : 'Products total: ${formatRupees(form.totalPaisa)}';
    return Semantics(
      liveRegion: true,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
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
                      color: AppColors.label,
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
              if (item.isPerKg)
                AppTextField.weight(
                  controller: _weight,
                  label: 'Weight (kg)',
                  hint: 'Enter weight',
                  isRequired: true,
                  enabled: widget.enabled,
                  onChanged: (value) =>
                      form.setWeight(item, parseKgToGrams(value)),
                )
              else
                AppTextField.integer(
                  controller: _quantity,
                  enabled: widget.enabled,
                  onChanged: (value) =>
                      form.setQuantity(item, int.tryParse(value.trim())),
                ),
              if (!form.isFree) ...[
                const SizedBox(height: AppSpacing.lg),
                AppTextField.amount(
                  controller: _price,
                  label: item.isPerKg
                      ? 'Price per kg (Rs.)'
                      : 'Price per piece (Rs.)',
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
      ),
    );
  }
}
