import '../../../common_widgets/app_snack_bar.dart';

import 'package:flutter/material.dart';

import '../../../common_widgets/app_3d_decorations.dart';
import '../../../common_widgets/app_choice_field.dart';
import '../../../common_widgets/app_text_field.dart';
import '../../../common_widgets/brand_loading_indicator.dart';
import '../../../common_widgets/liquid_glass.dart';
import '../../../common_widgets/primary_button.dart';
import '../../../constants/app_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/view_models/action_view_model.dart';
import '../../../design_system/foundations/radius/app_radius.dart';
import '../../../design_system/foundations/spacing/app_spacing.dart';
import '../../../utils/text.dart';
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
  final _business = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _viewModel = ActionViewModel();

  bool _loading = true;

  /// The saved details, shown read-only until Edit is tapped; null when
  /// nothing is saved yet (the form is shown).
  SenderProfile? _saved;
  bool _preferSenderName = false;
  bool _invoiceUsesSenderName = false;
  bool _labelUsesSenderName = false;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await widget.repository.getProfile();
      if (mounted && profile != null) {
        _saved = profile;
        _fill(profile);
      }
    } on AppFailure catch (e) {
      if (mounted) _viewModel.fail(e.message);
    } catch (_) {
      if (mounted) {
        _viewModel.fail('Could not load profile. You can enter details below.');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _fill(SenderProfile profile) {
    _name.text = profile.name;
    _business.text = profile.businessName;
    _preferSenderName = profile.preferSenderName;
    _invoiceUsesSenderName = profile.invoiceUsesSenderName;
    _labelUsesSenderName = profile.labelUsesSenderName;
    _phone.text = profile.phone;
    _address.text = profile.address;
  }

  @override
  void dispose() {
    _name.dispose();
    _business.dispose();
    _phone.dispose();
    _address.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final profile = SenderProfile(
      name: collapseSpaces(_name.text),
      businessName: collapseSpaces(_business.text),
      preferSenderName: _preferSenderName,
      invoiceUsesSenderName: _invoiceUsesSenderName,
      labelUsesSenderName: _labelUsesSenderName,
      phone: collapseSpaces(_phone.text),
      address: collapseSpaces(_address.text),
    );
    final success = await _viewModel.run(
      () => widget.repository.saveProfile(profile),
    );
    if (!success || !mounted) return;
    // Back to the read-only view of what was saved.
    setState(() {
      _saved = profile;
      _editing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      appSnackBar(
        'Sender details saved.',
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final saved = _saved;
    return Scaffold(
      // The backdrop continues behind the header's curve.
      extendBodyBehindAppBar: true,
      appBar: appCurvedAppBar(
        toolbarHeight: AppBarTitle.heightFor(context),
        title: const AppBarTitle(
          'Sender & return details',
          subtitle: 'Return address for slips & invoices',
        ),
      ),
      body: LiquidBackground(
        child: SafeArea(
          child: _loading
              ? const Center(child: BrandLoadingIndicator())
              : Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Padding(
                              padding: EdgeInsetsDirectional.symmetric(
                                horizontal: AppSpacing.xs,
                              ),
                              child: Text(
                                'These details will appear as your return address on parcel slips, box labels, and customer invoices.',
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.4,
                                  color: AppColors.label,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            if (saved != null && !_editing)
                              _SavedDetails(
                                profile: saved,
                                onEdit: () => setState(() {
                                  _fill(saved);
                                  _editing = true;
                                }),
                              )
                            else
                              ..._form(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  List<Widget> _form() {
    return [
      App3DCard(
        glass: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField.name(
              controller: _name,
              label: 'Sender name',
              hint: 'Enter sender name',
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField.name(
              controller: _business,
              label: 'Business name (optional)',
              hint: 'Enter business name',
              icon: Icons.storefront_outlined,
              isRequired: false,
            ),
            // Which name is used in each place. Without a business name the
            // sender name is used everywhere.
            for (final (label, initial, onChanged) in [
              (
                'Name in WhatsApp messages',
                _preferSenderName,
                (bool v) => _preferSenderName = v,
              ),
              (
                'Name on invoices',
                _invoiceUsesSenderName,
                (bool v) => _invoiceUsesSenderName = v,
              ),
              (
                'Name on printed labels',
                _labelUsesSenderName,
                (bool v) => _labelUsesSenderName = v,
              ),
            ]) ...[
              const SizedBox(height: AppSpacing.lg),
              AppChoiceField<bool>(
                label: label,
                initialValue: initial,
                options: const [
                  (value: false, label: 'Business name'),
                  (value: true, label: 'Sender name'),
                ],
                onChanged: onChanged,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppTextField.phone(
              controller: _phone,
              label: 'Sender phone number',
              hint: 'Enter sender phone number',
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField.multiline(
              controller: _address,
              label: 'Return address',
              hint: 'Enter return address',
              isRequired: true,
              validator: (v) =>
                  AppValidators.address(v, fieldName: 'Return address'),
            ),
          ],
        ),
      ),
      ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) => _viewModel.errorMessage != null
            ? Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Semantics(
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
              )
            : const SizedBox.shrink(),
      ),
      const SizedBox(height: AppSpacing.lg),
      ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) => PrimaryButton(
          label: 'Save details',
          isLoading: _viewModel.isLoading,
          onPressed: _save,
        ),
      ),
    ];
  }
}

/// The saved details, read-only, with an Edit button.
class _SavedDetails extends StatelessWidget {
  const _SavedDetails({required this.profile, required this.onEdit});
  final SenderProfile profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final hasBusiness = profile.businessName.isNotEmpty;
    return App3DCard(
      glass: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The Edit button moves under the name when both do not fit.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.brand50,
                      borderRadius: BorderRadius.circular(AppRadius.control),
                      border: Border.all(color: AppColors.brand100),
                    ),
                    child: const SizedBox(
                      width: 48,
                      height: 48,
                      child: ExcludeSemantics(
                        child: Icon(
                          Icons.storefront_outlined,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          hasBusiness ? profile.businessName : profile.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (hasBusiness)
                          Text(
                            'Sender: ${profile.name}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.label,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              GlassSurface(
                radius: AppRadius.control,
                ledgeHeight: 3,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.control),
                    ),
                  ),
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text(
                    'Edit',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: AppSpacing.x3l, color: AppColors.border),
          const _FieldLabel('Sender phone number'),
          Text(
            profile.phone,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('Return address'),
          Text(
            profile.address,
            style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
          ),
          for (final (label, value) in [
            ('Name in WhatsApp messages', profile.customerFacingName),
            ('Name on invoices', profile.invoiceName),
            ('Name on printed labels', profile.labelName),
          ]) ...[
            const SizedBox(height: AppSpacing.md),
            _FieldLabel(label),
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        letterSpacing: 1,
        color: AppColors.textSecondary,
      ),
    );
  }
}
