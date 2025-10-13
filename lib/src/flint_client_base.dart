import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:clock/clock.dart';
import 'package:flint_client/src/flint_web_socket_client.dart';
import 'package:flint_client/src/status_code_config.dart';

// Import your existing files
import 'cache/cache.dart';
import 'flint_response.dart';
import 'flint_error.dart';
import 'retry.dart';

/// Callback type for handling errors returned by [FlintClient].
typedef ErrorHandler = void Function(FlintError error);

/// Callback type to track upload or download progress.
/// [sent] is the number of bytes sent or received.
/// [total] is the total number of bytes.
typedef ProgressCallback = void Function(int sent, int total);

/// Intercepts HTTP requests before they are sent.
typedef RequestInterceptor = Future<void> Function(HttpClientRequest request);

/// Intercepts HTTP responses after they are received.
typedef ResponseInterceptor =
    Future<void> Function(HttpClientResponse response);

/// Parses JSON responses into a strongly-typed object [T].
typedef JsonParser<T> = T Function(dynamic json);
typedef RequestDoneCallback<T> =
    void Function(FlintResponse<T> response, FlintError? error);

/// A powerful HTTP client for making requests to REST APIs with
/// support for JSON, file uploads/downloads, progress tracking, caching, and retries.
class FlintClient {
  /// Base URL for all HTTP requests.
  final String? baseUrl;

  /// Default headers to include with every request.
  final Map<String, String> headers;

  /// Timeout duration for requests.
  final Duration timeout;

  /// Optional error handler callback.
  final ErrorHandler? onError;

  /// Optional interceptor called before each request is sent.
  final RequestInterceptor? requestInterceptor;

  /// Optional interceptor called after each response is received.
  final ResponseInterceptor? responseInterceptor;

  /// Cache store for responses
  final CacheStore cacheStore;

  /// Default cache configuration
  final CacheConfig defaultCacheConfig;

  /// Default retry configuration
  final RetryConfig defaultRetryConfig;

  /// Enables debug logging if true.
  final bool debug;

  /// Internal, long-lived [HttpClient] instance.
  final HttpClient _client;

  final StatusCodeConfig statusCodeConfig;

  /// Creates a new [FlintClient] instance.
  ///
  /// [baseUrl] sets the API base URL. If null, requests must provide full URLs.
  /// [headers] sets default headers for all requests.
  /// [timeout] sets the request timeout duration.
  /// [onError] provides a centralized error callback.
  /// [requestInterceptor] and [responseInterceptor] allow custom handling
  /// before sending requests or after receiving responses.
  /// [cacheStore] provides cache storage (defaults to MemoryCacheStore).
  /// [defaultCacheConfig] sets default caching behavior.
  /// [defaultRetryConfig] sets default retry behavior.
  /// [debug] enables console logging.
  bool _isDisposed = false;
  final RequestDoneCallback? onDone;

  FlintClient({
    this.baseUrl,
    this.headers = const {},
    this.timeout = const Duration(seconds: 30),
    this.onError,
    this.onDone, // Add this
    this.requestInterceptor,
    this.responseInterceptor,
    CacheStore? cacheStore,
    CacheConfig? defaultCacheConfig,
    RetryConfig? defaultRetryConfig,
    this.debug = false,
    this.statusCodeConfig =
        const StatusCodeConfig(), // Optional - defaults to standard
  }) : cacheStore = cacheStore ?? MemoryCacheStore(),
       defaultCacheConfig = defaultCacheConfig ?? const CacheConfig(),
       defaultRetryConfig = defaultRetryConfig ?? const RetryConfig(),
       _client = HttpClient()
         ..connectionTimeout = timeout
         ..idleTimeout = timeout;

  /// Creates a copy of this client with optional overrides.
  FlintClient copyWith({
    String? baseUrl,
    Map<String, String>? headers,
    Duration? timeout,
    ErrorHandler? onError,
    RequestInterceptor? requestInterceptor,
    ResponseInterceptor? responseInterceptor,
    CacheStore? cacheStore,
    CacheConfig? defaultCacheConfig,
    RequestDoneCallback? onDone, // Add this
    RetryConfig? defaultRetryConfig,
    bool? debug,
    StatusCodeConfig? statusCodeConfig,
  }) {
    return FlintClient(
      baseUrl: baseUrl ?? this.baseUrl,
      headers: headers ?? this.headers,
      timeout: timeout ?? this.timeout,
      onError: onError ?? this.onError,
      onDone: onDone ?? this.onDone, // Add this
      requestInterceptor: requestInterceptor ?? this.requestInterceptor,
      responseInterceptor: responseInterceptor ?? this.responseInterceptor,
      cacheStore: cacheStore ?? this.cacheStore,
      defaultCacheConfig: defaultCacheConfig ?? this.defaultCacheConfig,
      defaultRetryConfig: defaultRetryConfig ?? this.defaultRetryConfig,
      debug: debug ?? this.debug,
      statusCodeConfig: statusCodeConfig ?? this.statusCodeConfig,
    );
  }

