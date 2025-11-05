class GeminiResponse {
  final String? text; // ✅ Primary response text
  final List<String>? candidates; // All candidate texts
  final String? modelVersion;
  final Map<String, dynamic>? usage; // token usage info
  final Map<String, dynamic>? raw; // full raw API data

  GeminiResponse({
    this.text,
    this.candidates,
    this.modelVersion,
    this.usage,
    this.raw,
  });

  /// Parse raw Gemini API JSON into a structured model
  factory GeminiResponse.fromJson(dynamic json) {
    if (json == null) return GeminiResponse(raw: {});

    // Extract candidates text
    final List<String> candidateTexts =
        (json['candidates'] as List?)
            ?.map(
              (c) =>
                  (c['content']?['parts']?[0]?['text'] ??
                          c['content']?['parts']?.first?['text'] ??
                          '')
                      .toString(),
            )
            .where((t) => t.isNotEmpty)
            .toList() ??
        [];

    // Pick the first text as the main response
    final String? mainText = candidateTexts.isNotEmpty
        ? candidateTexts.first
        : null;

    // Extract usage info if available
    final Map<String, dynamic>? usage = json['usageMetadata'] != null
        ? {
            'promptTokens': json['usageMetadata']['promptTokenCount'],
            'responseTokens': json['usageMetadata']['candidatesTokenCount'],
            'totalTokens': json['usageMetadata']['totalTokenCount'],
          }
        : null;

    return GeminiResponse(
      text: mainText,
      candidates: candidateTexts,
      modelVersion: json['modelVersion'],
      usage: usage,
      raw: json,
    );
  }

  /// Returns a human-readable summary
  @override
  String toString() =>
      text ??
      (candidates != null && candidates!.isNotEmpty
          ? candidates!.first
          : 'No response text found');
}
