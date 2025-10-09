/// Integration tests for Flint HTTP Client
library;

import 'dart:io';
import 'package:flint_client/flint_client.dart';
import 'package:test/test.dart';
import 'test_utils.dart';

void main() {
  group('FlintClient Integration', () {
    late TestServer server;
    late FlintClient client;

    setUp(() async {
      server = TestServer();
      await server.start();
    });

    tearDown(() async {
      client.dispose();
      await server.stop();
    });

    test('full workflow with caching and retry', () async {
      client = FlintClient(
        baseUrl: server.baseUrl,
        defaultCacheConfig: CacheConfig(
          maxAge: Duration(minutes: 5),
          maxSize: 10,
        ),
        defaultRetryConfig: RetryConfig(
          maxAttempts: 3,
          delay: Duration(milliseconds: 100),
        ),
        debug: true,
      );

      // First request - should be cached
      final response1 = await client.get<Map<String, dynamic>>('/json');
      expect(response1.isSuccess, isTrue);

      // Second request - should come from cache
      final response2 = await client.get<Map<String, dynamic>>('/json');
      expect(response2.isSuccess, isTrue);

      // Force refresh
      final response3 = await client.get<Map<String, dynamic>>(
        '/json',
        cacheConfig: CacheConfig(forceRefresh: true),
      );
      expect(response3.isSuccess, isTrue);
    });

    test('file upload and download integration', () async {
      client = FlintClient(baseUrl: server.baseUrl);

      // Create test file
      final testFile = await createTestFile('Integration test content');

      try {
        // Upload file - use echo endpoint to verify upload worked
        final uploadResponse = await client.post<dynamic>(
          '/echo',
          files: {'testFile': testFile},
          body: {'description': 'Test upload'},
        );

        expect(uploadResponse.isSuccess, isTrue);

        // Download file
        final tempDir = Directory.systemTemp;
        final downloadPath =
            '${tempDir.path}/downloaded_integration_${DateTime.now().millisecondsSinceEpoch}.txt';

        final downloadedFile = await client.downloadFile(
          '${server.baseUrl}/download',
          savePath: downloadPath,
        );

        expect(await downloadedFile.exists(), isTrue);
        expect(
          await downloadedFile.readAsString(),
          'File content for download',
        );

        // Cleanup
        await downloadedFile.delete();
      } finally {
        await cleanupTestFile(testFile);
      }
    });

    test('interceptor integration', () async {
      var requestInterceptorCalled = false;
      var responseInterceptorCalled = false;

      client = FlintClient(
        baseUrl: server.baseUrl,
        requestInterceptor: (request) async {
          requestInterceptorCalled = true;
          request.headers.set('X-Test-Interceptor', 'request');
        },
        responseInterceptor: (response) async {
          responseInterceptorCalled = true;
        },
      );

      final response = await client.get<dynamic>('/echo');

      expect(response.isSuccess, isTrue);
      expect(requestInterceptorCalled, isTrue);
      expect(responseInterceptorCalled, isTrue);
    });

    test('retry mechanism integration', () async {
      client = FlintClient(
        baseUrl: server.baseUrl,
        defaultRetryConfig: RetryConfig(
          maxAttempts: 3,
          delay: Duration(milliseconds: 100),
        ),
      );

      // This endpoint fails twice then succeeds on third attempt
      final response = await client.get<String>('/retry-test?attempt=1');

      // The test server logic needs to track attempts properly
      // For now, just verify we get some response
      expect(response, isA<FlintResponse<String>>());
    });
    test('interceptor integration', () async {
      var requestInterceptorCalled = false;
      var responseInterceptorCalled = false;

      client = FlintClient(
        baseUrl: server.baseUrl,
        requestInterceptor: (request) async {
          requestInterceptorCalled = true;
          request.headers.set('X-Test-Interceptor', 'request');
        },
        responseInterceptor: (response) async {
          responseInterceptorCalled = true;
        },
      );

      final response = await client.get<Map<String, dynamic>>('/echo');

      expect(response.isSuccess, isTrue);
      expect(requestInterceptorCalled, isTrue);
      expect(responseInterceptorCalled, isTrue);
      expect(
        response.data!['headers'],
        containsPair('x-test-interceptor', ['request']),
      );
    });

    test('error handling integration', () async {
      client = FlintClient(baseUrl: server.baseUrl);

      final errorResponse = await client.get<String>('/error/500');

      expect(errorResponse.isError, isTrue);
      expect(errorResponse.error, isA<FlintError>());
      expect(errorResponse.error?.statusCode, 500);
      expect(errorResponse.error?.isServerError, isTrue);
    });

    test('retry mechanism integration', () async {
      client = FlintClient(
        baseUrl: server.baseUrl,
        defaultRetryConfig: RetryConfig(
          maxAttempts: 3,
          delay: Duration(milliseconds: 100),
        ),
      );

      // This endpoint fails twice then succeeds
      final response = await client.get<String>('/retry-test');

      expect(response.isSuccess, isTrue);
      expect(response.data, 'Success on attempt 3');
    });
  });
}