  /// Ensures that [baseUrl] is set before making a request.
  void _ensureBaseUrl() {
    if (baseUrl == null) {
      throw FlintError('Base URL not set. HTTP requests require a baseUrl.');
    }
  }

  /// Logs messages to console when [debug] is enabled.
  void _log(String message) {
    if (debug) {
      print('[FlintClient] $message');
    }
  }

  // WITH this improved version:
  FlintWebSocketClient ws(
    String path, {
    Map<String, dynamic>? params,
    Map<String, String>? headers,
  }) {
    _ensureBaseUrl();

    // Improved URL handling for both http and https
    final wsUrl =
        baseUrl!.replaceFirst(RegExp(r'^http'), 'ws') + _normalizePath(path);

    // Merge headers properly
    final mergedHeaders = <String, String>{...this.headers, ...headers ?? {}};

    // Extract token from Authorization header
    String? token;
    final authHeader = mergedHeaders['Authorization'];
    if (authHeader != null && authHeader.startsWith('Bearer ')) {
      token = authHeader.substring(7);
    }

    return FlintWebSocketClient(
      wsUrl,
      params: params,
      token: token,
      headers: mergedHeaders,
      debug: debug,
    );
  }

  // ADD this helper method (put it near other helper methods):
  String _normalizePath(String path) {
    if (path.startsWith('/')) return path;
    return '/$path';
  }

  /// Sends a GET request to [path] with optional query parameters, headers,
  /// file save path, cache configuration, retry configuration, and a custom JSON parser.
  Future<FlintResponse<T>> get<T>(
    String path, {
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    String? saveFilePath,
    CacheConfig? cacheConfig,
    StatusCodeConfig? statusConfig, // ADD THIS

    RetryConfig? retryConfig,
    JsonParser<T>? parser,
    ErrorHandler? onError,
    RequestDoneCallback? onDone,
  }) {
    final mainOnDone = onDone ?? this.onDone;
    _ensureBaseUrl();

    if (queryParameters != null && queryParameters.isNotEmpty) {
      path = _buildPathWithQuery(path, queryParameters);
    }

    return _request<T>(
      'GET',
      path,
      headers: headers,
      saveFilePath: saveFilePath,
      cacheConfig: cacheConfig,
      statusConfig: statusConfig,
      retryConfig: retryConfig,
      parser: parser,
      onError: onError,
      onDone: mainOnDone,
    );
  }

  /// Sends a POST request to [path] with optional body, files, headers,
  /// query parameters, progress callback, cache config, retry config, and a custom JSON parser.
  Future<FlintResponse<T>> post<T>(
    String path, {
    dynamic body,
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    String? saveFilePath,
    Map<String, File>? files,
    ProgressCallback? onSendProgress,
    StatusCodeConfig? statusConfig, // ADD THIS

    CacheConfig? cacheConfig,
    RetryConfig? retryConfig,
    JsonParser<T>? parser,
    ErrorHandler? onError,
    RequestDoneCallback? onDone,
  }) {
    final mainOnDone = onDone ?? this.onDone;

    _ensureBaseUrl();

    if (queryParameters != null && queryParameters.isNotEmpty) {
      path = _buildPathWithQuery(path, queryParameters);
    }

    return _request<T>(
      'POST',
      path,
      body: body,
      headers: headers,
      saveFilePath: saveFilePath,
      files: files,
      statusConfig: statusConfig,
      onSendProgress: onSendProgress,
      cacheConfig: cacheConfig,
      retryConfig: retryConfig,
      parser: parser,
      onError: onError,
      onDone: mainOnDone,
    );
  }

