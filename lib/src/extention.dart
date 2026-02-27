import 'dart:io';
import 'dart:convert';
import '../flint_client.dart';

extension FlintClientFileSaver on FlintClient {
  /// Uploads a single file using multipart/form-data.
  Future<FlintResponse<T>> uploadFile<T>(
    String path, {
    required File file,
    String fieldName = 'file',
    dynamic body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    String? saveFilePath,
    ProgressCallback? onSendProgress,
    StatusCodeConfig? statusConfig,
    CacheConfig? cacheConfig,
    RetryConfig? retryConfig,
    JsonParser<T>? parser,
    ErrorHandler? onError,
    RequestDoneCallback<T>? onDone,
    CancelToken? cancelToken,
    Duration? requestTimeout,
    ResponseParseMode? parseMode,
  }) {
    return post<T>(
      path,
      body: body,
      queryParameters: queryParameters,
      headers: headers,
      saveFilePath: saveFilePath,
      files: {fieldName: file},
      onSendProgress: onSendProgress,
      statusConfig: statusConfig,
      cacheConfig: cacheConfig,
      retryConfig: retryConfig,
      parser: parser,
      onError: onError,
      onDone: onDone,
      cancelToken: cancelToken,
      requestTimeout: requestTimeout,
      parseMode: parseMode,
    );
  }

  /// Uploads many files in one multipart/form-data request.
  Future<FlintResponse<T>> uploadFiles<T>(
    String path, {
    required Map<String, File> files,
    dynamic body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    String? saveFilePath,
    ProgressCallback? onSendProgress,
    StatusCodeConfig? statusConfig,
    CacheConfig? cacheConfig,
    RetryConfig? retryConfig,
    JsonParser<T>? parser,
    ErrorHandler? onError,
    RequestDoneCallback<T>? onDone,
    CancelToken? cancelToken,
    Duration? requestTimeout,
    ResponseParseMode? parseMode,
  }) {
    return post<T>(
      path,
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
      onDone: onDone,
      cancelToken: cancelToken,
      requestTimeout: requestTimeout,
      parseMode: parseMode,
    );
  }

  /// Saves response data to [path].
  /// Supports `File`, `List<int>`, `String`, `Map`, and `List`.
  Future<File> saveResponseData(FlintResponse response, String path) async {
    try {
      final data = response.data;
      final file = File(path);
      await file.parent.create(recursive: true);

      if (data is File) {
        return data.copy(file.path);
      }
      if (data is List<int>) {
        return file.writeAsBytes(data, flush: true);
      }
      if (data is String) {
        return file.writeAsString(data, flush: true);
      }
      if (data is Map || data is List) {
        return file.writeAsString(jsonEncode(data), flush: true);
      }
      throw FlintError(
        'Response data is not supported for file saving: ${data.runtimeType}',
      );
    } catch (e) {
      if (e is FlintError) rethrow;
      final error = FlintError('Failed to save file: $e');
      if (onError != null) onError!(error);
      throw error;
    }
  }

  /// Saves a [FlintResponse] containing a file or bytes to [path].
  /// Returns the saved [File] or null if the response is not a file.
  Future<File?> saveFile(FlintResponse response, String path) async {
    try {
      return await saveResponseData(response, path);
    } catch (e) {
      final err = FlintError('Failed to save file: $e');
      if (onError != null) onError!(err);
      return null;
    }
  }
}
