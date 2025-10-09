/// Tests for interceptors
library;

import 'dart:io';

import 'package:flint_client/flint_client.dart';
import 'package:test/test.dart';

void main() {
  group('Interceptors', () {
    test('request interceptor type is defined', () {
      interceptor(HttpClientRequest request) async {}
      expect(interceptor, isA<RequestInterceptor>());
    });

    test('response interceptor type is defined', () {
      interceptor(HttpClientResponse response) async {}
      expect(interceptor, isA<ResponseInterceptor>());
    });
  });
}
