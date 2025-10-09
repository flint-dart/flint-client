/// Tests for FlintResponse class
library;

import 'package:flint_client/flint_client.dart';
import 'package:test/test.dart';

void main() {
  group('FlintResponse', () {
    test('creates successful response', () {
      final response = FlintResponse<String>(
        statusCode: 200,
        data: 'test data',
        type: FlintResponseType.text,
      );

      expect(response.isSuccess, isTrue);
      expect(response.isError, isFalse);
      expect(response.success, isTrue);
      expect(response.statusCode, 200);
      expect(response.data, 'test data');
      expect(response.type, FlintResponseType.text);
      expect(response.error, isNull);
    });

    test('creates error response from FlintError', () {
      final error = FlintError('Test error', statusCode: 404);
      final response = FlintResponse.error(error);

      expect(response.isSuccess, isFalse);
      expect(response.isError, isTrue);
      expect(response.success, isFalse);
      expect(response.statusCode, 404);
      expect(response.data, isNull);
      expect(response.error, error);
    });

    test('automatically creates error for 4xx/5xx status codes', () {
      final response = FlintResponse<String>(
        statusCode: 404,
        data: 'Not found',
      );

      expect(response.isError, isTrue);
      expect(response.error, isA<FlintError>());
      expect(response.error?.statusCode, 404);
    });

    test('categorizes response types correctly', () {
      final successResponse = FlintResponse<String>(
        statusCode: 200,
        data: 'test',
      );
      final clientErrorResponse = FlintResponse<String>(
        statusCode: 404,
        data: 'test',
      );
      final serverErrorResponse = FlintResponse<String>(
        statusCode: 500,
        data: 'test',
      );
      final redirectResponse = FlintResponse<String>(
        statusCode: 301,
        data: 'test',
      );

      expect(successResponse.isSuccess, isTrue);
      expect(successResponse.isClientError, isFalse);
      expect(successResponse.isServerError, isFalse);
      expect(successResponse.isRedirect, isFalse);

      expect(clientErrorResponse.isClientError, isTrue);
      expect(serverErrorResponse.isServerError, isTrue);
      expect(redirectResponse.isRedirect, isTrue);
    });

    test('casts data to different type', () {
      final response = FlintResponse<Map<String, dynamic>>(
        statusCode: 200,
        data: {'name': 'John', 'age': 30},
      );

      final casted = response.cast<Map<String, dynamic>>();
      expect(casted, isA<Map<String, dynamic>>());
      expect(casted['name'], 'John');
    });

    test('safe cast returns null for invalid cast', () {
      final response = FlintResponse<String>(
        statusCode: 200,
        data: 'test string',
      );

      final casted = response.castOrNull<Map<String, dynamic>>();
      expect(casted, isNull);
    });

    test('maps response data to different type', () {
      final response = FlintResponse<Map<String, dynamic>>(
        statusCode: 200,
        data: {'name': 'John', 'age': 30},
      );

      final mapped = response.map<String>((data) => data['name'] as String);

      expect(mapped, isA<FlintResponse<String>>());
      expect(mapped.data, 'John');
      expect(mapped.statusCode, 200);
      expect(mapped.isSuccess, isTrue);
    });

    test('throwIfError throws for error responses', () {
      final errorResponse = FlintResponse.error(
        FlintError('Test error', statusCode: 500),
      );

      expect(() => errorResponse.throwIfError(), throwsA(isA<FlintError>()));
    });

    test('throwIfError returns this for successful responses', () {
      final successResponse = FlintResponse<String>(
        statusCode: 200,
        data: 'test',
      );

      final result = successResponse.throwIfError();
      expect(result, same(successResponse));
    });

    test('requireData returns data for successful responses', () {
      final response = FlintResponse<String>(
        statusCode: 200,
        data: 'test data',
      );

      expect(response.requireData, 'test data');
    });

    test('requireData throws for error responses', () {
      final errorResponse = FlintResponse.error(FlintError('Test error'));

      expect(() => errorResponse.requireData, throwsA(isA<FlintError>()));
    });

    test('requireData throws for null data', () {
      final response = FlintResponse<String>(statusCode: 200, data: null);

      expect(() => response.requireData, throwsA(isA<StateError>()));
    });

    test('creates copy with overridden properties', () {
      final original = FlintResponse<String>(
        statusCode: 200,
        data: 'original',
        type: FlintResponseType.text,
      );

      final copy = original.copyWith(
        statusCode: 201,
        data: 'modified',
        type: FlintResponseType.json,
      );

      expect(copy.statusCode, 201);
      expect(copy.data, 'modified');
      expect(copy.type, FlintResponseType.json);
    });

    test('creates error copy from successful response', () {
      final original = FlintResponse<String>(statusCode: 200, data: 'test');

      final error = FlintError('Custom error');
      final errorCopy = original.copyWith(isError: true, error: error);

      expect(errorCopy.isError, isTrue);
      expect(errorCopy.error, error);
      expect(errorCopy.data, isNull);
    });

    test('serializes to map', () {
      final response = FlintResponse<String>(
        statusCode: 200,
        data: 'test data',
        type: FlintResponseType.text,
      );

      final map = response.toMap();

      expect(map['statusCode'], 200);
      expect(map['success'], isTrue);
      expect(map['isError'], isFalse);
      expect(map['type'], contains('text'));
    });

    test('equality and hashCode', () {
      final response1 = FlintResponse<String>(
        statusCode: 200,
        data: 'test',
        type: FlintResponseType.text,
      );

      final response2 = FlintResponse<String>(
        statusCode: 200,
        data: 'test',
        type: FlintResponseType.text,
      );

      final response3 = FlintResponse<String>(
        statusCode: 404,
        data: 'not found',
        type: FlintResponseType.text,
      );

      expect(response1, equals(response2));
      expect(response1.hashCode, equals(response2.hashCode));
      expect(response1, isNot(equals(response3)));
    });

    test('toString provides informative output', () {
      final successResponse = FlintResponse<String>(
        statusCode: 200,
        data: 'test data',
      );

      final errorResponse = FlintResponse.error(
        FlintError('Test error', statusCode: 500),
      );

      expect(successResponse.toString(), contains('FlintResponse'));
      expect(successResponse.toString(), contains('statusCode: 200'));
      expect(successResponse.toString(), contains('success: true'));

      expect(errorResponse.toString(), contains('error:'));
      expect(errorResponse.toString(), contains('Test error'));
    });
  });
}
