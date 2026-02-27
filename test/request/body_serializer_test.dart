library;

import 'dart:convert';

import 'package:flint_client/flint_client.dart';
import 'package:test/test.dart';

void main() {
  group('BodySerializer', () {
    group('JsonBodySerializer', () {
      const serializer = JsonBodySerializer();

      test('serializes map into JSON bytes', () {
        final result = serializer.serialize({'name': 'flint'});
        final decoded = jsonDecode(utf8.decode(result.bytes));

        expect(decoded, containsPair('name', 'flint'));
        expect(result.contentType?.mimeType, 'application/json');
      });

      test('does not claim xml content type', () {
        final can = serializer.canSerialize(
          '<x/>',
          contentType: 'application/xml',
        );
        expect(can, isFalse);
      });
    });

    group('XmlBodySerializer', () {
      const serializer = XmlBodySerializer();

      test('serializes xml string and marks xml content type', () {
        final result = serializer.serialize('<note>ok</note>');
        final text = utf8.decode(result.bytes);

        expect(text, '<note>ok</note>');
        expect(result.contentType?.mimeType, 'application/xml');
      });

      test('recognizes +xml media type', () {
        final can = serializer.canSerialize(
          '{}',
          contentType: 'application/soap+xml',
        );
        expect(can, isTrue);
      });
    });

    group('FormUrlEncodedBodySerializer', () {
      const serializer = FormUrlEncodedBodySerializer();

      test('serializes map to url-encoded payload', () {
        final result = serializer.serialize({
          'name': 'Flint Client',
          'active': true,
        }, contentType: 'application/x-www-form-urlencoded');
        final text = utf8.decode(result.bytes);

        expect(text, contains('name=Flint+Client'));
        expect(text, contains('active=true'));
        expect(
          result.contentType?.mimeType,
          'application/x-www-form-urlencoded',
        );
      });

      test('only supports maps', () {
        final can = serializer.canSerialize(
          'not-map',
          contentType: 'application/x-www-form-urlencoded',
        );
        expect(can, isFalse);
      });
    });
  });
}
