import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

enum FlintErrorKind { unknown, timeout, cancelled, network, http, parse }

enum FlintResponseType { json, text, file, unknown, html, binary, stream }

typedef ErrorHandler = void Function(FlintError error);
typedef JsonParser<T> = T Function(dynamic json);
typedef RequestDoneCallback<T> =
    void Function(FlintResponse<T> response, FlintError? error);

class StatusCodeConfig {
  const StatusCodeConfig({
    this.successCodes = const {200, 201, 202, 204},
    this.errorCodes = const {
      400,
      401,
      402,
      403,
      404,
      405,
      408,
      409,
      410,
      422,
      429,
      500,
      501,
      502,
      503,
      504,
    },
    this.redirectCodes = const {301, 302, 303, 304, 307, 308},
    this.clientErrorCodes = const {
      400,
      401,
      402,
      403,
      404,
      405,
      408,
      409,
      410,
      422,
      429,
    },
    this.serverErrorCodes = const {500, 501, 502, 503, 504},
  });

  final Set<int> successCodes;
  final Set<int> errorCodes;
  final Set<int> redirectCodes;
  final Set<int> clientErrorCodes;
  final Set<int> serverErrorCodes;

  bool isSuccess(int statusCode) => successCodes.contains(statusCode);
  bool isError(int statusCode) => errorCodes.contains(statusCode);
  bool isRedirect(int statusCode) => redirectCodes.contains(statusCode);
  bool isClientError(int statusCode) => clientErrorCodes.contains(statusCode);
  bool isServerError(int statusCode) => serverErrorCodes.contains(statusCode);
}

class FlintError implements Exception {
  static const int cancelledStatusCode = 499;

  FlintError(
    this.message, {
    this.statusCode,
    this.originalException,
    this.data,
    this.url,
    this.method,
    FlintErrorKind? kind,
    this.retryAfter,
    DateTime? timestamp,
  }) : kind = kind ?? _inferKind(message, statusCode, originalException),
       timestamp = timestamp ?? DateTime.now();

  final String message;
  final int? statusCode;
  final dynamic originalException;
  final dynamic data;
  final Uri? url;
  final String? method;
  final FlintErrorKind kind;
  final Duration? retryAfter;
  final DateTime timestamp;

  factory FlintError.cancelled({
    String message = 'Request cancelled',
    Uri? url,
    String? method,
    dynamic originalException,
  }) {
    return FlintError(
      message,
      statusCode: cancelledStatusCode,
      originalException: originalException,
      url: url,
      method: method,
      kind: FlintErrorKind.cancelled,
    );
  }

  factory FlintError.fromException(
    dynamic exception, {
    int? statusCode,
    Uri? url,
    String? method,
  }) {
    if (exception is FlintError) return exception;
    return FlintError(
      exception.toString(),
      statusCode: statusCode,
      originalException: exception,
      url: url,
      method: method,
    );
  }

  bool get isClientError =>
      statusCode != null && statusCode! >= 400 && statusCode! < 500;
  bool get isServerError =>
      statusCode != null && statusCode! >= 500 && statusCode! < 600;
  bool get isNetworkError => kind == FlintErrorKind.network;
  bool get isTimeout => kind == FlintErrorKind.timeout;
  bool get isCancelled => kind == FlintErrorKind.cancelled;
  bool get isRateLimit => statusCode == 429;
  bool get isRetryable =>
      isServerError || isNetworkError || isTimeout || isRateLimit;

  Map<String, dynamic> toMap() {
    return {
      'message': message,
      'statusCode': statusCode,
      'data': data,
      'url': url?.toString(),
      'method': method,
      'kind': kind.name,
      'timestamp': timestamp.toIso8601String(),
      'retryAfterMs': retryAfter?.inMilliseconds,
    };
  }

  @override
  String toString() {
    final buffer = StringBuffer('FlintError: $message');
    if (statusCode != null) buffer.write(' (Status: $statusCode)');
    buffer.write(' [Kind: ${kind.name}]');
    if (url != null) {
      buffer.write(' [${method?.toUpperCase() ?? 'GET'} $url]');
    }
    return buffer.toString();
  }

