import 'protocol/flint_db_protocol.dart';

typedef FlintDbTransport =
    Future<Map<String, dynamic>> Function(
      String method,
      String path,
      Map<String, dynamic>? body,
    );

class FlintDbClientException implements Exception {
  const FlintDbClientException(this.message, {this.error});

  final String message;
  final FlintDbError? error;

  @override
  String toString() => message;
}

class FlintDbAuthSession {
  const FlintDbAuthSession({required this.token, required this.user});

  final String token;
  final Map<String, dynamic> user;
}

class FlintDbAuthClient {
  FlintDbAuthClient(this._transport, this._basePath);

  final FlintDbTransport _transport;
  final String _basePath;

  Future<FlintDbAuthSession> register({
    required String name,
    required String email,
    required String password,
  }) async => _session(
    await _transport('POST', '$_basePath/auth/register', {
      'name': name,
      'email': email,
      'password': password,
    }),
  );

  Future<FlintDbAuthSession> login({
    required String email,
    required String password,
  }) async => _session(
    await _transport('POST', '$_basePath/auth/login', {
      'email': email,
      'password': password,
    }),
  );

  Future<Map<String, dynamic>> me() async => Map<String, dynamic>.from(
    _data(await _transport('GET', '$_basePath/auth/me', null)) as Map,
  );

  FlintDbAuthSession _session(Map<String, dynamic> envelope) {
    final data = Map<String, dynamic>.from(_data(envelope) as Map);
    return FlintDbAuthSession(
      token: data['token'].toString(),
      user: Map<String, dynamic>.from(data['user'] as Map),
    );
  }
}

class FlintDbResourceClient {
  FlintDbResourceClient(this._transport, this._path);

  final FlintDbTransport _transport;
  final String _path;

  Future<FlintDbResult<List<Map<String, dynamic>>>> query(
    FlintDbQuery query,
  ) async => FlintDbResult<List<Map<String, dynamic>>>.fromJson(
    await _transport('POST', '$_path/query', query.toJson()),
    (value) => (value as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false),
  );

  Future<List<Map<String, dynamic>>> select({
    List<String> fields = const [],
    FlintDbFilter? filter,
    List<FlintDbOrder> order = const [],
    int? limit,
    int? offset,
  }) async {
    final result = await query(
      FlintDbQuery(
        select: fields,
        filter: filter,
        order: order,
        limit: limit,
        offset: offset,
      ),
    );
    if (!result.isSuccess) {
      throw FlintDbClientException(result.error!.message, error: result.error);
    }
    return result.data!;
  }

  Future<Map<String, dynamic>> insert(Map<String, dynamic> values) async =>
      Map<String, dynamic>.from(
        _data(await _transport('POST', _path, values)) as Map,
      );

  Future<Map<String, dynamic>> update(
    Object id,
    Map<String, dynamic> values,
  ) async => Map<String, dynamic>.from(
    _data(await _transport('PATCH', '$_path/$id', values)) as Map,
  );

  Future<void> delete(Object id) async {
    _data(await _transport('DELETE', '$_path/$id', null));
  }
}

Object? _data(Map<String, dynamic> envelope) {
  final rawError = envelope['error'];
  if (rawError is Map) {
    final error = FlintDbError.fromJson(Map<String, dynamic>.from(rawError));
    throw FlintDbClientException(error.message, error: error);
  }
  return envelope['data'];
}