  /// Sends a PUT request to [path] (similar to POST).
  Future<FlintResponse<T>> put<T>(
    String path, {
    dynamic body,
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    String? saveFilePath,
    Map<String, File>? files,
    ProgressCallback? onSendProgress,
    StatusCodeConfig? statusConfig, // ADD THIS

    CacheConfig? cacheConfig,
    RetryConfig? retryConfig,
    JsonParser<T>? parser,
    ErrorHandler? onError,
    RequestDoneCallback? onDone,
  }) {
    final mainOnDone = onDone ?? this.onDone;

    _ensureBaseUrl();

    if (queryParameters != null && queryParameters.isNotEmpty) {
      path = _buildPathWithQuery(path, queryParameters);
    }

    return _request<T>(
      'PUT',
      path,
      body: body,
      headers: headers,
      saveFilePath: saveFilePath,
      files: files,
      onSendProgress: onSendProgress,
      statusConfig: statusConfig,
      cacheConfig: cacheConfig,
      retryConfig: retryConfig,
      parser: parser,
      onError: onError,
      onDone: mainOnDone,
    );
  }

  /// Sends a PATCH request to [path] (similar to PUT).
  Future<FlintResponse<T>> patch<T>(
    String path, {
    dynamic body,
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    String? saveFilePath,
    Map<String, File>? files,
    ProgressCallback? onSendProgress,
    CacheConfig? cacheConfig,
    RetryConfig? retryConfig,
    JsonParser<T>? parser,
    StatusCodeConfig? statusConfig, // ADD THIS

    ErrorHandler? onError,
    RequestDoneCallback? onDone,
  }) {
    final mainOnDone = onDone ?? this.onDone;

    _ensureBaseUrl();

    if (queryParameters != null && queryParameters.isNotEmpty) {
      path = _buildPathWithQuery(path, queryParameters);
    }

    return _request<T>(
      'PATCH',
      path,
      body: body,
      headers: headers,
      saveFilePath: saveFilePath,
      files: files,
      onSendProgress: onSendProgress,
      cacheConfig: cacheConfig,
      retryConfig: retryConfig,
      statusConfig: statusConfig,
      parser: parser,
      onError: onError,
      onDone: mainOnDone,
    );
  }

  /// Sends a DELETE request to [path] with optional query parameters,
  /// headers, save file path, cache config, retry config, and custom JSON parser.
  Future<FlintResponse<T>> delete<T>(
    String path, {
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    String? saveFilePath,
    CacheConfig? cacheConfig,
    StatusCodeConfig? statusConfig, // ADD THIS

    RetryConfig? retryConfig,
    JsonParser<T>? parser,
    ErrorHandler? onError,
    RequestDoneCallback? onDone,
  }) {
    final mainOnDone = onDone ?? this.onDone;

    _ensureBaseUrl();

    if (queryParameters != null && queryParameters.isNotEmpty) {
      path = _buildPathWithQuery(path, queryParameters);
    }

    return _request<T>(
      'DELETE',
      path,
      headers: headers,
      saveFilePath: saveFilePath,
      cacheConfig: cacheConfig,
      retryConfig: retryConfig,
      statusConfig: statusConfig,
      parser: parser,
      onError: onError,
      onDone: mainOnDone,
    );
  }

  /// Builds a full path with query parameters appended.
  String _buildPathWithQuery(String path, Map<String, String> queryParameters) {
    final uri = Uri.parse(path);
    final newUri = uri.replace(
      queryParameters: {...uri.queryParameters, ...queryParameters},
    );
    return newUri.toString();
  }

  void dispose() {
    if (!_isDisposed) {
      _client.close(force: true);
      _isDisposed = true;
    }
  }

  // -------------------------
  // Internal request handling
  // -------------------------
  void _ensureNotDisposed() {
    if (_isDisposed) {
      throw FlintError(
        'FlintClient has been disposed and can no longer be used.',
      );
    }
  }

  /// Generates a cache key for the request
  String _generateCacheKey(
    String method,
    String path, {
    Map<String, String>? queryParameters,
    dynamic body,
    Map<String, String>? headers,
  }) {
    final uri = Uri.parse('$baseUrl$path');
    final keyComponents = [
      method.toUpperCase(),
      uri.toString(),
      if (queryParameters != null && queryParameters.isNotEmpty)
        Uri(queryParameters: queryParameters).toString(),
      if (body != null) jsonEncode(_sortJson(body)),
      if (headers != null && headers.isNotEmpty) jsonEncode(_sortMap(headers)),
    ];

    return keyComponents.join('|').hashCode.toString();
  }

  /// Sorts JSON objects for consistent cache keys
  dynamic _sortJson(dynamic data) {
    if (data is Map) {
      final sortedMap = <String, dynamic>{};
      final keys = data.keys.toList()..sort();
      for (final key in keys) {
        sortedMap[key] = _sortJson(data[key]);
      }
      return sortedMap;
    } else if (data is List) {
      return data.map(_sortJson).toList();
    }
    return data;
  }

