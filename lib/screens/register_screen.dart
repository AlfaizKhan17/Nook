import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../utils/auth_utils.dart';
import '../widgets/auth_widgets.dart';
import 'home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _auth = AuthService();

  bool _loading = false;
  String? _error;

  /// Set when the account was created but the email must be confirmed first.
  String? _confirmationSentTo;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final email = _email.text.trim();
      final response = await _auth.register(
        name: _name.text.trim(),
        email: email,
        phone: _phone.text.trim(),
        password: _password.text,
      );
      TextInput.finishAutofillContext();
      if (!mounted) return;

      if (response.session == null) {
        // Email confirmation is enabled: show a clear next step instead of a toast.
        setState(() => _confirmationSentTo = email);
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (_) => false,
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = AuthErrors.friendly(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    final sent = _confirmationSentTo != null;

    return AuthScaffold(
      showBack: true,
      compactBrand: true,
      footer: AuthFooterLink(
        prompt: 'Already have an account?',
        action: 'Sign in',
        onTap: () => Navigator.maybePop(context),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: sent ? _confirmation(context) : _form(context),
      ),
    );
  }

  Widget _form(BuildContext context) {
    final theme = Theme.of(context);
    final typoHint = AuthValidators.emailTypoHint(_email.text);

    return AutofillGroup(
      key: const ValueKey('form'),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Create your account', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 6),
            Text('Join your campus in under a minute.', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 22),
            AuthMessage(text: _error),
            AuthTextField(
              controller: _name,
              label: 'Full name',
              icon: Icons.person_outline_rounded,
              enabled: !_loading,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              validator: AuthValidators.name,
              onChanged: (_) => _clearError(),
            ),
            const SizedBox(height: 14),
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
                _clearError();
                setState(() {}); // refresh the typo suggestion
              },
            ),
            if (typoHint != null)
              Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => _email.text = typoHint),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                    child: Text(
                      'Did you mean $typoHint?',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 14),
            AuthTextField(
              controller: _phone,
              label: 'Phone number',
              icon: Icons.phone_outlined,
              enabled: !_loading,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.telephoneNumber],
              helperText: 'Shown to people who contact you about lost & found items.',
              validator: AuthValidators.phone,
              onChanged: (_) => _clearError(),
            ),
            const SizedBox(height: 14),
            AuthTextField(
              controller: _password,
              label: 'Password',
              icon: Icons.lock_outline_rounded,
              isPassword: true,
              enabled: !_loading,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              validator: AuthValidators.newPassword,
              onChanged: (_) {
                _clearError();
                setState(() {}); // refresh the strength meter
              },
            ),
            PasswordStrengthMeter(password: _password.text),
            const SizedBox(height: 14),
            AuthTextField(
              controller: _confirm,
              label: 'Confirm password',
              icon: Icons.lock_reset_rounded,
              isPassword: true,
              enabled: !_loading,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              validator: AuthValidators.confirmPassword(() => _password.text),
              onChanged: (_) => _clearError(),
              onFieldSubmitted: (_) => _register(),
            ),
            const SizedBox(height: 22),
            AuthButton(label: 'Create account', loading: _loading, onPressed: _register),
          ],
        ),
      ),
    );
  }

  Widget _confirmation(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Column(
      key: const ValueKey('confirmation'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(color: primary.withValues(alpha: .12), shape: BoxShape.circle),
            child: Icon(Icons.mark_email_read_outlined, color: primary, size: 32),
          ),
        ),
        const SizedBox(height: 18),
        Text('Check your inbox', textAlign: TextAlign.center, style: theme.textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          'We sent a confirmation link to\n$_confirmationSentTo.\nConfirm your email, then sign in.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
        ),
        const SizedBox(height: 24),
        AuthButton(label: 'Back to sign in', loading: false, onPressed: () => Navigator.maybePop(context)),
      ],
    );
  }
}
