import 'protocol/flint_db_protocol.dart';

import '../flint_client_base.dart';
import 'flint_database_client_core.dart';

export 'flint_database_client_core.dart';

class FlintDatabaseClient {
  FlintDatabaseClient({required this.client, this.basePath = '/db/v1'});

  final FlintClient client;
  final String basePath;

  late final FlintDbAuthClient auth = FlintDbAuthClient(_request, basePath);

  FlintDbResourceClient from(String resource) => FlintDbResourceClient(
    _request,
    '$basePath/${Uri.encodeComponent(resource)}',
  );

  Future<FlintDbResult<List<Map<String, dynamic>>>> query(
    String resource,
    FlintDbQuery query,
  ) => from(resource).query(query);

  Future<Map<String, dynamic>> _request(
    String method,
    String path,
    Map<String, dynamic>? body,
  ) async {
    final response = switch (method) {
      'GET' => await client.get<Map<String, dynamic>>(path, parser: _parse),
      'POST' => await client.post<Map<String, dynamic>>(
        path,
        body: body,
        parser: _parse,
      ),
      'PATCH' => await client.patch<Map<String, dynamic>>(
        path,
        body: body,
        parser: _parse,
      ),
      'DELETE' => await client.delete<Map<String, dynamic>>(
        path,
        parser: _parse,
      ),
      _ => throw ArgumentError.value(method, 'method'),
    };
    if (response.data != null) return response.data!;
    throw FlintDbClientException(
      response.error?.message ?? 'The database request failed.',
    );
  }

  static Map<String, dynamic> _parse(dynamic json) =>
      Map<String, dynamic>.from(json as Map);

  static FlintDbResult<List<Map<String, dynamic>>> decodeRows(
    Map<String, dynamic> json,
  ) => FlintDbResult<List<Map<String, dynamic>>>.fromJson(
    json,
    (value) => (value as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false),
  );
}
