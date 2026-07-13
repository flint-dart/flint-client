# Changelog

## 0.0.5 - 2026-07-13

### Added
- Added HTTP `QUERY` support with request bodies, query parameters, interceptors, timeout handling, response parsing, caching, and retry behavior.
- Added tests and documentation for RFC 10008 QUERY requests.

## 0.0.4 - 2026-05-26

### Added
- Added browser WebSocket support to the web `FlintClient` implementation.
- Exported browser-safe `FlintWebSocketClient` APIs for Flint UI apps.

### Fixed
- Fixed hosted browser builds that call `client.ws(...)` from Flint UI pages.

## 0.0.3 - 2026-05-14

### Added
- Added browser-safe package entrypoints with conditional exports.
- Added a web-compatible `FlintClient` implementation built on browser `XMLHttpRequest`.
- Added web exports for AI providers and response helpers.
- Added browser-focused tests for the web client export and AI provider availability.
- Added pub.dev-ready AI documentation to the README with usage guidance for `OpenAIProvider`, `GeminiProvider`, and `HuggingFaceProvider`.

### Improved
- Improved package metadata for pub.dev discoverability.
- Updated installation instructions to use `dart pub add flint_client`.
- Simplified README examples around HTTP, WebSocket, retry, cache, upload, and AI usage.
- Updated AI provider imports so they work in both Dart IO and browser builds.

### Fixed
- Fixed package exports so browser consumers do not import Dart IO-only client code.

## 0.0.2+1 - 2026-03-06
## 0.0.2 - 2026-02-27

### Added
- Added file convenience APIs:
  - `uploadFile(...)`
  - `uploadFiles(...)`
  - `saveResponseData(...)`
- Added runnable examples:
  - `example/lib/websocket_auth_example.dart`
  - `example/lib/http_methods_and_download_example.dart`
  - `example/lib/full_observability_mock_example.dart`

### Improved
- Improved WebSocket authentication flow in `FlintWebSocketClient`:
  - token provider support
  - token in query support
  - auto auth event support
  - runtime token/header updates
- Improved WebSocket reconnect/close semantics and event handling.

### Fixed
- Fixed WebSocket handshake headers merge/auth forwarding behavior.

### Tests
- Added WebSocket auth tests:
  - Authorization header handshake test
  - token-in-query handshake test
- Expanded file operation tests for upload/save helpers.

## 0.0.1+5
## 0.0.1+4
## 0.0.1+3
## 0.0.1+2

- Added full WebSocket communication support directly on `FlintClient` via `.wc`.
- `client.wc` returns a `FlintWebSocketClient` instance for real-time communication.
- Supports `on`, `emit`, `off`, `join`, and `leave` events.
- Maintains `onMessage` and `onJsonMessage` compatibility for existing projects.
- Supports JWT authentication headers for secure socket connections.
- Auto-reconnects with exponential backoff after disconnection.
- Connection lifecycle events: `connected`, `disconnected`, `reconnected`, `error`.
- Integrated room and broadcast system for scalable multi-user apps.
- Compatible with Flutter, Dart console, and Flint Dart backend.

## 0.0.1+1

- Improved HTTP client stability.
- Added file upload and download with progress tracking.
- Added request interceptors and customizable status code handling.
- Enhanced caching and retry mechanisms for failed requests.

## 0.0.1

- Initial release of Flint Client.
- Added HTTP client with caching, retry, and interceptors.
- Added support for custom status code configurations.
- Added file upload and download with progress tracking.
