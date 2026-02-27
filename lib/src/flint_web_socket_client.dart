import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'enum/websocket_connection_state.dart';

typedef AuthTokenProvider = FutureOr<String?> Function();

class FlintWebSocketClient {
  WebSocket? _socket;
  final String url;
  final Map<String, dynamic>? params;
  final bool debug;
  final bool sendTokenAsQuery;
  final String queryTokenKey;
  final bool autoAuthEvent;
  final String authEventName;
  final dynamic authPayload;
  final Duration heartbeatInterval;
  final Duration pongTimeout;
  final int maxReconnectAttempts;

  String? _token;
  AuthTokenProvider? _tokenProvider;
  Map<String, String> _headers;

  final _eventHandlers = <String, List<Function>>{};
  final _messageQueue = <Map<String, dynamic>>[];

  bool _reconnecting = false;
  bool _manuallyClosed = false;
  int _reconnectAttempts = 0;
  Timer? _heartbeatTimer;
  DateTime? _lastPong;
  WebSocketConnectionState _state = WebSocketConnectionState.disconnected;

  FlintWebSocketClient(
    this.url, {
    this.params,
    String? token,
    AuthTokenProvider? tokenProvider,
    this.debug = false,
    Map<String, String>? headers,
    this.sendTokenAsQuery = false,
    this.queryTokenKey = 'token',
    this.autoAuthEvent = false,
    this.authEventName = 'auth',
    this.authPayload,
    this.heartbeatInterval = const Duration(seconds: 25),
    this.pongTimeout = const Duration(seconds: 30),
    this.maxReconnectAttempts = 5,
  }) : _token = token,
       _tokenProvider = tokenProvider,
       _headers = {...?headers};

  String? get token => _token;
  Map<String, String> get headers => Map.unmodifiable(_headers);

  void setToken(String? token) {
    _token = token;
  }

  void setTokenProvider(AuthTokenProvider? provider) {
    _tokenProvider = provider;
  }

  void setHeaders(Map<String, String> headers) {
    _headers = {...headers};
  }

  void mergeHeaders(Map<String, String> headers) {
    _headers.addAll(headers);
  }

  Future<String?> _resolveToken() async {
    final provided = await _tokenProvider?.call();
    return provided ?? _token;
  }

  Future<Uri> _buildUri() async {
    final token = await _resolveToken();
    final query = <String, String>{
      ...?params?.map((k, v) => MapEntry(k, v.toString())),
    };
    if (sendTokenAsQuery && token != null && token.isNotEmpty) {
      query[queryTokenKey] = token;
    }
    return Uri.parse(
      url,
    ).replace(queryParameters: query.isEmpty ? null : query);
  }

  Future<Map<String, dynamic>> _buildHandshakeHeaders() async {
    final token = await _resolveToken();
    final merged = <String, dynamic>{..._headers};
    final hasAuthorizationHeader = merged.keys.any(
      (key) => key.toLowerCase() == HttpHeaders.authorizationHeader,
    );
    if (!sendTokenAsQuery &&
        token != null &&
        token.isNotEmpty &&
        !hasAuthorizationHeader) {
      merged[HttpHeaders.authorizationHeader] = 'Bearer $token';
    }
    return merged;
  }

  Future<void> connect() async {
    if (_state == WebSocketConnectionState.connected ||
        _state == WebSocketConnectionState.connecting) {
      if (debug) print('WebSocket is already connected/connecting');
      return;
    }

    _manuallyClosed = false;
    _setState(WebSocketConnectionState.connecting);

    final uri = await _buildUri();
    final handshakeHeaders = await _buildHandshakeHeaders();

    try {
      if (debug) {
        print('Connecting WebSocket to $uri');
        if (handshakeHeaders.isNotEmpty) {
          print('Handshake headers: $handshakeHeaders');
        }
      }

      _socket = await WebSocket.connect(
        uri.toString(),
        headers: handshakeHeaders,
      );

      _setState(WebSocketConnectionState.connected);
      _reconnectAttempts = 0;
      _lastPong = DateTime.now();

      _emitLocal('connect');
      if (debug) print('WebSocket connected to $uri');

      _socket!.listen(
        _handleMessage,
        onDone: () => _handleDisconnect('Connection closed'),
        onError: _handleDisconnect,
      );

      if (autoAuthEvent && authPayload != null) {
        emit(authEventName, authPayload);
      }

      _startHeartbeat();
      _flushMessageQueue();
    } catch (e) {
      _handleDisconnect(e);
    }
  }

  Future<void> reconnect() async {
    if (debug) print('Manual WebSocket reconnect requested');
    _reconnectAttempts = 0;
    _reconnecting = false;
    _manuallyClosed = false;
    await connect();
  }

  Future<void> authenticate(dynamic payload, {String event = 'auth'}) async {
    emit(event, payload);
  }

