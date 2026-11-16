/// Build-time configuration.
///
/// Override with `--dart-define`, for example:
/// `flutter run --dart-define=USE_MOCK_API=false --dart-define=API_BASE_URL=https://api.example.com`
class AppConfig {
  const AppConfig({required this.apiBaseUrl, required this.useMockApi});

  /// Values baked in at build time.
  static const AppConfig fromEnvironment = AppConfig(
    apiBaseUrl: String.fromEnvironment(
      'API_BASE_URL',
      // 10.0.2.2 is the host machine as seen from the Android emulator.
      defaultValue: 'http://10.0.2.2:8080',
    ),
    useMockApi: bool.fromEnvironment('USE_MOCK_API', defaultValue: true),
  );

  final String apiBaseUrl;

  /// While the backend does not exist, data sources answer from memory.
  final bool useMockApi;
}
