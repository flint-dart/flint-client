class GeminiChatResponse {
  final List<GeminiChatCandidate> candidates;
  final GeminiUsage? usageMetadata;
  final String? modelVersion;
  final String? responseId;

  GeminiChatResponse({
    required this.candidates,
    this.usageMetadata,
    this.modelVersion,
    this.responseId,
  });

  factory GeminiChatResponse.fromJson(Map<String, dynamic> json) {
    return GeminiChatResponse(
      candidates:
          (json['candidates'] as List<dynamic>?)
              ?.map((c) => GeminiChatCandidate.fromJson(c))
              .toList() ??
          [],
      usageMetadata: json['usageMetadata'] != null
          ? GeminiUsage.fromJson(json['usageMetadata'])
          : null,
      modelVersion: json['modelVersion'],
      responseId: json['responseId'],
    );
  }

  /// Returns combined text from all candidates (multi-turn conversation)
  String get fullText => candidates.map((c) => c.content.text).join('\n');

  /// Returns the latest model message (most relevant to user)
  String? get latestMessage =>
      candidates.isNotEmpty ? candidates.first.content.text : null;
}

class GeminiChatCandidate {
  final GeminiChatContent content;
  final String? finishReason;
  final int? index;

  GeminiChatCandidate({required this.content, this.finishReason, this.index});

  factory GeminiChatCandidate.fromJson(Map<String, dynamic> json) {
    return GeminiChatCandidate(
      content: GeminiChatContent.fromJson(json['content']),
      finishReason: json['finishReason'],
      index: json['index'],
    );
  }
}

class GeminiChatContent {
  final List<GeminiChatPart> parts;
  final String? role; // "user" or "model"

  GeminiChatContent({required this.parts, this.role});

  factory GeminiChatContent.fromJson(Map<String, dynamic> json) {
    return GeminiChatContent(
      parts:
          (json['parts'] as List<dynamic>?)
              ?.map((p) => GeminiChatPart.fromJson(p))
              .toList() ??
          [],
      role: json['role'],
    );
  }

  String get text => parts.map((p) => p.text ?? '').join('\n');
}

class GeminiChatPart {
  final String? text;

  GeminiChatPart({this.text});

  factory GeminiChatPart.fromJson(Map<String, dynamic> json) {
    return GeminiChatPart(text: json['text']);
  }
}

class GeminiUsage {
  final int? promptTokenCount;
  final int? candidatesTokenCount;
  final int? totalTokenCount;

  GeminiUsage({
    this.promptTokenCount,
    this.candidatesTokenCount,
    this.totalTokenCount,
  });

  factory GeminiUsage.fromJson(Map<String, dynamic> json) {
    return GeminiUsage(
      promptTokenCount: json['promptTokenCount'],
      candidatesTokenCount: json['candidatesTokenCount'],
      totalTokenCount: json['totalTokenCount'],
    );
  }
}