  static FlintErrorKind _inferKind(
    String message,
    int? statusCode,
    dynamic originalException,
  ) {
    final lower = message.toLowerCase();
    if (lower.contains('cancel')) return FlintErrorKind.cancelled;
    if (statusCode == 408 || lower.contains('timeout')) {
      return FlintErrorKind.timeout;
    }
    if (statusCode != null) return FlintErrorKind.http;
    if (originalException is FormatException) return FlintErrorKind.parse;
    if (lower.contains('network')) return FlintErrorKind.network;
    return FlintErrorKind.unknown;
  }
}

class FlintResponse<T> {
  FlintResponse({
    required this.statusCode,
    this.data,
    this.type = FlintResponseType.unknown,
    this.headers,
    this.url,
    this.method,
    DateTime? timestamp,
    this.duration,
    StatusCodeConfig? statusConfig,
  }) : statusConfig = statusConfig ?? const StatusCodeConfig(),
       success = (statusConfig ?? const StatusCodeConfig()).isSuccess(
         statusCode,
       ),
       isError = !(statusConfig ?? const StatusCodeConfig()).isSuccess(
         statusCode,
       ),
       error = !(statusConfig ?? const StatusCodeConfig()).isSuccess(statusCode)
           ? FlintError(
               'HTTP $statusCode',
               statusCode: statusCode,
               data: data,
               url: url,
               method: method,
               kind: FlintErrorKind.http,
               timestamp: timestamp,
             )
           : null,
       timestamp = timestamp ?? DateTime.now();

  FlintResponse.error(
    FlintError this.error, {
    this.headers,
    this.method,
    this.duration,
    StatusCodeConfig? statusConfig,
  }) : statusCode = error.statusCode ?? 500,
       data = null,
       isError = true,
       success = false,
       url = error.url,
       type = FlintResponseType.unknown,
       timestamp = error.timestamp,
       statusConfig = statusConfig ?? const StatusCodeConfig();

  final int statusCode;
  final T? data;
  final bool isError;
  final FlintResponseType type;
  final Map<String, String>? headers;
  final bool success;
  final FlintError? error;
  final Uri? url;
  final String? method;
  final DateTime timestamp;
  final Duration? duration;
  final StatusCodeConfig statusConfig;

  bool get isJson => type == FlintResponseType.json;
  bool get isText => type == FlintResponseType.text;
  bool get isHtml => type == FlintResponseType.html;
  bool get isFile => type == FlintResponseType.file;
  bool get isBinary => type == FlintResponseType.binary;
  bool get isSuccess => statusConfig.isSuccess(statusCode);
  bool get isClientError => statusConfig.isClientError(statusCode);
  bool get isServerError => statusConfig.isServerError(statusCode);
  bool get isRedirect => statusConfig.isRedirect(statusCode);

  T get requireData {
    if (isError && error != null) throw error!;
    if (data == null) throw StateError('Response data is null');
    return data as T;
  }

  FlintResponse<T> throwIfError() {
    if (isError && error != null) throw error!;
    return this;
  }
}

class FlintClient {
  FlintClient({
    this.baseUrl,
    this.headers = const {},
    this.defaultQueryParameters = const {},
    this.timeout = const Duration(seconds: 30),
    this.onError,
    this.throwIfError = false,
    this.onDone,
    this.debug = false,
    this.statusCodeConfig = const StatusCodeConfig(),
  });

  final String? baseUrl;
  final Map<String, String> headers;
  final Map<String, dynamic> defaultQueryParameters;
  final Duration timeout;
  final ErrorHandler? onError;
  final bool throwIfError;
  final RequestDoneCallback? onDone;
  final bool debug;
  final StatusCodeConfig statusCodeConfig;

