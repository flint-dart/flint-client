import 'dart:async';

import '../cache/cached_response.dart';
import '../flint_error.dart';
import '../flint_response.dart';
import 'request_context.dart';

typedef OnRequestStart = FutureOr<void> Function(RequestContext context);
typedef OnRequestEnd =
    FutureOr<void> Function(
      RequestContext context,
      FlintResponse<dynamic>? response,
      FlintError? error,
    );
typedef OnRetry =
    FutureOr<void> Function(
      RequestContext context,
      FlintError error,
      Duration delay,
    );
typedef OnCacheHit =
    FutureOr<void> Function(
      RequestContext context,
      String cacheKey,
      CachedResponse<dynamic> cachedResponse,
    );
typedef OnRequestError =
    FutureOr<void> Function(
      RequestContext context,
      FlintError error,
      bool willRetry,
    );

class RequestLifecycleHooks {
  final OnRequestStart? onRequestStart;
  final OnRequestEnd? onRequestEnd;
  final OnRetry? onRetry;
  final OnCacheHit? onCacheHit;
  final OnRequestError? onError;

  const RequestLifecycleHooks({
    this.onRequestStart,
    this.onRequestEnd,
    this.onRetry,
    this.onCacheHit,
    this.onError,
  });
}
