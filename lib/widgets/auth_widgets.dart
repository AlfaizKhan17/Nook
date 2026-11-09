import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../utils/auth_utils.dart';
import 'auth_background.dart';

/// Shared frame for the sign-in and register screens: painted backdrop, brand
/// header, a floating form card and an optional footer line.
class AuthScaffold extends StatelessWidget {
  /// Contents of the white/dark form card.
  final Widget child;

  /// Sits on the backdrop under the card, e.g. "New to Nook? Create an account".
  final Widget? footer;

  /// Shows a back arrow over the backdrop.
  final bool showBack;

  /// Smaller brand header, used on the longer register form.
  final bool compactBrand;

  const AuthScaffold({
    super.key,
    required this.child,
    this.footer,
    this.showBack = false,
    this.compactBrand = false,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: const Color(0xFF050B1F),
        body: AuthBackground(
          child: SafeArea(
            child: Stack(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final padding = EdgeInsets.fromLTRB(20, showBack ? 56 : 24, 20, 24);
                    return SingleChildScrollView(
                      padding: padding,
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight - padding.vertical),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 440),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _Brand(compact: compactBrand),
                                SizedBox(height: compactBrand ? 20 : 30),
                                TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0, end: 1),
                                  duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 550),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, value, card) => Opacity(
                                    opacity: value,
                                    child: Transform.translate(offset: Offset(0, (1 - value) * 24), child: card),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.surface,
                                      borderRadius: BorderRadius.circular(28),
                                      border: dark ? Border.all(color: Colors.white.withValues(alpha: .08)) : null,
                                      boxShadow: const [
                                        BoxShadow(color: Color(0x4D000000), blurRadius: 40, offset: Offset(0, 20)),
                                      ],
                                    ),
                                    child: child,
                                  ),
                                ),
                                if (footer != null) ...[const SizedBox(height: 20), footer!],
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                if (showBack)
                  Positioned(
                    top: 6,
                    left: 12,
                    child: Material(
                      color: Colors.white.withValues(alpha: .14),
                      shape: CircleBorder(side: BorderSide(color: Colors.white.withValues(alpha: .22))),
                      child: IconButton(
                        tooltip: 'Back',
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                        onPressed: () => Navigator.maybePop(context),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  final bool compact;
  const _Brand({required this.compact});

  @override
  Widget build(BuildContext context) {
    final size = compact ? 56.0 : 72.0;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A84FF), Color(0xFF5E5CE6)],
          ),
          borderRadius: BorderRadius.circular(size * .3),
          border: Border.all(color: Colors.white.withValues(alpha: .28)),
          boxShadow: const [BoxShadow(color: Color(0x660A84FF), blurRadius: 28, offset: Offset(0, 10))],
        ),
        child: Icon(Icons.spa_rounded, color: Colors.white, size: size * .5),
      ),
      SizedBox(height: compact ? 10 : 14),
      Text(
        'nook.',
        style: TextStyle(color: Colors.white, fontSize: compact ? 28 : 36, fontWeight: FontWeight.w800, letterSpacing: -1.3),
      ),
      const SizedBox(height: 4),
      Text(
        'A little place for your campus life.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white.withValues(alpha: .74), fontSize: 13.5),
      ),
    ]);
  }
}

/// "New to Nook? Create an account" line for [AuthScaffold.footer].
class AuthFooterLink extends StatelessWidget {
  final String prompt;
  final String action;
  final VoidCallback onTap;
  const AuthFooterLink({super.key, required this.prompt, required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(prompt, style: TextStyle(color: Colors.white.withValues(alpha: .78), fontSize: 14)),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 8)),
          child: Text(action, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        ),
      ],
    );
  }
}

/// Cross-fade between the two auth screens so the backdrop feels continuous.
class AuthRoute {
  const AuthRoute._();

  static Route<T> fade<T>(Widget page) => PageRouteBuilder<T>(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
      );
}

/// Text field used by both auth forms. Handles its own show/hide-password toggle.
class AuthTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool isPassword;
  final bool enabled;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final String? helperText;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.isPassword = false,
    this.enabled = true,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.helperText,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
  });

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final isEmail = widget.keyboardType == TextInputType.emailAddress;

    return TextFormField(
      controller: widget.controller,
      enabled: widget.enabled,
      obscureText: widget.isPassword && _hidden,
      keyboardType: widget.isPassword ? null : widget.keyboardType,
      textInputAction: widget.textInputAction,
      textCapitalization: widget.textCapitalization,
      autofillHints: widget.autofillHints,
      autocorrect: !(widget.isPassword || isEmail),
      enableSuggestions: !widget.isPassword,
      validator: widget.validator,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onFieldSubmitted,
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helperText,
        helperMaxLines: 2,
        prefixIcon: Icon(widget.icon),
        // The card is a surface colour, so fields need their own fill to stay visible.
        filled: true,
        fillColor: dark ? AppColors.darkElevated : AppColors.canvas,
        suffixIcon: widget.isPassword
            ? IconButton(
                tooltip: _hidden ? 'Show password' : 'Hide password',
                icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _hidden = !_hidden),
              )
            : null,
      ),
    );
  }
}

/// Full-width primary button with a built-in loading state.
class AuthButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onPressed;
  const AuthButton({super.key, required this.label, required this.loading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        disabledBackgroundColor: primary.withValues(alpha: .75),
        disabledForegroundColor: Colors.white,
      ),
      child: loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
            )
          : Text(label, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
    );
  }
}

/// Inline error (or success) banner that animates in above the form.
class AuthMessage extends StatelessWidget {
  final String? text;
  final bool success;
  const AuthMessage({super.key, this.text, this.success = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = success ? AppColors.found : scheme.error;

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      alignment: Alignment.topCenter,
      child: text == null
          ? const SizedBox(width: double.infinity)
          : Semantics(
              liveRegion: true,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withValues(alpha: .35)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(success ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded, color: accent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(text!, style: TextStyle(color: scheme.onSurface, fontSize: 13.5, height: 1.35))),
                ]),
              ),
            ),
    );
  }
}

/// Four-segment strength bar shown under the new-password field.
class PasswordStrengthMeter extends StatelessWidget {
  final String password;
  const PasswordStrengthMeter({super.key, required this.password});

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();

    final score = PasswordStrength.score(password);
    final filled = score == 0 ? 1 : score;
    final color = score <= 1
        ? AppColors.lost
        : score == 2
            ? const Color(0xFFFF9F0A)
            : AppColors.found;
    final empty = Theme.of(context).colorScheme.outline;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(children: [
        for (var i = 0; i < 4; i++) ...[
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 4,
              decoration: BoxDecoration(color: i < filled ? color : empty, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          if (i < 3) const SizedBox(width: 5),
        ],
        const SizedBox(width: 12),
        SizedBox(
          width: 64,
          child: Text(
            PasswordStrength.label(password),
            textAlign: TextAlign.end,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      ]),
    );
  }
}
