/// Tests for FlintError class
library;

import 'dart:io';
import 'package:flint_client/flint_client.dart';
import 'package:test/test.dart';

void main() {
  group('FlintError', () {
    test('creates basic error with message', () {
      final error = FlintError('Test error message');

      expect(error.message, 'Test error message');
      expect(error.statusCode, isNull);
      expect(error.originalException, isNull);
      expect(error.url, isNull);
      expect(error.method, isNull);
      expect(error.timestamp, isA<DateTime>());
    });

    test('creates error with all properties', () {
      final originalException = HttpException('Original');
      final url = Uri.parse('https://example.com/test');
      final method = 'GET';
      final timestamp = DateTime(2023, 1, 1);

      final error = FlintError(
        'Custom error',
        statusCode: 404,
        originalException: originalException,
        url: url,
        method: method,
        timestamp: timestamp,
      );

      expect(error.message, 'Custom error');
      expect(error.statusCode, 404);
      expect(error.originalException, originalException);
      expect(error.url, url);
      expect(error.method, method);
      expect(error.timestamp, timestamp);
    });

    test('creates from another exception', () {
      final originalException = SocketException('Network error');
      final error = FlintError.fromException(
        originalException,
        statusCode: 500,
        url: Uri.parse('https://example.com'),
        method: 'POST',
      );

      expect(error.message, contains('Network error'));
      expect(error.statusCode, 500);
      expect(error.originalException, originalException);
      expect(error.url?.toString(), 'https://example.com');
      expect(error.method, 'POST');
    });

    test('creates from HTTP response', () {
      final url = Uri.parse('https://example.com/api');
      final error = FlintError.fromHttpResponse(
        MockHttpResponse(404, 'Not Found'),
        customMessage: 'Custom not found',
        url: url,
        method: 'GET',
      );

      expect(error.message, 'Custom not found');
      expect(error.statusCode, 404);
      expect(error.url, url);
      expect(error.method, 'GET');
    });

    test('categorizes error types correctly', () {
      final networkError = FlintError(
        'Network',
        originalException: SocketException('test'),
      );
      final clientError = FlintError('Client', statusCode: 400);
      final serverError = FlintError('Server', statusCode: 500);
      final timeoutError = FlintError('Timeout', statusCode: 408);
      final rateLimitError = FlintError('Rate limit', statusCode: 429);

      expect(networkError.isNetworkError, isTrue);
      expect(clientError.isClientError, isTrue);
      expect(serverError.isServerError, isTrue);
      expect(timeoutError.isTimeout, isTrue);
      expect(rateLimitError.isRateLimit, isTrue);
    });

    test('determines retryability correctly', () {
      final networkError = FlintError(
        'Network',
        originalException: SocketException('test'),
      );
      final serverError = FlintError('Server', statusCode: 503);
      final timeoutError = FlintError('Timeout', statusCode: 408);
      final rateLimitError = FlintError('Rate limit', statusCode: 429);
      final clientError = FlintError('Client', statusCode: 400);

      expect(networkError.isRetryable, isTrue);
      expect(serverError.isRetryable, isTrue);
      expect(timeoutError.isRetryable, isTrue);
      expect(rateLimitError.isRetryable, isTrue);
      expect(clientError.isRetryable, isFalse);
    });

    test('creates copy with overridden properties', () {
      final original = FlintError(
        'Original',
        statusCode: 500,
        url: Uri.parse('https://original.com'),
      );

      final copy = original.copyWith(
        message: 'Modified',
        statusCode: 404,
        url: Uri.parse('https://modified.com'),
      );

      expect(copy.message, 'Modified');
      expect(copy.statusCode, 404);
      expect(copy.url?.toString(), 'https://modified.com');
      expect(copy.originalException, original.originalException);
      expect(copy.method, original.method);
    });

    test('serializes to and from map', () {
      final original = FlintError(
        'Test error',
        statusCode: 404,
        url: Uri.parse('https://example.com/api'),
        method: 'GET',
        timestamp: DateTime(2023, 1, 1, 12, 0, 0),
      );

      final map = original.toMap();
      final restored = FlintError.fromMap(map);

      expect(restored.message, original.message);
      expect(restored.statusCode, original.statusCode);
      expect(restored.url, original.url);
      expect(restored.method, original.method);
      expect(restored.timestamp, original.timestamp);
    });

    test('provides informative toString', () {
      final error = FlintError(
        'Resource not found',
        statusCode: 404,
        url: Uri.parse('https://api.example.com/users/123'),
        method: 'GET',
      );

      final string = error.toString();

      expect(string, contains('FlintError: Resource not found'));
      expect(string, contains('Status: 404'));
      expect(string, contains('GET https://api.example.com/users/123'));
    });

    test('equality and hashCode', () {
      final error1 = FlintError(
        'Error',
        statusCode: 500,
        url: Uri.parse('https://example.com'),
        method: 'POST',
      );

      final error2 = FlintError(
        'Error',
        statusCode: 500,
        url: Uri.parse('https://example.com'),
        method: 'POST',
      );

      final error3 = FlintError(
        'Different',
        statusCode: 404,
        url: Uri.parse('https://different.com'),
        method: 'GET',
      );

      expect(error1, equals(error2));
      expect(error1.hashCode, equals(error2.hashCode));
      expect(error1, isNot(equals(error3)));
    });
  });
}

// Mock HTTP response for testing
class MockHttpResponse implements HttpClientResponse {
  @override
  final int statusCode;
  @override
  final String reasonPhrase;

  MockHttpResponse(this.statusCode, this.reasonPhrase);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
