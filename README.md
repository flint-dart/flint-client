# flint_client

[![Pub Version](https://img.shields.io/pub/v/flint_client)](https://pub.dev/packages/flint_client)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Dart SDK](https://img.shields.io/badge/Dart-3.8%2B-blue.svg)](https://dart.dev)

Official Dart client for the [Flint](https://flintdart.dev) ecosystem.

`flint_client` gives you one package for:

- HTTP requests with typed parsing
- retry and cache support
- file upload and download helpers
- WebSocket communication
- AI provider integrations for OpenAI, Gemini, and Hugging Face

## Installation

From pub.dev:

```bash
dart pub add flint_client
```

For Flutter:

```bash
flutter pub add flint_client
```

Or add it manually:

```yaml
dependencies:
  flint_client: ^0.0.3+337
```

## Quick Start

```dart
import 'package:flint_client/flint_client.dart';

Future<void> main() async {
  final client = FlintClient(
    baseUrl: 'https://api.example.com',
    debug: true,
  );

  final response = await client.get<Map<String, dynamic>>('/health');

  if (response.isSuccess) {
    print(response.data);
  } else {
    print(response.error?.message);
  }

  client.dispose();
}
```

## Core Features

- Typed request and response handling
- Configurable retry policies
- In-memory caching with TTL controls
- Request and response lifecycle hooks
- Multipart uploads and file downloads
- WebSocket helpers through `client.wc(...)`
- AI providers with shared request flow and response helpers

## AI Support

The package exports built-in AI providers so you can talk to model APIs using the same Flint request stack.

### Available Providers

- `OpenAIProvider`
- `GeminiProvider`
- `HuggingFaceProvider`

### AI Quick Start

```dart
import 'package:flint_client/flint_client.dart';

Future<void> main() async {
  final gemini = GeminiProvider(apiKey: 'YOUR_GEMINI_KEY');

  gemini.addContextMemory(
    'You are helping users understand the Flint Dart ecosystem.',
  );

  final response = await gemini.request(
    model: 'gemini-2.5-flash',
    prompt: 'Summarize what Flint Client does in one paragraph.',
  );

  final parsed = GeminiResponse.fromJson(response.data);
  print(parsed.text);
}
```

### How To Use AI In flint_client

1. Create a provider with your API key.
2. Optionally add context with `addContextMemory(...)`.
3. Call `request(...)` with a model name and prompt.
4. Parse the raw response with the matching response helper.
5. Reuse the same provider if you want conversation history preserved.

### OpenAI Example

```dart
import 'package:flint_client/flint_client.dart';

Future<void> main() async {
  final openAI = OpenAIProvider(apiKey: 'YOUR_OPENAI_KEY');

  final response = await openAI.request(
    model: 'gpt-4o-mini',
    prompt: 'Write a short welcome message for Flint users.',
  );

  final parsed = OpenAIResponse.fromJson(response.data);
  print(parsed.text);
}
```

### Gemini Example

```dart
import 'package:flint_client/flint_client.dart';

Future<void> main() async {
  final gemini = GeminiProvider(apiKey: 'YOUR_GEMINI_KEY');

  final response = await gemini.request(
    model: 'gemini-2.5-flash',
    prompt: 'Explain caching in simple terms.',
    includeHistory: true,
    includeContext: true,
    maxTokens: 300,
  );

  final parsed = GeminiResponse.fromJson(response.data);
  print(parsed.text);
}
```

### Hugging Face Example

```dart
import 'package:flint_client/flint_client.dart';

Future<void> main() async {
  final hf = HuggingFaceProvider(apiKey: 'YOUR_HF_KEY');

  final response = await hf.request(
    model: 'gpt2',
    prompt: 'Generate a short API product tagline.',
  );

  final parsed = HuggingFaceResponse.fromJson(response.data);
  print(parsed.generatedText);
}
```

### AI Notes

- `AIProvider` keeps in-memory history on the provider instance.
- `resetHistory()` clears conversation history.
- `clearContextMemory()` removes stored context snippets.
- `includeHistory` and `includeContext` let you control what gets sent.
- The raw provider response is still available through `response.data`.

## HTTP Usage

### GET With Parsing

```dart
final response = await client.get<User>(
  '/users/1',
  parser: (json) => User.fromJson(json),
);
```

### POST JSON

```dart
final response = await client.post<Map<String, dynamic>>(
  '/products',
  body: {
    'title': 'New Product',
    'price': 29.99,
  },
);
```

### QUERY JSON

HTTP `QUERY` is defined by RFC 10008. It is safe and idempotent like `GET`, but
it can send request content like `POST`. Use it for complex search/filter
requests that should not mutate server state.

```dart
final response = await client.query<Map<String, dynamic>>(
  '/products/search',
  queryParameters: {'page': 1},
  body: {
    'category': 'electronics',
    'minimumPrice': 50000,
    'inStock': true,
  },
);
```

`queryParameters` still become URI query string values. `body` is QUERY request
content and uses the same JSON, text, form, timeout, interceptor, retry, cache,
and parsing pipeline as the other request methods. QUERY is included in the
default idempotent retry method set when retries are enabled.

Compatibility note: some proxies, browsers, servers, API gateways, and API
tools may not support `QUERY` yet. See RFC 10008:
https://www.rfc-editor.org/rfc/rfc10008.html.

### Retry Configuration

```dart
final response = await client.get<String>(
  '/retry-test',
  retryConfig: RetryConfig(
    maxAttempts: 3,
    delay: Duration(seconds: 1),
    maxDelay: Duration(seconds: 10),
    retryStatusCodes: {500, 502, 503},
  ),
);
```

### Cache Configuration

```dart
final response = await client.get<List<dynamic>>(
  '/products',
  cacheConfig: CacheConfig(
    maxAge: Duration(minutes: 10),
    forceRefresh: false,
  ),
);
```

### File Upload

```dart
final response = await client.uploadFile<Map<String, dynamic>>(
  '/upload',
  fileField: 'image',
  file: File('path/to/image.jpg'),
);
```

## WebSocket Usage

```dart
final ws = client.wc('/chat');

ws.on('connected', (_) => print('connected'));
ws.on('message', (data) => print(data));
ws.emit('send_message', {'text': 'Hello'});
```

## Links

- Package page: https://pub.dev/packages/flint_client
- AI docs in this README: https://github.com/flint-dart/flint-client#ai-support
- Full docs: https://flintdart.dev/docs/client
- Repository: https://github.com/flint-dart/flint-client
- Examples: https://github.com/flint-dart/flint-client/tree/main/example
- AI example file: https://github.com/flint-dart/flint-client/blob/main/example/lib/main.dart
- Issue tracker: https://github.com/flint-dart/flint-client/issues

## Development

```bash
dart pub get
dart test
```

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE).
