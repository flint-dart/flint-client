import 'dart:io';

import 'package:flint_client/flint_client.dart';

/// Retry configuration examples for Flint HTTP Client
///
/// This example demonstrates the sophisticated retry mechanism including:
/// - Basic retry configuration
/// - Exponential backoff with jitter
/// - Custom retry evaluators
/// - Different retry strategies per request

void main() async {
  final client = FlintClient(
    baseUrl: 'https://httpstat.us',
    defaultRetryConfig: RetryConfig(
      maxAttempts: 3,
      delay: Duration(seconds: 1),
      maxDelay: Duration(seconds: 10),
      retryOnTimeout: true,
      retryStatusCodes: {500, 502, 503, 504, 408, 429},
    ),
    debug: true,
  );

  try {
    // Basic retry on server errors
    print('=== Basic Retry on Server Error ===');
    final serverErrorResponse = await client.get<String>(
      '/500', // Server error
      retryConfig: RetryConfig(maxAttempts: 3, delay: Duration(seconds: 1)),
    );
    print('Final response after retries: ${serverErrorResponse.statusCode}');

    // Retry on timeout
    print('\n=== Retry on Timeout ===');
    final timeoutResponse = await client.get<String>(
      '/200?sleep=3000', // Simulate slow response
      retryConfig: RetryConfig(
        maxAttempts: 2,
        delay: Duration(seconds: 2),
        retryOnTimeout: true,
      ),
    );
    print('Timeout request completed: ${timeoutResponse.statusCode}');

    // Custom retry evaluator
    print('\n=== Custom Retry Evaluator ===');
    final customRetryResponse = await client.get<String>(
      '/429', // Rate limit
      retryConfig: RetryConfig(
        maxAttempts: 5,
        delay: Duration(seconds: 1),
        retryEvaluator: (error, attempt) {
          print('Retry evaluator: Attempt $attempt, Error: ${error.message}');

          // Custom retry logic
          if (error.isRateLimit) {
            print('Rate limit detected, waiting longer...');
            return true;
          }

          if (error.statusCode == 503) {
            print('Service unavailable, retrying...');
            return attempt <= 3; // Only retry 3 times for 503
          }

          // Default behavior for other errors
          return attempt <= 2;
        },
      ),
    );
    print('Custom retry completed: ${customRetryResponse.statusCode}');

    // Different retry strategies per request type
    print('\n=== Per-Request Retry Strategies ===');

    // Critical user data - aggressive retry
    await client.get<String>(
      '/users/1',
      retryConfig: RetryConfig(
        maxAttempts: 5,
        delay: Duration(milliseconds: 500),
        maxDelay: Duration(seconds: 5),
        retryOnTimeout: true,
        retryStatusCodes: {500, 502, 503, 504, 408, 429},
      ),
    );
    print('Critical data fetch completed');

    // Non-critical analytics data - minimal retry
    await client.post<String>(
      '/analytics',
      retryConfig: RetryConfig(
        maxAttempts: 1, // No retries for analytics
        retryOnTimeout: false,
      ),
    );
    print('Analytics data sent (no retries)');

    // File upload with retry
    print('\n=== File Upload with Retry ===');
    final tempFile = File('${Directory.systemTemp.path}/test_upload_retry.txt');
    await tempFile.writeAsString('Test content for retry demonstration');

    final uploadResponse = await client.post<Map<String, dynamic>>(
      '/post',
      files: {'file': tempFile},
      retryConfig: RetryConfig(
        maxAttempts: 3,
        delay: Duration(seconds: 2),
        retryEvaluator: (error, attempt) {
          // Only retry on network issues for file uploads
          return error.isNetworkError || error.isTimeout;
        },
      ),
    );
    print('File upload with retry completed: ${uploadResponse.statusCode}');

    // Exponential backoff demonstration
    print('\n=== Exponential Backoff Demonstration ===');
    await client.get<String>(
      '/500', // Will trigger retries
      retryConfig: RetryConfig(
        maxAttempts: 4,
        delay: Duration(seconds: 1),
        maxDelay: Duration(seconds: 30),
      ),
    );
    print('Exponential backoff test completed');

    // No retry for client errors (4xx)
    print('\n=== No Retry for Client Errors ===');
    await client.get<String>(
      '/400', // Bad request - shouldn't retry
      retryConfig: RetryConfig(
        maxAttempts: 3,
        retryEvaluator: (error, attempt) {
          // Don't retry client errors (4xx)
          if (error.isClientError) {
            print('Client error detected, not retrying');
            return false;
          }
          return true;
        },
      ),
    );
    print('Client error handled without retries');

    // Retry with increasing delays demonstration
    print('\n=== Retry Delay Progression ===');
    final startTime = DateTime.now();

    try {
      await client.get<String>(
        '/500', // Will fail and retry
        retryConfig: RetryConfig(
          maxAttempts: 4,
          delay: Duration(seconds: 1),
          maxDelay: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      final totalDuration = DateTime.now().difference(startTime);
      print('All retries exhausted after ${totalDuration.inSeconds} seconds');
    }

    // Clean up
    await tempFile.delete();
  } catch (e) {
    print('Error in retry examples: $e');
  } finally {
    client.dispose();
  }
}
