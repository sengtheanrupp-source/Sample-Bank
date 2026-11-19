import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

/// Runtime API configuration, editable from the Settings screen.
/// - base URL, issuer id, demo flag -> SharedPreferences
/// - token header                   -> Keychain / Android encrypted storage
class ApiSettings extends ChangeNotifier {
  static const _kBaseUrl = 'api.baseUrl';
  static const _kIssuer = 'api.issuerId';
  static const _kMock = 'api.mock';
  static const _kToken = 'api.token';

  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  String baseUrl = AppConfig.defaultBaseUrl;
  String token = AppConfig.defaultApiToken;
  String issuerId = AppConfig.defaultIssuerId;
  bool demoMode = AppConfig.defaultMock;

  /// Demo when switched on, or when no token is configured yet.
  bool get useMock => demoMode || token.trim().isEmpty;

  String get confirmUrl => '${_trimSlash(baseUrl)}${AppConfig.confirmPath}';

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      baseUrl = prefs.getString(_kBaseUrl) ?? baseUrl;
      issuerId = prefs.getString(_kIssuer) ?? issuerId;
      demoMode = prefs.getBool(_kMock) ?? demoMode;
      token = await _secure.read(key: _kToken) ?? token;
    } catch (e) {
      debugPrint('ApiSettings.load failed: $e'); // keep defaults
    }
    notifyListeners();
  }

  Future<void> save({
    required String baseUrl,
    required String token,
    required String issuerId,
    required bool demoMode,
  }) async {
    this.baseUrl = _trimSlash(baseUrl.trim());
    this.token = token.trim();
    this.issuerId =
        issuerId.trim().isEmpty ? AppConfig.defaultIssuerId : issuerId.trim();
    this.demoMode = demoMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBaseUrl, this.baseUrl);
    await prefs.setString(_kIssuer, this.issuerId);
    await prefs.setBool(_kMock, demoMode);
    if (this.token.isEmpty) {
      await _secure.delete(key: _kToken);
    } else {
      await _secure.write(key: _kToken, value: this.token);
    }
    notifyListeners();
  }

  Future<void> resetToDefaults() => save(
        baseUrl: AppConfig.defaultBaseUrl,
        token: AppConfig.defaultApiToken,
        issuerId: AppConfig.defaultIssuerId,
        demoMode: AppConfig.defaultMock,
      );

  /// Returns null when valid, otherwise a friendly reason.
  static String? validateBaseUrl(String v) {
    final uri = Uri.tryParse(v.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return 'Enter a full URL, e.g. https://api.yourbank.com';
    }
    if (uri.scheme != 'https' && uri.scheme != 'http') {
      return 'URL must start with https://';
    }
    return null;
  }

  static String _trimSlash(String s) =>
      s.endsWith('/') ? s.substring(0, s.length - 1) : s;
}
