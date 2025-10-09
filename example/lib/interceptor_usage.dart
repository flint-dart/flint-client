import 'dart:io';

import 'package:flint_client/flint_client.dart';

/// Interceptor usage examples for Flint HTTP Client
///
/// This example demonstrates request and response interceptors for:
/// - Authentication token management
/// - Request logging and monitoring
/// - Response transformation
/// - Error handling and recovery

void main() async {
  // Mock authentication service
  String? authToken;
  DateTime? tokenExpiry;

  bool isTokenExpired = DateTime.now().isAfter(tokenExpiry ?? DateTime.now());

  Future<String> refreshToken() async {
    print('🔐 Refreshing authentication token...');
    // Simulate token refresh
    await Future.delayed(Duration(milliseconds: 500));
    authToken = 'new_token_${DateTime.now().millisecondsSinceEpoch}';
    tokenExpiry = DateTime.now().add(Duration(minutes: 30));
    print('✅ Token refreshed: $authToken');
    return authToken!;
  }

  // Create client with interceptors
  final client = FlintClient(
    baseUrl: 'https://jsonplaceholder.typicode.com',
    debug: true,

    // Request interceptor - runs before each request
    requestInterceptor: (HttpClientRequest request) async {
      print('🚀 Request Interceptor: ${request.method} ${request.uri}');

      // Add authentication header if token exists
      if (authToken != null && !isTokenExpired) {
        request.headers.set('Authorization', 'Bearer $authToken');
        print('🔑 Added auth header');
      }

      // Add request ID for tracking
      final requestId = DateTime.now().millisecondsSinceEpoch;
      request.headers.set('X-Request-ID', requestId.toString());

      // Add common headers
      request.headers.set('User-Agent', 'FlintClient/1.0');
      request.headers.set('Accept', 'application/json');

      print('📝 Request headers: ${request.headers}');
    },

    // Response interceptor - runs after each response
    responseInterceptor: (HttpClientResponse response) async {
      print(
        '📥 Response Interceptor: ${response.statusCode} ${response.reasonPhrase}',
      );

      // Log response headers
      print('📊 Response headers: ${response.headers}');

      // Check for authentication issues
      if (response.statusCode == 401) {
        print('🔐 Authentication required - token may be expired');
      }

      // Monitor rate limiting
      if (response.statusCode == 429) {
        final retryAfter = response.headers.value('retry-after');
        print('🚦 Rate limited - retry after: $retryAfter');
      }

      // Log performance metrics
      final contentLength = response.contentLength;
      if (contentLength != -1) {
        print('💾 Response size: $contentLength bytes');
      }
    },
  );

  try {
    // Test with authentication
    print('=== Request with Authentication ===');

    // First, refresh the token
    await refreshToken();

    // Make authenticated request
    final authResponse = await client.get<Map<String, dynamic>>('/posts/1');
    print('Authenticated request completed: ${authResponse.statusCode}');

    // Simulate token expiration and retry
    print('\n=== Token Expiration Handling ===');
    tokenExpiry = DateTime.now().subtract(Duration(hours: 1)); // Force expiry

    final expiredTokenResponse = await client.get<Map<String, dynamic>>(
      '/posts/1',
      // Custom request interceptor for this specific request
    );
    print('Request with expired token: ${expiredTokenResponse.statusCode}');

    // Multiple requests showing interceptor usage
    print('\n=== Multiple Requests ===');
    final requests = [
      client.get<Map<String, dynamic>>('/posts/1'),
      client.get<Map<String, dynamic>>('/posts/2'),
      client.post<Map<String, dynamic>>(
        '/posts',
        body: {
          'title': 'Test Post',
          'body': 'This is a test post',
          'userId': 1,
        },
      ),
    ];

    final responses = await Future.wait(requests);
    print('Multiple requests completed: ${responses.length} responses');

    // Error response interception
    print('\n=== Error Response Interception ===');
    final errorResponse = await client.get<Map<String, dynamic>>(
      '/nonexistent-endpoint',
    );

    if (errorResponse.isError) {
      print('Error intercepted and handled: ${errorResponse.error?.message}');
    }

    // Custom interceptor for specific request
    print('\n=== Per-Request Custom Interceptor ===');
    await client.get<Map<String, dynamic>>('/posts/1');

    print('Custom interceptor request completed');

    // File upload with interceptors
    print('\n=== File Upload with Interceptors ===');
    final tempFile = File('${Directory.systemTemp.path}/interceptor_test.txt');
    await tempFile.writeAsString('Interceptor test file content');

    final uploadResponse = await client.post<Map<String, dynamic>>(
      '/posts',
      files: {'file': tempFile},
      body: {'title': 'File upload test'},
    );

    print(
      'File upload with interceptors completed: ${uploadResponse.statusCode}',
    );

    // Demonstrate request/response flow
    print('\n=== Complete Request/Response Flow ===');
    await client.get<Map<String, dynamic>>('/posts/1');

    print(
      'Complete flow: Request → Interceptors → Server → Interceptors → Response',
    );

    // Clean up
    await tempFile.delete();
  } catch (e) {
    print('Error in interceptor examples: $e');
  } finally {
    client.dispose();
  }
}
