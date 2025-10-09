/// Configurable status code mapping that frontend devs can customize
class StatusCodeConfig {
  final Set<int> successCodes;
  final Set<int> errorCodes;
  final Set<int> redirectCodes;
  final Set<int> clientErrorCodes;
  final Set<int> serverErrorCodes;

  /// Default configuration following standard HTTP
  const StatusCodeConfig({
    this.successCodes = const {200, 201, 202, 204},
    this.errorCodes = const {400, 401, 402, 403, 404, 405, 408, 409, 410, 422, 429, 500, 501, 502, 503, 504},
    this.redirectCodes = const {301, 302, 303, 304, 307, 308},
    this.clientErrorCodes = const {400, 401, 402, 403, 404, 405, 408, 409, 410, 422, 429},
    this.serverErrorCodes = const {500, 501, 502, 503, 504},
  });

  /// Create custom configuration based on API documentation
  const StatusCodeConfig.custom({
    required this.successCodes,
    required this.errorCodes,
    required this.redirectCodes,
    required this.clientErrorCodes,
    required this.serverErrorCodes,
  });

  /// Factory for common API patterns
  factory StatusCodeConfig.forApi({
    /// Some APIs use 200 for everything, even errors
    bool uses200ForErrors = false,
    
    /// Some APIs use custom success codes
    Set<int>? customSuccessCodes,
    
    /// Some APIs have special redirect behaviors
    Set<int>? customRedirectCodes,
  }) {
    if (uses200ForErrors) {
      return StatusCodeConfig.custom(
        successCodes: customSuccessCodes ?? {200},
        errorCodes: {200}, // They put error details in 200 responses
        redirectCodes: customRedirectCodes ?? {301, 302, 308},
        clientErrorCodes: {200},
        serverErrorCodes: {200},
      );
    }
    
    return StatusCodeConfig.custom(
      successCodes: customSuccessCodes ?? {200, 201, 204},
      errorCodes: const {400, 401, 403, 404, 422, 429, 500},
      redirectCodes: customRedirectCodes ?? {301, 302, 308},
      clientErrorCodes: const {400, 401, 403, 404, 422, 429},
      serverErrorCodes: const {500},
    );
  }

  /// Helper methods
  bool isSuccess(int statusCode) => successCodes.contains(statusCode);
  bool isError(int statusCode) => errorCodes.contains(statusCode);
  bool isRedirect(int statusCode) => redirectCodes.contains(statusCode);
  bool isClientError(int statusCode) => clientErrorCodes.contains(statusCode);
  bool isServerError(int statusCode) => serverErrorCodes.contains(statusCode);

  String getCategory(int statusCode) {
    if (isSuccess(statusCode)) return 'success';
    if (isRedirect(statusCode)) return 'redirect';
    if (isError(statusCode)) return 'error';
    return 'unknown';
  }

  StatusCodeConfig copyWith({
    Set<int>? successCodes,
    Set<int>? errorCodes,
    Set<int>? redirectCodes,
    Set<int>? clientErrorCodes,
    Set<int>? serverErrorCodes,
  }) {
    return StatusCodeConfig.custom(
      successCodes: successCodes ?? this.successCodes,
      errorCodes: errorCodes ?? this.errorCodes,
      redirectCodes: redirectCodes ?? this.redirectCodes,
      clientErrorCodes: clientErrorCodes ?? this.clientErrorCodes,
      serverErrorCodes: serverErrorCodes ?? this.serverErrorCodes,
    );
  }
}