import 'dart:math';

/// Mutable request-scoped state passed across client components.
class RequestContext {
  static final Random _random = Random();

  final String method;
  final Uri url;
  final String correlationId;

  int attempt;
  DateTime? startedAt;
  DateTime? endedAt;
  Duration? totalDuration;
  bool cacheHit;
  String? cacheKey;

  final Map<String, dynamic> metadata;

  RequestContext({
    required this.method,
    required this.url,
    String? correlationId,
    this.attempt = 1,
    this.startedAt,
    this.endedAt,
    this.totalDuration,
    this.cacheHit = false,
    this.cacheKey,
    Map<String, dynamic>? metadata,
  }) : correlationId = correlationId ?? _generateCorrelationId(),
       metadata = metadata ?? <String, dynamic>{};

  void setValue(String key, dynamic value) {
    metadata[key] = value;
  }

  T? getValue<T>(String key) {
    final value = metadata[key];
    if (value is T) {
      return value;
    }
    return null;
  }

  static String _generateCorrelationId() {
    final now = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final rand = _random.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
    return '$now-$rand';
  }
}
