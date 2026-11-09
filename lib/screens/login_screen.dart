import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../utils/auth_utils.dart';
import '../widgets/auth_widgets.dart';
import 'home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _auth = AuthService();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _auth.login(email: _email.text.trim(), password: _password.text);
      // Lets the OS password manager offer to save the credentials.
      TextInput.finishAutofillContext();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    } catch (e) {
      if (mounted) setState(() => _error = AuthErrors.friendly(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AuthScaffold(
      footer: AuthFooterLink(
        prompt: 'New to Nook?',
        action: 'Create an account',
        onTap: () => Navigator.push(context, AuthRoute.fade(const RegisterScreen())),
      ),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Welcome back', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 6),
              Text('Sign in to your campus community.', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 22),
              AuthMessage(text: _error),
              AuthTextField(
                controller: _email,
                label: 'Email address',
                icon: Icons.mail_outline_rounded,
                enabled: !_loading,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: AuthValidators.email,
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
              ),
              const SizedBox(height: 14),
              AuthTextField(
                controller: _password,
                label: 'Password',
                icon: Icons.lock_outline_rounded,
                isPassword: true,
                enabled: !_loading,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                validator: AuthValidators.currentPassword,
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onFieldSubmitted: (_) => _login(),
              ),
              const SizedBox(height: 22),
              AuthButton(label: 'Sign in', loading: _loading, onPressed: _login),
            ],
          ),
        ),
      ),
    );
  }
}
