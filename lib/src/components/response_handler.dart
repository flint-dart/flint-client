import 'dart:convert';
import 'dart:io';

import '../flint_error.dart';
import '../flint_response.dart';
import '../request/request_context.dart';
import '../response/parse_mode.dart';
import '../response/response_serializer.dart';
import '../status_code_config.dart';

class ResponseHandler {
  final StatusCodeConfig statusCodeConfig;
  final String? baseUrl;
  final void Function(String message) log;
  final List<ResponseSerializer> serializers;

  ResponseHandler({
    required this.statusCodeConfig,
    required this.baseUrl,
    required this.log,
    required this.serializers,
  });

  Future<FlintResponse<T>> handleResponse<T>(
    HttpClientResponse response,
    String? saveFilePath,
    T Function(dynamic data)? parser, {
    Uri? url,
    String? method,
    Duration? duration,
    StatusCodeConfig? statusConfig,
    RequestContext? context,
    ResponseParseMode parseMode = ResponseParseMode.lenient,
  }) async {
    try {
      final effectiveStatusConfig = statusConfig ?? statusCodeConfig;

      final contentType = response.headers.contentType?.mimeType ?? '';
      final bytes = await _readAllBytes(response);

      if (effectiveStatusConfig.isError(response.statusCode)) {
        final errorMessage = utf8.decode(bytes, allowMalformed: true);
        throw FlintError.fromHttpResponse(
          response,
          customMessage: 'HTTP ${response.statusCode}: $errorMessage',
          url: url,
          method: method,
        );
      }

      final serialized = await _deserializeWithFallback(
        response: response,
        bytes: bytes,
        contentType: contentType,
        url: url,
        saveFilePath: saveFilePath,
        context: context,
        parseMode: parseMode,
      );

      dynamic parsedData;
      if (parser != null) {
        try {
          parsedData = parser(serialized.data);
        } catch (e) {
          if (parseMode == ResponseParseMode.strict) {
            throw FlintError(
              'Response parsing failed: ${e.toString()}',
              kind: FlintErrorKind.parse,
            );
          }
          parsedData = _defaultParser<T>(
            serialized.data,
            serialized.type,
            parseMode: parseMode,
          );
        }
      } else {
        parsedData = _defaultParser<T>(
          serialized.data,
          serialized.type,
          parseMode: parseMode,
        );
      }

      return FlintResponse<T>(
        statusCode: response.statusCode,
        data: parsedData as T,
        type: serialized.type,
        headers: response.headers,
        url: url,
        method: method,
        duration: duration,
        statusConfig: effectiveStatusConfig,
      );
    } catch (e) {
      if (e is FlintError) rethrow;
      throw FlintError('Response handling failed: ${e.toString()}');
    }
  }

  T _defaultParser<T>(
    dynamic data,
    FlintResponseType responseType, {
    required ResponseParseMode parseMode,
  }) {
    if (parseMode == ResponseParseMode.strict) {
      return _strictParser<T>(data, responseType);
    }

    try {
      if (T == dynamic || data is T) {
        return data as T;
      }

      if (T == Map<String, dynamic>) {
        if (data is Map) {
          final result = <String, dynamic>{};
          for (final key in data.keys) {
            result[key.toString()] = data[key];
          }
          return result as T;
        }
        if (data is String) {
          try {
            final decoded = jsonDecode(data);
            if (decoded is Map) {
              final result = <String, dynamic>{};
              for (final key in decoded.keys) {
                result[key.toString()] = decoded[key];
              }
              return result as T;
            }
          } catch (_) {
            return {'data': data} as T;
          }
        }
        return <String, dynamic>{} as T;
      }

      switch (T) {
        case const (String):
          return data.toString() as T;
        case const (int):
          if (data is String) {
            return int.tryParse(data) as T? ?? 0 as T;
          }
          return (data is num ? data.toInt() : 0) as T;
        case const (double):
          if (data is String) {
            return double.tryParse(data) as T? ?? 0.0 as T;
          }
          return (data is num ? data.toDouble() : 0.0) as T;
        case const (bool):
          if (data is String) {
            return (data.toLowerCase() == 'true') as T;
          }
          return (data is bool ? data : false) as T;
        case const (Map):
          if (data is String && responseType == FlintResponseType.json) {
            try {
              return jsonDecode(data) as T;
            } catch (_) {
              return {data: data} as T;
            }
          }
          return (data is Map ? data : {}) as T;
        case const (List):
          if (data is String && responseType == FlintResponseType.json) {
            try {
              return jsonDecode(data) as T;
            } catch (_) {
              return [data] as T;
            }
          }
          return (data is List ? data : [data]) as T;
        default:
          try {
            return data as T;
          } catch (_) {
            throw FlintError(
              'Cannot parse response data from ${data.runtimeType} to $T',
            );
          }
      }
    } catch (e) {
      if (e is FlintError) rethrow;
      throw FlintError('Response parsing failed: ${e.toString()}');
    }
  }

