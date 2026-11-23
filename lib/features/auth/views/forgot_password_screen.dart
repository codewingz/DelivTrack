import 'package:flutter/material.dart';

import '../../../common_widgets/app_text_field.dart';
import '../../../common_widgets/primary_button.dart';
import '../../../constants/app_colors.dart';
import '../data/auth_repository.dart';
import '../../../core/view_models/action_view_model.dart';
import 'auth_scaffold.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    required this.repository,
    required this.onBackToLogin,
  });
  final AuthRepository repository;
  final VoidCallback onBackToLogin;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _viewModel = ActionViewModel();
  String? _sentTo;

  @override
  void dispose() {
    _email.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _email.text.trim();
    setState(() => _sentTo = null);
    final sent = await _viewModel.run(
      () => widget.repository.sendPasswordReset(email: email),
    );
    if (!mounted || !sent) return;
    setState(() => _sentTo = email);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final busy = _viewModel.isLoading;
        return AuthScaffold(
          formKey: _formKey,
          title: 'Reset password',
          subtitle: 'Enter your email to recover access',
          errorMessage: _viewModel.errorMessage,
          successMessage: _sentTo == null
              ? null
              : 'If an account exists for $_sentTo, a reset link is on its way. '
                    'Check your inbox and spam folder.',
          fields: [
            AppTextField.email(
              controller: _email,
              enabled: !busy,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
            ),
          ],
          button: PrimaryButton(
            label: _sentTo == null ? 'Send Reset Link' : 'Resend Link',
            isLoading: busy,
            onPressed: _submit,
          ),
          topLink: TextButton.icon(
            onPressed: widget.onBackToLogin,
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              padding: EdgeInsets.zero,
              foregroundColor: AppColors.primary,
            ),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text(
              'Back to Sign In',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        );
      },
    );
  }
}
