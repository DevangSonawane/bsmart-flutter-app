/// Supabase configuration values.
///
/// This file does NOT depend on `flutter_dotenv` so it is safe to import
/// anywhere during app startup. Call `SupabaseConfig.init(...)` early in
/// `main()` (after loading any env files) to override defaults.
class SupabaseConfig {
  static String _url = 'https://ctjzgimqvxgttepxsqig.supabase.co';
  static String _anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN0anpnaW1xdnhndHRlcHhzcWlnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk1MTM4MjAsImV4cCI6MjA4NTA4OTgyMH0.XZ4bfERi9fJYvTXAy9y6NLc3lo975wbFMUq5j8LPPs4';
  static String _googleWebClientId =
      '832065490130-951s4duefbauqlf26nkmgi69numkj563.apps.googleusercontent.com';
  static String _googleAndroidClientId =
      '832065490130-951s4duefbauqlf26nkmgi69numkj563.apps.googleusercontent.com';
  static String _googleIosClientId = 'YOUR_IOS_CLIENT_ID.apps.googleusercontent.com';

  /// Initialize runtime values (call after loading dotenv in `main()`).
  static void init({
    String? url,
    String? anonKey,
    String? googleWebClientId,
    String? googleAndroidClientId,
    String? googleIosClientId,
  }) {
    if (url != null && url.isNotEmpty) _url = url;
    if (anonKey != null && anonKey.isNotEmpty) _anonKey = anonKey;
    if (googleWebClientId != null && googleWebClientId.isNotEmpty) {
      _googleWebClientId = googleWebClientId;
    }
    if (googleAndroidClientId != null && googleAndroidClientId.isNotEmpty) {
      _googleAndroidClientId = googleAndroidClientId;
    }
    if (googleIosClientId != null && googleIosClientId.isNotEmpty) {
      _googleIosClientId = googleIosClientId;
    }
  }

  static String get url => _url;
  static String get anonKey => _anonKey;
  static String get googleWebClientId => _googleWebClientId;
  static String get googleAndroidClientId => _googleAndroidClientId;
  static String get googleIosClientId => _googleIosClientId;
}
