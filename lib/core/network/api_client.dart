import 'package:dio/dio.dart';

enum ApiFailure { offline, timeout, sessionExpired, rejected, server }

/// A failed request, with a message that is safe to show to the customer.
class ApiException implements Exception {
  const ApiException(this.message, {required this.kind, this.statusCode});

  final String message;
  final ApiFailure kind;
  final int? statusCode;

  bool get isConnectivity => kind == ApiFailure.offline || kind == ApiFailure.timeout;

  @override
  String toString() => message;
}

/// Thin JSON client over Dio.
///
/// - Attaches the bearer token from the in-memory session.
/// - Normalises failures into [ApiException].
/// - Reports an invalid or expired token through [onSessionInvalid] so the app
///   can sign the customer out once, centrally.
/// - Never retries automatically: order and payment requests are not idempotent
///   on the client side, so a retry is always an explicit customer action.
class ApiClient {
  ApiClient({
    required String baseUrl,
    required String? Function() readToken,
    required void Function() onSessionInvalid,
    Dio? dio,
  })  : _readToken = readToken,
        _onSessionInvalid = onSessionInvalid,
        _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 15),
              sendTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 25),
              headers: const {'Accept': 'application/json'},
              contentType: Headers.jsonContentType,
            ));

  final Dio _dio;
  final String? Function() _readToken;
  final void Function() _onSessionInvalid;

  static final RegExp _invalidToken = RegExp(r'invalid token|login again|log in again|not logged in', caseSensitive: false);

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query, bool auth = true}) =>
      _send(() => _dio.get<dynamic>(path, queryParameters: query, options: _options(auth)), auth);

  Future<Map<String, dynamic>> post(String path, {Object? data, bool auth = true}) =>
      _send(() => _dio.post<dynamic>(path, data: data, options: _options(auth)), auth);

  Options _options(bool auth) {
    final token = auth ? _readToken() : null;
    return Options(headers: {if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token'});
  }

  Future<Map<String, dynamic>> _send(Future<Response<dynamic>> Function() request, bool auth) async {
    try {
      final response = await request();
      final body = response.data;
      if (body is Map) return Map<String, dynamic>.from(body);
      return {'data': body};
    } on DioException catch (e) {
      throw _translate(e, auth);
    }
  }

  ApiException _translate(DioException e, bool auth) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException('The server took too long to respond. Please try again.', kind: ApiFailure.timeout);
      case DioExceptionType.connectionError:
        return const ApiException('Unable to reach the server. Check your internet connection and try again.',
            kind: ApiFailure.offline);
      default:
        break;
    }

    final status = e.response?.statusCode;
    final body = e.response?.data;
    String? serverMessage;
    if (body is Map) {
      final m = body['message'];
      if (m is String && m.trim().isNotEmpty) serverMessage = m.trim();
      if (m is List && m.isNotEmpty) serverMessage = m.first.toString();
    }

    // The backend answers an invalid/expired token with 401, or 400 "Invalid token".
    final tokenRejected = auth && (status == 401 || (serverMessage != null && _invalidToken.hasMatch(serverMessage)));
    if (tokenRejected) {
      _onSessionInvalid();
      return ApiException('Your session has expired. Please sign in again.',
          kind: ApiFailure.sessionExpired, statusCode: status);
    }

    if (status != null && status >= 500) {
      return ApiException('Something went wrong on our side. Please try again shortly.',
          kind: ApiFailure.server, statusCode: status);
    }
    return ApiException(serverMessage ?? 'The request could not be completed.',
        kind: ApiFailure.rejected, statusCode: status);
  }
}
