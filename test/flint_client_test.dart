/// Comprehensive tests for FlintClient
library;

import 'dart:io';
import 'dart:async';
import 'package:flint_client/flint_client.dart';
import 'package:test/test.dart';
import 'test_utils.dart';

class _CustomJsonResponseSerializer implements ResponseSerializer {
  const _CustomJsonResponseSerializer();

  @override
  bool canHandle(String contentType) =>
      contentType.toLowerCase().contains('application/json');

  @override
  Future<ResponseSerializerResult> deserialize(
    ResponseSerializerInput input,
  ) async {
    return ResponseSerializerResult(
      type: FlintResponseType.json,
      data: {'custom': true},
    );
  }
}

class _ThrowingJsonResponseSerializer implements ResponseSerializer {
  const _ThrowingJsonResponseSerializer();

  @override
  bool canHandle(String contentType) =>
      contentType.toLowerCase().contains('application/json');

  @override
  Future<ResponseSerializerResult> deserialize(
    ResponseSerializerInput input,
  ) async {
    throw FlintError('forced serializer failure', kind: FlintErrorKind.parse);
  }
}

class _FallbackJsonResponseSerializer implements ResponseSerializer {
  const _FallbackJsonResponseSerializer();

  @override
  bool canHandle(String contentType) =>
      contentType.toLowerCase().contains('application/json');

  @override
  Future<ResponseSerializerResult> deserialize(
    ResponseSerializerInput input,
  ) async {
    return ResponseSerializerResult(
      type: FlintResponseType.json,
      data: {'fallback': true},
    );
  }
}

