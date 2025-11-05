class OpenAIResponse {
  final String? text; // For chat or text completion
  final List<String>? messages; // Full message history (assistant replies)
  final List<List<double>>? embeddings; // For embedding results
  final Map<String, dynamic>? usage; // Tokens used, etc.
  final Map<String, dynamic>? raw; // Raw API response

  OpenAIResponse({
    this.text,
    this.messages,
    this.embeddings,
    this.usage,
    this.raw,
  });

  /// Parse any OpenAI API response into a structured model
  factory OpenAIResponse.fromJson(dynamic json) {
    if (json == null) return OpenAIResponse(raw: {});

    // 🧠 Case 1: Chat Completion (GPT-style)
    if (json['choices'] != null && json['choices'] is List) {
      final choices = json['choices'];
      final text =
          choices.first['message']?['content'] ?? choices.first['text'] ?? "";

      return OpenAIResponse(
        text: text.trim(),
        messages: choices
            .map<String?>((c) => c['message']?['content']?.toString())
            .whereType<String>()
            .toList(),
        usage: json['usage'],
        raw: json,
      );
    }

    // 🧠 Case 2: Embedding API
    if (json['data'] != null &&
        json['data'] is List &&
        json['data'].first['embedding'] != null) {
      return OpenAIResponse(
        embeddings: (json['data'] as List)
            .map<List<double>>((e) => (e['embedding'] as List).cast<double>())
            .toList(),
        usage: json['usage'],
        raw: json,
      );
    }

    // 🧠 Fallback — unknown structure
    return OpenAIResponse(raw: json);
  }

  /// Human-readable summary
  @override
  String toString() =>
      text ??
      (embeddings != null
          ? 'Embedding vector (${embeddings!.first.length} dims)'
          : 'Unknown response');
}
