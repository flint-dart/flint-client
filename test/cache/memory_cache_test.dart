/// Tests for MemoryCacheStore
library;

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

    test('cleans up expired entries', () async {
      // Create a fresh response (will expire in 5 minutes)
      final freshResponse = CachedResponse<String>(
        response: FlintResponse<String>(statusCode: 200, data: 'fresh'),
        key: 'fresh',
        maxAge: Duration(minutes: 5),
      );

      // Create an expired response (expired 1 minute ago)
      final expiredResponse = CachedResponse<String>(
        response: FlintResponse<String>(statusCode: 200, data: 'expired'),
        key: 'expired',
        maxAge: Duration(minutes: 1),
        cachedAt: DateTime.now().subtract(
          Duration(minutes: 2),
        ), // Cached 2 mins ago, maxAge 1 min = expired 1 min ago
      );

      await cache.set('fresh', freshResponse);
      await cache.set('expired', expiredResponse);

      // Verify both are in cache initially
      expect(await cache.get<String>('fresh'), isNotNull);
      expect(await cache.get<String>('expired'), isNotNull);

      // Cleanup entries that expired before now
      await cache.cleanup(DateTime.now());

      // Fresh should still be there, expired should be removed
      expect(await cache.get<String>('fresh'), isNotNull);
      expect(await cache.get<String>('expired'), isNull);
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
