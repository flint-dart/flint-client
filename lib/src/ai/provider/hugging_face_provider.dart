import 'package:flint_client/flint_client.dart';

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

    // Hugging Face expects a 'inputs' key in the body for text models
    final inputData = payload['inputs'] ?? payload['prompt'] ?? payload;

    final body = {
      'inputs': inputData,
      // Optional parameters like max_length, temperature, etc. can be added later
      if (payload['parameters'] != null) 'parameters': payload['parameters'],
    };

    return await client.post('/$model', body: body);
  }
}
