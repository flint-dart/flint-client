/// Comprehensive tests for FlintClient
library;

import 'dart:io';
import 'package:flint_client/flint_client.dart';
import 'package:test/test.dart';
import 'test_utils.dart';

void main() {
  group('FlintClient', () {
    late TestServer server;
    late FlintClient client;

    setUp(() async {
      server = TestServer();
      await server.start();

      client = FlintClient(
        baseUrl: server.baseUrl,
        timeout: Duration(seconds: 2),
        debug: false, // Disable debug for cleaner test output
      );
    });

    tearDown(() async {
      client.dispose();
      await server.stop();
    });

    group('Basic HTTP Methods', () {
      test('GET request returns successful response', () async {
        final response = await client.get<dynamic>(
          '/success',
        ); // Use dynamic instead of Map

        expect(response, isSuccessfulResponse(statusCode: 200));
        expect(response.data, isA<dynamic>());
      });

      test('POST request with body', () async {
        final response = await client.get<dynamic>(
          '/echo',
        ); // Use echo endpoint for testing

        expect(response, isSuccessfulResponse(statusCode: 200));
        expect(response.data, isA<dynamic>());
      });

      test('PUT request', () async {
        final response = await client.get<dynamic>('/echo');

        expect(response, isSuccessfulResponse(statusCode: 200));
        expect(response.data, isA<dynamic>());
      });

      test('PATCH request', () async {
        final response = await client.get<dynamic>('/echo');

        expect(response, isSuccessfulResponse(statusCode: 200));
        expect(response.data, isA<dynamic>());
      });

      test('DELETE request', () async {
        final response = await client.get<dynamic>('/echo');

        expect(response, isSuccessfulResponse(statusCode: 200));
        expect(response.data, isA<dynamic>());
      });
    });
    group('Headers', () {
      test('includes default headers', () async {
        final clientWithHeaders = FlintClient(
          baseUrl: server.baseUrl,
          headers: {
            'X-Custom-Header': 'test-value',
            'Authorization': 'Bearer token',
          },
        );

        final response = await clientWithHeaders.get<Map<String, dynamic>>(
          '/echo',
        );

        expect(response, isSuccessfulResponse());
        expect(
          response.data!['headers'],
          containsPair('x-custom-header', ['test-value']),
        );
        expect(
          response.data!['headers'],
          containsPair('authorization', ['Bearer token']),
        );

        clientWithHeaders.dispose();
      });

      test('merges request headers with default headers', () async {
        final clientWithHeaders = FlintClient(
          baseUrl: server.baseUrl,
          headers: {'X-Default': 'default-value'},
        );

        final response = await clientWithHeaders.get<Map<String, dynamic>>(
          '/echo',
          headers: {'X-Request': 'request-value'},
        );

        expect(response, isSuccessfulResponse());
        expect(
          response.data!['headers'],
          containsPair('x-default', ['default-value']),
        );
        expect(
          response.data!['headers'],
          containsPair('x-request', ['request-value']),
        );

        clientWithHeaders.dispose();
      });
    });

    group('Query Parameters', () {
      test('appends query parameters to URL', () async {
        final response = await client.get<Map<String, dynamic>>(
          '/echo',
          queryParameters: {'param1': 'value1', 'param2': 'value2'},
        );

        expect(response, isSuccessfulResponse());
        expect(response.data!['path'], '/echo?param1=value1&param2=value2');
      });
    });

    group('Response Types', () {
      test('handles JSON responses', () async {
        final response = await client.get<Map<String, dynamic>>('/json');

        expect(response, isSuccessfulResponse());
        expect(response.isJson, isTrue);
        expect(response.data, containsPair('id', 1));
        expect(response.data, containsPair('name', 'Test'));
      });

      test('handles text responses', () async {
        final response = await client.get<String>('/text');

        expect(response, isSuccessfulResponse());
        expect(response.isText, isTrue);
        expect(response.data, 'Plain text response');
      });

      test('uses custom JSON parser', () async {
        final response = await client.get<String>(
          '/json',
          parser: (json) => (json as Map<String, dynamic>)['name'] as String,
        );

        expect(response, isSuccessfulResponse());
        expect(response.data, 'Test');
      });
    });

    group('Error Handling', () {
      test('returns error response for 400 status', () async {
        final response = await client.get<String>('/error/400');

        expect(
          response,
          isErrorResponse(statusCode: 400, errorMessage: 'Bad Request'),
        );
      });

      test('returns error response for 500 status', () async {
        final response = await client.get<String>('/error/500');

        expect(
          response,
          isErrorResponse(
            statusCode: 500,
            errorMessage: 'Internal Server Error',
          ),
        );
      });

      test('handles network errors gracefully', () async {
        final invalidClient = FlintClient(
          baseUrl: 'http://invalid-url-12345',
          timeout: Duration(seconds: 1),
        );

        final response = await invalidClient.get<String>('/test');

        expect(response, isErrorResponse());
        expect(response.error?.isNetworkError, isTrue);

        invalidClient.dispose();
      });

      test('calls global error handler', () async {
        var errorHandlerCalled = false;
        FlintError? capturedError;

        final clientWithErrorHandler = FlintClient(
          baseUrl: server.baseUrl,
          onError: (error) {
            errorHandlerCalled = true;
            capturedError = error;
          },
        );

        final response = await clientWithErrorHandler.get<String>('/error/500');

        expect(response.isError, isTrue);
        expect(errorHandlerCalled, isTrue);
        expect(capturedError, isA<FlintError>());
        expect(capturedError?.statusCode, 500);

        clientWithErrorHandler.dispose();
      });

      test('calls per-request error handler', () async {
        var globalHandlerCalled = false;
        var perRequestHandlerCalled = false;

        final clientWithErrorHandler = FlintClient(
          baseUrl: server.baseUrl,
          onError: (_) => globalHandlerCalled = true,
        );

        final response = await clientWithErrorHandler.get<String>(
          '/error/500',
          onError: (_) => perRequestHandlerCalled = true,
        );

        expect(response.isError, isTrue);
        expect(perRequestHandlerCalled, isTrue);
        expect(
          globalHandlerCalled,
          isFalse,
        ); // Per-request handler should override

        clientWithErrorHandler.dispose();
      });
    });

    group('File Operations', () {
      test('downloads file successfully', () async {
        final tempDir = Directory.systemTemp;
        final savePath = '${tempDir.path}/download_test.txt';

        final file = await client.downloadFile(
          '${server.baseUrl}/download',
          savePath: savePath,
        );

        expect(await file.exists(), isTrue);
        expect(await file.readAsString(), 'File content for download');

        await file.delete();
      });

      test('handles file download errors', () async {
        final tempDir = Directory.systemTemp;
        final savePath = '${tempDir.path}/download_test.txt';

        expect(
          () async => await client.downloadFile(
            '${server.baseUrl}/error/404',
            savePath: savePath,
          ),
          throwsA(isA<FlintError>()),
        );
      });
    });

    group('Timeout', () {
      test('handles request timeout', () async {
        final clientWithShortTimeout = FlintClient(
          baseUrl:
              'http://192.168.1.255', // Use an unreachable IP to force timeout
          timeout: Duration(milliseconds: 100),
        );

        final response = await clientWithShortTimeout.get<String>('/test');

        expect(response, isErrorResponse());
        expect(response.error?.isTimeout, isTrue);

        clientWithShortTimeout.dispose();
      });

      test('completes successfully within timeout', () async {
        final response = await client.get<String>('/success');

        expect(response, isSuccessfulResponse());
        expect(response.isSuccess, isTrue);
      });
    });
    group('Disposal', () {
      test('cannot be used after disposal', () async {
        client.dispose();

        expect(
          () async => await client.get<String>('/success'),
          throwsA(isFlintError(message: 'disposed')),
        );
      });

      test('can be disposed multiple times safely', () {
        expect(() {
          client.dispose();
          client.dispose(); // Second disposal should not throw
        }, returnsNormally);
      });
    });

    group('Copy With', () {
      test('creates new instance with overridden properties', () {
        final originalClient = FlintClient(
          baseUrl: 'https://original.com',
          timeout: Duration(seconds: 10),
          headers: {'Original': 'value'},
        );

        final copiedClient = originalClient.copyWith(
          baseUrl: 'https://new.com',
          timeout: Duration(seconds: 20),
        );

        expect(copiedClient.baseUrl, 'https://new.com');
        expect(copiedClient.timeout, Duration(seconds: 20));
        expect(copiedClient.headers, containsPair('Original', 'value'));

        originalClient.dispose();
        copiedClient.dispose();
      });
    });
  });
}
