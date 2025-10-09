import 'package:flint_client/flint_client.dart';

/// Caching examples for Flint HTTP Client
///
/// This example demonstrates the powerful caching system including:
/// - Basic response caching
/// - Cache configuration
/// - Cache management
/// - Force refresh scenarios

void main() async {
  // Create client with caching enabled
  final client = FlintClient(
    baseUrl: 'https://jsonplaceholder.typicode.com',
    defaultCacheConfig: CacheConfig(
      maxAge: Duration(minutes: 5), // Cache responses for 5 minutes
      maxSize: 50, // Maximum 50 cached responses
    ),
    debug: true,
  );

  try {
    // Basic caching - First request will be cached
    print('=== Basic Caching ===');
    final startTime1 = DateTime.now();
    await client.get<Map<String, dynamic>>(
      '/posts/1',
      cacheConfig: CacheConfig(maxAge: Duration(minutes: 2)),
    );
    final duration1 = DateTime.now().difference(startTime1);
    print('First request took: ${duration1.inMilliseconds}ms');

    // Second request - should be served from cache
    final startTime2 = DateTime.now();
    await client.get<Map<String, dynamic>>(
      '/posts/1',
      cacheConfig: CacheConfig(maxAge: Duration(minutes: 2)),
    );
    final duration2 = DateTime.now().difference(startTime2);
    print('Second request took: ${duration2.inMilliseconds}ms (cached)');
    print(
      'Cache speedup: ${(duration1.inMilliseconds / duration2.inMilliseconds).toStringAsFixed(1)}x faster',
    );

    // Force refresh - bypass cache
    print('\n=== Force Refresh ===');
    final forceRefreshResponse = await client.get<Map<String, dynamic>>(
      '/posts/1',
      cacheConfig: CacheConfig(
        maxAge: Duration(minutes: 2),
        forceRefresh: true, // Ignore cache and fetch fresh data
      ),
    );
    print('Force refresh completed: ${forceRefreshResponse.statusCode}');

    // Different cache durations per endpoint
    print('\n=== Per-Request Cache Configuration ===');

    // User data - cache for longer (15 minutes)
    await client.get<Map<String, dynamic>>(
      '/users/1',
      cacheConfig: CacheConfig(maxAge: Duration(minutes: 15)),
    );
    print('User data cached for 15 minutes');

    // Posts data - cache for shorter time (2 minutes)
    await client.get<List<dynamic>>(
      '/posts',
      cacheConfig: CacheConfig(maxAge: Duration(minutes: 2)),
    );
    print('Posts data cached for 2 minutes');

    // Comments data - no caching
    await client.get<List<dynamic>>(
      '/comments',
      cacheConfig: CacheConfig(maxAge: Duration.zero), // Disable caching
    );
    print('Comments data not cached');

    // Cache management operations
    print('\n=== Cache Management ===');

    // Check current cache size
    final cacheSize = await client.cacheSize;
    print('Current cache size: $cacheSize items');

    // Remove specific cached item
    await client.removeCachedResponse('some-cache-key');
    print('Removed specific cache entry');

    // Clean up expired cache entries
    await client.cleanupExpiredCache();
    print('Expired cache entries cleaned up');

    // Clear entire cache
    await client.clearCache();
    print('Cache cleared completely');

    // Cache with different parameters
    print('\n=== Cache Key Variations ===');

    // Same endpoint, different query parameters = different cache keys
    client.get<List<dynamic>>(
      '/posts?page=1&limit=10',
      cacheConfig: CacheConfig(maxAge: Duration(minutes: 5)),
    );
    print('Cached posts page 1');

    await client.get<List<dynamic>>(
      '/posts?page=2&limit=10',
      cacheConfig: CacheConfig(maxAge: Duration(minutes: 5)),
    );
    print('Cached posts page 2 (different cache key)');

    // Verify both are cached separately
    final newCacheSize = await client.cacheSize;
    print('Cache now contains $newCacheSize separate entries');

    // Cache statistics demonstration
    print('\n=== Cache Statistics ===');
    // Make several requests to demonstrate cache hits
    final endpoints = [
      '/posts/1',
      '/posts/2',
      '/posts/3',
      '/users/1',
      '/users/2',
    ];

    for (var endpoint in endpoints) {
      final startTime = DateTime.now();
      await client.get<Map<String, dynamic>>(
        endpoint,
        cacheConfig: CacheConfig(maxAge: Duration(minutes: 10)),
      );
      final duration = DateTime.now().difference(startTime);
      print('$endpoint - ${duration.inMilliseconds}ms');
    }

    // Second pass - should be much faster due to caching
    print('\n--- Second Pass (Cached) ---');
    for (var endpoint in endpoints) {
      final startTime = DateTime.now();
      await client.get<Map<String, dynamic>>(
        endpoint,
        cacheConfig: CacheConfig(maxAge: Duration(minutes: 10)),
      );
      final duration = DateTime.now().difference(startTime);
      print('$endpoint - ${duration.inMilliseconds}ms (cached)');
    }
  } catch (e) {
    print('Error in caching examples: $e');
  } finally {
    client.dispose();
  }
}
