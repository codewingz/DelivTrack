import 'package:flutter/material.dart';

import '../../../common_widgets/app_text_field.dart';
import '../../../common_widgets/brand_loading_indicator.dart';
import '../../../common_widgets/primary_button.dart';
import '../../../constants/app_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/view_models/action_view_model.dart';
import '../../../design_system/foundations/spacing/app_spacing.dart';
import '../../../utils/app_validators.dart';
import '../data/sender_profile_repository.dart';
import '../domain/sender_profile.dart';

/// Screen where the merchant manages their return address, phone and sender name.
/// These details appear on parcel shipping slips, box labels, and customer invoices.
class SenderProfileScreen extends StatefulWidget {
  const SenderProfileScreen({super.key, required this.repository});

  final SenderProfileRepository repository;

  @override
  State<SenderProfileScreen> createState() => _SenderProfileScreenState();
}

class _SenderProfileScreenState extends State<SenderProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _viewModel = ActionViewModel();

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await widget.repository.getProfile();
      if (mounted && profile != null) {
        _name.text = profile.name;
        _phone.text = profile.phone;
        _address.text = profile.address;
      }
    } on AppFailure catch (e) {
      if (mounted) _viewModel.fail(e.message);
    } catch (_) {
      if (mounted) _viewModel.fail('Could not load profile. You can enter details below.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

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
    final success = await _viewModel.run(
      () => widget.repository.saveProfile(
        SenderProfile(
          name: _name.text,
          phone: _phone.text,
          address: _address.text,
        ),
      ),
    );
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sender details saved.'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sender & return details')),
      body: SafeArea(
        child: _loading
            ? const Center(child: BrandLoadingIndicator())
            : Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                      children: [
                        Text(
                          'These details will appear as your return address on parcel slips, box labels, and customer invoices.',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: AppColors.label),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AppTextField.name(
                          controller: _name,
                          label: 'Sender / Business name',
                          hint: 'e.g. Ali Collection',
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppTextField.phone(
                          controller: _phone,
                          label: 'Sender phone number',
                          hint: '0300 1234567',
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppTextField.multiline(
                          controller: _address,
                          label: 'Return address',
                          hint: 'Shop/House #, Street, City',
                          validator: (v) => AppValidators.address(
                            v,
                            fieldName: 'Return address',
                          ),
                        ),
                        ListenableBuilder(
                          listenable: _viewModel,
                          builder: (context, _) => _viewModel.errorMessage != null
                              ? Padding(
                                  padding: const EdgeInsets.only(
                                    top: AppSpacing.md,
                                  ),
                                  child: Text(
                                    _viewModel.errorMessage!,
                                    style: const TextStyle(
                                      color: AppColors.error,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        ListenableBuilder(
                          listenable: _viewModel,
                          builder: (context, _) => PrimaryButton(
                            label: 'Save details',
                            isLoading: _viewModel.isLoading,
                            onPressed: _save,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
