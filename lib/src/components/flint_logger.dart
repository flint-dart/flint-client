class FlintLogger {
  final bool debug;
  final Set<String> redactedHeaders;

  const FlintLogger({required this.debug, required this.redactedHeaders});

  void log(String message) {
    if (debug) {
      print('[FlintClient] $message');
    }
  }

  Map<String, String> sanitizeHeaders(Map<String, String> source) {
    final sanitized = <String, String>{};
    source.forEach((key, value) {
      if (redactedHeaders.contains(key.toLowerCase())) {
        sanitized[key] = '***REDACTED***';
      } else {
        sanitized[key] = value;
      }
    });
    return sanitized;
  }
}