  /// Sorts map for consistent cache keys
  Map<String, String> _sortMap(Map<String, String> map) {
    final sortedMap = <String, String>{};
    final keys = map.keys.toList()..sort();
    for (final key in keys) {
      sortedMap[key] = map[key]!;
    }
    return sortedMap;
  }

  /// Determines if a request should be retried based on the error and retry config
  bool _shouldRetry(FlintError error, int attempt, RetryConfig retryConfig) {
    // Check custom evaluator first
    if (retryConfig.retryEvaluator != null) {
      return retryConfig.retryEvaluator!(error, attempt);
    }

    // Check if we've exceeded max attempts
    if (attempt >= retryConfig.maxAttempts) {
      return false;
    }

    // Check status code retries
    if (error.statusCode != null &&
        retryConfig.retryStatusCodes.contains(error.statusCode)) {
      return true;
    }

    // Check exception type retries
    if (error.originalException != null) {
      for (final exceptionType in retryConfig.retryExceptions) {
        if (error.originalException.runtimeType == exceptionType) {
          return true;
        }
      }
    }

    // Check timeout retries
    if (retryConfig.retryOnTimeout &&
        error.message.toLowerCase().contains('timeout')) {
      return true;
    }

    return false;
  }

  /// Calculates delay for retry with exponential backoff and jitter
  Duration _calculateRetryDelay(int attempt, RetryConfig retryConfig) {
    // Exponential backoff: delay * 2^(attempt-1)
    final exponentialDelay =
        retryConfig.delay.inMilliseconds * pow(2, attempt - 1);

    // Add jitter (±25%) to avoid thundering herd problem
    final jitter = exponentialDelay * 0.25 * (Random().nextDouble() * 2 - 1);
    final delayWithJitter = exponentialDelay + jitter;

    // Cap at max delay
    final finalDelay = delayWithJitter.clamp(
      retryConfig.delay.inMilliseconds.toDouble(),
      retryConfig.maxDelay.inMilliseconds.toDouble(),
    );

    return Duration(milliseconds: finalDelay.round());
  }

  /// Sends the HTTP request using the specified [method] and [path].
  ///
  /// Handles JSON encoding, multipart files, interceptors, progress, caching, retries, and errors.
  Future<FlintResponse<T>> _request<T>(
    String method,
    String path, {
    dynamic body,
    Map<String, String>? headers,
    String? saveFilePath,
    Map<String, File>? files,
    ProgressCallback? onSendProgress,
    CacheConfig? cacheConfig,
    RetryConfig? retryConfig,
    JsonParser<T>? parser,
    ErrorHandler? onError,
    required StatusCodeConfig? statusConfig,
    RequestDoneCallback? onDone,
  }) async {
    _ensureNotDisposed();
    final effectiveStatusConfig = statusConfig ?? statusCodeConfig;

    final effectiveRetryConfig = retryConfig ?? defaultRetryConfig;
    int attempt = 1;

    while (true) {
      try {
        final response = await _executeRequest<T>(
          method,
          path,
          body: body,
          headers: headers,
          saveFilePath: saveFilePath,
          files: files,
          onSendProgress: onSendProgress,
          cacheConfig: cacheConfig,
          parser: parser,
          onError: onError,
          attempt: attempt,
          statusConfig: effectiveStatusConfig, // Pass to execute
        );
        onDone?.call(response, null);
        return response;
      } catch (e) {
        final error = e is FlintError
            ? e
            : FlintError.fromException(
                e,
                url: Uri.parse('$baseUrl$path'),
                method: method,
              );

        // Check if we should retry
        if (_shouldRetry(error, attempt, effectiveRetryConfig)) {
          final delay = _calculateRetryDelay(attempt, effectiveRetryConfig);
          _log(
            'Attempt $attempt failed: ${error.message}. Retrying in ${delay.inSeconds}s...',
          );

          await Future.delayed(delay);
          attempt++;
          continue;
        }

        // If we shouldn't retry or max attempts reached, handle the error
        final errorResponse = _handleError<T>(
          error,
          onError: onError,
          method: method,
          statusConfig: effectiveStatusConfig,
        );
        // Call onDone callback for error responses
        onDone?.call(errorResponse, error);
        return errorResponse;
      }
    }
  }

