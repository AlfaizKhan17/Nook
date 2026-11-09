/// Pure-Dart helpers for turning a poster's saved contact details into
/// tappable links, plus a small relative-time formatter.
///
/// Kept free of Flutter imports so it can be unit-tested anywhere.
class ContactUtils {
  const ContactUtils._();

  /// Keeps only digits and a single leading "+". Returns null when the value
  /// cannot be a real phone number (E.164 allows at most 15 digits).
  static String? dialNumber(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 5 || digits.length > 15) return null;
    return trimmed.startsWith('+') ? '+$digits' : digits;
  }

  /// International digits (no "+") as required by wa.me links.
  ///
  /// * "+91 98765 43210"  -> 919876543210
  /// * "0091 98765 43210" -> 919876543210
  /// * "098765 43210"     -> 919876543210 (leading 0 dropped, default code added)
  /// * "98765 43210"      -> 919876543210 (10 digits, default code added)
  /// * anything else      -> digits as typed (assumed to include a country code)
  static String? whatsappNumber(String? raw, {String defaultCountryCode = '91'}) {
    final dial = dialNumber(raw);
    if (dial == null) return null;
    if (dial.startsWith('+')) return dial.substring(1);
    if (dial.startsWith('00')) return dial.substring(2);
    final digits = dial.replaceFirst(RegExp(r'^0+'), '');
    if (digits.length == 10) return '$defaultCountryCode$digits';
    return digits;
  }

  static Uri? telUri(String? raw) {
    final number = dialNumber(raw);
    return number == null ? null : Uri(scheme: 'tel', path: number);
  }

  static Uri? whatsappUri(
    String? raw,
    String message, {
    String defaultCountryCode = '91',
  }) {
    final number = whatsappNumber(raw, defaultCountryCode: defaultCountryCode);
    if (number == null) return null;
    return Uri.parse('https://wa.me/$number?text=${Uri.encodeComponent(message)}');
  }

  static bool isValidEmail(String? email) =>
      email != null && RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.trim());

  /// Built by hand because [Uri.queryParameters] encodes spaces as "+", which
  /// many mail apps show literally.
  static Uri? mailUri(String? email, {String? subject, String? body}) {
    if (!isValidEmail(email)) return null;
    final params = <String>[
      if (subject != null && subject.isNotEmpty) 'subject=${Uri.encodeComponent(subject)}',
      if (body != null && body.isNotEmpty) 'body=${Uri.encodeComponent(body)}',
    ];
    final query = params.isEmpty ? '' : '?${params.join('&')}';
    return Uri.parse('mailto:${email!.trim()}$query');
  }

  /// Opening line for a message to the poster, worded for the listing type.
  static String contactMessage({required String itemType, required String title}) {
    if (itemType == 'FOUND') {
      return 'Hi, I saw your Nook post about the found item "$title". '
          'I think it may be mine. Can we talk?';
    }
    return 'Hi, I saw your Nook post about the lost item "$title". '
        'I may have information about it. Can we talk?';
  }

  static String mailSubject({required String itemType, required String title}) =>
      '${itemType == 'FOUND' ? 'Found' : 'Lost'} item on Nook: $title';

  /// "Just now", "5 min ago", "3 hr ago", "2 days ago", "3 wk ago", ...
  static String timeAgo(DateTime time, {DateTime? now}) {
    final diff = (now ?? DateTime.now()).difference(time);
    if (diff.inSeconds < 60) return 'Just now'; // also covers small clock skew
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays < 7) {
      return '${diff.inDays} ${diff.inDays == 1 ? 'day' : 'days'} ago';
    }
    if (diff.inDays < 30) return '${diff.inDays ~/ 7} wk ago';
    if (diff.inDays < 365) return '${diff.inDays ~/ 30} mo ago';
    return '${diff.inDays ~/ 365} yr ago';
  }
}
