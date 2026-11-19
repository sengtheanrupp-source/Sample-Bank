/// Build-time DEFAULTS. Everything API-related can be changed at runtime in
/// Settings (gear icon on Home); those values are saved on the device.
///
/// Optional build defaults:
///   flutter run \
///     --dart-define=BASE_URL=https://staging.bill24.io:22080 \
///     --dart-define=API_TOKEN=xxxxxxxx
class AppConfig {
  static const bankName = 'Romdoul Bank';

  static const defaultBaseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'https://staging.bill24.io:22080',
  );
  static const defaultApiToken = String.fromEnvironment(
    'API_TOKEN',
    defaultValue: '3c81cc406c554b7a90030efed8a4c23b',
  );
  static const defaultIssuerId = String.fromEnvironment(
    'ISSUER_ID',
    defaultValue: 'issuing@Bank',
  );
  static const defaultMock = bool.fromEnvironment('MOCK');

  static const confirmPath = '/qr/v2/confirm';
  static const requestTimeout = Duration(seconds: 20);

  /// Per-payment limits (sample values - set from your risk policy).
  static const maxUsd = 10000.0;
  static const maxKhr = 40000000.0;

  /// Sample FX rate used only to debit a USD account for a KHR QR (and back).
  static const khrPerUsd = 4100.0;
}
