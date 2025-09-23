/// Represents an error returned by the Flint client.
class FlintError {
  /// The error message describing what went wrong.
  final String message;

  /// Creates a new [FlintError] with the given [message].
  FlintError(this.message);

  @override
  String toString() => 'FlintError: $message';
}
