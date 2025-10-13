import 'dart:io';
import 'package:flint_client/src/flint_error.dart';
import 'package:flint_client/src/status_code_config.dart';

/// Enum representing the type of response returned by the Flint client.
enum FlintResponseType {
  /// Response is in JSON format
  json,

  /// Response is plain text
  text,

  /// Response is a file
  file,

  /// Response type is unknown
  unknown,

  /// Response is HTML
  html,

  /// Response is binary data
  binary,

  ///   stream, // ADD this line
  stream,
}

/// Represents a response from the Flint client.
///
/// This class wraps the response data, HTTP status code, headers, and
/// provides helpers to identify the type of the response.
class FlintResponse<T> {
  /// The HTTP status code returned by the request.
  final int statusCode;

  /// The response data. Can be of any type `T`.
  final T? data;

  /// Whether this response represents an error.
  final bool isError;

  /// The type of response (json, text, file, html, unknown).
  final FlintResponseType type;

  /// Optional HTTP headers returned with the response.
  final HttpHeaders? headers;

  /// Whether the request was successful based on status config.
  final bool success;

  /// The error object if this response represents an error.
  final FlintError? error;

  /// The URL that was requested.
  final Uri? url;

  /// The HTTP method used for the request.
  final String? method;

  /// The timestamp when the response was received.
  final DateTime timestamp;

  /// The duration of the request.
  final Duration? duration;

  /// Status code configuration for this response
  final StatusCodeConfig statusConfig;

