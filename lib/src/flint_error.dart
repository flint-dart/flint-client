import 'dart:async';
import 'dart:io';

/// Structured classification for [FlintError].
enum FlintErrorKind { unknown, timeout, cancelled, network, http, parse }

/// Represents an error returned by the Flint client.
class FlintError implements Exception {
  static const int cancelledStatusCode = 499;

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

  /// Structured kind of this error.
  final FlintErrorKind kind;
  final Duration? retryAfter;

  /// The timestamp when the error occurred.
  final DateTime timestamp;

  /// Creates a new [FlintError] with the given [message].
  FlintError(
    this.message, {
    this.statusCode,
    this.originalException,
    this.url,
    this.method,
    FlintErrorKind? kind,
    this.retryAfter,
    DateTime? timestamp,
  }) : kind =
           kind ??
           _inferKind(
             message: message,
             statusCode: statusCode,
             originalException: originalException,
           ),
       timestamp = timestamp ?? DateTime.now();

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
      kind: _inferKind(
        message: exception.toString(),
        statusCode: statusCode,
        originalException: exception,
      ),
      retryAfter: exception is FlintError ? exception.retryAfter : null,
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

    String? retryAfterHeader;
    try {
      retryAfterHeader = response.headers.value('retry-after');
    } catch (_) {
      retryAfterHeader = null;
    }

    return FlintError(
      customMessage ?? 'HTTP $statusCode$reasonPhrase',
      statusCode: statusCode,
      url: url,
      method: method,
      kind: statusCode == 408 ? FlintErrorKind.timeout : FlintErrorKind.http,
      retryAfter: _parseRetryAfter(retryAfterHeader),
    );
  }

  /// Creates a cancellation error with a dedicated status code and kind.
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

  /// Whether this error represents a client error (4xx status code).
  bool get isClientError =>
      statusCode != null && statusCode! >= 400 && statusCode! < 500;

  /// Whether this error represents a server error (5xx status code).
  bool get isServerError =>
      statusCode != null && statusCode! >= 500 && statusCode! < 600;

  /// Whether this error represents a network error (no response received).
  bool get isNetworkError => kind == FlintErrorKind.network;

  /// Whether this error represents a timeout.
  bool get isTimeout => kind == FlintErrorKind.timeout;

  /// Whether this error represents cancellation.
  bool get isCancelled => kind == FlintErrorKind.cancelled;

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
    FlintErrorKind? kind,
    Duration? retryAfter,
    DateTime? timestamp,
  }) {
    return FlintError(
      message ?? this.message,
      statusCode: statusCode ?? this.statusCode,
      originalException: originalException ?? this.originalException,
      url: url ?? this.url,
      method: method ?? this.method,
      kind: kind ?? this.kind,
      retryAfter: retryAfter ?? this.retryAfter,
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
      'kind': kind.name,
      'timestamp': timestamp.toIso8601String(),
      'retryAfterMs': retryAfter?.inMilliseconds,
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
      kind: _kindFromString(map['kind'] as String?),
      retryAfter: map['retryAfterMs'] != null
          ? Duration(milliseconds: map['retryAfterMs'] as int)
          : null,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }

  @override
  String toString() {
    final buffer = StringBuffer('FlintError: $message');

    if (statusCode != null) {
      buffer.write(' (Status: $statusCode)');
    }
    buffer.write(' [Kind: ${kind.name}]');

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
        other.kind == kind &&
        other.retryAfter == retryAfter &&
        other.url == url &&
        other.method == method;
  }

  @override
  int get hashCode {
    return Object.hash(message, statusCode, kind, retryAfter, url, method);
  }

  static Duration? _parseRetryAfter(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final trimmed = value.trim();
    final seconds = int.tryParse(trimmed);
    if (seconds != null) {
      return Duration(seconds: seconds);
    }
    try {
      final asDate = HttpDate.parse(trimmed);
      final delta = asDate.difference(DateTime.now().toUtc());
      if (delta.isNegative) return Duration.zero;
      return delta;
    } catch (_) {
      return null;
    }
  }

  static FlintErrorKind _kindFromString(String? value) {
    if (value == null) return FlintErrorKind.unknown;
    for (final kind in FlintErrorKind.values) {
      if (kind.name == value) return kind;
    }
    return FlintErrorKind.unknown;
  }

  static FlintErrorKind _inferKind({
    required String message,
    int? statusCode,
    dynamic originalException,
  }) {
    final lowerMessage = message.toLowerCase();

    if (lowerMessage.contains('cancel')) return FlintErrorKind.cancelled;
    if (statusCode == 408 ||
        originalException is TimeoutException ||
        lowerMessage.contains('timeout')) {
      return FlintErrorKind.timeout;
    }
    if (statusCode == cancelledStatusCode) return FlintErrorKind.cancelled;
    if (statusCode != null) return FlintErrorKind.http;
    if (originalException is HttpException) return FlintErrorKind.http;
    if (originalException is SocketException) return FlintErrorKind.network;
    if (originalException is FormatException) return FlintErrorKind.parse;
    if (lowerMessage.contains('parse') ||
        lowerMessage.contains('parsing') ||
        lowerMessage.contains('deserialize') ||
        lowerMessage.contains('serialization')) {
      return FlintErrorKind.parse;
    }
    return FlintErrorKind.unknown;
  }
}
