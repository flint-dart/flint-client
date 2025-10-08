import 'package:flint_client/src/flint_response.dart';
import 'package:clock/clock.dart'; // For testable time

/// Cached response data
class CachedResponse<T> {
  final FlintResponse<T> response;
  final DateTime cachedAt;
  final Duration maxAge;
  final String key;

  CachedResponse({
    required this.response,
    required this.key,
    required this.maxAge,
    DateTime? cachedAt,
  }) : cachedAt = cachedAt ?? clock.now();

  bool get isExpired => clock.now().isAfter(cachedAt.add(maxAge));
  bool get isValid => !isExpired;

  double get ageInSeconds =>
      clock.now().difference(cachedAt).inSeconds.toDouble();
  double get freshnessRatio => 1.0 - (ageInSeconds / maxAge.inSeconds);
}
