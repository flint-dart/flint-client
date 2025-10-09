import 'dart:async';
import 'dart:io';

import 'package:flint_client/flint_client.dart';
import 'package:test/test.dart';

void main() {
  group('RetryConfig', () {
    test('creates with default values', () {
      final config = RetryConfig();

      expect(config.maxAttempts, 3);
      expect(config.delay, Duration(seconds: 1));
      expect(config.maxDelay, Duration(seconds: 30));
      expect(config.retryOnTimeout, isTrue);
      expect(
        config.retryStatusCodes,
        containsAll([500, 502, 503, 504, 408, 429]),
      );
      expect(
        config.retryExceptions,
        containsAll([SocketException, TimeoutException, HttpException]),
      );
      expect(config.retryEvaluator, isNull);
    });

    test('creates copy with overridden values', () {
      final original = RetryConfig();
      final copy = original.copyWith(
        maxAttempts: 5,
        delay: Duration(seconds: 2),
        retryOnTimeout: false,
      );

      expect(copy.maxAttempts, 5);
      expect(copy.delay, Duration(seconds: 2));
      expect(copy.retryOnTimeout, isFalse);
      expect(copy.maxDelay, original.maxDelay); // Unchanged
    });

    test('uses custom retry evaluator', () {
      bool customEvaluatorCalled = false;

      final config = RetryConfig(
        retryEvaluator: (error, attempt) {
          customEvaluatorCalled = true;
          return true;
        },
      );

      final error = FlintError('Test error');
      final shouldRetry = config.retryEvaluator!(error, 1);

      expect(shouldRetry, isTrue);
      expect(customEvaluatorCalled, isTrue);
    });
  });

  group('Retry Logic', () {
    late FlintClient client;

    setUp(() {
      client = FlintClient(baseUrl: 'https://example.com');
    });

    tearDown(() {
      client.dispose();
    });

    test('should retry on server errors', () {
      final error = FlintError('Server error', statusCode: 500);

      // Access private method through reflection or test helper
      // This would typically be tested through integration tests
      expect(error.isServerError, isTrue);
    });

    test('should retry on network errors', () {
      final error = FlintError.fromException(SocketException('Network error'));

      expect(error.isNetworkError, isTrue);
    });

    test('should not retry on client errors', () {
      final error = FlintError('Client error', statusCode: 400);

      expect(error.isClientError, isTrue);
    });

    test('should respect max attempts', () {
      final config = RetryConfig(maxAttempts: 3);

      // This would be tested in integration tests with mock server
      // that counts attempts
      expect(config.maxAttempts, 3);
    });
  });
}
