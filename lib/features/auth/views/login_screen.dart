import 'package:flutter/material.dart';

import '../../../common_widgets/app_text_field.dart';
import '../../../common_widgets/primary_button.dart';
import '../../../constants/app_colors.dart';
import '../../../design_system/foundations/spacing/app_spacing.dart';
import '../data/auth_repository.dart';
import '../../../core/view_models/action_view_model.dart';
import 'auth_scaffold.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.repository,
    required this.onSignUp,
    required this.onForgotPassword,
  });
  final AuthRepository repository;
  final VoidCallback onSignUp;
  final VoidCallback onForgotPassword;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _viewModel = ActionViewModel();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    // On success the router redirects to the dashboard.
    await _viewModel.run(
      () => widget.repository.signIn(
        email: _email.text,
        password: _password.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final busy = _viewModel.isLoading;
        return AuthScaffold(
          formKey: _formKey,
          title: 'Welcome back',
          subtitle: 'Sign in to manage your parcels and payments.',
          errorMessage: _viewModel.errorMessage,
          fields: [
            AppTextField.email(controller: _email, enabled: !busy),
            AppTextField.password(
              controller: _password,
              enabled: !busy,
              minLength: 1,
              onFieldSubmitted: (_) => _submit(),
              labelAction: GestureDetector(
                onTap: busy ? null : widget.onForgotPassword,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Text(
                    'Forgot password?',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
          ],
          button: PrimaryButton(
            label: 'Sign In',
            isLoading: busy,
            onPressed: _submit,
          ),
          footer: AuthFooterLink(
            prompt: "Don't have an account?",
            action: 'Create account',
            onPressed: widget.onSignUp,
          ),
        );
      },
    );
  }
}