  Future<FlintResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    JsonParser<T>? parser,
    ErrorHandler? onError,
    RequestDoneCallback<T>? onDone,
    Duration? requestTimeout,
  }) {
    return request<T>(
      'GET',
      path,
      body: null,
      queryParameters: queryParameters,
      headers: headers,
      parser: parser,
      onError: onError,
      onDone: onDone,
      requestTimeout: requestTimeout,
    );
  }

  Future<FlintResponse<T>> post<T>(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    JsonParser<T>? parser,
    ErrorHandler? onError,
    RequestDoneCallback<T>? onDone,
    Duration? requestTimeout,
  }) {
    return request<T>(
      'POST',
      path,
      body: body,
      queryParameters: queryParameters,
      headers: headers,
      parser: parser,
      onError: onError,
      onDone: onDone,
      requestTimeout: requestTimeout,
    );
  }

  Future<FlintResponse<T>> put<T>(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    JsonParser<T>? parser,
    ErrorHandler? onError,
    RequestDoneCallback<T>? onDone,
    Duration? requestTimeout,
  }) {
    return request<T>(
      'PUT',
      path,
      body: body,
      queryParameters: queryParameters,
      headers: headers,
      parser: parser,
      onError: onError,
      onDone: onDone,
      requestTimeout: requestTimeout,
    );
  }

  Future<FlintResponse<T>> patch<T>(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    JsonParser<T>? parser,
    ErrorHandler? onError,
    RequestDoneCallback<T>? onDone,
    Duration? requestTimeout,
  }) {
    return request<T>(
      'PATCH',
      path,
      body: body,
      queryParameters: queryParameters,
      headers: headers,
      parser: parser,
      onError: onError,
      onDone: onDone,
      requestTimeout: requestTimeout,
    );
  }

  Future<FlintResponse<T>> delete<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    JsonParser<T>? parser,
    ErrorHandler? onError,
    RequestDoneCallback<T>? onDone,
    Duration? requestTimeout,
  }) {
    return request<T>(
      'DELETE',
      path,
      queryParameters: queryParameters,
      headers: headers,
      parser: parser,
      onError: onError,
      onDone: onDone,
      requestTimeout: requestTimeout,
    );
  }

  FlintClient withQuery(Map<String, dynamic> query) {
    return FlintClient(
      baseUrl: baseUrl,
      headers: headers,
      defaultQueryParameters: {...defaultQueryParameters, ...query},
      timeout: timeout,
      onError: onError,
      throwIfError: throwIfError,
      onDone: onDone,
      debug: debug,
      statusCodeConfig: statusCodeConfig,
    );
  }

  Future<FlintResponse<T>> request<T>(
    String method,
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    JsonParser<T>? parser,
    ErrorHandler? onError,
    RequestDoneCallback<T>? onDone,
    Duration? requestTimeout,
  }) async {
    final url = _url(path, queryParameters);
    final stopwatch = Stopwatch()..start();

    try {
      final response = await _send<T>(
        method.toUpperCase(),
        url,
        body: body,
        headers: headers,
        parser: parser,
        timeout: requestTimeout ?? timeout,
      );
      stopwatch.stop();
      final completed = FlintResponse<T>(
        statusCode: response.statusCode,
        data: response.data,
        type: response.type,
        headers: response.headers,
        url: Uri.parse(url),
        method: method,
        duration: stopwatch.elapsed,
        statusConfig: statusCodeConfig,
      );
      _finish(completed, null, onDone);
      return completed;
    } catch (error) {
      stopwatch.stop();
      final flintError = error is FlintError
          ? error
          : FlintError.fromException(
              error,
              url: Uri.parse(url),
              method: method,
            );
      final errorResponse = FlintResponse<T>.error(
        flintError,
        method: method,
        duration: stopwatch.elapsed,
        statusConfig: statusCodeConfig,
      );
      _finish(errorResponse, flintError, onDone);
      final handler = onError ?? this.onError;
      handler?.call(flintError);
      if (throwIfError) throw flintError;
      return errorResponse;
    }
  }

  Future<FlintResponse<T>> _send<T>(
    String method,
    String url, {
    dynamic body,
    Map<String, String>? headers,
    JsonParser<T>? parser,
    required Duration timeout,
  }) {
    final xhr = web.XMLHttpRequest();
    final completer = Completer<FlintResponse<T>>();
    final requestHeaders = <String, String>{
      'Accept': 'application/json',
      ...this.headers,
      ...?headers,
    };
    final encodedBody = _body(body, requestHeaders);

    xhr.open(method, url, true);
    for (final header in requestHeaders.entries) {
      xhr.setRequestHeader(header.key, header.value);
    }

    xhr.onLoad.listen((_) {
      final parsed = _parseResponse<T>(
        xhr.responseText,
        xhr.getResponseHeader('content-type') ?? '',
        parser,
      );
      final response = FlintResponse<T>(
        statusCode: xhr.status,
        data: parsed.data,
        type: parsed.type,
        headers: _responseHeaders(xhr.getAllResponseHeaders()),
        url: Uri.parse(url),
        method: method,
        statusConfig: statusCodeConfig,
      );

      if (response.isSuccess) {
        completer.complete(response);
      } else {
        completer.completeError(
          FlintError(
            'HTTP ${response.statusCode}',
            statusCode: response.statusCode,
            data: response.data,
            url: Uri.parse(url),
            method: method,
            kind: FlintErrorKind.http,
          ),
        );
      }
    });

    xhr.onError.listen((_) {
      completer.completeError(
        FlintError(
          'Network request failed',
          url: Uri.parse(url),
          method: method,
          kind: FlintErrorKind.network,
        ),
      );
    });

    if (encodedBody == null) {
      xhr.send();
    } else {
      xhr.send(encodedBody.toJS);
    }

    return completer.future.timeout(
      timeout,
      onTimeout: () {
        xhr.abort();
        throw FlintError(
          'Request timed out after ${timeout.inMilliseconds}ms',
          url: Uri.parse(url),
          method: method,
          kind: FlintErrorKind.timeout,
        );
      },
    );
  }

  void dispose() {}

  String _url(String path, Map<String, dynamic>? queryParameters) {
    if (baseUrl == null) {
      throw FlintError('Base URL not set. HTTP requests require a baseUrl.');
    }

    final normalizedBase = baseUrl!.endsWith('/')
        ? baseUrl!.substring(0, baseUrl!.length - 1)
        : baseUrl!;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$normalizedBase$normalizedPath');
    final merged = {
      ...uri.queryParameters,
      ...defaultQueryParameters,
      ...?queryParameters,
    };
    final clean = {
      for (final entry in merged.entries)
        if (entry.value != null) entry.key: entry.value.toString(),
    };

    return uri
        .replace(queryParameters: clean.isEmpty ? null : clean)
        .toString();
  }

  String? _body(dynamic body, Map<String, String> headers) {
    if (body == null) return null;
    if (body is String) return body;
    headers.putIfAbsent('Content-Type', () => 'application/json');
    return jsonEncode(body);
  }

  _ParsedResponse<T> _parseResponse<T>(
    String text,
    String contentType,
    JsonParser<T>? parser,
  ) {
    if (text.trim().isEmpty) {
      return _ParsedResponse<T>(null, FlintResponseType.unknown);
    }

    final isJson =
        contentType.toLowerCase().contains('json') ||
        text.trimLeft().startsWith('{') ||
        text.trimLeft().startsWith('[');

    if (isJson) {
      final decoded = jsonDecode(text);
      final data = parser == null ? decoded as T? : parser(decoded);
      return _ParsedResponse<T>(data, FlintResponseType.json);
    }

    final data = parser == null ? text as T? : parser(text);
    return _ParsedResponse<T>(data, FlintResponseType.text);
  }

  Map<String, String> _responseHeaders(String rawHeaders) {
    final parsed = <String, String>{};
    for (final line in rawHeaders.split(RegExp(r'\r?\n'))) {
      if (line.trim().isEmpty) continue;
      final separator = line.indexOf(':');
      if (separator <= 0) continue;
      parsed[line.substring(0, separator).toLowerCase()] = line
          .substring(separator + 1)
          .trim();
    }
    return parsed;
  }

  void _finish<T>(
    FlintResponse<T> response,
    FlintError? error,
    RequestDoneCallback<T>? onDone,
  ) {
    onDone?.call(response, error);
    if (this.onDone != null) this.onDone!(response, error);
  }
}

class _ParsedResponse<T> {
  const _ParsedResponse(this.data, this.type);

  final T? data;
  final FlintResponseType type;
}
