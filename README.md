# flint_client

[![Pub Version](https://img.shields.io/pub/v/flint_client)](https://pub.dev/packages/flint_client)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Dart](https://img.shields.io/badge/Dart-2.17+-blue.svg)](https://dart.dev)

Official Dart client for the [Flint](https://flintdart.eulogia.net) framework.  
Developed and maintained by **Eulogia**.

A powerful, feature-rich HTTP client for Dart and Flutter with built-in caching, retry mechanisms, interceptors, and customizable status code handling.

---

## 🚀 Features

- **🔄 Smart Retry Logic**: Configurable retry with exponential backoff and jitter
- **💾 Built-in Caching**: Memory cache with configurable TTL and freshness ratios
- **🎯 Customizable Status Codes**: Define your own success/error/redirect status mappings
- **📁 File Upload/Download**: Multipart form support with progress tracking
- **🔧 Interceptors**: Request/response interceptors for authentication and logging
- **⏱️ Progress Tracking**: Real-time upload/download progress callbacks
- **🛡️ Type Safety**: Generic response types with custom JSON parsers
- **🐛 Debug Logging**: Comprehensive debug output for development
- **📦 Zero Dependencies**: Pure Dart implementation

---

## 📦 Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  flint_client:
    git:
      url: https://github.com/flint-dart/flint-client.git
```

Then run:

```bash
dart pub get
```

---

## 🔧 Quick Start

### Basic Usage

```dart
import 'package:flint_client/flint_client.dart';

void main() async {
  final client = FlintClient(
    baseUrl: "https://api.example.com",
    debug: true, // Enable debug logging
  );

  final response = await client.get<User>("/users/1",
    parser: (json) => User.fromJson(json),
  );

  if (response.isSuccess) {
    print("User: ${response.data}");
  } else {
    print("Error: ${response.error}");
  }

  client.dispose();
}
```

### Advanced Configuration

```dart
final client = FlintClient(
  baseUrl: "https://api.example.com",
  headers: {
    'Authorization': 'Bearer your-token',
    'Content-Type': 'application/json',
  },
  timeout: Duration(seconds: 30),
  debug: true,
  statusCodeConfig: StatusCodeConfig.custom(
    successCodes: {200, 201, 204},
    errorCodes: {400, 401, 403, 404, 422, 500},
    redirectCodes: {301, 302},
  ),
  onError: (error) {
    print('Request failed: ${error.message}');
  },
);
```

---

## 📚 Usage Examples

### GET Request with Caching

```dart
final response = await client.get<List<Product>>(
  '/products',
  cacheConfig: CacheConfig(
    maxAge: Duration(minutes: 10),
    forceRefresh: false,
  ),
  parser: (json) {
    if (json is List) {
      return json.map((item) => Product.fromJson(item)).toList();
    }
    return [];
  },
);
```

### POST Request with JSON Body

```dart
final response = await client.post<Product>(
  '/products',
  body: {
    'title': 'New Product',
    'price': 29.99,
    'category': 'electronics',
  },
  parser: (json) => Product.fromJson(json),
);
```

### File Upload with Progress

```dart
final response = await client.post<Map<String, dynamic>>(
  '/upload',
  files: {
    'image': File('path/to/image.jpg'),
  },
  onSendProgress: (sent, total) {
    final progress = (sent / total * 100).round();
    print('Upload progress: $progress%');
  },
);
```

### Custom Status Code Handling

```dart
// For APIs that use non-standard status codes
final customConfig = StatusCodeConfig.custom(
  successCodes: {200, 201, 204, 304}, // Include 304 as success
  errorCodes: {400, 401, 500}, // Only specific errors
  redirectCodes: {302, 307},
);

final response = await client.get<User>(
  '/user',
  statusConfig: customConfig,
);

if (response.isSuccess) {
  // Handle success according to your custom config
}
```

### Error Handling with onDone Callback

```dart
final response = await client.get<User>(
  '/users/1',
  onDone: (response, error) {
    if (error != null) {
      print('Request completed with error: ${error.message}');
    } else {
      print('Request completed successfully: ${response.statusCode}');
    }
  },
);
```

---

## 🔌 API Reference

### HTTP Methods

- `get<T>(path, {query, headers, cache, parser})`
- `post<T>(path, {body, files, headers, parser})`
- `put<T>(path, {body, files, headers, parser})`
- `patch<T>(path, {body, files, headers, parser})`
- `delete<T>(path, {headers, parser})`

### Configuration Options

| Option | Type | Description |
|--------|------|-------------|
| `baseUrl` | `String` | Base URL for all requests |
| `headers` | `Map<String, String>` | Default headers |
| `timeout` | `Duration` | Request timeout duration |
| `debug` | `bool` | Enable debug logging |
| `statusCodeConfig` | `StatusCodeConfig` | Custom status code mappings |
| `onError` | `ErrorHandler` | Global error callback |
| `onDone` | `RequestDoneCallback` | Request completion callback |

### Response Properties

| Property | Type | Description |
|----------|------|-------------|
| `statusCode` | `int` | HTTP status code |
| `data` | `T` | Response data (parsed) |
| `isSuccess` | `bool` | Whether request succeeded |
| `isError` | `bool` | Whether request failed |
| `isRedirect` | `bool` | Whether response is redirect |
| `error` | `FlintError` | Error object (if any) |
| `headers` | `HttpHeaders` | Response headers |
| `duration` | `Duration` | Request duration |

---

## 🛠️ Advanced Features

### Custom Interceptors

```dart
final client = FlintClient(
  baseUrl: 'https://api.example.com',
  requestInterceptor: (request) async {
    // Add auth token to all requests
    request.headers.set('Authorization', 'Bearer $token');
  },
  responseInterceptor: (response) async {
    // Log all responses
    print('Response: ${response.statusCode}');
  },
);
```

### Retry Configuration

```dart
final response = await client.get<User>(
  '/users/1',
  retryConfig: RetryConfig(
    maxAttempts: 3,
    delay: Duration(seconds: 1),
    maxDelay: Duration(seconds: 10),
    retryStatusCodes: {500, 502, 503},
  ),
);
```

### Cache Management

```dart
// Clear entire cache
await client.clearCache();

// Remove specific cached item
await client.removeCachedResponse('cache-key');

// Get cache size
final size = await client.cacheSize;
```

---

## 🎯 Status Code Configuration

Handle non-standard APIs with custom status code mappings:

```dart
// For APIs that use 200 for errors
final weirdApiConfig = StatusCodeConfig.custom(
  successCodes: {200}, // Only 200 is success
  errorCodes: {200, 400, 500}, // 200 can be error!
  redirectCodes: {302},
);

// Standard HTTP (default)
final standardConfig = StatusCodeConfig();

// Pre-defined configurations
final only200 = StatusCodeConfig.only200;
final broadSuccess = StatusCodeConfig.broadSuccess;
```

---

## 📖 Documentation

- [Full API Documentation](https://flintdart.eulogia.net/docs/client)
- [GitHub Repository](https://github.com/flint-dart/flint-client)
- [Issue Tracker](https://github.com/flint-dart/flint-client/issues)
- [Examples Folder](/examples) - Complete usage examples

---

## 🤝 Contributing

We love contributions! Here's how to help:

1. **Fork** the repository
2. **Create** a feature branch: `git checkout -b feature/amazing-feature`
3. **Commit** your changes: `git commit -m 'Add amazing feature'`
4. **Push** to the branch: `git push origin feature/amazing-feature`
5. **Open** a Pull Request

### Development Setup

```bash
git clone https://github.com/flint-dart/flint-client.git
cd flint-client
dart pub get
dart test
```

---

## 📄 License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

---

## 🏗️ Built With

- [Dart](https://dart.dev) - Programming language
- [Flutter](https://flutter.dev) - UI framework (for Flutter apps)

---

## 👥 Maintainers

- [Eulogia](https://github.com/eulogia) - Core maintainer

---

## 🙏 Acknowledgments

- Inspired by popular HTTP clients like Dio and http
- Thanks to all our contributors and users

---

**⭐ Star this repo if you find it helpful!**
```



