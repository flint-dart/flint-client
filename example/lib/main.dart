import 'package:flint_client/flint_client.dart';

void main(List<String> args) async {
  final gemini = GeminiProvider(apiKey: '');

  gemini.addContextMemory(
    """Eulogia Technologies is a technology company that builds reliable software, hosting solutions, and learning platforms.  
Our focus is on helping individuals, businesses, and schools achieve more through simple, powerful tools.""",
  );

  final response = await gemini.request(
    model: 'gemini-2.5-flash',
    prompt: "Explain what Eulogia Technologies does.",
  );

  final parsed = GeminiResponse.fromJson(response.data);

  print("AI response: ${parsed.text}");
}

// Content?key=$apiKey
