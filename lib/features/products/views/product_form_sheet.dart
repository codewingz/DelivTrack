import 'package:flutter/material.dart';
import '../../../common_widgets/app_choice_field.dart';
import '../../../common_widgets/app_text_field.dart';
import '../../../common_widgets/primary_button.dart';
import '../../../constants/app_colors.dart';
import '../../../core/view_models/action_view_model.dart';
import '../../../design_system/foundations/spacing/app_spacing.dart';
import '../data/product_repository.dart';
import '../domain/product.dart';

/// Opens the add/edit sheet. Returns true when a product was saved.
Future<bool> showProductFormSheet(BuildContext context, ProductRepository repository, {Product? product}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) => ProductFormSheet(repository: repository, product: product),
  );
  return saved ?? false;
}

class ProductFormSheet extends StatefulWidget {
  const ProductFormSheet({super.key, required this.repository, this.product});
  final ProductRepository repository;

  /// Null when adding.
  final Product? product;

  @override
  State<ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends State<ProductFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.product?.name);
  final _viewModel = ActionViewModel();
  late SaleUnit? _unit = widget.product?.saleUnit;

  bool get _isEditing => widget.product != null;
  bool get _unitChanged => _isEditing && _unit != widget.product!.saleUnit;

  @override
  void dispose() {
    _name.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final unit = _unit!;
    final saved = await _viewModel.run(
      () => _isEditing
          ? widget.repository.update(widget.product!.id, name: _name.text, saleUnit: unit)
          : widget.repository.add(name: _name.text, saleUnit: unit),
    );
    if (!mounted || !saved) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final busy = _viewModel.isLoading;
        return SingleChildScrollView(
          padding: EdgeInsetsDirectional.fromSTEB(
            AppSpacing.xxl,
            AppSpacing.sm,
            AppSpacing.xxl,
            AppSpacing.xxl + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _isEditing ? 'Edit product' : 'Add product',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppTextField.name(
                  controller: _name,
                  label: 'Product name',
                  hint: 'e.g. Mango Box',
                  icon: Icons.inventory_2_outlined,
                  enabled: !busy,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppChoiceField<SaleUnit>(
                  label: 'Selling unit',
                  isRequired: true,
                  enabled: !busy,
                  initialValue: _unit,
                  options: [for (final unit in SaleUnit.values) (value: unit, label: unit.label)],
                  onChanged: (unit) => setState(() => _unit = unit),
                  validator: (unit) => unit == null ? 'Choose how this product is sold' : null,
                ),
                if (_unitChanged) ...[
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'Existing parcels keep their old unit.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
                if (_viewModel.errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _viewModel.errorMessage!,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.error),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xxl),
                PrimaryButton(label: _isEditing ? 'Save Changes' : 'Add Product', isLoading: busy, onPressed: _save),
              ],
            ),
          ),
        );
      },
    );
  }
}
