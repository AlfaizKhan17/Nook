/// App-wide, non-secret settings.
class AppConfig {
  const AppConfig._();

  /// Country calling code (without "+") used when a saved phone number has no
  /// country code, e.g. a 10-digit local number. Needed to build WhatsApp links.
  static const String defaultCountryCode = '91';
}
