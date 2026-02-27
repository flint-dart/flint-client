import 'dart:async';
import 'dart:io';
import 'components/cache_layer.dart';
import 'components/flint_logger.dart';
import 'components/request_executor.dart';
import 'components/response_handler.dart';
import 'components/retry_policy.dart';
import 'package:flint_client/src/flint_web_socket_client.dart';
import 'package:flint_client/src/request/body_serializer.dart';
import 'package:flint_client/src/request/cancel_token.dart';
import 'package:flint_client/src/request/request_context.dart';
import 'package:flint_client/src/request/request_lifecycle_hooks.dart';
import 'package:flint_client/src/request/request_options.dart';
import 'package:flint_client/src/response/parse_mode.dart';
import 'package:flint_client/src/response/response_serializer.dart';
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
typedef ContextualRequestInterceptor =
    Future<void> Function(HttpClientRequest request, RequestContext context);

/// Intercepts HTTP responses after they are received.
typedef ResponseInterceptor =
    Future<void> Function(HttpClientResponse response);
typedef ContextualResponseInterceptor =
    Future<void> Function(HttpClientResponse response, RequestContext context);

/// Parses JSON responses into a strongly-typed object [T].
typedef JsonParser<T> = T Function(dynamic json);
typedef RequestDoneCallback<T> =
    void Function(FlintResponse<T> response, FlintError? error);
typedef HookErrorHandler =
    void Function(
      String hookName,
      Object error,
      StackTrace stackTrace,
      RequestContext context,
    );

/// A powerful HTTP client for making requests to REST APIs with
/// support for JSON, file uploads/downloads, progress tracking, caching, and retries.
class FlintClient {
  /// Base URL for all HTTP requests.
  final String? baseUrl;

  /// Default headers to include with every request.
  final Map<String, String> headers;
  final Map<String, dynamic> defaultQueryParameters;

  /// Timeout duration for requests.
  final Duration timeout;

  /// Optional error handler callback.
  final ErrorHandler? onError;

  /// Optional interceptor called before each request is sent.
  final RequestInterceptor? requestInterceptor;
  final ContextualRequestInterceptor? contextualRequestInterceptor;

  /// Optional interceptor called after each response is received.
  final ResponseInterceptor? responseInterceptor;
  final ContextualResponseInterceptor? contextualResponseInterceptor;
  final RequestLifecycleHooks lifecycleHooks;
  final bool ignoreHookErrors;
  final HookErrorHandler? onHookError;

  /// Cache store for responses
  final CacheStore cacheStore;

  /// Default cache configuration
  final CacheConfig defaultCacheConfig;

  /// Default retry configuration - CHANGED: No retry by default
  final RetryConfig defaultRetryConfig;

  /// Enables debug logging if true.
  final bool debug;

  /// Internal, long-lived [HttpClient] instance.
  final HttpClient _client;

  final StatusCodeConfig statusCodeConfig;
  final List<BodySerializer> bodySerializers;
  final List<ResponseSerializer> responseSerializers;
  final ResponseParseMode defaultParseMode;
  final Set<String> redactedHeaders;
  late final FlintLogger _logger;
  late final RetryPolicy _retryPolicy;
  late final CacheLayer _cacheLayer;
  late final ResponseHandler _responseHandler;
  late final RequestExecutor _requestExecutor;

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
  /// [defaultRetryConfig] sets default retry behavior - CHANGED: No retry by default.
  /// [debug] enables console logging.
  bool _isDisposed = false;
  final RequestDoneCallback? onDone;

