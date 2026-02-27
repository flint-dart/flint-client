import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flint_client/flint_client.dart';

Future<void> main() async {
  final server = await _startMockServer();
  final baseUrl = 'http://localhost:${server.port}';

  final client = FlintClient(
    baseUrl: baseUrl,
    debug: true,
    defaultParseMode: ResponseParseMode.lenient,
    defaultCacheConfig: const CacheConfig(maxAge: Duration(minutes: 1)),
    defaultRetryConfig: RetryConfig(
      maxAttempts: 3,
      delay: const Duration(milliseconds: 250),
    ),
    lifecycleHooks: RequestLifecycleHooks(
      onRequestStart: (ctx) {
        print(
          '[Hook:start] ${ctx.method} ${ctx.url.path} cid=${ctx.correlationId}',
        );
      },
      onRetry: (ctx, err, delay) {
        print(
          '[Hook:retry] attempt=${ctx.attempt} delay=${delay.inMilliseconds}ms '
          'kind=${err.kind} message=${err.message}',
        );
      },
      onCacheHit: (ctx, key, _) {
        print('[Hook:cacheHit] key=$key cid=${ctx.correlationId}');
      },
      onRequestEnd: (ctx, response, error) {
        print(
          '[Hook:end] cid=${ctx.correlationId} status=${response?.statusCode} '
          'cacheHit=${ctx.cacheHit} duration=${ctx.totalDuration} '
          'error=${error?.kind}',
        );
      },
    ),
    contextualRequestInterceptor: (request, ctx) async {
      request.headers.set('X-Correlation-Id', ctx.correlationId);
      ctx.setValue('source', 'full_mock_example');
    },
    contextualResponseInterceptor: (response, ctx) async {
      print(
        '[Interceptor:response] status=${response.statusCode} '
        'source=${ctx.getValue<String>('source')}',
      );
    },
  );

  try {
    await _demoCacheHit(client);
    await _demoRetryThenSuccess(client);
    await _demoParseModes(client);
    await _demoCancelDuringRetryDelay(client);
  } finally {
    client.dispose();
    await server.close(force: true);
  }
}

Future<void> _demoCacheHit(FlintClient client) async {
  print('\n=== Demo: Cache hit ===');
  final first = await client.get<Map<String, dynamic>>('/json');
  final second = await client.get<Map<String, dynamic>>('/json');

  print('first success=${first.isSuccess} data=${first.data}');
  print('second success=${second.isSuccess} data=${second.data}');
}

Future<void> _demoRetryThenSuccess(FlintClient client) async {
  print('\n=== Demo: Retry then success ===');
  await client.get<String>('/retry-reset');
  final response = await client.get<String>('/retry-test');
  print(
    'retry-test success=${response.isSuccess} status=${response.statusCode} '
    'data=${response.data} error=${response.error}',
  );
}

Future<void> _demoParseModes(FlintClient client) async {
  print('\n=== Demo: Parse modes ===');

  final lenient = await client.get<int>('/text');
  print('lenient int parse success=${lenient.isSuccess} value=${lenient.data}');

  final strict = await client.get<int>(
    '/text',
    parseMode: ResponseParseMode.strict,
    cacheConfig: const CacheConfig(forceRefresh: true),
  );
  print(
    'strict int parse success=${strict.isSuccess} '
    'errorKind=${strict.error?.kind} message=${strict.error?.message}',
  );
}

Future<void> _demoCancelDuringRetryDelay(FlintClient client) async {
  print('\n=== Demo: Cancel during retry delay ===');
  await client.get<String>(
    '/retry-reset',
    cacheConfig: const CacheConfig(forceRefresh: true),
  );

  final token = CancelToken();
  final pending = client.get<String>(
    '/retry-test',
    cancelToken: token,
    cacheConfig: const CacheConfig(forceRefresh: true),
  );

  await Future<void>.delayed(const Duration(milliseconds: 60));
  token.cancel('user requested cancellation');

  final cancelled = await pending;
  print(
    'cancelled success=${cancelled.isSuccess} status=${cancelled.statusCode} '
    'errorKind=${cancelled.error?.kind} message=${cancelled.error?.message}',
  );
}

Future<HttpServer> _startMockServer() async {
  final server = await HttpServer.bind('localhost', 0);
  var retryAttempts = 0;

  server.listen((request) async {
    final response = request.response;
    final path = request.uri.path;

    if (path == '/json') {
      response.headers.contentType = ContentType.json;
      response.statusCode = 200;
      response.write(jsonEncode({'message': 'ok', 'id': 1}));
      await response.close();
      return;
    }

    if (path == '/text') {
      response.headers.contentType = ContentType.text;
      response.statusCode = 200;
      response.write('not-a-number');
      await response.close();
      return;
    }

    if (path == '/retry-reset') {
      retryAttempts = 0;
      response.statusCode = 200;
      response.write('retry counter reset');
      await response.close();
      return;
    }

    if (path == '/retry-test') {
      retryAttempts++;
      if (retryAttempts <= 2) {
        response.statusCode = 500;
        response.write('attempt $retryAttempts failed');
      } else {
        response.statusCode = 200;
        response.write('success on attempt $retryAttempts');
      }
      await response.close();
      return;
    }

    response.statusCode = 404;
    response.write('not found');
    await response.close();
  });

  return server;
}
