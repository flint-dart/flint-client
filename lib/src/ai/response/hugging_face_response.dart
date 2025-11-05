class HuggingFaceResponse {
  final String? generatedText;
  final List<dynamic>? embeddings;
  final List<dynamic>? labels;
  final List<dynamic>? scores;
  final Map<String, dynamic>? raw;

  HuggingFaceResponse({
    this.generatedText,
    this.embeddings,
    this.labels,
    this.scores,
    this.raw,
  });

  /// Parse API JSON response into structured data
  factory HuggingFaceResponse.fromJson(dynamic json) {
    if (json is List && json.isNotEmpty) {
      final first = json.first;

      // 🧠 Case 1: Text generation models (returns [{"generated_text": "..."}])
      if (first is Map && first.containsKey('generated_text')) {
        return HuggingFaceResponse(
          generatedText: first['generated_text'],
          raw: {'data': json},
        );
      }

      // 🧠 Case 2: Text classification / sentiment models
      if (first is Map && first.containsKey('label')) {
        return HuggingFaceResponse(
          labels: json.map((e) => e['label']).toList(),
          scores: json.map((e) => e['score']).toList(),
          raw: {'data': json},
        );
      }

      // 🧠 Case 3: Embedding models (return [[float, float, ...]])
      if (first is List) {
        return HuggingFaceResponse(embeddings: json, raw: {'data': json});
      }
    }

    // 🧠 Case 4: Fallback (if it's just a raw string or map)
    if (json is Map && json.containsKey('generated_text')) {
      return HuggingFaceResponse(
        generatedText: json['generated_text'],
        raw: json as Map<String, dynamic>,
      );
    }

    return HuggingFaceResponse(raw: {'data': json});
  }

  /// Convenience getter for quick printing
  @override
  String toString() =>
      generatedText ??
      (labels != null
          ? labels.toString()
          : embeddings?.toString() ?? 'Unknown response');
}
