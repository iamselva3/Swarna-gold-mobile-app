import 'dart:convert';

import 'package:flutter_customer_app/core/auth/session.dart';
import 'package:flutter_test/flutter_test.dart';

String _jwt(Map<String, dynamic> payload) {
  String seg(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${seg({'alg': 'HS256', 'typ': 'JWT'})}.${seg(payload)}.signature';
}

void main() {
  final future = DateTime.now().add(const Duration(days: 15)).millisecondsSinceEpoch ~/ 1000;

  test('decodes a customer token issued by the backend', () {
    final session = Session.fromToken(_jwt({
      '_id': '6ad852d255ccdf439c043747',
      'firstname': 'Demo',
      'lastname': 'Customer',
      'id_branch': '6ad74f5c1f4907e78f91af0a',
      'mobile': 9000000001,
      'exp': future,
    }));

    expect(session, isNotNull);
    expect(session!.customerId, '6ad852d255ccdf439c043747');
    expect(session.branchId, '6ad74f5c1f4907e78f91af0a');
    expect(session.mobile, '9000000001');
    expect(session.displayName, 'Demo Customer');
    expect(session.isExpired, isFalse);
  });

  test('treats a token past its expiry as expired', () {
    final past = DateTime.now().subtract(const Duration(minutes: 1)).millisecondsSinceEpoch ~/ 1000;
    final session = Session.fromToken(_jwt({'_id': 'abc', 'exp': past}));
    expect(session!.isExpired, isTrue);
  });

  test('rejects staff tokens and malformed input', () {
    expect(Session.fromToken(_jwt({'id_employee': 'e1', 'id_role': {'id_role': 2}})), isNull);
    expect(Session.fromToken('not-a-jwt'), isNull);
    expect(Session.fromToken('a.b.c'), isNull);
  });
}
