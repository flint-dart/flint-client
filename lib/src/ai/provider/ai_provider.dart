import 'package:flint_client/flint_client.dart';

/// Base AI provider — stores conversation history and context memory
abstract class AIProvider {
  final String baseUrl;
  final Map<String, String> headers;
  final List<AIMessage> _history = [];
  final List<String> _contextMemory = [];

  AIProvider({required this.baseUrl, this.headers = const {}});
  List<AIMessage> get history => _history;

  /// Add a text snippet to context memory
  void addContextMemory(String text) {
    if (text.trim().isEmpty) {
      throw Exception("❌ Context text cannot be empty.");
    }
    _contextMemory.add(text);
  }

  /// Clear all context memory
  void clearContextMemory() => _contextMemory.clear();

  /// Add a message to conversation history
  void addMessage(String role, String content) =>
      _history.add(AIMessage(role: role, content: content));

  /// Add a message to conversation history
  void addAllMessage(List<AIMessage> messages) => _history.addAll(messages);

  /// Reset conversation history
  void resetHistory() => _history.clear();

  /// Sends a request to AI with optional history and context
  Future<FlintResponse<dynamic>> request({
    required String model,
    String? prompt,
    bool includeHistory = true,
    bool includeContext = true,
    int maxTokens = 256,
  }) async {
    if (prompt != null) {
      addMessage('user', prompt);
    }

    final combinedPrompt = includeContext && _contextMemory.isNotEmpty
        ? "Context:\n${_contextMemory.join('\n\n')}\n\nUser: $prompt"
        : prompt;

    final payload = buildPayload(
      model,
      combinedPrompt,
      maxTokens,
      includeHistory,
    );

    final response = await sendRequest(model, payload);

    if (response.data != null) {
      addMessage('assistant', response.data.toString());
    }

    return response;
  }

  /// Build payload — can be overridden per provider
  dynamic buildPayload(
    String model,
    String? prompt,
    int maxTokens,
    bool includeHistory,
  ) {
    // Default implementation (can be overridden)
    final fullPrompt = includeHistory
        ? "${_history.map((m) => "${m.role}: ${m.content}").join("\n")}\n${prompt ?? ''}"
        : prompt ?? '';

    return {
      'model': model,
      'prompt': fullPrompt,
      'max_output_tokens': maxTokens,
    };
  }

  /// Must be implemented by each provider (Gemini, HF, etc.)
  Future<FlintResponse<dynamic>> sendRequest(String model, dynamic payload);
}
