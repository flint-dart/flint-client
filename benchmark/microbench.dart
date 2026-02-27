import 'dart:convert';
import 'dart:io';

import 'package:flint_client/flint_client.dart';

Future<void> main() async {
  final server = await HttpServer.bind('localhost', 0);
  server.listen((request) {
    final response = request.response;
    response.headers.contentType = ContentType.json;
    response.statusCode = 200;
    response.write(jsonEncode({'id': 1, 'name': 'benchmark'}));
    response.close();
  });

  final baseUrl = 'http://localhost:${server.port}';
  final payload = {
    'a': 1,
    'b': true,
    'c': List<int>.generate(10, (i) => i),
    'd': {'nested': 'value'},
  };

  final serializer = const JsonBodySerializer();
  final serializerSw = Stopwatch()..start();
  for (var i = 0; i < 10000; i++) {
    serializer.serialize(payload);
  }
  serializerSw.stop();

  final parseClient = FlintClient(
    baseUrl: baseUrl,
    defaultParseMode: ResponseParseMode.lenient,
  );
  final parseSw = Stopwatch()..start();
  for (var i = 0; i < 200; i++) {
    await parseClient.get<Map<String, dynamic>>('/');
  }
  parseSw.stop();
  parseClient.dispose();

  final cacheClient = FlintClient(
    baseUrl: baseUrl,
    defaultCacheConfig: CacheConfig(maxAge: Duration(minutes: 1)),
  );

  // Warm cache.
  await cacheClient.get<Map<String, dynamic>>('/');

  final cacheSw = Stopwatch()..start();
  for (var i = 0; i < 200; i++) {
    await cacheClient.get<Map<String, dynamic>>('/');
  }
  cacheSw.stop();
  cacheClient.dispose();

  await server.close(force: true);

  print(
    'serializer.json.serialize(10k): ${serializerSw.elapsedMilliseconds}ms',
  );
  print('client.parse.lenient(200 req): ${parseSw.elapsedMilliseconds}ms');
  print('client.cache.hit(200 req): ${cacheSw.elapsedMilliseconds}ms');
}
