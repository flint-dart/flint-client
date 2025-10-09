/// Advanced usage examples for Flint HTTP Client
///
/// This example demonstrates advanced features and patterns including:
/// - Combined caching, retry, and interceptors
/// - Custom response parsing
/// - Batch operations
/// - Error recovery strategies
/// - Performance optimization
library;

import 'package:flint_client/flint_client.dart';

// Advanced data models
class Post {
  final int id;
  final String title;
  final String body;
  final int userId;

  Post({
    required this.id,
    required this.title,
    required this.body,
    required this.userId,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'],
      title: json['title'],
      body: json['body'],
      userId: json['userId'],
    );
  }

  @override
  String toString() => 'Post($id): $title';
}

class UserWithPosts {
  final int id;
  final String name;
  final String email;
  final List<Post> posts;

  UserWithPosts({
    required this.id,
    required this.name,
    required this.email,
    required this.posts,
  });

  @override
  String toString() => 'User($id): $name with ${posts.length} posts';
}

void main() async {
  // Create a highly configured client
  final client = FlintClient(
    baseUrl: 'https://jsonplaceholder.typicode.com',
    timeout: Duration(seconds: 10),
    defaultCacheConfig: CacheConfig(
      maxAge: Duration(minutes: 10),
      maxSize: 100,
    ),
    defaultRetryConfig: RetryConfig(
      maxAttempts: 3,
      delay: Duration(seconds: 1),
      maxDelay: Duration(seconds: 10),
    ),
    requestInterceptor: (request) async {
      // Add analytics headers
      request.headers.set('X-Client-Version', '1.0.0');
      request.headers.set('X-Platform', 'Dart');
    },
    responseInterceptor: (response) async {
      // Monitor response times and sizes
      print(
        '📈 Response: ${response.statusCode}, '
        'Content-Length: ${response.contentLength}',
      );
    },
    debug: true,
  );

  try {
    // Complex data fetching with error recovery
    print('=== Complex Data Fetching ===');

    final userWithPosts = await _fetchUserWithPosts(client, 1);
    print('Fetched: $userWithPosts');

    // Batch operations with parallel execution
    print('\n=== Batch Operations ===');
    final batchResults = await _fetchBatchData(client, [1, 2, 3, 4, 5]);
    print('Batch completed: ${batchResults.length} users');

    // Custom response transformation
    print('\n=== Response Transformation ===');
    final transformedResponse = await client
        .get<List<Post>>(
          '/posts',
          parser: (json) {
            if (json is List) {
              return json.map((item) => Post.fromJson(item)).toList();
            }
            throw FlintError('Unexpected response format');
          },
        )
        .then((response) => response.map((posts) => posts.take(5).toList()));

    print('Transformed response: ${transformedResponse.data?.length} posts');

    // Conditional caching based on response
    print('\n=== Conditional Caching ===');
    await client
        .get<Map<String, dynamic>>(
          '/posts/1',
          cacheConfig: CacheConfig(
            maxAge: Duration(minutes: 5),
            forceRefresh: false,
          ),
        )
        .then((response) {
          // Only cache successful responses with data
          if (response.isSuccess && response.data != null) {
            return response;
          }
          // Don't cache error responses
          return response.copyWith();
        });

    // Advanced error recovery
    print('\n=== Advanced Error Recovery ===');
    final recoveredData = await _fetchWithFallback(
      client,
      '/nonexistent-endpoint',
      '/posts/1', // Fallback endpoint
    );
    print('Recovered data: $recoveredData');

    // Performance-optimized parallel requests
    print('\n=== Performance Optimization ===');
    final stopwatch = Stopwatch()..start();

    final parallelResults = await _fetchParallelData(client);
    stopwatch.stop();

    print('Parallel fetch completed in ${stopwatch.elapsedMilliseconds}ms');
    print('Fetched: ${parallelResults.length} items in parallel');

    // Memory management demonstration
    print('\n=== Memory Management ===');

    // Make multiple requests to fill cache
    for (int i = 1; i <= 20; i++) {
      await client.get<Map<String, dynamic>>(
        '/posts/$i',
        cacheConfig: CacheConfig(maxAge: Duration(minutes: 5)),
      );
    }

    final cacheSize = await client.cacheSize;
    print('Cache size after multiple requests: $cacheSize');

    // Clean up cache
    await client.clearCache();
    print('Cache cleared for memory management');

    // Real-world scenario: E-commerce app
    print('\n=== Real-world Scenario: E-commerce ===');
    await _simulateEcommerceScenario(client);
  } catch (e) {
    print('Error in advanced examples: $e');
  } finally {
    client.dispose();
  }
}

