import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flint_client/flint_client.dart';

Future<void> main() async {
  final server = await _startMockWsServer();
  final httpBaseUrl = 'http://localhost:${server.port}';
  final wsUrl = 'ws://localhost:${server.port}/ws';

  await _headerAuthExample(httpBaseUrl);
  await _queryAuthExample(wsUrl);
  await _authEventExample(wsUrl);

  await server.close(force: true);
}

Future<void> _headerAuthExample(String httpBaseUrl) async {
  print('\n=== WebSocket header auth (FlintClient.ws) ===');

  final client = FlintClient(
    baseUrl: httpBaseUrl,
    headers: {'Authorization': 'Bearer header-token-123'},
    debug: true,
  );

  final ws = client.ws('/ws', params: {'example': 'header'});
  ws.on('connect', (_) => print('Connected with header token'));
  ws.on('ack', (data) => print('Server ack: $data'));

  await ws.connect();
  ws.emit('message', {'text': 'hello from header auth'});

  await Future<void>.delayed(const Duration(milliseconds: 300));
  ws.dispose();
  client.dispose();
}

Future<void> _queryAuthExample(String wsUrl) async {
  print('\n=== WebSocket query auth (token in URL) ===');

  final ws = FlintWebSocketClient(
    wsUrl,
    params: {'example': 'query'},
    sendTokenAsQuery: true,
    queryTokenKey: 'token',
    tokenProvider: () async => 'query-token-456',
    debug: true,
  );

  ws.on('connect', (_) => print('Connected with query token'));
  ws.on('ack', (data) => print('Server ack: $data'));

  await ws.connect();
  ws.emit('message', {'text': 'hello from query auth'});

  await Future<void>.delayed(const Duration(milliseconds: 300));
  ws.dispose();
}

Future<void> _authEventExample(String wsUrl) async {
  print('\n=== WebSocket auth event after connect ===');

  final ws = FlintWebSocketClient(
    wsUrl,
    params: {'example': 'event'},
    autoAuthEvent: true,
    authEventName: 'auth',
    authPayload: {'token': 'event-token-789'},
    debug: true,
  );

  ws.on('connect', (_) => print('Connected, auth event will auto-send'));
  ws.on('authed', (data) => print('Auth accepted: $data'));
  ws.on('ack', (data) => print('Server ack: $data'));

  await ws.connect();
  ws.emit('message', {'text': 'hello after auth event'});

  await Future<void>.delayed(const Duration(milliseconds: 300));
  ws.dispose();
}

Future<HttpServer> _startMockWsServer() async {
  final server = await HttpServer.bind('localhost', 0);

  server.listen((request) async {
    if (request.uri.path != '/ws') {
      request.response
        ..statusCode = 404
        ..write('Not found')
        ..close();
      return;
    }

    final authHeader = request.headers.value(HttpHeaders.authorizationHeader);
    final tokenFromQuery = request.uri.queryParameters['token'];
    final exampleType = request.uri.queryParameters['example'] ?? 'unknown';

    final socket = await WebSocketTransformer.upgrade(request);
    socket.add(
      jsonEncode({
        'event': 'ack',
        'data': {
          'example': exampleType,
          'authHeader': authHeader,
          'tokenFromQuery': tokenFromQuery,
        },
      }),
    );

    socket.listen((raw) {
      try {
        final msg = jsonDecode(raw.toString()) as Map<String, dynamic>;
        final event = msg['event']?.toString() ?? '';
        final data = msg['data'];

        if (event == 'auth') {
          socket.add(jsonEncode({'event': 'authed', 'data': data}));
          return;
        }
        if (event == 'ping') {
          socket.add(jsonEncode({'event': 'pong'}));
          return;
        }

        socket.add(
          jsonEncode({
            'event': 'message',
            'data': {'echo': data},
          }),
        );
      } catch (_) {}
    });
  });

  return server;
}
