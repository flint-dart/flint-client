import 'dart:convert';
import 'dart:io';

import 'request_context.dart';

/// Serialized request payload with optional content type.
class SerializedBody {
  final List<int> bytes;
  final ContentType? contentType;

  const SerializedBody({required this.bytes, this.contentType});
}

/// Encodes request payloads into bytes.
abstract class BodySerializer {
  bool canSerialize(dynamic body, {String? contentType});

  SerializedBody serialize(
    dynamic body, {
    String? contentType,
    RequestContext? context,
  });
}

class JsonBodySerializer implements BodySerializer {
  const JsonBodySerializer();

  @override
  bool canSerialize(dynamic body, {String? contentType}) {
    if (contentType != null) {
      final lower = contentType.toLowerCase();
      if (lower.contains('application/json')) return true;
      if (lower.contains('xml')) return false;
      if (lower.contains('x-www-form-urlencoded')) return false;
    }

    if (body is Map || body is List) return true;
    return body is String;
  }

  @override
  SerializedBody serialize(
    dynamic body, {
    String? contentType,
    RequestContext? context,
  }) {
    final payload = body is String ? body : jsonEncode(body);
    final inferredType = ContentType('application', 'json', charset: 'utf-8');
    return SerializedBody(
      bytes: utf8.encode(payload),
      contentType: inferredType,
    );
  }
}

class XmlBodySerializer implements BodySerializer {
  const XmlBodySerializer();

  @override
  bool canSerialize(dynamic body, {String? contentType}) {
    final lowered = contentType?.toLowerCase();
    if (lowered != null &&
        (lowered.contains('application/xml') ||
            lowered.contains('text/xml') ||
            lowered.contains('+xml'))) {
      return true;
    }

    return body is String && body.trimLeft().startsWith('<');
  }

  @override
  SerializedBody serialize(
    dynamic body, {
    String? contentType,
    RequestContext? context,
  }) {
    final inferredType = ContentType('application', 'xml', charset: 'utf-8');
    return SerializedBody(
      bytes: body is List<int> ? body : utf8.encode(body.toString()),
      contentType: inferredType,
    );
  }
}

class FormUrlEncodedBodySerializer implements BodySerializer {
  const FormUrlEncodedBodySerializer();

  @override
  bool canSerialize(dynamic body, {String? contentType}) {
    if (body is! Map) return false;
    final lowered = contentType?.toLowerCase();
    return lowered != null &&
        lowered.contains('application/x-www-form-urlencoded');
  }

  @override
  SerializedBody serialize(
    dynamic body, {
    String? contentType,
    RequestContext? context,
  }) {
    final map = Map<String, String>.fromEntries(
      (body as Map).entries.map(
        (e) => MapEntry(e.key.toString(), e.value.toString()),
      ),
    );
    final encoded = Uri(queryParameters: map).query;
    final inferredType = ContentType(
      'application',
      'x-www-form-urlencoded',
      charset: 'utf-8',
    );
    return SerializedBody(
      bytes: utf8.encode(encoded),
      contentType: inferredType,
    );
  }
}