// Helper functions for advanced examples

Future<UserWithPosts> _fetchUserWithPosts(
  FlintClient client,
  int userId,
) async {
  try {
    // Fetch user and posts in parallel
    final userFuture = client.get<Map<String, dynamic>>(
      '/users/$userId',
      cacheConfig: CacheConfig(maxAge: Duration(minutes: 15)),
    );

    final postsFuture = client.get<List<dynamic>>(
      '/posts?userId=$userId',
      cacheConfig: CacheConfig(maxAge: Duration(minutes: 5)),
    );

    final results = await Future.wait([userFuture, postsFuture]);

    final userResponse = results[0];
    final postsResponse = results[1];

    if (userResponse.isClientError || postsResponse.isError) {
      throw FlintError('Failed to fetch user data');
    }

    final userData = userResponse.data as Map<String, dynamic>;
    final postsData = postsResponse.data as List<dynamic>;

    return UserWithPosts(
      id: userData['id'],
      name: userData['name'],
      email: userData['email'],
      posts: postsData.map((post) => Post.fromJson(post)).toList(),
    );
  } catch (e) {
    throw FlintError('User data fetch failed: ${e.toString()}');
  }
}

Future<List<Map<String, dynamic>>> _fetchBatchData(
  FlintClient client,
  List<int> userIds,
) async {
  final futures = userIds.map(
    (userId) => client.get<Map<String, dynamic>>(
      '/users/$userId',
      cacheConfig: CacheConfig(maxAge: Duration(minutes: 10)),
      retryConfig: RetryConfig(maxAttempts: 2),
    ),
  );

  final responses = await Future.wait(futures, eagerError: false);

  return responses
      .where((response) => response.isSuccess && response.data != null)
      .map((response) => response.data!)
      .toList();
}

Future<dynamic> _fetchWithFallback(
  FlintClient client,
  String primaryEndpoint,
  String fallbackEndpoint,
) async {
  try {
    final primaryResponse = await client.get<dynamic>(primaryEndpoint);
    if (primaryResponse.isSuccess) {
      return primaryResponse.data;
    }
  } catch (e) {
    print('Primary endpoint failed, trying fallback: $e');
  }

  // Try fallback
  final fallbackResponse = await client.get<dynamic>(fallbackEndpoint);
  return fallbackResponse.data;
}

Future<List<dynamic>> _fetchParallelData(FlintClient client) async {
  const endpoints = [
    '/posts/1',
    '/posts/2',
    '/posts/3',
    '/users/1',
    '/users/2',
    '/comments/1',
  ];

  final futures = endpoints.map(
    (endpoint) => client.get<dynamic>(
      endpoint,
      cacheConfig: CacheConfig(maxAge: Duration(minutes: 5)),
    ),
  );

  final responses = await Future.wait(futures, eagerError: false);

  return responses
      .where((response) => response.isSuccess)
      .map((response) => response.data)
      .toList();
}

Future<void> _simulateEcommerceScenario(FlintClient client) async {
  // Simulate an e-commerce app flow

  // 1. Fetch product catalog (cache aggressively)
  print('📦 Fetching product catalog...');
  final products = await client.get<List<dynamic>>(
    '/posts', // Simulating products
    cacheConfig: CacheConfig(maxAge: Duration(minutes: 30)),
    parser: (json) => (json as List).take(10).toList(),
  );
  print('✅ Loaded ${products.data?.length} products');

  // 2. Fetch user profile (cache user data)
  print('👤 Fetching user profile...');
  final userProfile = await client.get<Map<String, dynamic>>(
    '/users/1',
    cacheConfig: CacheConfig(maxAge: Duration(minutes: 15)),
  );
  print('✅ User profile loaded');

  // 3. Submit order (no caching, with retry)
  print('🛒 Submitting order...');
  final orderResponse = await client.post<Map<String, dynamic>>(
    '/posts', // Simulating order submission
    body: {
      'products': products.data?.length ?? 0,
      'userId': userProfile.data?['id'],
      'timestamp': DateTime.now().toIso8601String(),
    },
    retryConfig: RetryConfig(maxAttempts: 3, delay: Duration(seconds: 2)),
  );
  print('✅ Order submitted: ${orderResponse.statusCode}');

  // 4. Fetch order history (cache with shorter duration)
  print('📋 Fetching order history...');
  final orderHistory = await client.get<List<dynamic>>(
    '/posts?userId=1', // Simulating order history
    cacheConfig: CacheConfig(maxAge: Duration(minutes: 5)),
  );
  print('✅ Order history loaded: ${orderHistory.data?.length} orders');

  print('🏁 E-commerce flow completed successfully!');
}
