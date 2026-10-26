import 'dart:convert';

/// The signed-in customer, as described by the backend-issued JWT.
///
/// The token is only decoded (never trusted) on the device: the backend
/// verifies it on every request. Decoding lets the app know who is signed in,
/// which branch's rates to show and when the session ends.
class Session {
  const Session({
    required this.token,
    required this.customerId,
    required this.branchId,
    required this.firstName,
    required this.lastName,
    required this.mobile,
    this.expiresAt,
  });

  final String token;
  final String customerId;
  final String? branchId;
  final String firstName;
  final String lastName;
  final String mobile;
  final DateTime? expiresAt;

  String get displayName => [firstName, lastName].where((s) => s.isNotEmpty).join(' ');

  /// Treat the session as expired slightly early so a request never leaves
  /// with a token that dies in flight.
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!.subtract(const Duration(seconds: 30)));

  /// Returns null for anything that is not a customer token.
  static Session? fromToken(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      if (payload is! Map) return null;
      final id = payload['_id']?.toString();
      if (id == null || id.isEmpty) return null;
      final exp = payload['exp'];
      return Session(
        token: token,
        customerId: id,
        branchId: payload['id_branch']?.toString(),
        firstName: (payload['firstname'] ?? '').toString(),
        lastName: (payload['lastname'] ?? '').toString(),
        mobile: (payload['mobile'] ?? '').toString(),
        expiresAt: exp is num ? DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000) : null,
      );
    } catch (_) {
      return null;
    }
  }
}
