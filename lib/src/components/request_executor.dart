import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../flint_error.dart';
import '../flint_response.dart';
import '../request/body_serializer.dart';
import '../request/cancel_token.dart';
import '../request/request_context.dart';
import '../response/parse_mode.dart';
import '../status_code_config.dart';
import 'flint_logger.dart';
import 'response_handler.dart';

class RequestExecutor {
  final HttpClient client;
  final Duration timeout;
  final List<BodySerializer> bodySerializers;
  final FlintLogger logger;
  final Future<void> Function(HttpClientRequest request)? requestInterceptor;
  final Future<void> Function(HttpClientResponse response)? responseInterceptor;
  final Future<void> Function(
    HttpClientRequest request,
    RequestContext context,
  )?
  requestInterceptorWithContext;
  final Future<void> Function(
    HttpClientResponse response,
    RequestContext context,
  )?
  responseInterceptorWithContext;
  final ResponseHandler responseHandler;

  const RequestExecutor({
    required this.client,
    required this.timeout,
    required this.bodySerializers,
    required this.logger,
    required this.requestInterceptor,
    required this.responseInterceptor,
    required this.requestInterceptorWithContext,
    required this.responseInterceptorWithContext,
    required this.responseHandler,
  });

  Future<FlintResponse<T>> execute<T>(
    String method,
    Uri url, {
    dynamic body,
    Map<String, String>? defaultHeaders,
    Map<String, String>? requestHeaders,
    String? saveFilePath,
    Map<String, File>? files,
    void Function(int sent, int total)? onSendProgress,
    T Function(dynamic data)? parser,
    int attempt = 1,
    StatusCodeConfig? statusConfig,
    CancelToken? cancelToken,
    Duration? requestTimeout,
    RequestContext? context,
    ResponseParseMode parseMode = ResponseParseMode.lenient,
  }) async {
    final requestContext =
        context ?? RequestContext(method: method.toUpperCase(), url: url);
    if (cancelToken?.isCancelled == true) {
      throw FlintError.cancelled(
        message:
            'Request cancelled before start: ${cancelToken?.reason ?? 'no reason'}',
        url: url,
        method: method,
      );
    }

    logger.log('$method $url (attempt $attempt)');
    final stopwatch = Stopwatch()..start();

    final request = await _createRequest(method, url);
    final detachCancel = _attachCancelHandler(cancelToken, request);

    try {
      final allHeaders = {...?defaultHeaders, ...?requestHeaders};
      allHeaders.putIfAbsent(
        'X-Correlation-Id',
        () => requestContext.correlationId,
      );
      allHeaders.forEach((k, v) => request.headers.set(k, v));
      logger.log('Headers: ${logger.sanitizeHeaders(allHeaders)}');

      if (requestInterceptor != null) {
        await requestInterceptor!(request);
      }
      if (requestInterceptorWithContext != null) {
        await requestInterceptorWithContext!(request, requestContext);
      }

      if (files != null && files.isNotEmpty) {
        await _handleMultipartRequest(request, body, files, onSendProgress);
      } else if (body != null) {
        await _handleSerializedRequestBody(
          request,
          body,
          onSendProgress,
          context: requestContext,
        );
      }

      final effectiveTimeout = requestTimeout ?? timeout;
      final response = await _awaitWithCancellation<HttpClientResponse>(
        request.close().timeout(
          effectiveTimeout,
          onTimeout: () => throw TimeoutException(
            'Request timeout after ${effectiveTimeout.inMilliseconds}ms',
          ),
        ),
        cancelToken,
      );
      stopwatch.stop();

      if (responseInterceptor != null) {
        await responseInterceptor!(response);
      }
      if (responseInterceptorWithContext != null) {
        await responseInterceptorWithContext!(response, requestContext);
      }

      logger.log('Response: ${response.statusCode} ${response.reasonPhrase}');
      return responseHandler.handleResponse<T>(
        response,
        saveFilePath,
        parser,
        url: url,
        method: method,
        duration: stopwatch.elapsed,
        statusConfig: statusConfig,
        context: requestContext,
        parseMode: parseMode,
      );
    } catch (e) {
      if (e is FlintError) rethrow;
      throw FlintError.fromException(e, url: url, method: method);
    } finally {
      detachCancel();
    }
  }

  Future<HttpClientRequest> _createRequest(String method, Uri url) async {
    try {
      switch (method.toUpperCase()) {
        case 'POST':
          return await client.postUrl(url);
        case 'PUT':
          return await client.putUrl(url);
        case 'PATCH':
          return await client.patchUrl(url);
        case 'DELETE':
          return await client.deleteUrl(url);
        default:
          return await client.getUrl(url);
      }
    } catch (e) {
      throw FlintError('Failed to create request: ${e.toString()}');
    }
  }

