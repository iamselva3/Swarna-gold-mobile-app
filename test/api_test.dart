import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_customer_app/core/data/customer_repository.dart';
import 'package:flutter_customer_app/core/network/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers every request with a fixed status and JSON body, and records it.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.status, this.body);

  final int status;
  final Object body;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    last = options;
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

({ApiClient client, _FakeAdapter adapter, List<int> invalidCalls}) _client(int status, Object body, {String? token = 't0k'}) {
  final adapter = _FakeAdapter(status, body);
  final dio = Dio(BaseOptions(baseUrl: 'http://test.local'))..httpClientAdapter = adapter;
  final invalid = <int>[];
  final client = ApiClient(
    baseUrl: 'http://test.local',
    readToken: () => token,
    onSessionInvalid: () => invalid.add(1),
    dio: dio,
  );
  return (client: client, adapter: adapter, invalidCalls: invalid);
}

void main() {
  test('attaches the bearer token to authenticated requests only', () async {
    final c = _client(200, {'data': []});
    await c.client.get('/private');
    expect(c.adapter.last!.headers['Authorization'], 'Bearer t0k');

    await c.client.get('/public', auth: false);
    expect(c.adapter.last!.headers.containsKey('Authorization'), isFalse);
  });

  test('backend "Invalid token" ends the session once', () async {
    final c = _client(400, {'message': 'Invalid token, Please login again'});
    await expectLater(
      c.client.get('/schemeaccount/mobile/schemeaccounts'),
      throwsA(isA<ApiException>().having((e) => e.kind, 'kind', ApiFailure.sessionExpired)),
    );
    expect(c.invalidCalls, hasLength(1));
  });

  test('a rejected sign-in surfaces the backend message without ending a session', () async {
    final c = _client(400, {'message': 'Incorrect password.'});
    await expectLater(
      c.client.post('/customer/login', data: {}, auth: false),
      throwsA(isA<ApiException>()
          .having((e) => e.message, 'message', 'Incorrect password.')
          .having((e) => e.kind, 'kind', ApiFailure.rejected)),
    );
    expect(c.invalidCalls, isEmpty);
  });

  test('server errors use a generic message', () async {
    final c = _client(500, {'message': 'Internal server error'});
    await expectLater(
      c.client.get('/anything'),
      throwsA(isA<ApiException>().having((e) => e.kind, 'kind', ApiFailure.server)),
    );
  });

  test('an order without a payment session is reported as a failure, not a success', () async {
    // The backend answers 201 even when the gateway refused to create the order.
    final c = _client(201, {
      'message': 'Payment proceeded successfully',
      'data': {'orderId': 'ord_1'},
    });
    final repo = CustomerRepository(c.client);
    await expectLater(
      repo.createInstallmentOrder(accountId: 'acc', amount: 2000, convenienceFee: 0),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('not been charged'))),
    );
  });

  test('only paymentStatus true counts as paid', () async {
    expect(await CustomerRepository(_client(201, {'paymentStatus': true}).client).isOrderPaid('o'), isTrue);
    expect(await CustomerRepository(_client(201, {'paymentStatus': false}).client).isOrderPaid('o'), isFalse);
    expect(await CustomerRepository(_client(201, {'message': 'x'}).client).isOrderPaid('o'), isFalse);
  });

  test('instalment order payload matches the backend contract', () async {
    final c = _client(201, {
      'data': {'orderId': 'ord_1', 'session': 'session_abc'},
    });
    final order = await CustomerRepository(c.client)
        .createInstallmentOrder(accountId: 'acc1', amount: 2000, convenienceFee: 0);
    expect(order.orderId, 'ord_1');
    expect(order.sessionId, 'session_abc');
    final body = c.adapter.last!.data as Map;
    expect(body['schemes'], [
      {'id_scheme_account': 'acc1', 'amount': 2000.0, 'convenience_fee': 0.0},
    ]);
    expect(body['grandTotal'], 2000.0);
  });
}
