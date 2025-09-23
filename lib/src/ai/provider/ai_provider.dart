import 'dart:io';
import 'package:flint_client/src/ai/model/ai_model.dart';
import 'package:flint_client/src/flint_response.dart';

abstract class AIProvider {
  final String baseUrl;
  final Map<String, String> headers;
  final List<AIMessage> _history = []; // stores conversation

  AIProvider({required this.baseUrl, this.headers = const {}});

  /// Sends a request to the AI model with optional conversation history
  Future<FlintResponse<dynamic>> request({
    required String model,
    String? prompt,
    Map<String, File>? files,
    FlintResponseType responseType = FlintResponseType.json,
    int maxTokens = 256,
    bool includeHistory = true, // new flag
  }) async {
    // Add the user's message to history
    if (prompt != null) {
      _history.add(AIMessage(role: 'user', content: prompt));
    }

    // Build the payload including conversation if requested
    final payload = _buildPayload(
      model,
      prompt,
      files,
      maxTokens,
      includeHistory,
    );

    final response = await sendRequest(model, payload);

    // Add AI response to history
    if (response.data != null) {
      _history.add(
        AIMessage(role: 'assistant', content: response.data.toString()),
      );
    }

    return response;
  }

  /// Each provider implements how the request is actually sent
  Future<FlintResponse<dynamic>> sendRequest(String model, dynamic payload);

  /// Build the payload including history
  dynamic _buildPayload(
    String model,
    String? prompt,
    Map<String, File>? files,
    int maxTokens,
    bool includeHistory,
  ) {
    if (includeHistory) {
      return {
        'model': model,
        'inputs': _history.map((m) => m.toJson()).toList(),
        'max_tokens': maxTokens,
      };
    } else {
      return {'model': model, 'inputs': prompt, 'max_tokens': maxTokens};
    }
  }

  /// Optional: reset conversation history
  void resetHistory() => _history.clear();
}
