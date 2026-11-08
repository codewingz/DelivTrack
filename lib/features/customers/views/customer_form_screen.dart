import 'package:flutter/material.dart';

import '../../../common_widgets/app_text_field.dart';
import '../../../common_widgets/confirm_dialog.dart';
import '../../../common_widgets/primary_button.dart';
import '../../../constants/app_colors.dart';
import '../../../core/view_models/action_view_model.dart';
import '../../../design_system/foundations/spacing/app_spacing.dart';
import '../../../utils/app_validators.dart';
import '../data/customer_repository.dart';
import '../domain/customer.dart';

/// Add or edit a customer on a full screen. Pops with the saved customer's id,
/// so a caller (e.g. Add Parcel) can select the new customer.
class CustomerFormScreen extends StatefulWidget {
  const CustomerFormScreen({
    super.key,
    required this.repository,
    this.customer,
  });
  final CustomerRepository repository;

  /// Null when adding.
  final Customer? customer;

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.customer?.name);
  late final _phone = TextEditingController(text: widget.customer?.phone);
  late final _address = TextEditingController(text: widget.customer?.address);
  final _viewModel = ActionViewModel();
  bool _saved = false;

  bool get _isEditing => widget.customer != null;

  bool get _isDirty =>
      _name.text != (widget.customer?.name ?? '') ||
      _phone.text != (widget.customer?.phone ?? '') ||
      _address.text != (widget.customer?.address ?? '');

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    Customer? duplicate;
    final looked = await _viewModel.run(() async {
      duplicate = await widget.repository.findByPhone(
        _phone.text,
        excludeId: widget.customer?.id,
      );
    });
    if (!mounted || !looked) return;

    final existing = duplicate;
    if (existing != null) {
      final saveAnyway = await showConfirmDialog(
        context,
        title: 'Number already used',
        message:
            'A customer with this number already exists: ${existing.name}. Save anyway?',
        confirmLabel: 'Save anyway',
      );
      if (!mounted || !saveAnyway) return;
    }

    String? savedId;
    final saved = await _viewModel.run(() async {
      final existingCustomer = widget.customer;
      if (existingCustomer == null) {
        savedId = await widget.repository.add(
          name: _name.text,
          phone: _phone.text,
          address: _address.text,
        );
      } else {
        await widget.repository.update(
          existingCustomer.id,
          name: _name.text,
          phone: _phone.text,
          address: _address.text,
        );
        savedId = existingCustomer.id;
      }
    });
    if (!mounted || !saved) return;
    _saved = true;
    Navigator.of(context).pop(savedId);
  }

  Future<void> _confirmDiscard() async {
    final discard = await showConfirmDialog(
      context,
      title: 'Discard changes?',
      message: 'What you entered will be lost.',
      confirmLabel: 'Discard',
      destructive: true,
    );
    if (!mounted || !discard) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_name, _phone, _address, _viewModel]),
      builder: (context, _) {
        final busy = _viewModel.isLoading;
        return PopScope(
          canPop: _saved || !_isDirty,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _confirmDiscard();
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(_isEditing ? 'Edit customer' : 'Add customer'),
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
                          AppTextField.name(
                            controller: _name,
                            label: 'Customer name',
                            hint: 'e.g. Ali Raza',
                            enabled: !busy,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          AppTextField.phone(
                            controller: _phone,
                            label: 'Phone number',
                            enabled: !busy,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          AppTextField.multiline(
                            controller: _address,
                            label: 'Full address',
                            hint: 'House, street, area, city',
                            isRequired: true,
                            maxLength: 200,
                            enabled: !busy,
                            validator: (value) => AppValidators.address(
                              value,
                              fieldName: 'Full address',
                            ),
                          ),
                          if (_viewModel.errorMessage != null) ...[
                            const SizedBox(height: AppSpacing.lg),
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                _viewModel.errorMessage!,
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
                            label: _isEditing
                                ? 'Save Changes'
                                : 'Save Customer',
                            isLoading: busy,
                            onPressed: _save,
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