  /// Executes a single request attempt (without retry logic)
  Future<FlintResponse<T>> _executeRequest<T>(
    String method,
    String path, {
    dynamic body,
    Map<String, String>? headers,
    String? saveFilePath,
    Map<String, File>? files,
    ProgressCallback? onSendProgress,
    CacheConfig? cacheConfig,
    JsonParser<T>? parser,
    ErrorHandler? onError,
    int attempt = 1,
    StatusCodeConfig? statusConfig,
  }) async {
    final url = Uri.parse('$baseUrl$path');
    _log('$method $url (attempt $attempt)');

    final stopwatch = Stopwatch()..start();

    // Handle caching for GET requests
    final effectiveCacheConfig = cacheConfig ?? defaultCacheConfig;
    final shouldCache =
        effectiveCacheConfig.maxAge > Duration.zero &&
        (method.toUpperCase() == 'GET' || cacheConfig != null);

    String? cacheKey;
    if (shouldCache && !effectiveCacheConfig.forceRefresh) {
      cacheKey = _generateCacheKey(
        method,
        path,
        queryParameters: Uri.parse(path).queryParameters,
        body: body,
        headers: headers,
      );

      final cached = await cacheStore.get<T>(cacheKey);
      if (cached != null && cached.isValid) {
        _log(
          'Cache HIT: $cacheKey (freshness: ${(cached.freshnessRatio * 100).toStringAsFixed(1)}%)',
        );
        return cached.response;
      } else if (cached != null) {
        _log('Cache EXPIRED: $cacheKey');
      }
    }

    final request = await _createRequest(_client, method, url);

    // Merge headers
    final allHeaders = {...this.headers, ...headers ?? {}};
    allHeaders.forEach((k, v) => request.headers.set(k, v));

    // Request interceptor
    if (requestInterceptor != null) {
      try {
        await requestInterceptor!(request);
      } catch (e) {
        throw FlintError('Request interceptor error: ${e.toString()}');
      }
    }

    // Handle request body
    if (files != null && files.isNotEmpty) {
      await _handleMultipartRequest(request, body, files, onSendProgress);
    } else if (body != null) {
      await _handleJsonRequest(request, body, onSendProgress);
    }

    final response = await request.close();
    stopwatch.stop();

    // Response interceptor
    if (responseInterceptor != null) {
      try {
        await responseInterceptor!(response);
      } catch (e) {
        throw FlintError('Response interceptor error: ${e.toString()}');
      }
    }

    _log('Response: ${response.statusCode} ${response.reasonPhrase}');
    final flintResponse = await _handleResponse<T>(
      response,
      saveFilePath,
      parser,
      url: url,
      method: method,
      duration: stopwatch.elapsed,
    );

    // Cache successful responses
    if (shouldCache &&
        cacheKey != null &&
        flintResponse.statusCode >= 200 &&
        flintResponse.statusCode < 300) {
      try {
        final cachedResponse = CachedResponse<T>(
          response: flintResponse,
          key: cacheKey,
          maxAge: effectiveCacheConfig.maxAge,
        );
        await cacheStore.set<T>(cacheKey, cachedResponse);
        _log(
          'Cached response: $cacheKey (maxAge: ${effectiveCacheConfig.maxAge})',
        );
      } catch (e) {
        _log('Failed to cache response: $e');
      }
    }

    return flintResponse;
  }

  Future<HttpClientRequest> _createRequest(
    HttpClient client,
    String method,
    Uri url,
  ) async {
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
    ProgressCallback? onSendProgress,
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

      // Helper functions
      String buildField(String name, String value) =>
          '--$boundary\r\nContent-Disposition: form-data; name="$name"\r\n\r\n$value\r\n';

      String buildFileHeader(String name, String fileName, int length) =>
          '--$boundary\r\nContent-Disposition: form-data; name="$name"; filename="$fileName"\r\nContent-Type: application/octet-stream\r\nContent-Length: $length\r\n\r\n';

      // Write form fields
      if (body != null && body is Map<String, dynamic>) {
        body.forEach((key, value) {
          final fieldData = buildField(key, value.toString());
          request.write(fieldData);
          updateProgress(utf8.encode(fieldData).length);
        });
      }

      // Write files
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
        updateProgress(2); // \r\n bytes
      }

