import 'dart:async';
import 'dart:io';

import 'package:flint_client/src/flint_error.dart';

/// Configuration for request retries
///

typedef RetryEvaluator = bool Function(FlintError error, int attempt);

class RetryConfig {
  final int maxAttempts;
  final Duration delay;
  final Duration maxDelay;
  final bool retryOnTimeout;
  final Set<int> retryStatusCodes;
  final Set<Type> retryExceptions;
  final RetryEvaluator? retryEvaluator;

  const RetryConfig({
    this.maxAttempts = 3,
    this.delay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    this.retryOnTimeout = true,
    this.retryStatusCodes = const {500, 502, 503, 504, 408, 429},
    this.retryExceptions = const {
      SocketException,
      TimeoutException,
      HttpException,
    },
    this.retryEvaluator,
  });

  RetryConfig copyWith({
    int? maxAttempts,
    Duration? delay,
    Duration? maxDelay,
    bool? retryOnTimeout,
    Set<int>? retryStatusCodes,
    Set<Type>? retryExceptions,
    RetryEvaluator? retryEvaluator,
  }) {
    return RetryConfig(
      maxAttempts: maxAttempts ?? this.maxAttempts,
      delay: delay ?? this.delay,
      maxDelay: maxDelay ?? this.maxDelay,
      retryOnTimeout: retryOnTimeout ?? this.retryOnTimeout,
      retryStatusCodes: retryStatusCodes ?? this.retryStatusCodes,
      retryExceptions: retryExceptions ?? this.retryExceptions,
      retryEvaluator: retryEvaluator ?? this.retryEvaluator,
    );
  }
}
