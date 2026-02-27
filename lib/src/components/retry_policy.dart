import 'dart:math';

import '../flint_error.dart';
import '../request/request_context.dart';
import '../retry.dart';

class RetryPolicy {
  const RetryPolicy();

  bool shouldRetry(
    FlintError error,
    int attempt,
    RetryConfig retryConfig, {
    required String method,
    RequestContext? context,
  }) {
    context?.attempt = attempt;
    if (retryConfig.maxAttempts == 0) {
      return false;
    }

    final normalizedMethod = method.toUpperCase();
    if (!retryConfig.retryMethods.contains(normalizedMethod)) {
      return false;
    }

    if (attempt > retryConfig.maxAttempts) {
      return false;
    }

    if (retryConfig.retryEvaluator != null) {
      return retryConfig.retryEvaluator!(error, attempt);
    }

    if (error.statusCode != null &&
        retryConfig.retryStatusCodes.contains(error.statusCode)) {
      return true;
    }

    if (error.originalException != null) {
      for (final exceptionType in retryConfig.retryExceptions) {
        if (error.originalException.runtimeType == exceptionType) {
          return true;
        }
      }
    }

    if (retryConfig.retryOnTimeout && error.isTimeout) {
      return true;
    }

    return false;
  }

  Duration calculateDelay(
    int attempt,
    RetryConfig retryConfig, {
    FlintError? error,
  }) {
    if (retryConfig.honorRetryAfter && error?.retryAfter != null) {
      final serverDelay = error!.retryAfter!;
      if (serverDelay.isNegative) {
        return Duration.zero;
      }
      return serverDelay > retryConfig.maxDelay
          ? retryConfig.maxDelay
          : serverDelay;
    }

    final exponentialDelay =
        retryConfig.delay.inMilliseconds * pow(2, attempt - 1);
    final jitter = exponentialDelay * 0.25 * (Random().nextDouble() * 2 - 1);
    final delayWithJitter = exponentialDelay + jitter;

    final finalDelay = delayWithJitter.clamp(
      retryConfig.delay.inMilliseconds.toDouble(),
      retryConfig.maxDelay.inMilliseconds.toDouble(),
    );

    return Duration(milliseconds: finalDelay.round());
  }
}
