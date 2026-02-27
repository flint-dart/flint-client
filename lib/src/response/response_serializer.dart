import 'dart:convert';
import 'dart:io';

import '../flint_error.dart';
import '../flint_response.dart';
import '../request/request_context.dart';

class ResponseSerializerInput {
  final HttpClientResponse response;
  final List<int> bytes;
  final Uri? requestUrl;
  final String? baseUrl;
  final String? saveFilePath;
  final RequestContext? context;

  const ResponseSerializerInput({
    required this.response,
    required this.bytes,
    this.requestUrl,
    this.baseUrl,
    this.saveFilePath,
    this.context,
  });
}

class ResponseSerializerResult {
  final FlintResponseType type;
  final dynamic data;

  const ResponseSerializerResult({required this.type, required this.data});
}

abstract class ResponseSerializer {
  bool canHandle(String contentType);

  Future<ResponseSerializerResult> deserialize(ResponseSerializerInput input);
}

class JsonResponseSerializer implements ResponseSerializer {
  const JsonResponseSerializer();

  @override
  bool canHandle(String contentType) =>
      contentType.toLowerCase().contains('application/json');

  @override
  Future<ResponseSerializerResult> deserialize(
    ResponseSerializerInput input,
  ) async {
    try {
      dynamic data;
      try {
        data = jsonDecode(utf8.decode(input.bytes));
      } catch (_) {
        data = utf8.decode(input.bytes);
      }

      return ResponseSerializerResult(type: FlintResponseType.json, data: data);
    } catch (e) {
      throw FlintError('JSON response deserialization failed: ${e.toString()}');
    }
  }
}

class TextResponseSerializer implements ResponseSerializer {
  const TextResponseSerializer();

  @override
  bool canHandle(String contentType) {
    final lower = contentType.toLowerCase();
    return lower.contains('text') ||
        lower.contains('html') ||
        lower == 'application/xml' ||
        lower == 'text/xml' ||
        lower.endsWith('+xml');
  }

  @override
  Future<ResponseSerializerResult> deserialize(
    ResponseSerializerInput input,
  ) async {
    try {
      return ResponseSerializerResult(
        type: FlintResponseType.text,
        data: utf8.decode(input.bytes),
      );
    } catch (e) {
      throw FlintError('Text response deserialization failed: ${e.toString()}');
    }
  }
}

class BinaryResponseSerializer implements ResponseSerializer {
  const BinaryResponseSerializer();

  @override
  bool canHandle(String contentType) => true;

  @override
  Future<ResponseSerializerResult> deserialize(
    ResponseSerializerInput input,
  ) async {
    try {
      final fileName = input.saveFilePath ?? _extractFileName(input);
      final file = File(fileName);
      final directory = file.parent;
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      await file.writeAsBytes(input.bytes);

      return ResponseSerializerResult(type: FlintResponseType.file, data: file);
    } catch (e) {
      throw FlintError(
        'Binary response deserialization failed: ${e.toString()}',
      );
    }
  }

  String _extractFileName(ResponseSerializerInput input) {
    try {
      final contentDisposition = input.response.headers.value(
        'content-disposition',
      );
      if (contentDisposition != null) {
        final match = RegExp(
          'filename="([^"]+)"',
        ).firstMatch(contentDisposition);
        if (match != null) return match.group(1)!;
      }

      final sourceUri =
          input.requestUrl ??
          (input.baseUrl != null ? Uri.tryParse(input.baseUrl!) : null);
      if (sourceUri != null && sourceUri.pathSegments.isNotEmpty) {
        return sourceUri.pathSegments.last;
      }
      return 'download_${DateTime.now().millisecondsSinceEpoch}';
    } catch (_) {
      return 'download_${DateTime.now().millisecondsSinceEpoch}';
    }
  }
}
