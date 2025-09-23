import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'flint_response.dart';
import 'flint_error.dart';

/// Callback type for handling errors returned by [FlintClient].
typedef ErrorHandler = void Function(FlintError error);

/// Callback type to track upload or download progress.
/// [sent] is the number of bytes sent or received.
/// [total] is the total number of bytes.
typedef ProgressCallback = void Function(int sent, int total);

/// Intercepts HTTP requests before they are sent.
typedef RequestInterceptor = Future<void> Function(HttpClientRequest request);

/// Intercepts HTTP responses after they are received.
typedef ResponseInterceptor =
    Future<void> Function(HttpClientResponse response);

/// Parses JSON responses into a strongly-typed object [T].
typedef JsonParser<T> = T Function(dynamic json);

/// A powerful HTTP client for making requests to REST APIs with
/// support for JSON, file uploads/downloads, and progress tracking.
///
/// Provides convenient methods for HTTP verbs (GET, POST, PUT, PATCH, DELETE)
/// and allows custom interceptors, timeout configuration, and automatic
/// error handling.
class FlintClient {
  /// Base URL for all HTTP requests.
  final String? baseUrl;

  /// Default headers to include with every request.
  final Map<String, String> headers;

  /// Timeout duration for requests.
  final Duration timeout;

  /// Optional error handler callback.
  final ErrorHandler? onError;

  /// Optional interceptor called before each request is sent.
  final RequestInterceptor? requestInterceptor;

  /// Optional interceptor called after each response is received.
  final ResponseInterceptor? responseInterceptor;

  /// Enables debug logging if true.
  final bool debug;

  /// Internal, long-lived [HttpClient] instance.
  final HttpClient _client;

  /// Creates a new [FlintClient] instance.
  ///
  /// [baseUrl] sets the API base URL. If null, requests must provide full URLs.
  /// [headers] sets default headers for all requests.
  /// [timeout] sets the request timeout duration.
  /// [onError] provides a centralized error callback.
  /// [requestInterceptor] and [responseInterceptor] allow custom handling
  /// before sending requests or after receiving responses.
  /// [debug] enables console logging.
  FlintClient({
    this.baseUrl,
    this.headers = const {},
    this.timeout = const Duration(seconds: 30),
    this.onError,
    this.requestInterceptor,
    this.responseInterceptor,
    this.debug = false,
  }) : _client =
           HttpClient() // Initialize it in the constructor
             ..connectionTimeout = timeout
             ..idleTimeout = timeout;

