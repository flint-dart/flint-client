             
# Changelog

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
- 🔗 Added full **WebSocket communication** support directly on `FlintClient` via `.wc`.
- `client.wc` returns a `FlintWebSocketClient` instance for real-time communication.
- Works just like Socket.io — supports `on`, `emit`, `off`, `join`, and `leave` events.
- Maintains `onMessage` and `onJsonMessage` compatibility for existing projects.
- Supports JWT authentication headers for secure socket connections.
- Auto-reconnects with exponential backoff after disconnection.
- Connection lifecycle events: `connected`, `disconnected`, `reconnected`, `error`.
- Integrated room and broadcast system for scalable multi-user apps.
- Compatible with Flutter, Dart console, and Flint Dart backend.

### 💡 Example: Using Flint WebSocket via `.wc`

```dart
import 'package:flint_client/flint_client.dart';

void main() async {
  final client = FlintClient(
    baseUrl: "https://api.example.com",
    token: "your_jwt_token_here",
  );

  // Access WebSocket through the .wc property
  final ws = client.wc("/chat");

  // Listen for connection
  ws.on("connected", (_) => print("✅ Connected to WebSocket"));

  // Listen for JSON messages
  ws.onJsonMessage((data) {
    print("Received JSON: $data");
  });

  // Listen for custom event
  ws.on("chat_message", (data) {
    print("💬 Message: $data");
  });

  // Emit (send) event
  ws.emit("send_message", {"text": "Hello from Flint Client"});

  // Join a room
  ws.join("general");

  // Broadcast example
  ws.broadcast("system_notice", {"msg": "Server update incoming..."});
}
````

---

## 0.0.1+1

* Improved HTTP client stability.
* Added file upload/download with progress tracking.
* Support for request interceptors and customizable status code handling.
* Enhanced caching and retry mechanism for failed requests.

---

## 0.0.1

* Initial release of Flint Client.
* Complete HTTP client with caching, retry, and interceptors.
* Support for custom status code configurations.
* File upload/download with progress tracking.

```
