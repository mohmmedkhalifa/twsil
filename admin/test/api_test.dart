import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('HTTP response decoding parses JSON strings cleanly', () {
    const rawBody = '{"access_token": "test_token", "user": {"id": "123"}}';
    final decoded = jsonDecode(rawBody);
    expect(decoded, isA<Map>());
    expect(decoded['access_token'], equals('test_token'));
  });
}