  /// Creates a copy of this client with optional overrides.
  FlintClient copyWith({
    String? baseUrl,
    Map<String, String>? headers,
    Duration? timeout,
    ErrorHandler? onError,
    RequestInterceptor? requestInterceptor,
    ResponseInterceptor? responseInterceptor,
    bool? debug,
  }) {
    return FlintClient(
      baseUrl: baseUrl ?? this.baseUrl,
      headers: headers ?? this.headers,
      timeout: timeout ?? this.timeout,
      onError: onError ?? this.onError,
      requestInterceptor: requestInterceptor ?? this.requestInterceptor,
      responseInterceptor: responseInterceptor ?? this.responseInterceptor,
      debug: debug ?? this.debug,
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
    if (debug) {
      print('[FlintClient] $message');
    }
  }

  /// Sends a GET request to [path] with optional query parameters, headers,
  /// file save path, and a custom JSON parser.
  Future<FlintResponse<T>> get<T>(
    String path, {
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    String? saveFilePath,
    JsonParser<T>? parser,
  }) {
    _ensureBaseUrl();

    if (queryParameters != null && queryParameters.isNotEmpty) {
      path = _buildPathWithQuery(path, queryParameters);
    }

    return _request<T>(
      'GET',
      path,
      headers: headers,
      saveFilePath: saveFilePath,
      parser: parser,
    );
  }

  /// Sends a POST request to [path] with optional body, files, headers,
  /// query parameters, progress callback, and a custom JSON parser.
  Future<FlintResponse<T>> post<T>(
    String path, {
    dynamic body,
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    String? saveFilePath,
    Map<String, File>? files,
    ProgressCallback? onSendProgress,
    JsonParser<T>? parser,
  }) {
    _ensureBaseUrl();

    if (queryParameters != null && queryParameters.isNotEmpty) {
      path = _buildPathWithQuery(path, queryParameters);
    }

    return _request<T>(
      'POST',
      path,
      body: body,
      headers: headers,
      saveFilePath: saveFilePath,
      files: files,
      onSendProgress: onSendProgress,
      parser: parser,
    );
  }

  /// Sends a PUT request to [path] (similar to POST).
  Future<FlintResponse<T>> put<T>(
    String path, {
    dynamic body,
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    String? saveFilePath,
    Map<String, File>? files,
    ProgressCallback? onSendProgress,
    JsonParser<T>? parser,
  }) {
    _ensureBaseUrl();

    if (queryParameters != null && queryParameters.isNotEmpty) {
      path = _buildPathWithQuery(path, queryParameters);
    }

    return _request<T>(
      'PUT',
      path,
      body: body,
      headers: headers,
      saveFilePath: saveFilePath,
      files: files,
      onSendProgress: onSendProgress,
      parser: parser,
    );
  }

  /// Sends a PATCH request to [path] (similar to PUT).
  Future<FlintResponse<T>> patch<T>(
    String path, {
    dynamic body,
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    String? saveFilePath,
    Map<String, File>? files,
    ProgressCallback? onSendProgress,
    JsonParser<T>? parser,
  }) {
    _ensureBaseUrl();

    if (queryParameters != null && queryParameters.isNotEmpty) {
      path = _buildPathWithQuery(path, queryParameters);
    }

    return _request<T>(
      'PATCH',
      path,
      body: body,
      headers: headers,
      saveFilePath: saveFilePath,
      files: files,
      onSendProgress: onSendProgress,
      parser: parser,
    );
  }

  /// Sends a DELETE request to [path] with optional query parameters,
  /// headers, save file path, and custom JSON parser.
  Future<FlintResponse<T>> delete<T>(
    String path, {
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    String? saveFilePath,
    JsonParser<T>? parser,
  }) {
    _ensureBaseUrl();

    if (queryParameters != null && queryParameters.isNotEmpty) {
      path = _buildPathWithQuery(path, queryParameters);
    }

    return _request<T>(
      'DELETE',
      path,
      headers: headers,
      saveFilePath: saveFilePath,
      parser: parser,
    );
  }

  /// Builds a full path with query parameters appended.
  String _buildPathWithQuery(String path, Map<String, String> queryParameters) {
    final uri = Uri.parse(path);
    final newUri = uri.replace(
      queryParameters: {...uri.queryParameters, ...queryParameters},
    );
    return newUri.toString();
  }
  // -------------------------
  // Internal request handling
  // -------------------------

  /// Sends the HTTP request using the specified [method] and [path].
  ///
  /// Handles JSON encoding, multipart files, interceptors, progress, and errors.
  Future<FlintResponse<T>> _request<T>(
    String method,
    String path, {
    dynamic body,
    Map<String, String>? headers,
    String? saveFilePath,
    Map<String, File>? files,
    ProgressCallback? onSendProgress,
    JsonParser<T>? parser,
  }) async {
    final url = Uri.parse('$baseUrl$path');
    final client = _client;

    _log('$method $url');

    try {
      HttpClientRequest request = await _createRequest(client, method, url);

      // Merge headers
      final allHeaders = {...this.headers, ...headers ?? {}};
      allHeaders.forEach((k, v) => request.headers.set(k, v));

      // Request interceptor
      if (requestInterceptor != null) {
        await requestInterceptor!(request);
      }

      // Handle request body
      if (files != null && files.isNotEmpty) {
        await _handleMultipartRequest(request, body, files, onSendProgress);
      } else if (body != null) {
        await _handleJsonRequest(request, body, onSendProgress);
      }

      final response = await request.close();

      // Response interceptor
      if (responseInterceptor != null) {
        await responseInterceptor!(response);
      }

      _log('Response: ${response.statusCode} ${response.reasonPhrase}');

      return await _handleResponse<T>(response, saveFilePath, parser);
    } on SocketException catch (e) {
      return _handleError<T>(FlintError('Network error: ${e.message}'));
    } on TimeoutException catch (e) {
      return _handleError<T>(FlintError('Request timeout: ${e.message}'));
    } on HttpException catch (e) {
      return _handleError<T>(FlintError('HTTP error: ${e.message}'));
    } catch (e) {
      return _handleError<T>(FlintError('Unexpected error: ${e.toString()}'));
    } finally {
      client.close();
    }
  }

  Future<HttpClientRequest> _createRequest(
    HttpClient client,
    String method,
    Uri url,
  ) async {
    switch (method.toUpperCase()) {
      case 'POST':
        return await client.postUrl(url);
      case 'PUT':
        return await client.putUrl(url);
      case 'PATCH':
        return await client.patchUrl(url);
      case 'DELETE':
        return await client.deleteUrl(url);
      default:
        return await client.getUrl(url);
    }
  }

  Future<void> _handleMultipartRequest(
    HttpClientRequest request,
    dynamic body,
    Map<String, File> files,
    ProgressCallback? onSendProgress,
  ) async {
    final boundary =
        '----FlintClientBoundary${DateTime.now().millisecondsSinceEpoch}';
    request.headers.set(
      HttpHeaders.contentTypeHeader,
      'multipart/form-data; boundary=$boundary',
    );

    final totalSize = await _calculateRequestSize(body, files);
    int sentSize = 0;

    void updateProgress(int additionalBytes) {
      sentSize += additionalBytes;
      onSendProgress?.call(sentSize, totalSize);
    }

    // Helper functions
    String buildField(String name, String value) =>
        '--$boundary\r\nContent-Disposition: form-data; name="$name"\r\n\r\n$value\r\n';

    String buildFileHeader(String name, String fileName, int length) =>
        '--$boundary\r\nContent-Disposition: form-data; name="$name"; filename="$fileName"\r\nContent-Type: application/octet-stream\r\nContent-Length: $length\r\n\r\n';

    // Write form fields
    if (body != null && body is Map<String, dynamic>) {
      body.forEach((key, value) {
        final fieldData = buildField(key, value.toString());
        request.write(fieldData);
        updateProgress(utf8.encode(fieldData).length);
      });
    }

    // Write files
    for (var entry in files.entries) {
      final file = entry.value;
      final fileName = file.path.split(Platform.pathSeparator).last;
      final fileLength = await file.length();

      final fileHeader = buildFileHeader(entry.key, fileName, fileLength);
      request.write(fileHeader);
      updateProgress(utf8.encode(fileHeader).length);

      await _writeFileWithProgress(file, request, updateProgress);

      request.write('\r\n');
      updateProgress(2); // \r\n bytes
    }

    // Final boundary
    final endBoundary = '--$boundary--\r\n';
    request.write(endBoundary);
    updateProgress(utf8.encode(endBoundary).length);
  }

  Future<void> _handleJsonRequest(
    HttpClientRequest request,
    dynamic body,
    ProgressCallback? onSendProgress,
  ) async {
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    final jsonData = jsonEncode(body);
    final dataBytes = utf8.encode(jsonData);

    if (onSendProgress != null) {
      // Write in chunks for progress tracking
      const chunkSize = 1024;
      for (int i = 0; i < dataBytes.length; i += chunkSize) {
        final end = i + chunkSize < dataBytes.length
            ? i + chunkSize
            : dataBytes.length;
        request.add(dataBytes.sublist(i, end));
        onSendProgress(end, dataBytes.length);
        await Future.delayed(Duration.zero);
      }
    } else {
      request.write(jsonData);
    }
  }

  Future<int> _calculateRequestSize(
    dynamic body,
    Map<String, File> files,
  ) async {
    int size = 0;

    if (body != null && body is Map<String, dynamic>) {
      body.forEach((key, value) {
        size += utf8
            .encode(
              '--boundary\r\nContent-Disposition: form-data; name="$key"\r\n\r\n$value\r\n',
            )
            .length;
      });
    }

    for (var file in files.values) {
      final fileLength = await file.length();
      size += utf8
          .encode(
            '--boundary\r\nContent-Disposition: form-data; name="file"; filename="filename"\r\nContent-Type: application/octet-stream\r\n\r\n',
          )
          .length;
      size += fileLength;
      size += 2; // \r\n
    }

    size += utf8.encode('--boundary--\r\n').length;
    return size;
  }

  Future<void> _writeFileWithProgress(
    File file,
    HttpClientRequest request,
    void Function(int) updateProgress,
  ) async {
    //   const chunkSize = 4096;
    final stream = file.openRead();

    await for (final chunk in stream) {
      request.add(chunk);
      updateProgress(chunk.length);
    }
  }

  Future<FlintResponse<T>> _handleResponse<T>(
    HttpClientResponse response,
    String? saveFilePath,
    JsonParser<T>? parser,
  ) async {
    final contentType = response.headers.contentType?.mimeType ?? '';
    final bytes = await _readAllBytes(response);

    // Handle error status codes
    if (response.statusCode >= 400) {
      final errorMessage = utf8.decode(bytes, allowMalformed: true);
      throw FlintError('HTTP ${response.statusCode}: $errorMessage');
    }

    // Determine response type and handle accordingly
    if (contentType.contains('application/json')) {
      return _handleJsonResponse<T>(response, bytes, parser);
    } else if (contentType.contains('text') || contentType.contains('html')) {
      return _handleTextResponse<T>(response, bytes, parser);
    } else {
      return _handleBinaryResponse<T>(response, bytes, saveFilePath, parser);
    }
  }

  Future<FlintResponse<T>> _handleJsonResponse<T>(
    HttpClientResponse response,
    List<int> bytes,
    JsonParser<T>? parser,
  ) async {
    dynamic data;

    try {
      data = jsonDecode(utf8.decode(bytes));
    } catch (e) {
      // If JSON decoding fails, fallback to string
      data = utf8.decode(bytes);
    }

    // Apply parser if provided
    if (parser != null) {
      try {
        data = parser(data);
      } catch (e) {
        throw FlintError('JSON parsing failed: ${e.toString()}');
      }
    } else {
      data = _defaultParser<T>(data, FlintResponseType.json);
    }

    return FlintResponse<T>(
      statusCode: response.statusCode,
      data: data as T,
      type: FlintResponseType.json,
      headers: response.headers,
    );
  }

  Future<FlintResponse<T>> _handleTextResponse<T>(
    HttpClientResponse response,
    List<int> bytes,
    JsonParser<T>? parser,
  ) async {
    final textData = utf8.decode(bytes);
    T data;

    if (parser != null) {
      try {
        data = parser(textData);
      } catch (e) {
        data = _defaultParser<T>(textData, FlintResponseType.text);
      }
    } else {
      data = _defaultParser<T>(textData, FlintResponseType.text);
    }

    return FlintResponse<T>(
      statusCode: response.statusCode,
      data: data,
      type: FlintResponseType.text,
      headers: response.headers,
    );
  }

  Future<FlintResponse<T>> _handleBinaryResponse<T>(
    HttpClientResponse response,
    List<int> bytes,
    String? saveFilePath,
    JsonParser<T>? parser,
  ) async {
    final fileName =
        saveFilePath ?? _extractFileName(response, Uri.parse('$baseUrl'));
    final file = File(fileName);
    await file.writeAsBytes(bytes);

    T data;
    if (parser != null) {
      try {
        data = parser(file);
      } catch (e) {
        data = _defaultParser<T>(file, FlintResponseType.file);
      }
    } else {
      data = _defaultParser<T>(file, FlintResponseType.file);
    }

    return FlintResponse<T>(
      statusCode: response.statusCode,
      data: data,
      type: FlintResponseType.file,
      headers: response.headers,
    );
  }

  // Smart default parser that handles common cases
  T _defaultParser<T>(dynamic data, FlintResponseType responseType) {
    // If T is dynamic or matches the raw data type, return as-is
    if (T == dynamic || data is T) {
      return data as T;
    }

    // Handle common type conversions
    switch (T) {
      case String:
        return data.toString() as T;
      case int:
        if (data is String) {
          return int.tryParse(data) as T? ?? 0 as T;
        }
        return (data is num ? data.toInt() : 0) as T;
      case double:
        if (data is String) {
          return double.tryParse(data) as T? ?? 0.0 as T;
        }
        return (data is num ? data.toDouble() : 0.0) as T;
      case bool:
        if (data is String) {
          return (data.toLowerCase() == 'true') as T;
        }
        return (data is bool ? data : false) as T;
      case Map:
        if (data is String && responseType == FlintResponseType.json) {
          try {
            return jsonDecode(data) as T;
          } catch (e) {
            return {data: data} as T;
          }
        }
        return (data is Map ? data : {}) as T;
      case List:
        if (data is String && responseType == FlintResponseType.json) {
          try {
            return jsonDecode(data) as T;
          } catch (e) {
            return [data] as T;
          }
        }
        return (data is List ? data : [data]) as T;
      default:
        if (responseType == FlintResponseType.json && data is Map) {
          return data as T;
        }

        try {
          return data as T;
        } catch (e) {
          throw FlintError('Unable to convert $data to type $T');
        }
    }
  }

  String _extractFileName(HttpClientResponse response, Uri url) {
    final contentDisposition = response.headers.value('content-disposition');
    if (contentDisposition != null) {
      final match = RegExp('filename="([^"]+)"').firstMatch(contentDisposition);
      if (match != null) return match.group(1)!;
    }

    return url.pathSegments.isNotEmpty
        ? url.pathSegments.last
        : 'download_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Logs, handles, or throws errors internally and triggers the
  /// optional [onError] callback.
  FlintResponse<T> _handleError<T>(FlintError error) {
    _log('Error: ${error.message}');
    if (onError != null) onError!(error);
    return FlintResponse.error(error);
  }

  Future<List<int>> _readAllBytes(HttpClientResponse response) async {
    final List<int> bytes = [];
    final contentLength = response.contentLength;
    int received = 0;

    await for (var chunk in response) {
      bytes.addAll(chunk);
      received += chunk.length;

      if (contentLength != -1) {
        final progress = (received / contentLength * 100).round();
        _log('Download progress: $progress%');
      }
    }
    return bytes;
  }

  /// Downloads a file from [url] and saves it to [savePath] while
  /// optionally reporting [onProgress].
  Future<File> downloadFile(
    String url, {
    required String savePath,
    ProgressCallback? onProgress,
  }) async {
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
  }
}
