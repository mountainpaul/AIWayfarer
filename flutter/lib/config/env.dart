/// Compile/runtime configuration for Wayfarer.
///
/// API_BASE_URL can be overridden at build time via:
///   flutter run --dart-define=API_BASE_URL=https://wayfarer.example.com
class Env {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  /// SQLite database file name on device.
  static const String dbFileName = 'wayfarer.db';
}
