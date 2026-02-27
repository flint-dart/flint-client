import 'dart:convert';

import 'package:clock/clock.dart';

import '../cache/cache.dart';
import '../flint_response.dart';
import '../request/request_context.dart';

class CacheLayer {
  final CacheStore cacheStore;
  final CacheConfig defaultCacheConfig;
  final void Function(String message) log;

  const CacheLayer({
    required this.cacheStore,
    required this.defaultCacheConfig,
    required this.log,
  });

  bool shouldCache(String method, CacheConfig effectiveConfig) {
    return effectiveConfig.maxAge > Duration.zero &&
        (method.toUpperCase() == 'GET' ||
            effectiveConfig != const CacheConfig());
  }

  String generateCacheKey(
    String baseUrl,
    String method,
    String path, {
    Map<String, dynamic>? queryParameters,
    dynamic body,
    Map<String, String>? headers,
  }) {
    final uri = Uri.parse('$baseUrl$path');
    final keyComponents = [
      method.toUpperCase(),
      uri.toString(),
      if (queryParameters != null && queryParameters.isNotEmpty)
        Uri(queryParameters: queryParameters).toString(),
      if (body != null) jsonEncode(_sortJson(body)),
      if (headers != null && headers.isNotEmpty) jsonEncode(_sortMap(headers)),
    ];

    return keyComponents.join('|').hashCode.toString();
  }

  Future<CachedResponse<T>?> get<T>(String key, {RequestContext? context}) {
    context?.cacheKey = key;
    return cacheStore.get<T>(key);
  }

  Future<void> cacheResponse<T>(
    String key,
    FlintResponse<T> response,
    CacheConfig config, {
    RequestContext? context,
  }) async {
    context?.cacheKey = key;
    final cachedResponse = CachedResponse<T>(
      response: response,
      key: key,
      maxAge: config.maxAge,
    );
    await cacheStore.set<T>(key, cachedResponse);
  }

  Future<void> clear() async {
    await cacheStore.clear();
    log('Cache cleared');
  }

  Future<void> remove(String key) async {
    await cacheStore.delete(key);
    log('Removed cached response: $key');
  }

  Future<void> cleanupExpired() async {
    await cacheStore.cleanup(clock.now());
    log('Expired cache entries cleaned up');
  }

  Future<int> size() async => cacheStore.size();

  Future<void> preload(Map<String, FlintResponse<dynamic>> responses) async {
    for (final entry in responses.entries) {
      final cachedResponse = CachedResponse(
        response: entry.value,
        key: entry.key,
        maxAge: defaultCacheConfig.maxAge,
      );
      await cacheStore.set(entry.key, cachedResponse);
    }
    log('Preloaded ${responses.length} responses into cache');
  }

  dynamic _sortJson(dynamic data) {
    if (data is Map) {
      final sortedMap = <String, dynamic>{};
      final keys = data.keys.toList()..sort();
      for (final key in keys) {
        sortedMap[key] = _sortJson(data[key]);
      }
      return sortedMap;
    } else if (data is List) {
      return data.map(_sortJson).toList();
    }
    return data;
  }

  Map<String, String> _sortMap(Map<String, String> map) {
    final sortedMap = <String, String>{};
    final keys = map.keys.toList()..sort();
    for (final key in keys) {
      sortedMap[key] = map[key]!;
    }
    return sortedMap;
  }
}