Future<List<String>> _capturePrints(Future<void> Function() action) async {
  final lines = <String>[];
  await runZoned(
    () async => await action(),
    zoneSpecification: ZoneSpecification(
      print: (_, __, ___, line) {
        lines.add(line);
      },
    ),
  );
  return lines;
}

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
        final response = await client.get<Map<String, dynamic>>('/echo');

        expect(response, isSuccessfulResponse(statusCode: 200));
        expect(response.data!['method'], 'GET');
      });

      test('POST request with body', () async {
        final response = await client.post<Map<String, dynamic>>(
          '/echo',
          body: {'name': 'flint'},
        );

        expect(response, isSuccessfulResponse(statusCode: 200));
        expect(response.data!['method'], 'POST');
        expect(response.data!['body'], containsPair('name', 'flint'));
      });

      test('PUT request', () async {
        final response = await client.put<Map<String, dynamic>>(
          '/echo',
          body: {'enabled': true},
        );

        expect(response, isSuccessfulResponse(statusCode: 200));
        expect(response.data!['method'], 'PUT');
      });

      test('PATCH request', () async {
        final response = await client.patch<Map<String, dynamic>>(
          '/echo',
          body: {'name': 'patched'},
        );

        expect(response, isSuccessfulResponse(statusCode: 200));
        expect(response.data!['method'], 'PATCH');
      });

      test('DELETE request', () async {
        final response = await client.delete<Map<String, dynamic>>('/echo');

        expect(response, isSuccessfulResponse(statusCode: 200));
        expect(response.data!['method'], 'DELETE');
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
        expect(
          response.data!['path'],
          anyOf(
            '/echo?param1=value1&param2=value2',
            '/echo?param2=value2&param1=value1',
          ),
        );
        expect(response.data!['query'], containsPair('param1', 'value1'));
        expect(response.data!['query'], containsPair('param2', 'value2'));
      });

      test('withQuery applies default query parameters', () async {
        final scopedClient = client.withQuery({'apiKey': '123'});
        final response = await scopedClient.get<Map<String, dynamic>>(
          '/echo',
          queryParameters: {'page': 2},
        );

        expect(response, isSuccessfulResponse());
        expect(response.data!['query'], containsPair('apiKey', '123'));
        expect(response.data!['query'], containsPair('page', '2'));
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

      test('handles XML responses as text', () async {
        final response = await client.get<String>('/xml');

        expect(response, isSuccessfulResponse());
        expect(response.isText, isTrue);
        expect(response.data, contains('<name>Flint</name>'));
      });

      test('sends XML request body when content type is XML', () async {
        const xmlBody = '<user><name>Flint</name></user>';
        final response = await client.post<Map<String, dynamic>>(
          '/echo',
          body: xmlBody,
          headers: {'Content-Type': 'application/xml'},
        );

        expect(response, isSuccessfulResponse());
        expect(response.data!['method'], 'POST');
        expect(response.data!['body'], xmlBody);

        final contentTypeValues = List<String>.from(
          (response.data!['headers'] as Map<String, dynamic>)['content-type']
              as List,
        );
        expect(
          contentTypeValues.any((value) => value.contains('application/xml')),
          isTrue,
        );
      });

      test('sends form-url-encoded body with modular serializer', () async {
        final response = await client.post<Map<String, dynamic>>(
          '/echo',
          body: {'name': 'Flint Client', 'active': 'true'},
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        );

        expect(response, isSuccessfulResponse());
        expect(response.data!['body'], contains('name=Flint+Client'));
        expect(response.data!['body'], contains('active=true'));
      });

      test('uses custom JSON parser', () async {
        final response = await client.get<String>(
          '/json',
          parser: (json) => (json as Map<String, dynamic>)['name'] as String,
        );

        expect(response, isSuccessfulResponse());
        expect(response.data, 'Test');
      });

      test('supports custom response serializer chain', () async {
        final customClient = FlintClient(
          baseUrl: server.baseUrl,
          responseSerializers: const [
            _CustomJsonResponseSerializer(),
            JsonResponseSerializer(),
            TextResponseSerializer(),
            BinaryResponseSerializer(),
          ],
        );

        final response = await customClient.get<Map<String, dynamic>>('/json');
        expect(response, isSuccessfulResponse());
        expect(response.data, containsPair('custom', true));
        customClient.dispose();
      });

      test(
        'lenient serializer fallback uses next serializer in chain',
        () async {
          final customClient = FlintClient(
            baseUrl: server.baseUrl,
            defaultParseMode: ResponseParseMode.lenient,
            responseSerializers: const [
              _ThrowingJsonResponseSerializer(),
              _FallbackJsonResponseSerializer(),
            ],
          );

          final response = await customClient.get<Map<String, dynamic>>(
            '/json',
          );
          expect(response.isSuccess, isTrue);
          expect(response.data, containsPair('fallback', true));
          customClient.dispose();
        },
      );

      test('strict serializer mode fails on first serializer error', () async {
        final customClient = FlintClient(
          baseUrl: server.baseUrl,
          defaultParseMode: ResponseParseMode.strict,
          responseSerializers: const [
            _ThrowingJsonResponseSerializer(),
            _FallbackJsonResponseSerializer(),
          ],
        );

        final response = await customClient.get<Map<String, dynamic>>('/json');
        expect(response.isError, isTrue);
        expect(response.error?.kind, FlintErrorKind.parse);
        customClient.dispose();
      });
    });

    group('Parse Modes', () {
      test('lenient parse mode does best-effort conversion', () async {
        final response = await client.get<int>('/text');

        expect(response.isSuccess, isTrue);
        expect(response.data, 0);
      });

      test('strict parse mode returns parse error on mismatch', () async {
        final strictClient = FlintClient(
          baseUrl: server.baseUrl,
          defaultParseMode: ResponseParseMode.strict,
        );

        final response = await strictClient.get<int>('/text');
        expect(response.isError, isTrue);
        expect(response.error?.kind, FlintErrorKind.parse);
        strictClient.dispose();
      });

      test('per-request parse mode override takes precedence', () async {
        final lenientClient = FlintClient(
          baseUrl: server.baseUrl,
          defaultParseMode: ResponseParseMode.lenient,
        );

        final response = await lenientClient.request<int>(
          'GET',
          '/text',
          options: RequestOptions<int>(parseMode: ResponseParseMode.strict),
        );

        expect(response.isError, isTrue);
        expect(response.error?.kind, FlintErrorKind.parse);
        lenientClient.dispose();
      });
    });

    group('Error Handling', () {
      test('returns error response for 400 status', () async {
        final response = await client.get<String>('/error/400');

        expect(
          response,
          isErrorResponse(statusCode: 400, errorMessage: 'Bad Request'),
        );
        expect(response.error?.data, 'Bad Request');
      });

      test('throws FlintError when throwIfError is enabled', () async {
        final throwingClient = FlintClient(
          baseUrl: server.baseUrl,
          throwIfError: true,
        );

        await expectLater(
          () => throwingClient.get<String>('/error/400'),
          throwsA(
            isA<FlintError>()
                .having((e) => e.statusCode, 'statusCode', 400)
                .having((e) => e.data, 'data', 'Bad Request'),
          ),
        );

        throwingClient.dispose();
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

      test('preserves JSON error object as FlintError.data', () async {
        final response = await client.get<Map<String, dynamic>>('/error/json');

        expect(response.isError, isTrue);
        expect(response.statusCode, 422);
        expect(response.error?.message, contains('Validation failed'));
        expect(response.error?.data, isA<Map>());
        expect(
          response.error?.data,
          containsPair('message', 'Validation failed'),
        );
      });

      test('preserves JSON error list as FlintError.data', () async {
        final response = await client.get<List<dynamic>>('/error/list');

        expect(response.isError, isTrue);
        expect(response.statusCode, 409);
        expect(response.error?.data, isA<List>());
        expect(response.error?.data, containsAll(['duplicate', 'conflict']));
      });

      test('handles network errors gracefully', () async {
        final invalidClient = FlintClient(
          baseUrl: 'http://localhost:1',
          timeout: Duration(seconds: 1),
        );

        final response = await invalidClient.get<String>('/test');

        expect(response, isErrorResponse());
        expect(response.error, isNotNull);
        expect(response.error?.message, isNotEmpty);

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

      test('uploadFile extension uploads a single file', () async {
        final file = await createTestFile('single upload');
        int progressEvents = 0;

        try {
          final response = await client.uploadFile<Map<String, dynamic>>(
            '/echo',
            file: file,
            fieldName: 'avatar',
            body: {'description': 'single'},
            onSendProgress: (_, __) {
              progressEvents++;
            },
          );

          expect(response.isSuccess, isTrue);
          expect(response.data!['method'], 'POST');
          final headers = response.data!['headers'] as Map<String, dynamic>;
          final contentTypeValues = List<String>.from(
            headers['content-type'] as List,
          );
          expect(
            contentTypeValues.any(
              (value) => value.toLowerCase().contains('multipart/form-data'),
            ),
            isTrue,
          );
          expect(progressEvents, greaterThan(0));
        } finally {
          await cleanupTestFile(file);
        }
      });

      test('uploadFiles extension uploads many files', () async {
        final file1 = await createTestFile('file one');
        final file2 = await createTestFile('file two');

        try {
          final response = await client.uploadFiles<Map<String, dynamic>>(
            '/echo',
            files: {'fileA': file1, 'fileB': file2},
            body: {'description': 'batch'},
          );

          expect(response.isSuccess, isTrue);
          expect(response.data!['method'], 'POST');
          final headers = response.data!['headers'] as Map<String, dynamic>;
          final contentTypeValues = List<String>.from(
            headers['content-type'] as List,
          );
          expect(
            contentTypeValues.any(
              (value) => value.toLowerCase().contains('multipart/form-data'),
            ),
            isTrue,
          );
        } finally {
          await cleanupTestFile(file1);
          await cleanupTestFile(file2);
        }
      });

      test('saveResponseData writes string response data', () async {
        final tempDir = Directory.systemTemp;
        final savePath = '${tempDir.path}/save_response_data_string.txt';
        final response = FlintResponse<String>(statusCode: 200, data: 'hello');

        final file = await client.saveResponseData(response, savePath);

        expect(await file.exists(), isTrue);
        expect(await file.readAsString(), 'hello');
        await file.delete();
      });

      test('saveResponseData writes binary response data', () async {
        final tempDir = Directory.systemTemp;
        final savePath = '${tempDir.path}/save_response_data_binary.bin';
        final response = FlintResponse<List<int>>(
          statusCode: 200,
          data: [1, 2, 3, 4],
        );

        final file = await client.saveResponseData(response, savePath);

        expect(await file.exists(), isTrue);
        expect(await file.readAsBytes(), [1, 2, 3, 4]);
        await file.delete();
      });
    });

    group('Timeout', () {
      test('handles request timeout', () async {
        final clientWithShortTimeout = FlintClient(
          baseUrl: server.baseUrl,
          timeout: Duration(milliseconds: 100),
        );

        final response = await clientWithShortTimeout.get<String>('/timeout');

        expect(response, isErrorResponse());
        expect(response.error?.isTimeout, isTrue);

        clientWithShortTimeout.dispose();
      });

      test('completes successfully within timeout', () async {
        final response = await client.get<String>('/success');

        expect(response, isSuccessfulResponse());
        expect(response.isSuccess, isTrue);
      });

      test('can cancel in-flight request with CancelToken', () async {
        final token = CancelToken();
        final pending = client.get<String>('/timeout', cancelToken: token);
        await Future<void>.delayed(Duration(milliseconds: 50));
        token.cancel('user aborted');

        final response = await pending;
        expect(response.isError, isTrue);
        expect(response.error?.message.toLowerCase(), contains('cancelled'));
        expect(response.error?.kind, FlintErrorKind.cancelled);
        expect(response.error?.statusCode, FlintError.cancelledStatusCode);
      });

      test('returns cancelled error when token is already cancelled', () async {
        final token = CancelToken()..cancel('already cancelled');
        final response = await client.get<String>(
          '/success',
          cancelToken: token,
        );

        expect(response.isError, isTrue);
        expect(response.error?.message.toLowerCase(), contains('cancelled'));
        expect(response.error?.kind, FlintErrorKind.cancelled);
        expect(response.error?.statusCode, FlintError.cancelledStatusCode);
      });

      test('cancelled requests are never cached', () async {
        final cacheClient = FlintClient(
          baseUrl: server.baseUrl,
          defaultCacheConfig: CacheConfig(maxAge: Duration(minutes: 5)),
        );
        final token = CancelToken();
        final pending = cacheClient.get<String>('/timeout', cancelToken: token);
        await Future<void>.delayed(Duration(milliseconds: 50));
        token.cancel('cache test cancel');

        final response = await pending;
        expect(response.isError, isTrue);
        expect(response.error?.kind, FlintErrorKind.cancelled);
        expect(await cacheClient.cacheSize, 0);
        cacheClient.dispose();
      });

      test('requestTimeout overrides client timeout per request', () async {
        final longTimeoutClient = FlintClient(
          baseUrl: server.baseUrl,
          timeout: Duration(seconds: 5),
        );

        final response = await longTimeoutClient.get<String>(
          '/timeout',
          requestTimeout: Duration(milliseconds: 120),
        );

        expect(response.isError, isTrue);
        expect(response.error?.isTimeout, isTrue);
        longTimeoutClient.dispose();
      });
    });

    group('Retry Idempotency', () {
      test('does not retry POST by default', () async {
        final retryClient = FlintClient(
          baseUrl: server.baseUrl,
          defaultRetryConfig: RetryConfig(
            maxAttempts: 3,
            delay: Duration(milliseconds: 10),
          ),
        );

        await retryClient.get<String>('/retry-reset');
        final response = await retryClient.post<String>('/retry-test');

        expect(response.isError, isTrue);
        expect(response.statusCode, 500);
        retryClient.dispose();
      });

      test('retries POST when explicitly opted in', () async {
        final retryClient = FlintClient(
          baseUrl: server.baseUrl,
          defaultRetryConfig: RetryConfig(
            maxAttempts: 3,
            delay: Duration(milliseconds: 10),
            retryMethods: {...RetryConfig.defaultRetryMethods, 'POST'},
          ),
        );

        await retryClient.get<String>('/retry-reset');
        final response = await retryClient.post<String>('/retry-test');

        expect(response.isSuccess, isTrue);
        expect(response.data, contains('Success on attempt 3'));
        retryClient.dispose();
      });
    });

    group('Retry Hardening', () {
      test('honors Retry-After delay when enabled', () async {
        final retryClient = FlintClient(
          baseUrl: server.baseUrl,
          defaultRetryConfig: RetryConfig(
            maxAttempts: 2,
            delay: Duration(milliseconds: 10),
            honorRetryAfter: true,
          ),
        );

        final sw = Stopwatch()..start();
        final response = await retryClient.get<String>('/retry-after-test');
        sw.stop();

        expect(response.isSuccess, isTrue);
        expect(response.data, 'Retry-After respected');
        expect(sw.elapsedMilliseconds, greaterThanOrEqualTo(900));
        retryClient.dispose();
      });

      test('stops retrying when maxRetryTime budget is exceeded', () async {
        final retryClient = FlintClient(
          baseUrl: server.baseUrl,
          defaultRetryConfig: RetryConfig(
            maxAttempts: 5,
            delay: Duration(milliseconds: 200),
            maxRetryTime: Duration(milliseconds: 250),
          ),
        );

        final response = await retryClient.get<String>('/always-500');

        expect(response.isError, isTrue);
        expect(response.error?.message.toLowerCase(), contains('retry budget'));
        retryClient.dispose();
      });
    });

    group('Resilience Matrix', () {
      test('retry + cancel race cancels during retry delay', () async {
        final token = CancelToken();
        final raceClient = FlintClient(
          baseUrl: server.baseUrl,
          defaultRetryConfig: RetryConfig(
            maxAttempts: 3,
            delay: Duration(seconds: 1),
          ),
        );

        await raceClient.get<String>('/retry-reset');
        final stopwatch = Stopwatch()..start();
        final pending = raceClient.get<String>(
          '/retry-test',
          cancelToken: token,
        );
        await Future<void>.delayed(Duration(milliseconds: 50));
        token.cancel('cancel during backoff');

        final response = await pending;
        stopwatch.stop();

        expect(response.isError, isTrue);
        expect(response.error?.kind, FlintErrorKind.cancelled);
        expect(stopwatch.elapsedMilliseconds, lessThan(900));
        raceClient.dispose();
      });

      test('cache + cancel never stores partial/cancelled responses', () async {
        final token = CancelToken();
        final cacheClient = FlintClient(
          baseUrl: server.baseUrl,
          defaultCacheConfig: CacheConfig(maxAge: Duration(minutes: 5)),
        );

        final pending = cacheClient.get<String>('/timeout', cancelToken: token);
        await Future<void>.delayed(Duration(milliseconds: 50));
        token.cancel('cancel cache path');

        final response = await pending;
        expect(response.isError, isTrue);
        expect(response.error?.kind, FlintErrorKind.cancelled);
        expect(await cacheClient.cacheSize, 0);
        cacheClient.dispose();
      });
    });

    group('Logging and Redaction', () {
      test('debug logs redact configured sensitive headers', () async {
        final redactionClient = FlintClient(
          baseUrl: server.baseUrl,
          debug: true,
        );

        final logs = await _capturePrints(() async {
          await redactionClient.get<Map<String, dynamic>>(
            '/echo',
            headers: {
              'Authorization': 'Bearer secret-token',
              'X-Trace': 'visible',
            },
          );
        });

        final output = logs.join('\n').toLowerCase();
        expect(output, contains('***redacted***'));
        expect(output, isNot(contains('secret-token')));
        expect(output, contains('x-trace'));
        redactionClient.dispose();
      });
    });

    group('Observability', () {
      test(
        'fires request start/end hooks with correlation ID and timing',
        () async {
          RequestContext? started;
          RequestContext? ended;

          final observedClient = FlintClient(
            baseUrl: server.baseUrl,
            lifecycleHooks: RequestLifecycleHooks(
              onRequestStart: (context) {
                started = context;
              },
              onRequestEnd: (context, _, __) {
                ended = context;
              },
            ),
          );

          final response = await observedClient.get<Map<String, dynamic>>(
            '/echo',
          );

          expect(response.isSuccess, isTrue);
          expect(started, isNotNull);
          expect(ended, isNotNull);
          expect(started!.correlationId, isNotEmpty);
          expect(ended!.correlationId, started!.correlationId);
          expect(ended!.startedAt, isNotNull);
          expect(ended!.endedAt, isNotNull);
          expect(ended!.totalDuration, isNotNull);
          expect(ended!.totalDuration!.inMilliseconds, greaterThanOrEqualTo(0));
          observedClient.dispose();
        },
      );

      test('fires retry hook for retried idempotent requests', () async {
        final retryDelays = <Duration>[];

        final observedClient = FlintClient(
          baseUrl: server.baseUrl,
          defaultRetryConfig: RetryConfig(
            maxAttempts: 3,
            delay: Duration(milliseconds: 10),
          ),
          lifecycleHooks: RequestLifecycleHooks(
            onRetry: (context, error, delay) {
              retryDelays.add(delay);
              expect(context.method, 'GET');
              expect(error.statusCode, 500);
            },
          ),
        );

        await observedClient.get<String>('/retry-reset');
        final response = await observedClient.get<String>('/retry-test');

        expect(response.isSuccess, isTrue);
        expect(retryDelays.length, 2);
        observedClient.dispose();
      });

      test('fires cache-hit hook and marks context cacheHit', () async {
        int cacheHits = 0;
        bool endSawCacheHit = false;

        final observedClient = FlintClient(
          baseUrl: server.baseUrl,
          defaultCacheConfig: CacheConfig(maxAge: Duration(minutes: 1)),
          lifecycleHooks: RequestLifecycleHooks(
            onCacheHit: (context, cacheKey, _) {
              cacheHits++;
              expect(cacheKey, isNotEmpty);
              expect(context.cacheHit, isTrue);
            },
            onRequestEnd: (context, _, __) {
              if (context.cacheHit) {
                endSawCacheHit = true;
              }
            },
          ),
        );

        await observedClient.get<Map<String, dynamic>>('/echo');
        final response = await observedClient.get<Map<String, dynamic>>(
          '/echo',
        );

        expect(response.isSuccess, isTrue);
        expect(cacheHits, 1);
        expect(endSawCacheHit, isTrue);
        observedClient.dispose();
      });

      test('passes RequestContext through contextual interceptors', () async {
        String? requestCorrelation;
        String? responseCorrelation;
        RequestContext? optionContext;

        final observedClient = FlintClient(
          baseUrl: server.baseUrl,
          contextualRequestInterceptor: (request, context) async {
            requestCorrelation = context.correlationId;
            context.setValue('seen', true);
            request.headers.set('X-Context-Seen', 'yes');
          },
          contextualResponseInterceptor: (response, context) async {
            responseCorrelation = context.correlationId;
            expect(context.getValue<bool>('seen'), isTrue);
          },
        );

        optionContext = RequestContext(
          method: 'GET',
          url: Uri.parse('${server.baseUrl}/echo'),
        );
        final response = await observedClient.request<Map<String, dynamic>>(
          'GET',
          '/echo',
          options: RequestOptions<Map<String, dynamic>>(context: optionContext),
        );

        expect(response.isSuccess, isTrue);
        expect(requestCorrelation, optionContext.correlationId);
        expect(responseCorrelation, optionContext.correlationId);
        expect(
          response.data!['headers'],
          containsPair('x-context-seen', ['yes']),
        );
        observedClient.dispose();
      });

      test('fires onError hook with retry intent', () async {
        final events = <bool>[];
        final observedClient = FlintClient(
          baseUrl: server.baseUrl,
          defaultRetryConfig: RetryConfig(
            maxAttempts: 2,
            delay: Duration(milliseconds: 10),
          ),
          lifecycleHooks: RequestLifecycleHooks(
            onError: (context, error, willRetry) {
              events.add(willRetry);
              expect(context.method, 'GET');
              expect(error.statusCode, isNotNull);
            },
          ),
        );

        final response = await observedClient.get<String>('/always-500');
        expect(response.isError, isTrue);
        expect(events, isNotEmpty);
        expect(events.first, isTrue);
        expect(events.last, isFalse);
        observedClient.dispose();
      });

      test(
        'hook failures are ignored by default and surfaced via onHookError',
        () async {
          var hookErrorCaptured = false;
          final observedClient = FlintClient(
            baseUrl: server.baseUrl,
            onHookError: (hookName, error, _, __) {
              hookErrorCaptured = hookName == 'onRequestStart';
            },
            lifecycleHooks: RequestLifecycleHooks(
              onRequestStart: (_) {
                throw StateError('hook fail');
              },
            ),
          );

          final response = await observedClient.get<Map<String, dynamic>>(
            '/echo',
          );
          expect(response.isSuccess, isTrue);
          expect(hookErrorCaptured, isTrue);
          observedClient.dispose();
        },
      );
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

    group('Modular API', () {
      test('request() supports RequestOptions', () async {
        final response = await client.request<Map<String, dynamic>>(
          'POST',
          '/echo',
          options: RequestOptions<Map<String, dynamic>>(
            body: {'from': 'request-options'},
            headers: {'X-Feature': 'modular'},
          ),
        );

        expect(response, isSuccessfulResponse(statusCode: 200));
        expect(response.data!['method'], 'POST');
        expect(
          response.data!['headers'],
          containsPair('x-feature', ['modular']),
        );
        expect(response.data!['body'], containsPair('from', 'request-options'));
      });
    });
  });
}
