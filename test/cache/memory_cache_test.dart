/// Tests for MemoryCacheStore
library;

import 'package:clock/clock.dart';
import 'package:flint_client/flint_client.dart';
import 'package:test/test.dart';

void main() {
  group('MemoryCacheStore', () {
    late MemoryCacheStore cache;
    late FlintResponse<String> testResponse;

    setUp(() {
      cache = MemoryCacheStore(maxSize: 3);
      testResponse = FlintResponse<String>(statusCode: 200, data: 'test data');
    });

    test('stores and retrieves cached response', () async {
      final cached = CachedResponse<String>(
        response: testResponse,
        key: 'test-key',
        maxAge: Duration(minutes: 5),
      );

      await cache.set('test-key', cached);
      final retrieved = await cache.get<String>('test-key');

      expect(retrieved, equals(cached));
    });

    test('returns null for non-existent key', () async {
      final result = await cache.get<String>('non-existent');
      expect(result, isNull);
    });

    test('returns null for expired response', () async {
      final expiredResponse = CachedResponse<String>(
        response: testResponse,
        key: 'expired-key',
        maxAge: Duration(milliseconds: 1), // Very short lifetime
      );

      await cache.set('expired-key', expiredResponse);

      // Wait for expiration
      await Future.delayed(Duration(milliseconds: 10));

      final result = await cache.get<String>('expired-key');
      expect(result, isNull);
    });

    test('evicts oldest entries when at capacity', () async {
      // Fill cache to capacity
      for (int i = 1; i <= 3; i++) {
        final cached = CachedResponse<String>(
          response: testResponse,
          key: 'key-$i',
          maxAge: Duration(minutes: 5),
        );
        await cache.set('key-$i', cached);
      }

      // Add one more - should evict the oldest
      final newCached = CachedResponse<String>(
        response: testResponse,
        key: 'key-4',
        maxAge: Duration(minutes: 5),
      );
      await cache.set('key-4', newCached);

      // Oldest should be evicted
      final oldest = await cache.get<String>('key-1');
      expect(oldest, isNull);

      // Newer entries should still be there
      expect(await cache.get<String>('key-2'), isNotNull);
      expect(await cache.get<String>('key-3'), isNotNull);
      expect(await cache.get<String>('key-4'), isNotNull);
    });

    test('deletes specific key', () async {
      final cached = CachedResponse<String>(
        response: testResponse,
        key: 'delete-key',
        maxAge: Duration(minutes: 5),
      );

      await cache.set('delete-key', cached);
      await cache.delete('delete-key');

      final result = await cache.get<String>('delete-key');
      expect(result, isNull);
    });

    test('clears all entries', () async {
      await cache.set(
        'key1',
        CachedResponse<String>(
          response: testResponse,
          key: 'key1',
          maxAge: Duration(minutes: 5),
        ),
      );
      await cache.set(
        'key2',
        CachedResponse<String>(
          response: testResponse,
          key: 'key2',
          maxAge: Duration(minutes: 5),
        ),
      );

      await cache.clear();

      expect(await cache.get<String>('key1'), isNull);
      expect(await cache.get<String>('key2'), isNull);
    });

    // In test/cache/memory_cache_test.dart around line 141
    test('MemoryCacheStore cleans up expired entries', () async {
      final store = MemoryCacheStore();
      final key = 'test-key';
      final response = FlintResponse<String>(
        statusCode: 200,
        data: 'test data',
      );

      final cached = CachedResponse<String>(
        response: response,
        key: key,
        maxAge: Duration(seconds: 1), // Very short expiration
      );

      await store.set(key, cached);

      // Wait for expiration
      await Future.delayed(Duration(seconds: 2));

      // Cleanup should remove expired entries
      await store.cleanup(clock.now().add(Duration(seconds: 5)));

      final result = await store.get<String>(key);
      expect(result, isNull); // Should be null after cleanup
    });

    test('reports correct size', () async {
      expect(await cache.size(), 0);

      await cache.set(
        'key1',
        CachedResponse<String>(
          response: testResponse,
          key: 'key1',
          maxAge: Duration(minutes: 5),
        ),
      );

      expect(await cache.size(), 1);

      await cache.set(
        'key2',
        CachedResponse<String>(
          response: testResponse,
          key: 'key2',
          maxAge: Duration(minutes: 5),
        ),
      );

      expect(await cache.size(), 2);
    });
  });
}
