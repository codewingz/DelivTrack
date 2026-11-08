import 'package:flutter/material.dart';

import '../../../common_widgets/app_text_field.dart';
import '../../../common_widgets/confirm_dialog.dart';
import '../../../common_widgets/primary_button.dart';
import '../../../constants/app_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/view_models/action_view_model.dart';
import '../../../design_system/foundations/spacing/app_spacing.dart';
import '../../../utils/app_validators.dart';
import '../../../utils/phone.dart';
import '../../../utils/text.dart';
import '../data/contact_picker.dart';
import '../data/customer_repository.dart';
import '../domain/customer.dart';

/// Add or edit a customer on a full screen. Pops with the saved customer's id,
/// so a caller (e.g. Add Parcel) can select the new customer.
class CustomerFormScreen extends StatefulWidget {
  const CustomerFormScreen({
    super.key,
    required this.repository,
    this.customer,
    this.contactPicker = const SystemContactPicker(),
  });
  final CustomerRepository repository;

  /// Where "Choose from contacts" gets the number from.
  final ContactPicker contactPicker;

  /// Null when adding.
  final Customer? customer;

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.customer?.name);
  late final _phone = TextEditingController(text: widget.customer?.phone);
  late final _phone2 = TextEditingController(text: widget.customer?.phone2);
  late final _address = TextEditingController(text: widget.customer?.address);
  late final _details = TextEditingController(
    text: widget.customer?.businessDetails,
  );
  final _viewModel = ActionViewModel();

  /// The name last filled in from a contact. While the name field still holds exactly this, the
  /// user has not typed their own, so choosing another contact may replace it.
  String? _autoName;
  bool _saved = false;
  bool _picking = false;
  bool _triedToSave = false;

  bool get _isEditing => widget.customer != null;

  bool get _isDirty =>
      _name.text != (widget.customer?.name ?? '') ||
      _phone.text != (widget.customer?.phone ?? '') ||
      _phone2.text != (widget.customer?.phone2 ?? '') ||
      _address.text != (widget.customer?.address ?? '') ||
      _details.text != (widget.customer?.businessDetails ?? '');

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _phone2.dispose();
    _address.dispose();
    _details.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  /// Fills [target] with the number of a contact the user picks. Only the first number also fills
  /// the name, and only while the name is empty or still the one a previous pick filled in, so a
  /// name the user typed (or the first contact's name) is never replaced by the second number.
  Future<void> _pickContact(
    TextEditingController target, {
    bool fillName = false,
  }) async {
    if (_picking) return;
    _picking = true;
    PickedContact? picked;
    String? problem;
    try {
      picked = await widget.contactPicker.pick();
    } on AppFailure catch (e) {
      problem = e.message;
    } finally {
      _picking = false;
    }
    if (!mounted) return;
    if (problem != null) return _viewModel.fail(problem);
    if (picked == null) return;
    target.text = cleanContactPhone(picked.phone);
    final name = collapseSpaces(picked.name);
    if (fillName &&
        name.isNotEmpty &&
        (_name.text.trim().isEmpty || _name.text == _autoName)) {
      _autoName = name.length > 60 ? name.substring(0, 60).trim() : name;
      _name.text = _autoName!;
    }
    // Once Save has shown errors, picking a number should clear the phone error right away.
    if (_triedToSave) _formKey.currentState?.validate();
  }

  Future<void> _save() async {
    _triedToSave = true;
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
          phone2: _phone2.text,
          businessDetails: _details.text,
        );
      } else {
        await widget.repository.update(
          existingCustomer.id,
          name: _name.text,
          phone: _phone.text,
          address: _address.text,
          phone2: _phone2.text,
          businessDetails: _details.text,
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
      listenable: Listenable.merge([
        _name,
        _phone,
        _phone2,
        _address,
        _details,
        _viewModel,
      ]),
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
                            onPickContact: () =>
                                _pickContact(_phone, fillName: true),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          AppTextField.phone(
                            controller: _phone2,
                            label: 'Second phone number (optional)',
                            hint: 'Another number',
                            isRequired: false,
                            enabled: !busy,
                            onPickContact: () => _pickContact(_phone2),
                            validator: (value) =>
                                (value ?? '').trim().isNotEmpty &&
                                    normalizePhone(value!) ==
                                        normalizePhone(_phone.text)
                                ? 'This is the same as the first number'
                                : null,
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
                          const SizedBox(height: AppSpacing.lg),
                          AppTextField.multiline(
                            controller: _details,
                            label: 'Business details (optional)',
                            hint: 'e.g. Animate Dairy Farm, buyer of high-protein feed',
                            minLines: 2,
                            maxLength: 200,
                            enabled: !busy,
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
