/// Tests for cache configuration
library;

import 'package:flint_client/flint_client.dart';
import 'package:test/test.dart';

void main() {
  group('CacheConfig', () {
    test('creates with default values', () {
      final config = CacheConfig();

      expect(config.maxAge, Duration(hours: 1));
      expect(config.persist, isFalse);
      expect(config.maxSize, 100);
      expect(config.forceRefresh, isFalse);
    });

    test('creates copy with overridden values', () {
      final original = CacheConfig();
      final copy = original.copyWith(
        maxAge: Duration(minutes: 30),
        persist: true,
        maxSize: 50,
      );

      expect(copy.maxAge, Duration(minutes: 30));
      expect(copy.persist, isTrue);
      expect(copy.maxSize, 50);
      expect(copy.forceRefresh, original.forceRefresh);
    });
  });
}
