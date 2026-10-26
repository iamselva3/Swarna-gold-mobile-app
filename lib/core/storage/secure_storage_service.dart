import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the access token in the platform keystore (Android Keystore-backed
/// encrypted preferences / iOS Keychain). Nothing else about the customer is
/// stored on the device — profile data is always fetched from the backend.
class SecureStorageService {
  const SecureStorageService();

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  static const String _keyToken = 'auth_token';

  Future<String?> readToken() => _storage.read(key: _keyToken);

  Future<void> writeToken(String token) => _storage.write(key: _keyToken, value: token);

  Future<void> clear() => _storage.deleteAll();
}
