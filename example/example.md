
# Flint Client Examples

A collection of practical examples showing how to use the Flint Client HTTP package.

## 📋 Table of Contents

1. [Basic Usage](#basic-usage)
2. [Custom Status Codes](#custom-status-codes)
3. [Caching](#caching)
4. [Retry Mechanism](#retry-mechanism)
5. [File Upload/Download](#file-uploaddownload)
6. [Interceptors](#interceptors)
7. [Error Handling](#error-handling)
8. [Complete Flutter App](#complete-flutter-app)

---

## 🔰 Basic Usage

### Simple GET Request

```dart
import 'package:flint_client/flint_client.dart';

void main() async {
  final client = FlintClient(
    baseUrl: 'https://jsonplaceholder.typicode.com',
    debug: true,
  );

  try {
    final response = await client.get<Map<String, dynamic>>('/posts/1');
    
    if (response.isSuccess) {
      print('Post title: ${response.data?['title']}');
    } else {
      print('Error: ${response.error?.message}');
    }
  } finally {
    client.dispose();
  }
}
```

### POST Request with JSON Body

```dart
final response = await client.post<Map<String, dynamic>>(
  '/posts',
  body: {
    'title': 'New Post',
    'body': 'This is the post content',
    'userId': 1,
  },
);

if (response.isSuccess) {
  print('Created post with ID: ${response.data?['id']}');
}
```

### Using Custom Parsers

```dart
class Post {
  final int id;
  final String title;
  final String body;

  Post({required this.id, required this.title, required this.body});

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'],
      title: json['title'],
      body: json['body'],
    );
  }
}

final response = await client.get<Post>(
  '/posts/1',
  parser: (json) => Post.fromJson(json),
);

if (response.isSuccess) {
  print('Post: ${response.data!.title}');
}
```

---

## 🎯 Custom Status Codes

### Handling Non-Standard APIs

```dart
// Some APIs use non-standard status codes
final customConfig = StatusCodeConfig.custom(
  successCodes: {200, 201, 204, 304}, // Include 304 as success
  errorCodes: {400, 401, 403, 404, 422, 500},
  redirectCodes: {301, 302, 307},
);

final client = FlintClient(
  baseUrl: 'https://api.example.com',
  statusCodeConfig: customConfig,
);

// Or per-request override
final response = await client.get<User>(
  '/user',
  statusConfig: StatusCodeConfig.only200, // Only 200 is success
);
```

### API That Uses 200 for Everything

```dart
final weirdApiConfig = StatusCodeConfig.custom(
  successCodes: {200},
  errorCodes: {200}, // The API returns 200 even for errors!
  redirectCodes: {302},
);

final response = await client.get<Map>(
  '/weird-endpoint',
  statusConfig: weirdApiConfig,
);

// Now response.isSuccess will be false if the API returns
// an error message in a 200 response
```

---

## 💾 Caching

### Basic Caching

```dart
final response = await client.get<List<Post>>(
  '/posts',
  cacheConfig: CacheConfig(
    maxAge: Duration(minutes: 10), // Cache for 10 minutes
    forceRefresh: false,
  ),
  parser: (json) {
    if (json is List) {
      return json.map((item) => Post.fromJson(item)).toList();
    }
    return [];
  },
);
```

### Cache Management

```dart
// Clear entire cache
await client.clearCache();

// Remove specific cached item
await client.removeCachedResponse('cache-key');

// Get cache statistics
final cacheSize = await client.cacheSize;
print('Cache size: $cacheSize items');

// Clean up expired entries
await client.cleanupExpiredCache();
```

### Force Refresh

```dart
// Ignore cache and force fresh data
final response = await client.get<Post>(
  '/posts/1',
  cacheConfig: CacheConfig(forceRefresh: true),
);
```

---

## 🔄 Retry Mechanism

### Automatic Retry on Failure

```dart
final response = await client.get<Post>(
  '/posts/1',
  retryConfig: RetryConfig(
    maxAttempts: 3,
    delay: Duration(seconds: 1),
    maxDelay: Duration(seconds: 10),
    retryStatusCodes: {500, 502, 503}, // Retry on server errors
    retryOnTimeout: true,
  ),
);
```

### Custom Retry Evaluator

```dart
final retryConfig = RetryConfig(
  maxAttempts: 5,
  retryEvaluator: (error, attempt) {
    // Retry on network errors or specific status codes
    if (error.statusCode == 429) { // Rate limited
      return true;
    }
    if (error.message.contains('socket') {
      return true;
    }
    return attempt < 3; // Retry first 3 attempts for any error
  },
);
```

---

## 📁 File Upload/Download

### File Upload with Progress

```dart
final response = await client.post<Map<String, dynamic>>(
  '/upload',
  files: {
    'avatar': File('path/to/avatar.jpg'),
    'document': File('path/to/document.pdf'),
  },
  body: {
    'userId': 123,
    'description': 'Profile picture',
  },
  onSendProgress: (sent, total) {
    final progress = (sent / total * 100).round();
    print('Upload progress: $progress%');
  },
);
```

### File Download

```dart
final file = await client.downloadFile(
  'https://example.com/large-file.zip',
  savePath: '/path/to/save/large-file.zip',
  onProgress: (received, total) {
    if (total > 0) {
      final progress = (received / total * 100).round();
      print('Download progress: $progress%');
    }
  },
);

print('File downloaded to: ${file.path}');
```

### Binary Response Handling

```dart
final response = await client.get<File>(
  '/download/image.jpg',
  saveFilePath: '/path/to/save/image.jpg',
);

if (response.isSuccess) {
  print('Image saved as: ${response.data!.path}');
}
```

---

## 🔧 Interceptors

### Request Interceptor (Authentication)

```dart
final client = FlintClient(
  baseUrl: 'https://api.example.com',
  requestInterceptor: (request) async {
    // Add auth token to all requests
    final token = await getAuthToken();
    request.headers.set('Authorization', 'Bearer $token');
    
    // Log request
    print('Sending ${request.method} to ${request.uri}');
  },
);
```

### Response Interceptor (Error Handling)

```dart
final client = FlintClient(
  baseUrl: 'https://api.example.com',
  responseInterceptor: (response) async {
    // Log response
    print('Received ${response.statusCode} from ${response.uri}');
    
    // Handle specific status codes globally
    if (response.statusCode == 401) {
      // Token expired, refresh it
      await refreshAuthToken();
    }
  },
);
```

### Combined Interceptors

```dart
final client = FlintClient(
  baseUrl: 'https://api.example.com',
  requestInterceptor: (request) async {
    request.headers.set('X-Request-ID', generateUuid());
    request.headers.set('User-Agent', 'MyApp/1.0.0');
  },
  responseInterceptor: (response) async {
    final serverId = response.headers.value('x-server-id');
    if (serverId != null) {
      print('Request handled by server: $serverId');
    }
  },
);
```

---

## 🚨 Error Handling

### Global Error Handler

```dart
final client = FlintClient(
  baseUrl: 'https://api.example.com',
  onError: (error) {
    // Global error handling
    print('Request failed: ${error.message}');
    
    // Send to analytics
    analytics.trackError(error);
    
    // Show user-friendly message
    if (error.statusCode == 401) {
      showLoginPrompt();
    }
  },
);
```

### Per-Request Error Handling

```dart
final response = await client.get<Post>(
  '/posts/999', // Non-existent post
  onError: (error) {
    print('This specific request failed: ${error.message}');
  },
);
```

### Using onDone Callback

```dart
final response = await client.get<Post>(
  '/posts/1',
  onDone: (response, error) {
    // This runs regardless of success or failure
    if (error != null) {
      print('Request completed with error: ${error.message}');
    } else {
      print('Request completed successfully: ${response.statusCode}');
    }
  },
);
```

### Response Helper Methods

```dart
final response = await client.get<User>('/users/1');

// Check response status
if (response.isSuccess) {
  final user = response.data!;
} else if (response.isNotFound) {
  print('User not found!');
} else if (response.isUnauthorized) {
  print('Please login again!');
} else if (response.isServerError) {
  print('Server error, please try again later.');
}

// Use when() for clean conditional handling
response.when(
  onSuccess: (user) => print('User: $user'),
  onError: (error) => print('Error: ${error.message}'),
  onRedirect: () => print('Redirect required'),
);
```

---

## 📱 Complete Flutter App

### Flutter Product List Example

```dart
import 'package:flutter/material.dart';
import 'package:flint_client/flint_client.dart';

class Product {
  final int id;
  final String title;
  final double price;
  final String image;

  Product({
    required this.id,
    required this.title,
    required this.price,
    required this.image,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      title: json['title'],
      price: json['price']?.toDouble() ?? 0.0,
      image: json['image'],
    );
  }
}

class ProductService {
  static const String baseUrl = 'https://fakestoreapi.com';
  final FlintClient _client;

  ProductService() : _client = FlintClient(baseUrl: baseUrl, debug: true);

  Future<List<Product>> getProducts() async {
    final response = await _client.get<List<Product>>(
      '/products',
      cacheConfig: CacheConfig(maxAge: Duration(minutes: 5)),
      parser: (json) {
        if (json is List) {
          return json.map((item) => Product.fromJson(item)).toList();
        }
        return [];
      },
    );

    if (response.isSuccess) {
      return response.data ?? [];
    } else {
      throw Exception('Failed to load products: ${response.error?.message}');
    }
  }

  Future<Product> getProduct(int id) async {
    final response = await _client.get<Product>(
      '/products/$id',
      parser: (json) => Product.fromJson(json),
    );

    if (response.isSuccess && response.data != null) {
      return response.data!;
    } else {
      throw Exception('Failed to load product: ${response.error?.message}');
    }
  }

  void dispose() {
    _client.dispose();
  }
}

class ProductListPage extends StatefulWidget {
  const ProductListPage({super.key});

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  final ProductService _service = ProductService();
  List<Product> _products = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final products = await _service.getProducts();
      setState(() {
        _products = products;
        _isLoading = false;
        _errorMessage = '';
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadProducts,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_errorMessage'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadProducts,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _products.length,
      itemBuilder: (context, index) {
        final product = _products[index];
        return ListTile(
          leading: Image.network(product.image, width: 50, height: 50),
          title: Text(product.title),
          subtitle: Text('\$${product.price.toStringAsFixed(2)}'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProductDetailPage(
                  product: product,
                  service: _service,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class ProductDetailPage extends StatelessWidget {
  final Product product;
  final ProductService service;

  const ProductDetailPage({
    super.key,
    required this.product,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(product.title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.network(product.image),
            const SizedBox(height: 16),
            Text(
              product.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '\$${product.price.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.green,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## 🎉 Advanced Usage

### Multiple API Clients

```dart
class ApiManager {
  final FlintClient mainApi;
  final FlintClient legacyApi;
  final FlintClient externalApi;

  ApiManager()
      : mainApi = FlintClient(
          baseUrl: 'https://api.new.com',
          headers: {'Authorization': 'Bearer main-token'},
        ),
        legacyApi = FlintClient(
          baseUrl: 'https://api.old.com',
          statusCodeConfig: StatusCodeConfig.uses200ForErrors(),
        ),
        externalApi = FlintClient(
          baseUrl: 'https://api.external.com',
          timeout: Duration(seconds: 10),
        );

  void dispose() {
    mainApi.dispose();
    legacyApi.dispose();
    externalApi.dispose();
  }
}
```

### Custom Cache Store

```dart
class MyCacheStore implements CacheStore {
  final Map<String, CachedResponse<dynamic>> _cache = {};

  @override
  Future<void> set<T>(String key, CachedResponse<T> response) async {
    _cache[key] = response;
  }

  @override
  Future<CachedResponse<T>?> get<T>(String key) async {
    return _cache[key] as CachedResponse<T>?;
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
  Future<void> cleanup(DateTime now) async {
    _cache.removeWhere((key, value) => !value.isValid);
  }

  @override
  Future<int> get size async => _cache.length;
}

// Use custom cache store
final client = FlintClient(
  baseUrl: 'https://api.example.com',
  cacheStore: MyCacheStore(),
);
```

---

## 🚀 Performance Tips

1. **Reuse Client Instances**: Create one client instance and reuse it
2. **Dispose Properly**: Call `dispose()` when done to close connections
3. **Use Appropriate Cache TTL**: Balance freshness vs performance
4. **Configure Retry Wisely**: Don't retry too aggressively on user actions
5. **Use Compression**: Enable gzip on your server for better performance

---

## 📞 Support

For more help, check out:
- [Full Documentation](https://flintdart.eulogia.net)
- [GitHub Repository](https://github.com/flint-dart/flint-client)
- [Issue Tracker](https://github.com/flint-dart/flint-client/issues)

Happy coding! 🎯
```

This comprehensive `example.md` covers:

- ✅ **All major features** of your Flint Client
- ✅ **Real-world use cases** with practical examples
- ✅ **Flutter integration** with complete app example
- ✅ **Advanced scenarios** like multiple APIs and custom cache
- ✅ **Error handling** patterns
- ✅ **Performance tips**
