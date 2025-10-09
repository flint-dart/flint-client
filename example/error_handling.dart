/// Comprehensive error handling example for Flint HTTP Client
///
/// This example demonstrates various error handling strategies including:
/// - Global error handlers
/// - Per-request error handlers
/// - Error categorization and recovery strategies
library;

import 'package:flint_client/flint_client.dart';

void main() async {
  // Create client with global error handler
  final client = FlintClient(
    baseUrl:
        'https://httpstat.us', // Service that returns specific status codes
    debug: true,
    onError: (error) {
      // Global error handler - called for all requests
      print('🔥 Global error handler: ${error.message}');

      // Categorize errors for different handling strategies
      if (error.isNetworkError) {
        print('🌐 Network issue - check connection');
      } else if (error.isServerError) {
        print('🖥️ Server issue - try again later');
      } else if (error.isClientError) {
        print('📱 Client error - check your request');
      } else if (error.isTimeout) {
        print('⏰ Request timeout - server is slow');
      } else if (error.isRateLimit) {
        print('🚦 Rate limited - slow down requests');
      }
    },
  );

  try {
    // Success case
    print('=== Success Case ===');
    final successResponse = await client.get<String>('/200');
    print('Success: ${successResponse.statusCode}');

    // Client error (404) with per-request error handler
    print('\n=== Client Error (404) ===');
    final notFoundResponse = await client.get<String>(
      '/404',
      onError: (error) {
        // Per-request error handler overrides global handler
        print('🔍 Resource not found: ${error.message}');
        // Show user-friendly message
        print('The requested resource was not found.');
      },
    );

    if (notFoundResponse.isError) {
      print('Error response handled gracefully');
    }

    // Server error (500)
    print('\n=== Server Error (500) ===');
    final serverErrorResponse = await client.get<String>('/500');
    if (serverErrorResponse.isError) {
      print('Server error occurred: ${serverErrorResponse.error?.message}');
    }

    // Timeout simulation
    print('\n=== Timeout Handling ===');
    await client.get<String>(
      '/200?sleep=5000', // Simulate slow response
      onError: (error) {
        if (error.isTimeout) {
          print('⏰ Custom timeout handling: ${error.message}');
        }
      },
    );

    // Using throwIfError() for safe error propagation
    print('\n=== Using throwIfError() ===');
    try {
      final response = await client.get<String>('/400');
      response.throwIfError(); // Throws if error
      print('This wont execute for error responses');
    } on FlintError catch (e) {
      print('Caught error with throwIfError(): ${e.message}');
    }

    // Using requireData for safe data access
    print('\n=== Using requireData ===');
    try {
      final response = await client.get<String>('/200');
      final data = response.requireData; // Throws if error or null data
      print('Data accessed safely: $data');
    } on FlintError catch (e) {
      print('Error accessing data: ${e.message}');
    } on StateError catch (e) {
      print('Data was null: $e');
    }

    // Error categorization in practice
    print('\n=== Error Categorization ===');
    final responses = await Future.wait([
      client.get<String>('/200'),
      client.get<String>('/404'),
      client.get<String>('/500'),
      client.get<String>('/429'), // Rate limit
    ], eagerError: false);

    for (final response in responses) {
      if (response.isError) {
        final error = response.error!;
        print('Error: ${error.message}');
        print('  - Is retryable: ${error.isRetryable}');
        print('  - Is client error: ${error.isClientError}');
        print('  - Is server error: ${error.isServerError}');
        print('  - Status code: ${error.statusCode}');
      }
    }
  } catch (e) {
    print('Unexpected error: $e');
  } finally {
    client.dispose();
  }
}
