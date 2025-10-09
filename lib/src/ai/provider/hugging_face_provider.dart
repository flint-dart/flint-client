import 'package:flint_client/flint_client.dart';
import 'package:flint_client/src/ai/provider/ai_provider.dart';

class HuggingFaceProvider extends AIProvider {
  HuggingFaceProvider({required String apiKey})
    : super(
        baseUrl: 'https://api-inference.huggingface.co/models',
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
    return await client.post('/$model', body: payload);
  }
}
