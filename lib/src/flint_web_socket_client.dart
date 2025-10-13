import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'enum/websocket_connection_state.dart';

class FlintWebSocketClient {
  WebSocket? _socket;
  final String url;
  final Map<String, dynamic>? params;
  final String? token;
  final bool debug;
  final Map<String, String>? headers; // Add this field

  final _eventHandlers = <String, List<Function>>{};
  final _messageQueue = <Map<String, dynamic>>[];

  bool _reconnecting = false;
  int _reconnectAttempts = 0;
  Timer? _heartbeatTimer;
  DateTime? _lastPong;
  WebSocketConnectionState _state = WebSocketConnectionState.disconnected;

  static const int _maxReconnectAttempts = 5;
  static const Duration _heartbeatInterval = Duration(seconds: 25);
  static const Duration _pongTimeout = Duration(seconds: 30);

  FlintWebSocketClient(
    this.url, {
    this.params,
    this.token,
    this.debug = false,
    this.headers, // Add this parameter
  });

  // -------------------- CONNECTION --------------------

  Future<void> connect() async {
    if (_state == WebSocketConnectionState.connected ||
        _state == WebSocketConnectionState.connecting) {
      if (debug) print('⚠️ Already connected or connecting');
      return;
    }

    _setState(WebSocketConnectionState.connecting);

    final uri = Uri.parse(url).replace(
      queryParameters: params?.map((k, v) => MapEntry(k, v.toString())),
    );

    final mergedHeaders = <String, dynamic>{};
    if (headers != null) {
      mergedHeaders.addAll(headers!);
    }
    if (token != null && !mergedHeaders.containsKey('Authorization')) {
      mergedHeaders['Authorization'] = 'Bearer $token';
    }

    try {
      if (debug) {
        print('🔌 Connecting to $uri ...');
        if (mergedHeaders.isNotEmpty) {
          print('📨 Headers: $mergedHeaders');
        }
      }
      _socket = await WebSocket.connect(uri.toString(), headers: headers);

      _setState(WebSocketConnectionState.connected);
      _reconnectAttempts = 0;
      _lastPong = DateTime.now();

      _emitLocal('connect');
      if (debug) print('✅ Connected to $uri');

      _socket!.listen(
        (data) => _handleMessage(data),
        onDone: () => _handleDisconnect('Connection closed'),
        onError: (err) => _handleDisconnect(err),
      );

      _startHeartbeat();
      _flushMessageQueue();
    } catch (e) {
      _handleDisconnect(e);
    }
  }

  void close([int code = WebSocketStatus.normalClosure, String? reason]) {
    if (debug) print('🔌 Closing connection...');

    _setState(WebSocketConnectionState.disconnected);
    _reconnecting = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _eventHandlers.clear();
    _messageQueue.clear();

    if (_socket != null) {
      try {
        _socket!.close(code, reason);
      } catch (e) {
        if (debug) print('⚠️ Error during close: $e');
      }
      _socket = null;
    }

    _emitLocal('close', reason);
  }

  bool get isConnected => _state == WebSocketConnectionState.connected;
  WebSocketConnectionState get state => _state;

  // -------------------- STATE MANAGEMENT --------------------

  void _setState(WebSocketConnectionState newState) {
    if (_state != newState) {
      _state = newState;
      _emitLocal('state_change', newState);
      if (debug) print('🔄 State changed: $newState');
    }
  }

  // -------------------- EVENT SYSTEM --------------------

  void on(String event, Function(dynamic data) handler) {
    _eventHandlers.putIfAbsent(event, () => []).add(handler);
  }

  void off(String event, [Function? handler]) {
    if (handler == null) {
      _eventHandlers.remove(event);
    } else {
      _eventHandlers[event]?.remove(handler);
    }
  }

  void _emitLocal(String event, [dynamic data]) {
    final handlers = _eventHandlers[event];
    if (handlers != null) {
      for (final h in List.from(handlers)) {
        try {
          h(data);
        } catch (e) {
          if (debug) print('⚠️ Handler error on $event: $e');
        }
      }
    }
  }

  void emit(String event, dynamic data) {
    final payload = {"event": event, "data": data};

    if (_socket != null && isConnected) {
      try {
        final encoded = jsonEncode(payload);
        _socket!.add(encoded);
        if (debug) print('📤 Emit: $encoded');
      } catch (e) {
        if (debug) print('⚠️ Emit error: $e');
        _messageQueue.add(payload);
      }
    } else {
      _messageQueue.add(payload);
      if (debug) print('💾 Queued (offline): $event');
    }
  }