      // Final boundary
      final endBoundary = '--$boundary--\r\n';
      request.write(endBoundary);
      updateProgress(utf8.encode(endBoundary).length);
    } catch (e) {
      throw FlintError('Multipart request failed: ${e.toString()}');
    }
  }

  Future<void> _handleJsonRequest(
    HttpClientRequest request,
    dynamic body,
    ProgressCallback? onSendProgress,
  ) async {
    try {
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      final jsonData = jsonEncode(body);
      final dataBytes = utf8.encode(jsonData);

      if (onSendProgress != null) {
        // Write in chunks for progress tracking
        const chunkSize = 1024;
        for (int i = 0; i < dataBytes.length; i += chunkSize) {
          final end = i + chunkSize < dataBytes.length
              ? i + chunkSize
              : dataBytes.length;
          request.add(dataBytes.sublist(i, end));
          onSendProgress(end, dataBytes.length);
          await Future.delayed(Duration.zero);
        }
      } else {
        request.write(jsonData);
      }
    } catch (e) {
      throw FlintError('JSON request failed: ${e.toString()}');
    }
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
        size += 2; // \r\n
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

  Future<FlintResponse<T>> _handleResponse<T>(
    HttpClientResponse response,
    String? saveFilePath,
    JsonParser<T>? parser, {
    Uri? url,
    String? method,
    Duration? duration,
    StatusCodeConfig? statusConfig,
  }) async {
    try {
      final effectiveStatusConfig = statusConfig ?? statusCodeConfig;

      final contentType = response.headers.contentType?.mimeType ?? '';
      final bytes = await _readAllBytes(response);

      // Handle error status codes
      // Only throw error if status is configured as error
      if (effectiveStatusConfig.isError(response.statusCode)) {
        final errorMessage = utf8.decode(bytes, allowMalformed: true);
        throw FlintError(
          'HTTP ${response.statusCode}: $errorMessage',
          statusCode: response.statusCode,
          url: url,
          method: method,
        );
      }

      // Determine response type and handle accordingly
      if (contentType.contains('application/json')) {
        return await _handleJsonResponse<T>(
          response,
          bytes,
          parser,
          url: url,
          method: method,
          duration: duration,
          statusConfig: effectiveStatusConfig,
        );
      } else if (contentType.contains('text') || contentType.contains('html')) {
        return await _handleTextResponse<T>(
          response,
          bytes,
          parser,
          url: url,
          method: method,
          duration: duration,
          statusConfig: effectiveStatusConfig,
        );
      } else {
        return await _handleBinaryResponse<T>(
          response,
          bytes,
          saveFilePath,
          parser,
          url: url,
          method: method,
          duration: duration,
          statusConfig: effectiveStatusConfig,
        );
      }
    } catch (e) {
      if (e is FlintError) rethrow;
      throw FlintError('Response handling failed: ${e.toString()}');
    }
  }

  Future<FlintResponse<T>> _handleJsonResponse<T>(
    HttpClientResponse response,
    List<int> bytes,
    JsonParser<T>? parser, {
    Uri? url,
    String? method,
    Duration? duration,
    StatusCodeConfig? statusConfig,
  }) async {
    final effectiveStatusConfig = statusConfig ?? statusCodeConfig;

    try {
      dynamic data;

      try {
        data = jsonDecode(utf8.decode(bytes));
      } catch (e) {
        // If JSON decoding fails, fallback to string
        data = utf8.decode(bytes);
      }

      // Apply parser if provided
      if (parser != null) {
        try {
          data = parser(data);
        } catch (e) {
          throw FlintError('JSON parsing failed: ${e.toString()}');
        }
      } else {
        data = _defaultParser<T>(data, FlintResponseType.json);
      }

      return FlintResponse<T>(
        statusCode: response.statusCode,
        data: data as T,
        type: FlintResponseType.json,
        headers: response.headers,
        url: url,
        method: method,
        duration: duration,
        statusConfig: effectiveStatusConfig,
      );
    } catch (e) {
      if (e is FlintError) rethrow;
      throw FlintError(
        'JSON response handling failed: ${e.toString()}',
        method: method,
        url: url,
        statusCode: response.statusCode,
      );
    }
  }

  // Similarly update _handleTextResponse and _handleBinaryResponse with url, method, duration parameters

  Future<FlintResponse<T>> _handleTextResponse<T>(
    HttpClientResponse response,
    List<int> bytes,
    JsonParser<T>? parser, {
    Uri? url,
    String? method,
    Duration? duration,
    StatusCodeConfig? statusConfig,
  }) async {
    final effectiveStatusConfig = statusConfig ?? statusCodeConfig;

    try {
      final textData = utf8.decode(bytes);
      T data;

      if (parser != null) {
        try {
          data = parser(textData);
        } catch (e) {
          data = _defaultParser<T>(textData, FlintResponseType.text);
        }
      } else {
        data = _defaultParser<T>(textData, FlintResponseType.text);
      }

      return FlintResponse<T>(
        statusCode: response.statusCode,
        data: data,
        type: FlintResponseType.text,
        headers: response.headers,
        statusConfig: effectiveStatusConfig,
      );
    } catch (e) {
      if (e is FlintError) rethrow;
      throw FlintError(
        'Text response handling failed: ${e.toString()}',
        method: method,
        url: url,
        statusCode: response.statusCode,
      );
    }
  }

  Future<FlintResponse<T>> _handleBinaryResponse<T>(
    HttpClientResponse response,
    List<int> bytes,
    String? saveFilePath,
    JsonParser<T>? parser, {
    Uri? url,
    String? method,
    Duration? duration,
    StatusCodeConfig? statusConfig,
  }) async {
    final effectiveStatusConfig = statusConfig ?? statusCodeConfig;

    try {
      final fileName =
          saveFilePath ?? _extractFileName(response, Uri.parse('$baseUrl'));
      final file = File(fileName);

      // Ensure directory exists
      final directory = file.parent;
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      await file.writeAsBytes(bytes);

      T data;
      if (parser != null) {
        try {
          data = parser(file);
        } catch (e) {
          data = _defaultParser<T>(file, FlintResponseType.file);
        }
      } else {
        data = _defaultParser<T>(file, FlintResponseType.file);
      }

      return FlintResponse<T>(
        statusCode: response.statusCode,
        data: data,
        type: FlintResponseType.file,
        headers: response.headers,
        statusConfig: effectiveStatusConfig,
      );
    } catch (e) {
      if (e is FlintError) rethrow;
      throw FlintError(
        'Binary response handling failed: ${e.toString()}',
        method: method,
        url: url,
        statusCode: response.statusCode,
      );
    }
  }

  /// Smart default parser that handles common cases
  T _defaultParser<T>(dynamic data, FlintResponseType responseType) {
    try {
      // If T is dynamic or matches the raw data type, return as-is
      if (T == dynamic || data is T) {
        return data as T;
      }

      // Special handling for Map<String, dynamic> which is commonly used in tests
      if (T == Map<String, dynamic>) {
        if (data is Map) {
          // Convert any Map to Map<String, dynamic>
          final result = <String, dynamic>{};
          for (final key in data.keys) {
            result[key.toString()] = data[key];
          }
          return result as T;
        }
        if (data is String) {
          try {
            final decoded = jsonDecode(data);
            if (decoded is Map) {
              final result = <String, dynamic>{};
              for (final key in decoded.keys) {
                result[key.toString()] = decoded[key];
              }
              return result as T;
            }
          } catch (e) {
            // If JSON decoding fails, wrap in a map
            return {'data': data} as T;
          }
        }
        // Return empty map as fallback
        return <String, dynamic>{} as T;
      }

      // Handle common type conversions
      switch (T) {
        case const (String):
          return data.toString() as T;
        case const (int):
          if (data is String) {
            return int.tryParse(data) as T? ?? 0 as T;
          }
          return (data is num ? data.toInt() : 0) as T;
        case const (double):
          if (data is String) {
            return double.tryParse(data) as T? ?? 0.0 as T;
          }
          return (data is num ? data.toDouble() : 0.0) as T;
        case const (bool):
          if (data is String) {
            return (data.toLowerCase() == 'true') as T;
          }
          return (data is bool ? data : false) as T;
        case const (Map):
          if (data is String && responseType == FlintResponseType.json) {
            try {
              return jsonDecode(data) as T;
            } catch (e) {
              return {data: data} as T;
            }
          }
          return (data is Map ? data : {}) as T;
        case const (List):
          if (data is String && responseType == FlintResponseType.json) {
            try {
              return jsonDecode(data) as T;
            } catch (e) {
              return [data] as T;
            }
          }
          return (data is List ? data : [data]) as T;
        default:
          // For other types, try direct cast or return data as-is
          try {
            return data as T;
          } catch (e) {
            // If all else fails, return the data and let the caller handle it
            return data as T;
          }
      }
    } catch (e) {
      if (e is FlintError) rethrow;
      // Don't throw an error here - return data as-is and let the parser handle it
      return data as T;
    }
  }

  String _extractFileName(HttpClientResponse response, Uri url) {
    try {
      final contentDisposition = response.headers.value('content-disposition');
      if (contentDisposition != null) {
        final match = RegExp(
          'filename="([^"]+)"',
        ).firstMatch(contentDisposition);
        if (match != null) return match.group(1)!;
      }

      return url.pathSegments.isNotEmpty
          ? url.pathSegments.last
          : 'download_${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      return 'download_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// Logs, handles, or throws errors internally and triggers the
  /// optional [onError] callback.
  /// Logs, handles, or throws errors internally and triggers the
  /// optional [onError] callback.
  FlintResponse<T> _handleError<T>(
    FlintError error, {
    ErrorHandler? onError,
    String? method,
    Duration? duration,
    StatusCodeConfig? statusConfig,
  }) {
    final effectiveStatusConfig = statusConfig ?? statusCodeConfig;

    _log('Error: ${error.message}');

    // Priority: per-request error handler > global error handler
    if (onError != null) {
      onError(error);
    } else if (this.onError != null) {
      this.onError!(error);
    }

    return FlintResponse.error(
      error,
      method: method,
      duration: duration,
      statusConfig: effectiveStatusConfig,
    );
  }

  Future<List<int>> _readAllBytes(HttpClientResponse response) async {
    try {
      final List<int> bytes = [];
      final contentLength = response.contentLength;
      int received = 0;

      await for (var chunk in response) {
        bytes.addAll(chunk);
        received += chunk.length;

        if (contentLength != -1) {
          final progress = (received / contentLength * 100).round();
          _log('Download progress: $progress%');
        }
      }
      return bytes;
    } catch (e) {
      throw FlintError('Failed to read response bytes: ${e.toString()}');
    }
  }

  // Cache Management Methods

  /// Clears all cached responses
  Future<void> clearCache() async {
    await cacheStore.clear();
    _log('Cache cleared');
  }

  /// Removes a specific cached response
  Future<void> removeCachedResponse(String key) async {
    await cacheStore.delete(key);
    _log('Removed cached response: $key');
  }

  /// Cleans up expired cache entries
  Future<void> cleanupExpiredCache() async {
    await cacheStore.cleanup(clock.now());
    _log('Expired cache entries cleaned up');
  }

  /// Gets the current cache size
  Future<int> get cacheSize async => await cacheStore.size();

  /// Preloads responses into cache
  Future<void> preloadCache(
    Map<String, FlintResponse<dynamic>> responses,
  ) async {
    for (final entry in responses.entries) {
      final cachedResponse = CachedResponse(
        response: entry.value,
        key: entry.key,
        maxAge: defaultCacheConfig.maxAge,
      );
      await cacheStore.set(entry.key, cachedResponse);
    }
    _log('Preloaded ${responses.length} responses into cache');
  }

  /// Downloads a file from [url] and saves it to [savePath] while
  /// optionally reporting [onProgress].
  Future<File> downloadFile(
    String url, {
    required String savePath,
    ProgressCallback? onProgress,
    RetryConfig? retryConfig,
    ErrorHandler? onError,
    StatusCodeConfig? statusConfig,
  }) async {
    final effectiveStatusConfig = statusConfig ?? statusCodeConfig;

    final effectiveRetryConfig = retryConfig ?? defaultRetryConfig;
    int attempt = 1;

    while (true) {
      try {
        final request = await HttpClient().getUrl(Uri.parse(url));
        final response = await request.close();

        if (response.statusCode != 200) {
          throw FlintError('Download failed: ${response.statusCode}');
        }

        final file = File(savePath);
        final IOSink sink = file.openWrite();
        final contentLength = response.contentLength;
        int received = 0;

        try {
          await for (var chunk in response) {
            sink.add(chunk);
            received += chunk.length;

            if (contentLength != -1 && onProgress != null) {
              onProgress(received, contentLength);
            }
          }
          await sink.close();
          return file;
        } catch (e) {
          await sink.close();
          await file.delete();
          throw FlintError('Download failed: ${e.toString()}');
        }
      } catch (e) {
        final error = e is FlintError
            ? e
            : FlintError('Download failed: ${e.toString()}');

        // Check if we should retry
        if (_shouldRetry(error, attempt, effectiveRetryConfig)) {
          final delay = _calculateRetryDelay(attempt, effectiveRetryConfig);
          _log(
            'Download attempt $attempt failed: ${error.message}. Retrying in ${delay.inSeconds}s...',
          );

          await Future.delayed(delay);
          attempt++;
          continue;
        }

        // If we shouldn't retry or max attempts reached, handle the error
        _handleError<dynamic>(
          error,
          onError: onError,
          statusConfig: effectiveStatusConfig,
        );
        throw error;
      }
    }
  }
}
