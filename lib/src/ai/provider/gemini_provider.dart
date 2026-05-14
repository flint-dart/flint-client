import 'package:flint_client/src/ai/provider/ai_provider.dart';
import 'package:flint_client/src/flint_client_base.dart'
    if (dart.library.js_interop) 'package:flint_client/src/web/flint_client_web.dart';
import 'package:flint_client/src/flint_response.dart'
    if (dart.library.js_interop) 'package:flint_client/src/web/flint_client_web.dart';

class GeminiProvider extends AIProvider {
  final String apiKey;
  GeminiProvider({required this.apiKey})
    : super(
        baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
        headers: {'Content-Type': 'application/json'},
      );

  @override
  dynamic buildPayload(
    String model,
    String? prompt,
    int maxTokens,
    bool includeHistory,
  ) {
    if (prompt == null || prompt.trim().isEmpty) {
      throw Exception("❌ Gemini prompt cannot be empty.");
    }

    // Include history as part of text if needed
    final fullText = includeHistory
        ? "${history.map((m) => "${m.role}: ${m.content}").join("\n")}\nUser: $prompt"
        : prompt;

    // Gemini expects "contents -> parts -> text"
    return {
      "contents": [
        {
          "parts": [
            {"text": fullText},
          ],
        },
      ],
    };
  }

  @override
  Future<FlintResponse<dynamic>> sendRequest(
    String model,
    dynamic payload,
  ) async {
    final client = FlintClient(baseUrl: baseUrl, headers: headers, debug: true);
    final endpoint = '/models/$model:generateContent?key=$apiKey';

    return await client.post(endpoint, body: payload);
  }
}