  /// Creates a successful response.
  ///
  /// [statusCode] is required.
  /// [data] is the response payload.
  /// [type] indicates the type of the response.
  /// [headers] optionally contains HTTP headers.
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
               url: url,
               method: method,
               timestamp: timestamp,
             )
           : null,
       timestamp = timestamp ?? DateTime.now();

  /// Creates an error response.
  ///
  /// [error] is the [FlintError] representing the error details.
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

  /// Creates a response from an HTTP response.
  factory FlintResponse.fromHttpResponse(
    HttpClientResponse response, {
    T? data,
    FlintResponseType type = FlintResponseType.unknown,
    Uri? url,
    String? method,
    Duration? duration,
    StatusCodeConfig? statusConfig,
  }) {
    final config = statusConfig ?? const StatusCodeConfig();
    final isSuccess = config.isSuccess(response.statusCode);
    final isError = !isSuccess;

    FlintError? error;
    if (isError) {
      error = FlintError.fromHttpResponse(response, url: url, method: method);
    }

    return FlintResponse<T>._(
      statusCode: response.statusCode,
      data: data,
      type: type,
      headers: response.headers,
      url: url,
      method: method,
      duration: duration,
      isError: isError,
      success: isSuccess,
      error: error,
      statusConfig: config,
    );
  }

  // Private constructor for internal use
  FlintResponse._({
    required this.statusCode,
    this.data,
    required this.type,
    this.headers,
    this.url,
    this.method,
    this.duration,
    required this.isError,
    required this.success,
    this.error,
    DateTime? timestamp,
    required this.statusConfig,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Returns true if the response type is JSON.
  bool get isJson => type == FlintResponseType.json;

  /// Returns true if the response type is plain text.
  bool get isText => type == FlintResponseType.text;

  /// Returns true if the response type is HTML.
  bool get isHtml => type == FlintResponseType.html;

  /// Returns true if the response type is a file.
  bool get isFile => type == FlintResponseType.file;

  /// Returns true if the response type is binary.
  bool get isBinary => type == FlintResponseType.binary;
  bool get isSuccess => statusConfig.isSuccess(statusCode);

  /// Status helpers that use the config (NOT hardcoded values)
  bool get isClientError => statusConfig.isClientError(statusCode);
  bool get isServerError => statusConfig.isServerError(statusCode);
  bool get isRedirect => statusConfig.isRedirect(statusCode);

  /// For debugging - shows which config is being used
  @override
  String toString() {
    final buffer = StringBuffer('FlintResponse(');
    buffer.write('statusCode: $statusCode, ');
    buffer.write('success: $success, ');
    buffer.write('type: $type, ');
    buffer.write('usingConfig: ${statusConfig.runtimeType}, ');

    if (url != null) {
      buffer.write('url: $url, ');
    }

    if (method != null) {
      buffer.write('method: $method, ');
    }

    if (duration != null) {
      buffer.write('duration: ${duration!.inMilliseconds}ms, ');
    }

    if (isError && error != null) {
      buffer.write('error: $error');
    } else {
      buffer.write('data: ${data != null ? data.toString() : 'null'}');
    }

    buffer.write(')');
    return buffer.toString();
  }

  /// Returns the response data cast to a different type [R].
  ///
  /// Throws a [StateError] if the cast fails.
  R cast<R>() {
    if (data is R) {
      return data as R;
    }
    throw StateError(
      'Cannot cast response data from ${T.toString()} to ${R.toString()}',
    );
  }

  /// Returns the response data as type [R], or null if the cast fails.
  R? castOrNull<R>() {
    try {
      return data as R?;
    } catch (_) {
      return null;
    }
  }

  /// Transforms the response data using the provided [transformer].
  ///
  /// Returns a new [FlintResponse] with the transformed data.
  FlintResponse<R> map<R>(R Function(T data) transformer) {
    if (isError) {
      return FlintResponse.error(
        error!,
        headers: headers,
        method: method,
        duration: duration,
        statusConfig: statusConfig,
      );
    }

    return FlintResponse<R>(
      statusCode: statusCode,
      data: data != null ? transformer(data as T) : null,
      type: type,
      headers: headers,
      url: url,
      method: method,
      timestamp: timestamp,
      duration: duration,
      statusConfig: statusConfig,
    );
  }

  /// Creates a copy of this response with optional overrides.
  FlintResponse<T> copyWith({
    int? statusCode,
    T? data,
    FlintResponseType? type,
    HttpHeaders? headers,
    bool? isError,
    bool? success,
    FlintError? error,
    Uri? url,
    String? method,
    Duration? duration,
    DateTime? timestamp,
    StatusCodeConfig? statusConfig,
  }) {
    if (isError == true || error != null) {
      final effectiveError = error ?? this.error ?? FlintError('Unknown error');
      return FlintResponse.error(
        effectiveError.copyWith(
          url: url ?? this.url,
          method: method ?? this.method,
        ),
        headers: headers ?? this.headers,
        method: method ?? this.method,
        duration: duration ?? this.duration,
        statusConfig: statusConfig ?? this.statusConfig,
      );
    }

    return FlintResponse<T>(
      statusCode: statusCode ?? this.statusCode,
      data: data ?? this.data,
      type: type ?? this.type,
      headers: headers ?? this.headers,
      url: url ?? this.url,
      method: method ?? this.method,
      timestamp: timestamp ?? this.timestamp,
      duration: duration ?? this.duration,
      statusConfig: statusConfig ?? this.statusConfig,
    );
  }

  /// Converts the response to a map for serialization.
  Map<String, dynamic> toMap() {
    return {
      'statusCode': statusCode,
      'success': success,
      'isError': isError,
      'type': type.toString(),
      'url': url?.toString(),
      'method': method,
      'timestamp': timestamp.toIso8601String(),
      'duration': duration?.inMilliseconds,
      'error': error?.toMap(),
      'statusConfig': {
        'successCodes': statusConfig.successCodes.toList(),
        'clientErrorCodes': statusConfig.clientErrorCodes.toList(),
        'serverErrorCodes': statusConfig.serverErrorCodes.toList(),
        'redirectCodes': statusConfig.redirectCodes.toList(),
      },
    };
  }

  /// Throws the error if this response represents an error.
  ///
  /// Returns this response if it's successful.
  FlintResponse<T> throwIfError() {
    if (isError && error != null) {
      throw error!;
    }
    return this;
  }

  /// Returns the data if the response is successful, otherwise throws the error.
  T get requireData {
    if (isError && error != null) {
      throw error!;
    }
    if (data == null) {
      throw StateError('Response data is null');
    }
    return data as T;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is FlintResponse<T> &&
        other.statusCode == statusCode &&
        other.data == data &&
        other.type == type &&
        other.success == success &&
        other.isError == isError &&
        other.url == url &&
        other.method == method &&
        other.statusConfig.successCodes == statusConfig.successCodes;
  }

  @override
  int get hashCode {
    return Object.hash(
      statusCode,
      data,
      type,
      success,
      isError,
      url,
      method,
      statusConfig.successCodes,
    );
  }
}
