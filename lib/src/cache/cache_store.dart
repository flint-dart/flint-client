import 'package:flint_client/src/cache/cached_response.dart';

/// Cache storage abstraction
abstract class CacheStore {
  Future<CachedResponse<T>?> get<T>(String key);
  Future<void> set<T>(String key, CachedResponse<T> response);
  Future<void> delete(String key);
  Future<void> clear();
  Future<void> cleanup(DateTime before);
  Future<int> size();
}