  FlintClient({
    this.baseUrl,
    this.headers = const {},
    this.defaultQueryParameters = const {},
    this.timeout = const Duration(seconds: 30),
    this.onError,
    this.onDone,
    this.requestInterceptor,
    this.responseInterceptor,
    this.contextualRequestInterceptor,
    this.contextualResponseInterceptor,
    this.lifecycleHooks = const RequestLifecycleHooks(),
    this.ignoreHookErrors = true,
    this.onHookError,
    CacheStore? cacheStore,
    CacheConfig? defaultCacheConfig,
    RetryConfig? defaultRetryConfig,
    List<BodySerializer>? bodySerializers,
    List<ResponseSerializer>? responseSerializers,
    this.defaultParseMode = ResponseParseMode.lenient,
    Set<String>? redactedHeaders,
    this.debug = false,
    this.statusCodeConfig = const StatusCodeConfig(),
  }) : cacheStore = cacheStore ?? MemoryCacheStore(),
       defaultCacheConfig = defaultCacheConfig ?? const CacheConfig(),
       // CHANGED: Default to no retries unless explicitly configured
       defaultRetryConfig = defaultRetryConfig ?? RetryConfig.noRetry,
       bodySerializers =
           bodySerializers ??
           const [
             FormUrlEncodedBodySerializer(),
             XmlBodySerializer(),
             JsonBodySerializer(),
           ],
       responseSerializers =
           responseSerializers ??
           const [
             JsonResponseSerializer(),
             TextResponseSerializer(),
             BinaryResponseSerializer(),
           ],
       redactedHeaders =
           redactedHeaders ??
           const {
             'authorization',
             'cookie',
             'set-cookie',
             'x-api-key',
             'proxy-authorization',
           },
       _client = HttpClient()
         ..connectionTimeout = timeout
         ..idleTimeout = timeout {
    _logger = FlintLogger(debug: debug, redactedHeaders: this.redactedHeaders);
    _retryPolicy = const RetryPolicy();
    _cacheLayer = CacheLayer(
      cacheStore: this.cacheStore,
      defaultCacheConfig: this.defaultCacheConfig,
      log: _logger.log,
    );
    _responseHandler = ResponseHandler(
      statusCodeConfig: statusCodeConfig,
      baseUrl: baseUrl,
      log: _logger.log,
      serializers: this.responseSerializers,
    );
    _requestExecutor = RequestExecutor(
      client: _client,
      timeout: timeout,
      bodySerializers: this.bodySerializers,
      logger: _logger,
      requestInterceptor: requestInterceptor,
      responseInterceptor: responseInterceptor,
      requestInterceptorWithContext: contextualRequestInterceptor,
      responseInterceptorWithContext: contextualResponseInterceptor,
      responseHandler: _responseHandler,
    );
  }

