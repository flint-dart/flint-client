import 'dart:async';

/// Token used to cancel in-flight requests.
class CancelToken {
  final Completer<String?> _cancelCompleter = Completer<String?>();
  String? _reason;

  /// True when [cancel] was called.
  bool get isCancelled => _cancelCompleter.isCompleted;

  /// Optional cancellation reason.
  String? get reason => _reason;

  /// Completes when the token is cancelled.
  Future<String?> get whenCancelled => _cancelCompleter.future;

  /// Cancels the token. Repeated calls are ignored.
  void cancel([String? reason]) {
    if (isCancelled) return;
    _reason = reason;
    _cancelCompleter.complete(reason);
  }
}