  T _strictParser<T>(dynamic data, FlintResponseType responseType) {
    try {
      if (T == dynamic || data is T) {
        return data as T;
      }

      if (T == Map<String, dynamic>) {
        if (data is Map) {
          return Map<String, dynamic>.from(data) as T;
        }
        if (data is String && responseType == FlintResponseType.json) {
          final decoded = jsonDecode(data);
          if (decoded is Map) {
            return Map<String, dynamic>.from(decoded) as T;
          }
        }
        throw FlintError(
          'Cannot strictly parse ${data.runtimeType} to $T',
          kind: FlintErrorKind.parse,
        );
      }

      switch (T) {
        case const (String):
          if (data is String) return data as T;
          break;
        case const (int):
          if (data is int) return data as T;
          if (data is num) return data.toInt() as T;
          break;
        case const (double):
          if (data is num) return data.toDouble() as T;
          break;
        case const (bool):
          if (data is bool) return data as T;
          break;
        case const (Map):
          if (data is Map) return data as T;
          break;
        case const (List):
          if (data is List) return data as T;
          break;
        default:
          if (data is T) return data;
      }

      throw FlintError(
        'Cannot strictly parse ${data.runtimeType} to $T',
        kind: FlintErrorKind.parse,
      );
    } catch (e) {
      if (e is FlintError) rethrow;
      throw FlintError(
        'Response strict parsing failed: ${e.toString()}',
        kind: FlintErrorKind.parse,
      );
    }
  }

  Future<ResponseSerializerResult> _deserializeWithFallback({
    required HttpClientResponse response,
    required List<int> bytes,
    required String contentType,
    Uri? url,
    String? saveFilePath,
    RequestContext? context,
    required ResponseParseMode parseMode,
  }) async {
    final candidates = serializers
        .where((s) => s.canHandle(contentType))
        .toList();
    if (candidates.isEmpty) {
      candidates.add(const BinaryResponseSerializer());
    }

    FlintError? lastError;
    for (final serializer in candidates) {
      try {
        return await serializer.deserialize(
          ResponseSerializerInput(
            response: response,
            bytes: bytes,
            requestUrl: url,
            baseUrl: baseUrl,
            saveFilePath: saveFilePath,
            context: context,
          ),
        );
      } catch (e) {
        final error = e is FlintError
            ? e
            : FlintError(
                'Response deserialization failed: ${e.toString()}',
                kind: FlintErrorKind.parse,
              );
        lastError = error;
        if (parseMode == ResponseParseMode.strict) {
          rethrow;
        }
      }
    }

    if (parseMode == ResponseParseMode.lenient) {
      return ResponseSerializerResult(
        type: FlintResponseType.text,
        data: utf8.decode(bytes, allowMalformed: true),
      );
    }

    throw lastError ??
        FlintError(
          'No response serializer matched content type: $contentType',
          kind: FlintErrorKind.parse,
        );
  }

  Future<List<int>> _readAllBytes(HttpClientResponse response) async {
    try {
      final bytes = <int>[];
      final contentLength = response.contentLength;
      int received = 0;

      await for (var chunk in response) {
        bytes.addAll(chunk);
        received += chunk.length;

        if (contentLength != -1) {
          final progress = (received / contentLength * 100).round();
          log('Download progress: $progress%');
        }
      }
      return bytes;
    } catch (e) {
      throw FlintError('Failed to read response bytes: ${e.toString()}');
    }
  }
}