  /// Creates a copy of this client with optional overrides.
  FlintClient copyWith({
    String? baseUrl,
    Map<String, String>? headers,
    Map<String, dynamic>? defaultQueryParameters,
    Duration? timeout,
    ErrorHandler? onError,
    RequestInterceptor? requestInterceptor,
    ResponseInterceptor? responseInterceptor,
    ContextualRequestInterceptor? contextualRequestInterceptor,
    ContextualResponseInterceptor? contextualResponseInterceptor,
    bool? ignoreHookErrors,
    HookErrorHandler? onHookError,
    CacheStore? cacheStore,
    CacheConfig? defaultCacheConfig,
    RequestDoneCallback? onDone,
    RetryConfig? defaultRetryConfig,
    List<BodySerializer>? bodySerializers,
    List<ResponseSerializer>? responseSerializers,
    ResponseParseMode? defaultParseMode,
    Set<String>? redactedHeaders,
    bool? debug,
    StatusCodeConfig? statusCodeConfig,
    RequestLifecycleHooks? lifecycleHooks,
  }) {
    return FlintClient(
      baseUrl: baseUrl ?? this.baseUrl,
      headers: headers ?? this.headers,
      defaultQueryParameters:
          defaultQueryParameters ?? this.defaultQueryParameters,
      timeout: timeout ?? this.timeout,
      onError: onError ?? this.onError,
      onDone: onDone ?? this.onDone,
      requestInterceptor: requestInterceptor ?? this.requestInterceptor,
      responseInterceptor: responseInterceptor ?? this.responseInterceptor,
      contextualRequestInterceptor:
          contextualRequestInterceptor ?? this.contextualRequestInterceptor,
      contextualResponseInterceptor:
          contextualResponseInterceptor ?? this.contextualResponseInterceptor,
      ignoreHookErrors: ignoreHookErrors ?? this.ignoreHookErrors,
      onHookError: onHookError ?? this.onHookError,
      cacheStore: cacheStore ?? this.cacheStore,
      defaultCacheConfig: defaultCacheConfig ?? this.defaultCacheConfig,
      defaultRetryConfig: defaultRetryConfig ?? this.defaultRetryConfig,
      bodySerializers: bodySerializers ?? this.bodySerializers,
      responseSerializers: responseSerializers ?? this.responseSerializers,
      defaultParseMode: defaultParseMode ?? this.defaultParseMode,
      redactedHeaders: redactedHeaders ?? this.redactedHeaders,
      debug: debug ?? this.debug,
      statusCodeConfig: statusCodeConfig ?? this.statusCodeConfig,
      lifecycleHooks: lifecycleHooks ?? this.lifecycleHooks,
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
    _logger.log(message);
  }

  // WebSocket client method
  FlintWebSocketClient ws(
    String path, {
    Map<String, dynamic>? params,
    Map<String, String>? headers,
  }) {
    _ensureBaseUrl();

    final wsUrl =
        baseUrl!.replaceFirst(RegExp(r'^http'), 'ws') + _normalizePath(path);

    final mergedHeaders = <String, String>{...this.headers, ...headers ?? {}};

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

  String _normalizePath(String path) {
    if (path.startsWith('/')) return path;
    return '/$path';
  }

  /// Sends a GET request to [path] with optional query parameters, headers,
  /// file save path, cache configuration, retry configuration, and a custom JSON parser.
  Future<FlintResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    String? saveFilePath,
    CacheConfig? cacheConfig,
    StatusCodeConfig? statusConfig,
    RetryConfig? retryConfig, // Only retry if explicitly provided
    JsonParser<T>? parser,
    ErrorHandler? onError,
    RequestDoneCallback<T>? onDone,
    CancelToken? cancelToken,
    Duration? requestTimeout,
    ResponseParseMode? parseMode,
  }) {
    return request<T>(
      'GET',
      path,
      options: RequestOptions<T>(
        queryParameters: queryParameters,
        headers: headers,
        saveFilePath: saveFilePath,
        cacheConfig: cacheConfig,
        statusConfig: statusConfig,
        retryConfig: retryConfig,
        parser: parser,
        onError: onError,
        onDone: onDone ?? this.onDone,
        cancelToken: cancelToken,
        timeout: requestTimeout,
        parseMode: parseMode,
      ),
    );
  }

