import 'dart:async';
import 'dart:io';

import 'package:flint_client/src/flint_error.dart';

/// Configuration for request retries

typedef RetryEvaluator = bool Function(FlintError error, int attempt);

class RetryConfig {
  static const Set<String> defaultRetryMethods = {
    'GET',
    'HEAD',
    'PUT',
    'DELETE',
    'OPTIONS',
    'TRACE',
  };

  final int maxAttempts;
  final Duration delay;
  final Duration maxDelay;
  final bool retryOnTimeout;
  final Set<int> retryStatusCodes;
  final Set<Type> retryExceptions;
  final Set<String> retryMethods;
  final RetryEvaluator? retryEvaluator;
  final bool honorRetryAfter;
  final Duration? maxRetryTime;

  const RetryConfig({
    this.maxAttempts = 0,
    this.delay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    this.retryOnTimeout = false,
    this.retryStatusCodes = const {500, 502, 503, 504, 408, 429},
    this.retryExceptions = const {
      SocketException,
      TimeoutException,
      HttpException,
    },
    this.retryMethods = defaultRetryMethods,
    this.retryEvaluator,
    this.honorRetryAfter = true,
    this.maxRetryTime,
  });

  /// Creates a RetryConfig that disables all retries
  static const RetryConfig noRetry = RetryConfig(
    maxAttempts: 0, // 0 means no retries - only the initial attempt
    retryExceptions: {},
    retryStatusCodes: {},
    retryMethods: {},
  );

  RetryConfig copyWith({
    int? maxAttempts,
    Duration? delay,
    Duration? maxDelay,
    bool? retryOnTimeout,
    Set<int>? retryStatusCodes,
    Set<Type>? retryExceptions,
    Set<String>? retryMethods,
    RetryEvaluator? retryEvaluator,
    bool? honorRetryAfter,
    Duration? maxRetryTime,
  }) {
    return RetryConfig(
      maxAttempts: maxAttempts ?? this.maxAttempts,
      delay: delay ?? this.delay,
      maxDelay: maxDelay ?? this.maxDelay,
      retryOnTimeout: retryOnTimeout ?? this.retryOnTimeout,
      retryStatusCodes: retryStatusCodes ?? this.retryStatusCodes,
      retryExceptions: retryExceptions ?? this.retryExceptions,
      retryMethods: retryMethods ?? this.retryMethods,
      retryEvaluator: retryEvaluator ?? this.retryEvaluator,
      honorRetryAfter: honorRetryAfter ?? this.honorRetryAfter,
      maxRetryTime: maxRetryTime ?? this.maxRetryTime,
    );
  }

  /// Returns true if retries are enabled for this configuration
  bool get shouldRetry => maxAttempts > 0;
}
