import 'package:flint_client/src/ai/provider/ai_provider.dart';
import 'package:flint_client/src/flint_client_base.dart';
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

    // Extract inputs and prepare messages
    final inputs = payload['inputs'];

    final requestBody = {
      'model': model,
      'messages': inputs is List
          ? inputs // already structured chat messages
          : [
              {'role': 'user', 'content': inputs.toString()},
            ],
      'max_tokens': payload['max_tokens'] ?? 256,
    };

    return await client.post('/chat/completions', body: requestBody);
  }
}
