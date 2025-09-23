import 'package:flint_client/flint_client.dart';
import 'package:flint_client/src/ai/provider/ai_provider.dart';
import 'package:flint_client/src/flint_response.dart';

class OpenAIProvider extends AIProvider {
  OpenAIProvider({required String apiKey})
    : super(
        baseUrl: 'https://api.openai.com/v1',
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
      );

  @override
  Future<FlintResponse<dynamic>> sendRequest(
    String model,
    dynamic payload,
  ) async {
    final client = FlintClient(baseUrl: baseUrl, headers: headers, debug: true);

    // OpenAI expects messages array for chat models
    final requestBody = {
      'model': model,
      'messages': payload['inputs'], // includes history
      'max_tokens': payload['max_tokens'],
    };

    return await client.post('/chat/completions', body: requestBody);
  }
}