  void _flushMessageQueue() {
    if (_messageQueue.isEmpty || !isConnected) return;

    if (debug) print('📦 Flushing ${_messageQueue.length} queued messages');

    for (final message in List.from(_messageQueue)) {
      try {
        _socket!.add(jsonEncode(message));
        _messageQueue.remove(message);
        if (debug) print('📤 Sent queued: ${message["event"]}');
      } catch (e) {
        if (debug) print('⚠️ Failed to send queued message: $e');
        break;
      }
    }
  }

  void _handleMessage(dynamic data) {
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map) {
        final event = decoded["event"];
        final messageData = decoded["data"];

        if (event == "pong") {
          _lastPong = DateTime.now();
          if (debug) print('💓 Pong received');
          return;
        }

        _emitLocal(event, messageData);
      } else {
        _emitLocal("message", decoded);
      }
    } catch (_) {
      _emitLocal("message", data);
    }
  }

  // -------------------- AUTO RECONNECT --------------------

  void _handleDisconnect([dynamic error]) {
    if (_reconnecting || _state == WebSocketConnectionState.disconnected) {
      return;
    }

    _reconnecting = true;
    _setState(WebSocketConnectionState.reconnecting);
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    _emitLocal('disconnect', error);
    if (debug) print('❌ Disconnected: $error');

    if (_reconnectAttempts < _maxReconnectAttempts) {
      // Exponential backoff delay (3s, 6s, 12s, 24s, 30s)
      final baseDelay = Duration(seconds: 3 * (1 << _reconnectAttempts));
      final delay = _reconnectAttempts == _maxReconnectAttempts - 1
          ? Duration(seconds: 30)
          : baseDelay;

      _reconnectAttempts++;

      if (debug) {
        print(
          '🔁 Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts/$_maxReconnectAttempts)...',
        );
      }

      Timer(delay, () async {
        _reconnecting = false;
        await connect();
      });
    } else {
      if (debug) print('🚫 Max reconnect attempts reached');
      _setState(WebSocketConnectionState.disconnected);
      _emitLocal('reconnect_failed');
    }
  }

  // -------------------- HEARTBEAT --------------------

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (timer) {
      if (!isConnected) {
        timer.cancel();
        return;
      }

      // Check pong timeout
      if (_lastPong != null &&
          DateTime.now().difference(_lastPong!) > _pongTimeout) {
        if (debug) print('💔 No pong response - assuming dead connection');
        _handleDisconnect('Heartbeat timeout');
        return;
      }

      try {
        _socket?.add(jsonEncode({'event': 'ping'}));
        if (debug) print('💓 Ping sent');
      } catch (e) {
        if (debug) print('⚠️ Heartbeat failed: $e');
        _handleDisconnect('Heartbeat failed');
      }
    });
  }

  // -------------------- ROOM SYSTEM --------------------

  void join(String room) => emit('join', {"room": room});
  void leave(String room) => emit('leave', {"room": room});

  // -------------------- UTILITIES --------------------

  /// Get number of queued messages
  int get queuedMessageCount => _messageQueue.length;

  /// Get current reconnect attempt number
  int get reconnectAttempt => _reconnectAttempts;

  /// Manually trigger reconnection
  Future<void> reconnect() async {
    if (debug) print('🔄 Manual reconnection triggered');
    _reconnectAttempts = 0;
    _reconnecting = false;
    await connect();
  }

  // -------------------- DISPOSAL --------------------

  void dispose() {
    close(WebSocketStatus.goingAway, 'Client disposed');
  }
}

// -------------------- USAGE EXAMPLE --------------------
/*
void main() async {
  final client = FlintWebSocketClient(
    'ws://localhost:8080/ws',
    token: 'your-token',
    params: {'userId': '123'},
    debug: true,
  );

  client.on('connect', (_) {
    print('Connected!');
    client.join('room1');
    client.emit('chat', {'message': 'Hello!'});
  });

  client.on('disconnect', (error) {
    print('Disconnected: $error');
  });

  client.on('state_change', (state) {
    print('State: $state');
  });

  client.on('chat', (data) {
    print('Received: $data');
  });

  await client.connect();

  // Close after 10 seconds
  Timer(Duration(seconds: 10), () {
    client.close();
  });
}
*/
