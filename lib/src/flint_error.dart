import 'dart:async';
import 'dart:io';

/// Represents an error returned by the Flint client.
class FlintError implements Exception {
  /// The error message describing what went wrong.
  final String message;

  /// The HTTP status code if this error came from an HTTP response.
  final int? statusCode;

  /// The original exception that caused this error, if any.
  final dynamic originalException;

  /// The URL that was being requested when the error occurred.
  final Uri? url;

  /// The HTTP method that was being used when the error occurred.
  final String? method;

  /// The timestamp when the error occurred.
  final DateTime timestamp;

  /// Creates a new [FlintError] with the given [message].
  FlintError(
    this.message, {
    this.statusCode,
    this.originalException,
    this.url,
    this.method,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Creates a [FlintError] from another exception.
  factory FlintError.fromException(
    dynamic exception, {
    int? statusCode,
    Uri? url,
    String? method,
  }) {
    if (exception is FlintError) {
      return exception;
    }

    return FlintError(
      exception.toString(),
      statusCode: statusCode,
      originalException: exception,
      url: url,
      method: method,
    );
  }

  /// Creates a [FlintError] from an HTTP response.
  factory FlintError.fromHttpResponse(
    HttpClientResponse response, {
    String? customMessage,
    Uri? url,
    String? method,
  }) {
    final statusCode = response.statusCode;
    final reasonPhrase = response.reasonPhrase;

    return FlintError(
      customMessage ?? 'HTTP $statusCode$reasonPhrase',
      statusCode: statusCode,
      url: url,
      method: method,
    );
  }

  /// Whether this error represents a client error (4xx status code).
  bool get isClientError =>
      statusCode != null && statusCode! >= 400 && statusCode! < 500;

  /// Whether this error represents a server error (5xx status code).
  bool get isServerError =>
      statusCode != null && statusCode! >= 500 && statusCode! < 600;

  /// Whether this error represents a network error (no response received).
  bool get isNetworkError =>
      statusCode == null && originalException is SocketException;

  /// Whether this error represents a timeout.
  bool get isTimeout =>
      statusCode == 408 ||
      (originalException is TimeoutException) ||
      message.toLowerCase().contains('timeout');

  /// Whether this error represents a rate limit (429 Too Many Requests).
  bool get isRateLimit => statusCode == 429;

  /// Whether this error should be retried based on common retry patterns.
  bool get isRetryable {
    // Server errors are generally retryable
    if (isServerError) return true;

    // Network errors are generally retryable
    if (isNetworkError) return true;

    // Timeouts are generally retryable
    if (isTimeout) return true;

    // Rate limits are generally retryable (after appropriate delay)
    if (isRateLimit) return true;

    // Some client errors might be retryable (e.g., 408 Request Timeout)
    if (statusCode == 408) return true;

    return false;
  }

  /// Creates a copy of this error with optional overrides.
  FlintError copyWith({
    String? message,
    int? statusCode,
    dynamic originalException,
    Uri? url,
    String? method,
    DateTime? timestamp,
  }) {
    return FlintError(
      message ?? this.message,
      statusCode: statusCode ?? this.statusCode,
      originalException: originalException ?? this.originalException,
      url: url ?? this.url,
      method: method ?? this.method,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  /// Converts the error to a map for serialization.
  Map<String, dynamic> toMap() {
    return {
      'message': message,
      'statusCode': statusCode,
      'url': url?.toString(),
      'method': method,
      'timestamp': timestamp.toIso8601String(),
      'isClientError': isClientError,
      'isServerError': isServerError,
      'isNetworkError': isNetworkError,
      'isTimeout': isTimeout,
      'isRateLimit': isRateLimit,
      'isRetryable': isRetryable,
    };
  }

  /// Creates an error from a map.
  factory FlintError.fromMap(Map<String, dynamic> map) {
    return FlintError(
      map['message'] as String,
      statusCode: map['statusCode'] as int?,
      url: map['url'] != null ? Uri.parse(map['url'] as String) : null,
      method: map['method'] as String?,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }

  @override
  String toString() {
    final buffer = StringBuffer('FlintError: $message');

    if (statusCode != null) {
      buffer.write(' (Status: $statusCode)');
    }

    if (url != null) {
      buffer.write(' [${method?.toUpperCase() ?? 'GET'} $url]');
    }

    if (originalException != null) {
      buffer.write(' - Caused by: $originalException');
    }

    return buffer.toString();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is FlintError &&
        other.message == message &&
        other.statusCode == statusCode &&
        other.url == url &&
        other.method == method;
  }

  @override
  int get hashCode {
    return Object.hash(message, statusCode, url, method);
  }
}
