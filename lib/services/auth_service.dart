import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

enum AuthOutcome { ok, cancelled, unavailable }

/// Face ID / fingerprint, falling back to the device PIN/pattern.
class AuthService {
  static final _auth = LocalAuthentication();

  static Future<AuthOutcome> confirm(String reason) async {
    try {
      if (!await _auth.isDeviceSupported()) return AuthOutcome.unavailable;
      final ok = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
      return ok ? AuthOutcome.ok : AuthOutcome.cancelled;
    } on PlatformException {
      // No screen lock set up, or biometrics unavailable on this device.
      return AuthOutcome.unavailable;
    }
  }
}
