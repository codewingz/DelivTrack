import 'package:flutter/material.dart';
import '../../../common_widgets/app_text_field.dart';
import '../../../common_widgets/primary_button.dart';
import '../data/auth_repository.dart';
import '../viewmodel/auth_action_view_model.dart';
import 'auth_scaffold.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key, required this.repository, required this.onLogIn});
  final AuthRepository repository;
  final VoidCallback onLogIn;

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _viewModel = AuthActionViewModel();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    // On success the router redirects to the dashboard.
    await _viewModel.run(
      () => widget.repository.signUp(
        name: _name.text,
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
          title: 'Create account',
          errorMessage: _viewModel.errorMessage,
          fields: [
            AppTextField.name(controller: _name, enabled: !busy),
            AppTextField.email(controller: _email, enabled: !busy),
            AppTextField.password(
              controller: _password,
              enabled: !busy,
              textInputAction: TextInputAction.next,
            ),
            AppTextField.confirmPassword(
              controller: _confirm,
              passwordController: _password,
              enabled: !busy,
              onFieldSubmitted: (_) => _submit(),
            ),
          ],
          button: PrimaryButton(label: 'Sign Up', isLoading: busy, onPressed: _submit),
          footer: AuthFooterLink(
            prompt: 'Already have an account?',
            action: 'Log in',
            onPressed: widget.onLogIn,
          ),
        );
      },
    );
  }
}
