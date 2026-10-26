import 'package:flutter/foundation.dart';

/// Build-time configuration.
///
/// Every environment-specific value comes from `--dart-define`, so no backend
/// URL, gateway mode or credential is hard-coded for a particular deployment.
/// See docs/DEVELOPMENT.md for the defines used in development.
class AppConfig {
  AppConfig._();

  static const String _apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const String _cashfreeEnv = String.fromEnvironment('CASHFREE_ENV', defaultValue: 'SANDBOX');

  // Development-only demo sign-in. Both values must be supplied at build time
  // and the helper is compiled out of release builds (see [demoLogin]).
  static const String _demoMobile = String.fromEnvironment('DEMO_MOBILE');
  static const String _demoPassword = String.fromEnvironment('DEMO_PASSWORD');

  /// Backend origin, without a trailing slash.
  static String get apiBaseUrl {
    if (_apiBaseUrl.isNotEmpty) {
      return _apiBaseUrl.endsWith('/') ? _apiBaseUrl.substring(0, _apiBaseUrl.length - 1) : _apiBaseUrl;
    }
    // Local defaults: the Android emulator reaches the host machine on 10.0.2.2.
    return kIsWeb ? 'http://localhost:3001' : 'http://10.0.2.2:3001';
  }

  /// The backend creates Cashfree orders against the sandbox unless it is
  /// configured otherwise, so the SDK environment must be set to match.
  static bool get cashfreeProduction => _cashfreeEnv.toUpperCase() == 'PRODUCTION';

  /// Demo credentials for the "Use demo account" helper on the sign-in screen.
  ///
  /// Returns null in release builds (the constant check lets the compiler drop
  /// the branch entirely) and whenever the defines were not supplied. The
  /// helper only fills the form — sign-in still goes through the real API.
  static ({String mobile, String password})? get demoLogin {
    if (kReleaseMode) return null;
    if (_demoMobile.isEmpty || _demoPassword.isEmpty) return null;
    return (mobile: _demoMobile, password: _demoPassword);
  }
}
