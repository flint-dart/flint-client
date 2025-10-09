import 'package:flint_client/src/cache/cache_store.dart';
import 'package:flint_client/src/cache/cached_response.dart';

/// In-memory cache implementation
class MemoryCacheStore implements CacheStore {
  final Map<String, CachedResponse<dynamic>> _cache = {};
  final int maxSize;

  MemoryCacheStore({this.maxSize = 100});

  @override
  Future<CachedResponse<T>?> get<T>(String key) async {
    final cached = _cache[key];
    if (cached == null) return null;

    if (cached.isExpired) {
      _cache.remove(key);
      return null;
    }

    return cached as CachedResponse<T>;
  }

  @override
  Future<void> set<T>(String key, CachedResponse<T> response) async {
    // Evict if we're at capacity
    if (_cache.length >= maxSize && !_cache.containsKey(key)) {
      _evictOldest();
    }

    _cache[key] = response;
  }

  @override
  Future<void> delete(String key) async {
    _cache.remove(key);
  }

  @override
  Future<void> clear() async {
    _cache.clear();
  }

  @override
  Future<void> cleanup(DateTime before) async {
    // Remove entries that expired BEFORE the given timestamp
    // This means entries whose expiration time is before the 'before' parameter
    _cache.removeWhere((key, value) {
      final expirationTime = value.cachedAt.add(value.maxAge);
      return expirationTime.isBefore(before);
    });
  }

  @override
  Future<int> size() async => _cache.length;

  void _evictOldest() {
    if (_cache.isEmpty) return;

    String? oldestKey;
    DateTime? oldestTime;

    for (final entry in _cache.entries) {
      if (oldestTime == null || entry.value.cachedAt.isBefore(oldestTime)) {
        oldestTime = entry.value.cachedAt;
        oldestKey = entry.key;
      }
    }

    if (oldestKey != null) {
      _cache.remove(oldestKey);
    }
  }
}
