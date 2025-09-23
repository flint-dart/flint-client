class AIMessage {
  final String role; // "user" or "assistant"
  final String content;

  AIMessage({required this.role, required this.content});

  Map<String, String> toJson() => {'role': role, 'content': content};
}
