import 'dart:io';

import '../cache/cache.dart';
import '../flint_error.dart';
import '../flint_response.dart';
import '../response/parse_mode.dart';
import '../retry.dart';
import '../status_code_config.dart';
import 'cancel_token.dart';
import 'request_context.dart';

class RequestOptions<T> {
  final dynamic body;
  final Map<String, dynamic>? queryParameters;
  final Map<String, String>? headers;
  final String? saveFilePath;
  final Map<String, File>? files;
  final void Function(int sent, int total)? onSendProgress;
  final StatusCodeConfig? statusConfig;
  final CacheConfig? cacheConfig;
  final RetryConfig? retryConfig;
  final T Function(dynamic data)? parser;
  final void Function(FlintError error)? onError;
  final void Function(FlintResponse<T> response, FlintError? error)? onDone;
  final CancelToken? cancelToken;
  final Duration? timeout;
  final RequestContext? context;
  final ResponseParseMode? parseMode;

  const RequestOptions({
    this.body,
    this.queryParameters,
    this.headers,
    this.saveFilePath,
    this.files,
    this.onSendProgress,
    this.statusConfig,
    this.cacheConfig,
    this.retryConfig,
    this.parser,
    this.onError,
    this.onDone,
    this.cancelToken,
    this.timeout,
    this.context,
    this.parseMode,
  });
}
