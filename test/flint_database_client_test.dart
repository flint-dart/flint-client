import 'package:flint_client/flint_client.dart';
import 'package:test/test.dart';

void main() {
  test('database client decodes the shared success envelope', () {
    final result = FlintDatabaseClient.decodeRows({
      'data': [
        {'id': 'todo-1', 'title': 'Ship Flint DB API'},
      ],
      'error': null,
      'meta': {'requestId': 'req_1', 'count': 1},
    });

    expect(result.isSuccess, isTrue);
    expect(result.data!.single['id'], 'todo-1');
    expect(result.meta.requestId, 'req_1');
  });

  test('database client preserves the shared error envelope', () {
    final result = FlintDatabaseClient.decodeRows({
      'data': null,
      'error': {
        'code': 'permission_denied',
        'message': 'The operation is not allowed.',
      },
      'meta': {'requestId': 'req_2'},
    });

    expect(result.isSuccess, isFalse);
    expect(result.error!.code, FlintDbErrorCode.permissionDenied);
    expect(result.meta.requestId, 'req_2');
  });

  test('high-level auth client hides auth endpoint paths', () async {
    String? requestedPath;
    final auth = FlintDbAuthClient((method, path, body) async {
      requestedPath = path;
      return {
        'data': {
          'token': 'jwt-token',
          'user': {'id': 'user-1'},
        },
        'error': null,
        'meta': {'requestId': 'req_auth'},
      };
    }, '/db/v1');

    final session = await auth.register(
      name: 'Ada',
      email: 'ada@example.com',
      password: 'secret12',
    );

    expect(requestedPath, '/db/v1/auth/register');
    expect(session.token, 'jwt-token');
    expect(session.user['id'], 'user-1');
  });

  test(
    'high-level resource client maps CRUD to the package transport',
    () async {
      final calls = <String>[];
      final todos = FlintDbResourceClient((method, path, body) async {
        calls.add('$method $path');
        return {
          'data': method == 'DELETE'
              ? {'deleted': true}
              : {'id': 'todo-1', ...?body},
          'error': null,
          'meta': {'requestId': 'req_crud'},
        };
      }, '/db/v1/todos');

      await todos.insert({'title': 'Build package'});
      await todos.update('todo-1', {'completed': true});
      await todos.delete('todo-1');

      expect(calls, [
        'POST /db/v1/todos',
        'PATCH /db/v1/todos/todo-1',
        'DELETE /db/v1/todos/todo-1',
      ]);
    },
  );
}
