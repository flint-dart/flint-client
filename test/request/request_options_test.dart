library;

import 'package:flint_client/flint_client.dart';
import 'package:test/test.dart';

void main() {
  group('RequestOptions', () {
    test('stores provided values', () {
      final token = CancelToken();
      final context = RequestContext(
        method: 'GET',
        url: Uri.parse('https://example.com'),
      );
      final options = RequestOptions<String>(
        body: {'a': 1},
        queryParameters: {'page': 2},
        headers: {'X-Test': '1'},
        timeout: Duration(milliseconds: 150),
        cancelToken: token,
        context: context,
        parseMode: ResponseParseMode.strict,
        parser: (data) => data.toString(),
      );

      expect(options.body, isA<Map>());
      expect(options.queryParameters, containsPair('page', 2));
      expect(options.headers, containsPair('X-Test', '1'));
      expect(options.timeout, Duration(milliseconds: 150));
      expect(options.cancelToken, same(token));
      expect(options.context, same(context));
      expect(options.parseMode, ResponseParseMode.strict);
      expect(options.parser?.call(10), '10');
    });

    test('supports empty/default configuration', () {
      const options = RequestOptions<dynamic>();

      expect(options.body, isNull);
      expect(options.queryParameters, isNull);
      expect(options.headers, isNull);
      expect(options.timeout, isNull);
      expect(options.cancelToken, isNull);
      expect(options.context, isNull);
      expect(options.parseMode, isNull);
    });
  });
}
