import 'dart:io';
import 'package:flint_client/src/flint_error.dart';

/// Enum representing the type of response returned by the Flint client.
enum FlintResponseType {
  /// Response is in JSON format
  json,

  /// Response is plain text
  text,

  /// Response is a file
  file,

  /// Response type is unknown
  unknown,

  /// Response is HTML
  html,
}

/// Represents a response from the Flint client.
///
/// This class wraps the response data, HTTP status code, headers, and
/// provides helpers to identify the type of the response.
class FlintResponse<T> {
  /// The HTTP status code returned by the request.
  final int statusCode;

  /// The response data. Can be of any type `T`.
  final T? data;

  /// Whether this response represents an error.
  final bool isError;

  /// The type of response (json, text, file, html, unknown).
  final FlintResponseType type;

  /// Optional HTTP headers returned with the response.
  final HttpHeaders? headers;
  final bool success;

  /// Creates a successful response.
  ///
  /// [statusCode] is required.
  /// [data] is the response payload.
  /// [type] indicates the type of the response.
  /// [headers] optionally contains HTTP headers.
  /// success
  FlintResponse({
    required this.statusCode,
    this.data,
    this.type = FlintResponseType.unknown,
    this.headers,
    this.success = true,
  }) : isError = false;

  /// Creates an error response.
  ///
  /// [error] is the [FlintError] representing the error details.
  /// The status code is set to 500 by default, and `isError` is true.
  FlintResponse.error(FlintError error)
    : statusCode = 500,
      data = null, // optionally: data = error
      isError = true,
      headers = null,
      success = false,
      type = FlintResponseType.unknown;

  /// Returns true if the response type is JSON.
  bool get isJson => type == FlintResponseType.json;

  /// Returns true if the response type is plain text.
  bool get isText => type == FlintResponseType.text;

  /// Returns true if the response type is a file.
  bool get isFile => type == FlintResponseType.file;
}
