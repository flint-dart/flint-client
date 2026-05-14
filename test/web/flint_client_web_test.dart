@TestOn('browser')
library;

import 'package:flint_client/flint_client.dart';
import 'package:test/test.dart';

void main() {
  group('web FlintClient export', () {
    test('exposes browser-safe client and response API', () {
      final client = FlintClient(
        baseUrl: 'https://example.test',
        headers: const {'X-Test': 'yes'},
        defaultQueryParameters: const {'from': 'browser'},
      );

      final response = FlintResponse<Map<String, dynamic>>(
        statusCode: 200,
        data: const {'ok': true},
        type: FlintResponseType.json,
      );

      expect(client.baseUrl, 'https://example.test');
      expect(client.headers, containsPair('X-Test', 'yes'));
      expect(response.isSuccess, isTrue);
      expect(response.isJson, isTrue);
      expect(response.requireData, containsPair('ok', true));

      client.dispose();
    });

    test('returns typed error responses', () {
      final error = FlintError(
        'Unauthorized',
        statusCode: 401,
        kind: FlintErrorKind.http,
      );
      final response = FlintResponse<String>.error(error);

      expect(response.isError, isTrue);
      expect(response.error, same(error));
      expect(response.error?.isClientError, isTrue);
      expect(() => response.throwIfError(), throwsA(same(error)));
    });

    test('exposes AI providers in browser builds', () {
      final openAI = OpenAIProvider(apiKey: 'test-key');
      final gemini = GeminiProvider(apiKey: 'test-key');
      final huggingFace = HuggingFaceProvider(apiKey: 'test-key');

      openAI.addMessage('user', 'hello');

      expect(openAI.history, hasLength(1));
      expect(openAI.history.first, isA<AIMessage>());
      expect(gemini.baseUrl, contains('generativelanguage'));
      expect(huggingFace.baseUrl, contains('huggingface'));
    });
  });
}
