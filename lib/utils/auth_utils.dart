import 'contact_utils.dart';

/// Form validators for the login and register screens. Each returns an error
/// message, or null when the value is acceptable.
class AuthValidators {
  const AuthValidators._();

  static String? name(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter your full name';
    if (text.length < 2) return 'That name looks too short';
    return null;
  }

  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter your email address';
    if (!ContactUtils.isValidEmail(text)) return 'Enter a valid email address';
    return null;
  }

  static String? phone(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter your phone number';
    if (ContactUtils.dialNumber(text) == null) return 'Enter a valid phone number';
    return null;
  }

  /// Sign-in only checks presence; the server decides if it is correct.
  static String? currentPassword(String? value) =>
      (value == null || value.isEmpty) ? 'Enter your password' : null;

  /// Supabase's default minimum is 6 characters.
  static String? newPassword(String? value) {
    if (value == null || value.isEmpty) return 'Create a password';
    if (value.length < 6) return 'Use at least 6 characters';
    return null;
  }

  static String? Function(String?) confirmPassword(String Function() original) {
    return (value) {
      if (value == null || value.isEmpty) return 'Re-enter your password';
      if (value != original()) return 'Passwords do not match';
      return null;
    };
  }

  /// Suggests a corrected address for common typos such as "name@gmail.con" or
  /// "name@gmial.com". Returns null when nothing looks wrong.
  static String? emailTypoHint(String? value) {
    final text = value?.trim() ?? '';
    final at = text.lastIndexOf('@');
    if (at <= 0 || at == text.length - 1) return null;

    final local = text.substring(0, at);
    final domain = text.substring(at + 1).toLowerCase();

    const domainFixes = {
      'gmial.com': 'gmail.com',
      'gmai.com': 'gmail.com',
      'gmaill.com': 'gmail.com',
      'gnail.com': 'gmail.com',
      'gmail.co': 'gmail.com',
      'gamil.com': 'gmail.com',
      'hotmial.com': 'hotmail.com',
      'hotmal.com': 'hotmail.com',
      'yahooo.com': 'yahoo.com',
      'yaho.com': 'yahoo.com',
      'outlok.com': 'outlook.com',
      'outloook.com': 'outlook.com',
      'iclod.com': 'icloud.com',
    };
    final fixedDomain = domainFixes[domain];
    if (fixedDomain != null) return '$local@$fixedDomain';

    // Mistyped ".com" endings: .con .cmo .ocm .vom .xom .comm
    final tld = RegExp(r'\.(con|cmo|ocm|vom|xom|comm)$');
    if (tld.hasMatch(domain)) {
      return '$local@${domain.replaceFirst(tld, '.com')}';
    }
    return null;
  }
}

/// Simple, honest password feedback (length + character variety).
class PasswordStrength {
  const PasswordStrength._();

  /// 0 (weak) to 4 (strong). Anything under 6 characters scores 0.
  static int score(String password) {
    if (password.length < 6) return 0;
    var points = 0;
    if (password.length >= 8) points++;
    if (RegExp(r'[a-z]').hasMatch(password) && RegExp(r'[A-Z]').hasMatch(password)) points++;
    if (RegExp(r'\d').hasMatch(password)) points++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) points++;
    return points;
  }

  static String label(String password) {
    if (password.isEmpty) return '';
    if (password.length < 6) return 'Too short';
    const labels = ['Weak', 'Weak', 'Fair', 'Good', 'Strong'];
    return labels[score(password)];
  }
}

/// Turns raw exceptions from Supabase auth into short, friendly sentences.
class AuthErrors {
  const AuthErrors._();

  static String friendly(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    final lower = raw.toLowerCase();

    if (lower.contains('invalid login credentials')) {
      return 'Incorrect email or password.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Please confirm your email first. Check your inbox for the link.';
    }
    if (lower.contains('already registered') ||
        lower.contains('already been registered') ||
        lower.contains('user_already_exists')) {
      return 'An account with this email already exists. Try signing in instead.';
    }
    if (lower.contains('rate limit') || lower.contains('too many')) {
      return 'Too many attempts. Please wait a minute and try again.';
    }
    if (lower.contains('password') &&
        (lower.contains('weak') || lower.contains('at least'))) {
      return 'Choose a stronger password (at least 6 characters).';
    }
    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('clientexception') ||
        lower.contains('network')) {
      return 'No internet connection. Check your network and try again.';
    }

    // AuthException(message: Something, statusCode: 400) -> "Something"
    final match = RegExp(r'message:\s*(.*?)(?:,\s*(?:statusCode|code)\b|\)$)')
        .firstMatch(raw);
    final text = (match?.group(1) ?? raw).trim();
    if (text.isEmpty) return 'Something went wrong. Please try again.';
    return text[0].toUpperCase() + text.substring(1);
  }
}
