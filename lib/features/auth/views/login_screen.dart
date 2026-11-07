import 'package:flutter/material.dart';
import '../../../common_widgets/app_text_field.dart';
import '../../../common_widgets/primary_button.dart';
import '../data/auth_repository.dart';
import '../viewmodel/auth_action_view_model.dart';
import 'auth_scaffold.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.repository, required this.onSignUp});
  final AuthRepository repository;
  final VoidCallback onSignUp;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _viewModel = AuthActionViewModel();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await _viewModel.run(
      () => widget.repository.signIn(email: _email.text, password: _password.text),
    );
    if (!mounted || !ok) return;
    messenger.showSnackBar(const SnackBar(content: Text('Logged in successfully.')));
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
          subtitle: 'Log in to manage your parcels and payments.',
          errorMessage: _viewModel.errorMessage,
          fields: [
            AppTextField.email(controller: _email, enabled: !busy),
            AppTextField.password(
              controller: _password,
              enabled: !busy,
              minLength: 1,
              onFieldSubmitted: (_) => _submit(),
            ),
          ],
          button: PrimaryButton(label: 'Log In', isLoading: busy, onPressed: _submit),
          footer: AuthFooterLink(
            prompt: "Don't have an account?",
            action: 'Sign up',
            onPressed: widget.onSignUp,
          ),
        );
      },
    );
  }
}
