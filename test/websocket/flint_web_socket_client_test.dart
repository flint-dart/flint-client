library;

import 'dart:async';
import 'dart:io';

import 'package:flint_client/flint_client.dart';
import 'package:test/test.dart';

void main() {
  group('FlintWebSocketClient auth', () {
    late HttpServer server;
    late String wsUrl;

    setUp(() async {
      server = await HttpServer.bind('localhost', 0);
      wsUrl = 'ws://localhost:${server.port}/ws';
    });

    tearDown(() async {
      await server.close(force: true);
    });

    test(
      'flintClient.ws forwards Authorization header during handshake',
      () async {
        final capturedHeaders = Completer<Map<String, List<String>>>();
        server.listen((request) async {
          if (!capturedHeaders.isCompleted) {
            final headers = <String, List<String>>{};
            request.headers.forEach((name, values) {
              headers[name] = List<String>.from(values);
            });
            capturedHeaders.complete(headers);
          }
          final socket = await WebSocketTransformer.upgrade(request);
          socket.close();
        });

        final baseClient = FlintClient(
          baseUrl: 'http://localhost:${server.port}',
          headers: {'Authorization': 'Bearer ws-secret'},
        );

        final wsClient = baseClient.ws('/ws');
        await wsClient.connect();

        final headers = await capturedHeaders.future.timeout(
          const Duration(seconds: 2),
        );
        expect(headers['authorization'], isNotNull);
        expect(headers['authorization']!, contains('Bearer ws-secret'));

        wsClient.dispose();
        baseClient.dispose();
      },
    );

    test('supports token auth via query parameter', () async {
      final capturedQuery = Completer<Map<String, String>>();
      server.listen((request) async {
        if (!capturedQuery.isCompleted) {
          capturedQuery.complete(
            Map<String, String>.from(request.uri.queryParameters),
          );
        }
        final socket = await WebSocketTransformer.upgrade(request);
        socket.close();
      });

      final wsClient = FlintWebSocketClient(
        wsUrl,
        sendTokenAsQuery: true,
        queryTokenKey: 'authToken',
        tokenProvider: () async => 'dynamic-token',
      );

      await wsClient.connect();

      final query = await capturedQuery.future.timeout(
        const Duration(seconds: 2),
      );
      expect(query['authToken'], 'dynamic-token');

      wsClient.dispose();
    });
  });
}
