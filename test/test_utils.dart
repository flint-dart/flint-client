/// Test utilities for Flint HTTP Client tests
library;

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flint_client/flint_client.dart';
import 'package:test/test.dart';

/// A simple HTTP server for testing
class TestServer {
  late HttpServer _server;
  int _port = 0;
  int _retryAttempts = 0;
  int _retryAfterAttempts = 0;

  int get port => _port;
  String get baseUrl => 'http://localhost:$port';

  /// Starts the test server
  Future<void> start() async {
    _server = await HttpServer.bind('localhost', 0);
    _port = _server.port;
    _retryAttempts = 0;
    _retryAfterAttempts = 0;

    _server.listen((HttpRequest request) async {
      await _handleRequest(request);
    });
  }

  /// Stops the test server
  Future<void> stop() async {
    await _server.close();
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final path = request.uri.path;
    final method = request.method;

    try {
      // Default response
      HttpResponse response = request.response;

      // Simulate different response scenarios based on path
      if (path == '/success') {
        response
          ..statusCode = 200
          ..write(jsonEncode({'message': 'Success', 'data': 'test'}))
          ..close();
      } else if (path == '/error/400') {
        response
          ..statusCode = 400
          ..write('Bad Request')
          ..close();
      } else if (path == '/error/500') {
        response
          ..statusCode = 500
          ..write('Internal Server Error')
          ..close();
      } else if (path == '/error/json') {
        response
          ..headers.contentType = ContentType.json
          ..statusCode = 422
          ..write(
            jsonEncode({
              'message': 'Validation failed',
              'errors': {
                'email': ['Invalid email'],
              },
            }),
          )
          ..close();
      } else if (path == '/error/list') {
        response
          ..headers.contentType = ContentType.json
          ..statusCode = 409
          ..write(jsonEncode(['duplicate', 'conflict']))
          ..close();
      } else if (path == '/timeout') {
        // Simulate slow response
        Future.delayed(Duration(seconds: 3), () {
          response
            ..statusCode = 200
            ..write('Slow Response')
            ..close();
        });
      } else if (path == '/json') {
        response
          ..headers.contentType = ContentType.json
          ..statusCode = 200
          ..write(jsonEncode({'id': 1, 'name': 'Test'}))
          ..close();
      } else if (path == '/text') {
        response
          ..headers.contentType = ContentType.text
          ..statusCode = 200
          ..write('Plain text response')
          ..close();
      } else if (path == '/xml') {
        response
          ..headers.contentType = ContentType('application', 'xml')
          ..statusCode = 200
          ..write('<note><id>1</id><name>Flint</name></note>')
          ..close();
      } else if (path == '/echo') {
        final headers = <String, List<String>>{};
        request.headers.forEach((name, values) {
          headers[name] = List<String>.from(values);
        });

        final rawBody = await utf8.decoder.bind(request).join();
        dynamic parsedBody;
        if (rawBody.isNotEmpty) {
          try {
            parsedBody = jsonDecode(rawBody);
          } catch (_) {
            parsedBody = rawBody;
          }
        }

        final query = <String, String>{};
        request.uri.queryParameters.forEach((key, value) {
          query[key] = value;
        });

        final pathWithQuery = request.uri.hasQuery
            ? '${request.uri.path}?${request.uri.query}'
            : request.uri.path;

        final body = <String, dynamic>{
          'method': method,
          'path': pathWithQuery,
          'query': query,
          'headers': headers,
          'body': parsedBody,
        };

        response
          ..statusCode = 200
          ..write(jsonEncode(body))
          ..close();
      } else if (path == '/download') {
        response
          ..headers.contentType = ContentType.binary
          ..statusCode = 200
          ..write('File content for download')
          ..close();
      } else if (path == '/retry-test') {
        _retryAttempts++;
        if (_retryAttempts <= 2) {
          response
            ..statusCode = 500
            ..write('Attempt $_retryAttempts failed')
            ..close();
        } else {
          response
            ..statusCode = 200
            ..write('Success on attempt $_retryAttempts')
            ..close();
        }
      } else if (path == '/retry-reset') {
        _retryAttempts = 0;
        _retryAfterAttempts = 0;
        response
          ..statusCode = 200
          ..write('Retry counter reset')
          ..close();
      } else if (path == '/retry-after-test') {
        _retryAfterAttempts++;
        if (_retryAfterAttempts == 1) {
          response.headers.set('Retry-After', '1');
          response
            ..statusCode = 429
            ..write('Rate limited');
        } else {
          response
            ..statusCode = 200
            ..write('Retry-After respected');
        }
        response.close();
      } else if (path == '/always-500') {
        response
          ..statusCode = 500
          ..write('Always failing endpoint')
          ..close();
      } else {
        response
          ..statusCode = 404
          ..write('Not Found: $path')
          ..close();
      }
    } catch (e) {
      request.response
        ..statusCode = 500
        ..write('Server Error: $e')
        ..close();
    }
  }
}

/// Creates a test file for file operation tests
Future<File> createTestFile(String content) async {
  final tempDir = Directory.systemTemp;
  final file = File(
    '${tempDir.path}/test_${DateTime.now().millisecondsSinceEpoch}.txt',
  );
  await file.writeAsString(content);
  return file;
}

/// Cleans up test files
Future<void> cleanupTestFile(File file) async {
  if (await file.exists()) {
    await file.delete();
  }
}

/// Matcher for FlintError with specific properties
Matcher isFlintError({
  String? message,
  int? statusCode,
  bool? isNetworkError,
  bool? isServerError,
  bool? isClientError,
}) {
  return allOf([
    isA<FlintError>(),
    if (message != null)
      predicate<FlintError>((error) => error.message.contains(message)),
    if (statusCode != null)
      predicate<FlintError>((error) => error.statusCode == statusCode),
    if (isNetworkError != null)
      predicate<FlintError>((error) => error.isNetworkError == isNetworkError),
    if (isServerError != null)
      predicate<FlintError>((error) => error.isServerError == isServerError),
    if (isClientError != null)
      predicate<FlintError>((error) => error.isClientError == isClientError),
  ]);
}

/// Matcher for successful FlintResponse
/// Matcher for successful FlintResponse
Matcher isSuccessfulResponse<T>({
  int? statusCode,
  dynamic data,
  FlintResponseType? type,
}) {
  return allOf([
    isA<FlintResponse<T>>(),
    predicate<FlintResponse<T>>((response) => response.isSuccess),
    predicate<FlintResponse<T>>((response) => !response.isError),
    if (statusCode != null)
      predicate<FlintResponse<T>>(
        (response) => response.statusCode == statusCode,
      ),
    if (data != null)
      predicate<FlintResponse<T>>((response) => response.data == data),
    if (type != null)
      predicate<FlintResponse<T>>((response) => response.type == type),
  ]);
}

/// Matcher for error FlintResponse
Matcher isErrorResponse<T>({int? statusCode, String? errorMessage}) {
  return allOf([
    isA<FlintResponse<T>>(),
    predicate<FlintResponse<T>>((response) => response.isError),
    predicate<FlintResponse<T>>((response) => !response.success),
    if (statusCode != null)
      predicate<FlintResponse<T>>(
        (response) => response.statusCode == statusCode,
      ),
    if (errorMessage != null)
      predicate<FlintResponse<T>>(
        (response) => response.error?.message.contains(errorMessage) == true,
      ),
  ]);
}
