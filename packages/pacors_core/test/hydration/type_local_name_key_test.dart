import 'package:test/test.dart';
import 'package:pacors_core/src/hydration/type_local_name_key.dart';

void main() {
  group('TypeLocalNameKey', () {
    test('should create key with type and local name', () {
      const key = TypeLocalNameKey(String, 'test');

      expect(key.type, equals(String));
      expect(key.localName, equals('test'));
    });

    test('should implement equality correctly', () {
      const key1 = TypeLocalNameKey(String, 'test');
      const key2 = TypeLocalNameKey(String, 'test');
      const key3 = TypeLocalNameKey(int, 'test');
      const key4 = TypeLocalNameKey(String, 'other');

      expect(key1, equals(key2));
      expect(key1, isNot(equals(key3)));
      expect(key1, isNot(equals(key4)));
    });

    test('should implement hashCode correctly', () {
      const key1 = TypeLocalNameKey(String, 'test');
      const key2 = TypeLocalNameKey(String, 'test');
      const key3 = TypeLocalNameKey(int, 'test');

      expect(key1.hashCode, equals(key2.hashCode));
      expect(key1.hashCode, isNot(equals(key3.hashCode)));
    });

    test('should have meaningful toString', () {
      const key = TypeLocalNameKey(String, 'test');

      expect(key.toString(), equals('TypeLocalNameKey(String, test)'));
    });
  });
}