  /// Sends a POST request to [path] with optional body, files, headers,
  /// query parameters, progress callback, cache config, retry config, and a custom JSON parser.
  Future<FlintResponse<T>> post<T>(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    String? saveFilePath,
    Map<String, File>? files,
    ProgressCallback? onSendProgress,
    StatusCodeConfig? statusConfig,
    CacheConfig? cacheConfig,
    RetryConfig? retryConfig, // Only retry if explicitly provided
    JsonParser<T>? parser,
    ErrorHandler? onError,
    RequestDoneCallback<T>? onDone,
    CancelToken? cancelToken,
    Duration? requestTimeout,
    ResponseParseMode? parseMode,
  }) {
    return request<T>(
      'POST',
      path,
      options: RequestOptions<T>(
        body: body,
        queryParameters: queryParameters,
        headers: headers,
        saveFilePath: saveFilePath,
        files: files,
        onSendProgress: onSendProgress,
        statusConfig: statusConfig,
        cacheConfig: cacheConfig,
        retryConfig: retryConfig,
        parser: parser,
        onError: onError,
        onDone: onDone ?? this.onDone,
        cancelToken: cancelToken,
        timeout: requestTimeout,
        parseMode: parseMode,
      ),
    );
  }

  /// Sends a PUT request to [path] (similar to POST).
  Future<FlintResponse<T>> put<T>(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    String? saveFilePath,
    Map<String, File>? files,
    ProgressCallback? onSendProgress,
    StatusCodeConfig? statusConfig,
    CacheConfig? cacheConfig,
    RetryConfig? retryConfig, // Only retry if explicitly provided
    JsonParser<T>? parser,
    ErrorHandler? onError,
    RequestDoneCallback<T>? onDone,
    CancelToken? cancelToken,
    Duration? requestTimeout,
    ResponseParseMode? parseMode,
  }) {
    return request<T>(
      'PUT',
      path,
      options: RequestOptions<T>(
        body: body,
        queryParameters: queryParameters,
        headers: headers,
        saveFilePath: saveFilePath,
        files: files,
        onSendProgress: onSendProgress,
        statusConfig: statusConfig,
        cacheConfig: cacheConfig,
        retryConfig: retryConfig,
        parser: parser,
        onError: onError,
        onDone: onDone ?? this.onDone,
        cancelToken: cancelToken,
        timeout: requestTimeout,
        parseMode: parseMode,
      ),
    );
  }

  /// Sends a PATCH request to [path] (similar to PUT).
  Future<FlintResponse<T>> patch<T>(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    String? saveFilePath,
    Map<String, File>? files,
    ProgressCallback? onSendProgress,
    CacheConfig? cacheConfig,
    RetryConfig? retryConfig, // Only retry if explicitly provided
    JsonParser<T>? parser,
    StatusCodeConfig? statusConfig,
    ErrorHandler? onError,
    RequestDoneCallback<T>? onDone,
    CancelToken? cancelToken,
    Duration? requestTimeout,
    ResponseParseMode? parseMode,
  }) {
    return request<T>(
      'PATCH',
      path,
      options: RequestOptions<T>(
        body: body,
        queryParameters: queryParameters,
        headers: headers,
        saveFilePath: saveFilePath,
        files: files,
        onSendProgress: onSendProgress,
        cacheConfig: cacheConfig,
        retryConfig: retryConfig,
        statusConfig: statusConfig,
        parser: parser,
        onError: onError,
        onDone: onDone ?? this.onDone,
        cancelToken: cancelToken,
        timeout: requestTimeout,
        parseMode: parseMode,
      ),
    );
  }

  FlintClient withQuery(Map<String, dynamic> query) {
    return copyWith(
      defaultQueryParameters: {...defaultQueryParameters, ...query},
    );
  }

  /// Sends a DELETE request to [path] with optional query parameters,
  /// headers, save file path, cache config, retry config, and custom JSON parser.
  Future<FlintResponse<T>> delete<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    String? saveFilePath,
    CacheConfig? cacheConfig,
    StatusCodeConfig? statusConfig,
    RetryConfig? retryConfig, // Only retry if explicitly provided
    JsonParser<T>? parser,
    ErrorHandler? onError,
    RequestDoneCallback<T>? onDone,
    CancelToken? cancelToken,
    Duration? requestTimeout,
    ResponseParseMode? parseMode,
  }) {
    return request<T>(
      'DELETE',
      path,
      options: RequestOptions<T>(
        queryParameters: queryParameters,
        headers: headers,
        saveFilePath: saveFilePath,
        cacheConfig: cacheConfig,
        retryConfig: retryConfig,
        statusConfig: statusConfig,
        parser: parser,
        onError: onError,
        onDone: onDone ?? this.onDone,
        cancelToken: cancelToken,
        timeout: requestTimeout,
        parseMode: parseMode,
      ),
    );
  }

  /// Generic request entrypoint with a modular [RequestOptions] object.
  Future<FlintResponse<T>> request<T>(
    String method,
    String path, {
    RequestOptions<T>? options,
  }) {
    _ensureBaseUrl();
    final opts = options ?? RequestOptions<T>();

    final mergedQuery = {...defaultQueryParameters, ...?opts.queryParameters};
    if (mergedQuery.isNotEmpty) {
      path = _buildPathWithQuery(path, mergedQuery);
    }

    final RequestDoneCallback<T>? effectiveOnDone =
        opts.onDone ??
        (onDone != null ? (response, error) => onDone!(response, error) : null);

    return _request<T>(
      method,
      path,
      body: opts.body,
      headers: opts.headers,
      saveFilePath: opts.saveFilePath,
      files: opts.files,
      onSendProgress: opts.onSendProgress,
      cacheConfig: opts.cacheConfig,
      retryConfig: opts.retryConfig,
      parser: opts.parser,
      onError: opts.onError,
      onDone: effectiveOnDone,
      statusConfig: opts.statusConfig,
      cancelToken: opts.cancelToken,
      requestTimeout: opts.timeout,
      context: opts.context,
      parseMode: opts.parseMode ?? defaultParseMode,
    );
  }

  /// Builds a full path with query parameters appended.
  String _buildPathWithQuery(
    String path,
    Map<String, dynamic> queryParameters,
  ) {
    final uri = Uri.parse(path);
    final normalized = <String, dynamic>{};
    queryParameters.forEach((key, value) {
      if (value == null) return;
      if (value is Iterable) {
        normalized[key] = value.map((v) => v.toString()).toList();
      } else {
        normalized[key] = value.toString();
      }
    });
    final newUri = uri.replace(
      queryParameters: {...uri.queryParameters, ...normalized},
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

  //// Determines if a request should be retried based on the error and retry config
  bool _shouldRetry(
    FlintError error,
    int attempt,
    RetryConfig retryConfig, {
    required String method,
    RequestContext? context,
  }) {
    return _retryPolicy.shouldRetry(
      error,
      attempt,
      retryConfig,
      method: method,
      context: context,
    );
  }

  /// Calculates delay for retry with exponential backoff and jitter
  Duration _calculateRetryDelay(
    int attempt,
    RetryConfig retryConfig, {
    FlintError? error,
  }) {
    return _retryPolicy.calculateDelay(attempt, retryConfig, error: error);
  }

  Future<void> _runHook(
    String hookName,
    RequestContext context,
    FutureOr<void> Function() hook,
  ) async {
    try {
      await hook();
    } catch (e, st) {
      onHookError?.call(hookName, e, st, context);
      if (!ignoreHookErrors) {
        rethrow;
      }
      _log('Lifecycle hook "$hookName" failed: $e');
    }
  }

  bool _canRetryWithinBudget(RetryConfig retryConfig, Duration elapsed) {
    final budget = retryConfig.maxRetryTime;
    if (budget == null) {
      return true;
    }
    return elapsed < budget;
  }

  Future<void> _waitForRetryDelay(
    Duration delay, {
    CancelToken? cancelToken,
    required String method,
    required Uri url,
  }) async {
    if (cancelToken == null) {
      await Future.delayed(delay);
      return;
    }

    if (cancelToken.isCancelled) {
      throw FlintError.cancelled(
        message: 'Request cancelled: ${cancelToken.reason ?? 'no reason'}',
        method: method,
        url: url,
      );
    }

    final delayFuture = Future<void>.delayed(delay);
    final cancelFuture = cancelToken.whenCancelled.then((reason) {
      throw FlintError.cancelled(
        message: 'Request cancelled: ${reason ?? 'no reason'}',
        method: method,
        url: url,
      );
    });

    await Future.any<void>([delayFuture, cancelFuture]);
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
    RequestDoneCallback<T>? onDone,
    CancelToken? cancelToken,
    Duration? requestTimeout,
    RequestContext? context,
    ResponseParseMode? parseMode,
  }) async {
    _ensureNotDisposed();
    final effectiveStatusConfig = statusConfig ?? statusCodeConfig;
    final requestUrl = Uri.parse('$baseUrl$path');
    final requestContext =
        context ??
        RequestContext(method: method.toUpperCase(), url: requestUrl);
    final requestStopwatch = Stopwatch()..start();
    requestContext.startedAt = DateTime.now();
    if (lifecycleHooks.onRequestStart != null) {
      await _runHook(
        'onRequestStart',
        requestContext,
        () => lifecycleHooks.onRequestStart!.call(requestContext),
      );
    }

    // CHANGED: Use provided retryConfig or default (which is no-retry)
    final effectiveRetryConfig = retryConfig ?? defaultRetryConfig;
    int attempt = 1;
    FlintResponse<T>? finalResponse;
    FlintError? finalError;

    try {
      while (true) {
        requestContext.attempt = attempt;
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
            statusConfig: effectiveStatusConfig,
            cancelToken: cancelToken,
            requestTimeout: requestTimeout,
            context: requestContext,
            parseMode: parseMode ?? defaultParseMode,
          );
          finalResponse = response;
          onDone?.call(response, null);
          return response;
        } catch (e) {
          final error = e is FlintError
              ? e
              : FlintError.fromException(e, url: requestUrl, method: method);

          // CHANGED: Only retry if explicitly configured to do so
          if (_shouldRetry(
            error,
            attempt,
            effectiveRetryConfig,
            method: method,
            context: requestContext,
          )) {
            final withinBudget = _canRetryWithinBudget(
              effectiveRetryConfig,
              requestStopwatch.elapsed,
            );
            if (!withinBudget) {
              final budgetError = error.copyWith(
                message:
                    'Retry budget exceeded after ${requestStopwatch.elapsed.inMilliseconds}ms: ${error.message}',
              );
              if (lifecycleHooks.onError != null) {
                await _runHook(
                  'onError',
                  requestContext,
                  () => lifecycleHooks.onError!.call(
                    requestContext,
                    budgetError,
                    false,
                  ),
                );
              }
              final errorResponse = _handleError<T>(
                budgetError,
                onError: onError,
                method: method,
                statusConfig: effectiveStatusConfig,
              );
              finalResponse = errorResponse;
              finalError = budgetError;
              onDone?.call(errorResponse, budgetError);
              return errorResponse;
            }

            final delay = _calculateRetryDelay(
              attempt,
              effectiveRetryConfig,
              error: error,
            );
            _log(
              'Attempt $attempt failed: ${error.message}. Retrying in ${delay.inSeconds}s...',
            );
            if (lifecycleHooks.onError != null) {
              await _runHook(
                'onError',
                requestContext,
                () => lifecycleHooks.onError!.call(requestContext, error, true),
              );
            }
            if (lifecycleHooks.onRetry != null) {
              await _runHook(
                'onRetry',
                requestContext,
                () =>
                    lifecycleHooks.onRetry!.call(requestContext, error, delay),
              );
            }
            try {
              await _waitForRetryDelay(
                delay,
                cancelToken: cancelToken,
                method: method,
                url: requestUrl,
              );
            } catch (waitError) {
              final retryWaitError = waitError is FlintError
                  ? waitError
                  : FlintError.fromException(
                      waitError,
                      url: requestUrl,
                      method: method,
                    );
              if (lifecycleHooks.onError != null) {
                await _runHook(
                  'onError',
                  requestContext,
                  () => lifecycleHooks.onError!.call(
                    requestContext,
                    retryWaitError,
                    false,
                  ),
                );
              }
              final errorResponse = _handleError<T>(
                retryWaitError,
                onError: onError,
                method: method,
                statusConfig: effectiveStatusConfig,
              );
              finalResponse = errorResponse;
              finalError = retryWaitError;
              onDone?.call(errorResponse, retryWaitError);
              return errorResponse;
            }
            attempt++;
            continue;
          }

          if (lifecycleHooks.onError != null) {
            await _runHook(
              'onError',
              requestContext,
              () => lifecycleHooks.onError!.call(requestContext, error, false),
            );
          }
          // If we shouldn't retry or max attempts reached, handle the error
          final errorResponse = _handleError<T>(
            error,
            onError: onError,
            method: method,
            statusConfig: effectiveStatusConfig,
          );
          finalResponse = errorResponse;
          finalError = error;
          // Call onDone callback for error responses
          onDone?.call(errorResponse, error);
          return errorResponse;
        }
      }
    } finally {
      requestStopwatch.stop();
      requestContext.endedAt = DateTime.now();
      requestContext.totalDuration = requestStopwatch.elapsed;
      if (lifecycleHooks.onRequestEnd != null) {
        await _runHook(
          'onRequestEnd',
          requestContext,
          () => lifecycleHooks.onRequestEnd!.call(
            requestContext,
            finalResponse,
            finalError,
          ),
        );
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
    CancelToken? cancelToken,
    Duration? requestTimeout,
    RequestContext? context,
    ResponseParseMode? parseMode,
  }) async {
    final url = Uri.parse('$baseUrl$path');
    final requestContext =
        context ?? RequestContext(method: method.toUpperCase(), url: url);
    final effectiveCacheConfig = cacheConfig ?? defaultCacheConfig;
    final shouldCache =
        effectiveCacheConfig.maxAge > Duration.zero &&
        (method.toUpperCase() == 'GET' || cacheConfig != null);

    String? cacheKey;
    if (shouldCache && !effectiveCacheConfig.forceRefresh) {
      cacheKey = _cacheLayer.generateCacheKey(
        baseUrl ?? '',
        method,
        path,
        queryParameters: Uri.parse(path).queryParameters,
        body: body,
        headers: headers,
      );

      final cached = await _cacheLayer.get<T>(
        cacheKey,
        context: requestContext,
      );
      if (cached != null && cached.isValid) {
        requestContext.cacheHit = true;
        requestContext.cacheKey = cacheKey;
        if (lifecycleHooks.onCacheHit != null) {
          await _runHook(
            'onCacheHit',
            requestContext,
            () => lifecycleHooks.onCacheHit!.call(
              requestContext,
              cacheKey!,
              cached,
            ),
          );
        }
        _log(
          'Cache HIT: $cacheKey (freshness: ${(cached.freshnessRatio * 100).toStringAsFixed(1)}%)',
        );
        return cached.response;
      } else if (cached != null) {
        _log('Cache EXPIRED: $cacheKey');
      }
    }

    final flintResponse = await _requestExecutor.execute<T>(
      method,
      url,
      body: body,
      defaultHeaders: this.headers,
      requestHeaders: headers,
      saveFilePath: saveFilePath,
      files: files,
      onSendProgress: onSendProgress,
      parser: parser,
      attempt: attempt,
      statusConfig: statusConfig,
      cancelToken: cancelToken,
      requestTimeout: requestTimeout,
      context: requestContext,
      parseMode: parseMode ?? defaultParseMode,
    );

    if (shouldCache &&
        cacheKey != null &&
        flintResponse.statusCode >= 200 &&
        flintResponse.statusCode < 300) {
      try {
        await _cacheLayer.cacheResponse<T>(
          cacheKey,
          flintResponse,
          effectiveCacheConfig,
          context: requestContext,
        );
        _log(
          'Cached response: $cacheKey (maxAge: ${effectiveCacheConfig.maxAge})',
        );
      } catch (e) {
        _log('Failed to cache response: $e');
      }
    }

    return flintResponse;
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

  // Cache Management Methods

  /// Clears all cached responses
  Future<void> clearCache() async {
    await _cacheLayer.clear();
  }

  /// Removes a specific cached response
  Future<void> removeCachedResponse(String key) async {
    await _cacheLayer.remove(key);
  }

  /// Cleans up expired cache entries
  Future<void> cleanupExpiredCache() async {
    await _cacheLayer.cleanupExpired();
  }

  /// Gets the current cache size
  Future<int> get cacheSize async => await _cacheLayer.size();

  /// Preloads responses into cache
  Future<void> preloadCache(
    Map<String, FlintResponse<dynamic>> responses,
  ) async {
    await _cacheLayer.preload(responses);
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
    final retryStopwatch = Stopwatch()..start();

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
        if (_shouldRetry(error, attempt, effectiveRetryConfig, method: 'GET')) {
          if (!_canRetryWithinBudget(
            effectiveRetryConfig,
            retryStopwatch.elapsed,
          )) {
            final budgetError = error.copyWith(
              message:
                  'Retry budget exceeded after ${retryStopwatch.elapsed.inMilliseconds}ms: ${error.message}',
            );
            _handleError<dynamic>(
              budgetError,
              onError: onError,
              statusConfig: effectiveStatusConfig,
            );
            throw budgetError;
          }

          final delay = _calculateRetryDelay(
            attempt,
            effectiveRetryConfig,
            error: error,
          );
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
