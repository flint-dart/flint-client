library;

import 'package:flint_client/flint_client.dart';
import 'package:test/test.dart';

void main() {
  group('CancelToken', () {
    test('starts in non-cancelled state', () {
      final token = CancelToken();

      expect(token.isCancelled, isFalse);
      expect(token.reason, isNull);
    });

    test('cancel sets state and reason', () async {
      final token = CancelToken();
      token.cancel('stop');

      expect(token.isCancelled, isTrue);
      expect(token.reason, 'stop');
      expect(await token.whenCancelled, 'stop');
    });

    test('second cancel call does not override reason', () async {
      final token = CancelToken();
      token.cancel('first');
      token.cancel('second');

      expect(token.reason, 'first');
      expect(await token.whenCancelled, 'first');
    });
  });
}