  void close([int code = WebSocketStatus.normalClosure, String? reason]) {
    if (debug) print('Closing WebSocket connection');

    _manuallyClosed = true;
    _reconnecting = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    if (_socket != null) {
      try {
        _socket!.close(code, reason);
      } catch (_) {}
      _socket = null;
    }

    _setState(WebSocketConnectionState.disconnected);
    _emitLocal('close', reason);
  }

  void dispose() {
    close(WebSocketStatus.goingAway, 'Client disposed');
    _eventHandlers.clear();
    _messageQueue.clear();
  }

  bool get isConnected => _state == WebSocketConnectionState.connected;
  WebSocketConnectionState get state => _state;
  int get queuedMessageCount => _messageQueue.length;
  int get reconnectAttempt => _reconnectAttempts;

  void _setState(WebSocketConnectionState newState) {
    if (_state != newState) {
      _state = newState;
      _emitLocal('state_change', newState);
      if (debug) print('WebSocket state changed: $newState');
    }
  }

  void on(String event, Function(dynamic data) handler) {
    _eventHandlers.putIfAbsent(event, () => []).add(handler);
  }

  void off(String event, [Function? handler]) {
    if (handler == null) {
      _eventHandlers.remove(event);
      return;
    }
    _eventHandlers[event]?.remove(handler);
  }

  void _emitLocal(String event, [dynamic data]) {
    final handlers = _eventHandlers[event];
    if (handlers == null) return;
    for (final handler in List<Function>.from(handlers)) {
      try {
        handler(data);
      } catch (e) {
        if (debug) print('Local handler failed for "$event": $e');
      }
    }
  }

  void emit(String event, dynamic data) {
    final payload = <String, dynamic>{'event': event, 'data': data};
    if (_socket != null && isConnected) {
      try {
        final encoded = jsonEncode(payload);
        _socket!.add(encoded);
        if (debug) print('WebSocket emit: $encoded');
      } catch (e) {
        if (debug) print('WebSocket emit failed, queueing message: $e');
        _messageQueue.add(payload);
      }
      return;
    }

    _messageQueue.add(payload);
    if (debug) print('WebSocket offline, queued event "$event"');
  }

  void _flushMessageQueue() {
    if (_messageQueue.isEmpty || !isConnected || _socket == null) return;
    if (debug) print('Flushing ${_messageQueue.length} queued messages');

    for (final message in List<Map<String, dynamic>>.from(_messageQueue)) {
      try {
        _socket!.add(jsonEncode(message));
        _messageQueue.remove(message);
      } catch (_) {
        break;
      }
    }
  }

  void _handleMessage(dynamic data) {
    try {
      final decoded = jsonDecode(data.toString());
      if (decoded is Map<String, dynamic>) {
        final event = decoded['event'];
        final messageData = decoded['data'];

        if (event == 'pong') {
          _lastPong = DateTime.now();
          if (debug) print('WebSocket pong received');
          return;
        }

        if (event is String && event.isNotEmpty) {
          _emitLocal(event, messageData);
        } else {
          _emitLocal('message', decoded);
        }
      } else {
        _emitLocal('message', decoded);
      }
    } catch (_) {
      _emitLocal('message', data);
    }
  }

  void _handleDisconnect([dynamic error]) {
    if (_state == WebSocketConnectionState.disconnected) return;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    _emitLocal('disconnect', error);
    if (debug) print('WebSocket disconnected: $error');

    if (_manuallyClosed) {
      _setState(WebSocketConnectionState.disconnected);
      return;
    }

    if (_reconnecting) return;
    _reconnecting = true;
    _setState(WebSocketConnectionState.reconnecting);

    if (_reconnectAttempts >= maxReconnectAttempts) {
      _reconnecting = false;
      _setState(WebSocketConnectionState.disconnected);
      _emitLocal('reconnect_failed');
      return;
    }

    final baseDelaySeconds = 3 * (1 << _reconnectAttempts);
    final delay = _reconnectAttempts == maxReconnectAttempts - 1
        ? const Duration(seconds: 30)
        : Duration(seconds: baseDelaySeconds);
    _reconnectAttempts++;

    if (debug) {
      print(
        'WebSocket reconnect in ${delay.inSeconds}s '
        '(attempt $_reconnectAttempts/$maxReconnectAttempts)',
      );
    }

    Timer(delay, () async {
      _reconnecting = false;
      if (_manuallyClosed) return;
      await connect();
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(heartbeatInterval, (timer) {
      if (!isConnected || _socket == null) {
        timer.cancel();
        return;
      }

      if (_lastPong != null &&
          DateTime.now().difference(_lastPong!) > pongTimeout) {
        _handleDisconnect('Heartbeat timeout');
        return;
      }

      try {
        _socket!.add(jsonEncode({'event': 'ping'}));
      } catch (_) {
        _handleDisconnect('Heartbeat failed');
      }
    });
  }

  void join(String room) => emit('join', {'room': room});
  void leave(String room) => emit('leave', {'room': room});
}