  Future<void> _handleMultipartRequest(
    HttpClientRequest request,
    dynamic body,
    Map<String, File> files,
    void Function(int sent, int total)? onSendProgress,
  ) async {
    try {
      final boundary =
          '----FlintClientBoundary${DateTime.now().millisecondsSinceEpoch}';
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'multipart/form-data; boundary=$boundary',
      );

      final totalSize = await _calculateRequestSize(body, files);
      int sentSize = 0;

      void updateProgress(int additionalBytes) {
        sentSize += additionalBytes;
        onSendProgress?.call(sentSize, totalSize);
      }

      String buildField(String name, String value) =>
          '--$boundary\r\nContent-Disposition: form-data; name="$name"\r\n\r\n$value\r\n';

      String buildFileHeader(String name, String fileName, int length) =>
          '--$boundary\r\nContent-Disposition: form-data; name="$name"; filename="$fileName"\r\nContent-Type: application/octet-stream\r\nContent-Length: $length\r\n\r\n';

      if (body != null && body is Map<String, dynamic>) {
        body.forEach((key, value) {
          final fieldData = buildField(key, value.toString());
          request.write(fieldData);
          updateProgress(utf8.encode(fieldData).length);
        });
      }

      for (var entry in files.entries) {
        final file = entry.value;
        if (!await file.exists()) {
          throw FlintError('File not found: ${file.path}');
        }

        final fileName = file.path.split(Platform.pathSeparator).last;
        final fileLength = await file.length();

        final fileHeader = buildFileHeader(entry.key, fileName, fileLength);
        request.write(fileHeader);
        updateProgress(utf8.encode(fileHeader).length);

        await _writeFileWithProgress(file, request, updateProgress);

        request.write('\r\n');
        updateProgress(2);
      }

      final endBoundary = '--$boundary--\r\n';
      request.write(endBoundary);
      updateProgress(utf8.encode(endBoundary).length);
    } catch (e) {
      throw FlintError('Multipart request failed: ${e.toString()}');
    }
  }

  Future<void> _handleSerializedRequestBody(
    HttpClientRequest request,
    dynamic body,
    void Function(int sent, int total)? onSendProgress, {
    RequestContext? context,
  }) async {
    try {
      final declaredContentType = request.headers.contentType?.mimeType;
      final serializer = _selectSerializer(body, declaredContentType);

      final serialized =
          serializer?.serialize(
            body,
            contentType: declaredContentType,
            context: context,
          ) ??
          SerializedBody(
            bytes: body is List<int> ? body : utf8.encode(body.toString()),
          );

      if (request.headers.contentType == null &&
          serialized.contentType != null) {
        request.headers.contentType = serialized.contentType;
      }

      await _writeBytesWithProgress(request, serialized.bytes, onSendProgress);
    } catch (e) {
      throw FlintError('Request body serialization failed: ${e.toString()}');
    }
  }

  BodySerializer? _selectSerializer(dynamic body, String? contentType) {
    for (final serializer in bodySerializers) {
      if (serializer.canSerialize(body, contentType: contentType)) {
        return serializer;
      }
    }
    return null;
  }

  Future<void> _writeBytesWithProgress(
    HttpClientRequest request,
    List<int> bytes,
    void Function(int sent, int total)? onSendProgress,
  ) async {
    if (onSendProgress == null) {
      request.add(bytes);
      return;
    }

    const chunkSize = 1024;
    for (int i = 0; i < bytes.length; i += chunkSize) {
      final end = i + chunkSize < bytes.length ? i + chunkSize : bytes.length;
      request.add(bytes.sublist(i, end));
      onSendProgress(end, bytes.length);
      await Future.delayed(Duration.zero);
    }
  }

  Future<R> _awaitWithCancellation<R>(
    Future<R> task,
    CancelToken? cancelToken,
  ) async {
    if (cancelToken == null) {
      return await task;
    }
    if (cancelToken.isCancelled) {
      throw FlintError.cancelled(
        message: 'Request cancelled: ${cancelToken.reason ?? 'no reason'}',
      );
    }

    final completer = Completer<R>();
    final sub = cancelToken.whenCancelled.asStream().listen((reason) {
      if (!completer.isCompleted) {
        completer.completeError(
          FlintError.cancelled(
            message: 'Request cancelled: ${reason ?? 'no reason'}',
          ),
        );
      }
    });

    task
        .then(
          (value) {
            if (!completer.isCompleted) {
              completer.complete(value);
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!completer.isCompleted) {
              completer.completeError(error, stackTrace);
            }
          },
        )
        .whenComplete(() => sub.cancel());

    return completer.future;
  }

  void Function() _attachCancelHandler(
    CancelToken? cancelToken,
    HttpClientRequest request,
  ) {
    if (cancelToken == null) {
      return () {};
    }

    if (cancelToken.isCancelled) {
      request.abort(
        FlintError.cancelled(
          message: 'Request cancelled: ${cancelToken.reason ?? 'no reason'}',
        ),
      );
      return () {};
    }

    final sub = cancelToken.whenCancelled.asStream().listen((reason) {
      request.abort(
        FlintError.cancelled(
          message: 'Request cancelled: ${reason ?? 'no reason'}',
        ),
      );
    });
    return () => sub.cancel();
  }

  Future<int> _calculateRequestSize(
    dynamic body,
    Map<String, File> files,
  ) async {
    try {
      int size = 0;

      if (body != null && body is Map<String, dynamic>) {
        body.forEach((key, value) {
          size += utf8
              .encode(
                '--boundary\r\nContent-Disposition: form-data; name="$key"\r\n\r\n$value\r\n',
              )
              .length;
        });
      }

      for (var file in files.values) {
        if (!await file.exists()) {
          throw FlintError('File not found: ${file.path}');
        }
        final fileLength = await file.length();
        size += utf8
            .encode(
              '--boundary\r\nContent-Disposition: form-data; name="file"; filename="filename"\r\nContent-Type: application/octet-stream\r\n\r\n',
            )
            .length;
        size += fileLength;
        size += 2;
      }

      size += utf8.encode('--boundary--\r\n').length;
      return size;
    } catch (e) {
      throw FlintError('Failed to calculate request size: ${e.toString()}');
    }
  }

  Future<void> _writeFileWithProgress(
    File file,
    HttpClientRequest request,
    void Function(int) updateProgress,
  ) async {
    try {
      final stream = file.openRead();
      await for (final chunk in stream) {
        request.add(chunk);
        updateProgress(chunk.length);
      }
    } catch (e) {
      throw FlintError('Failed to write file: ${e.toString()}');
    }
  }
}
