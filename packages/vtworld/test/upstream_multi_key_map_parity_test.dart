import 'package:test/test.dart';
import 'package:vtworld/src/core/multi_key_map.dart';

void main() {
  group('TwoKeyMap', () {
    late TwoKeyMap<Object, Object, String> map;
    setUp(() => map = TwoKeyMap<Object, Object, String>());

    test('set, get', () {
      expect(map.get(1, 2), isNull);
      map.set(1, 2, 'foo');
      expect(map.get(1, 2), 'foo');
      map.set(1, 3, 'bar');
      expect(map.get(1, 2), 'foo');
      expect(map.get(1, 3), 'bar');
      map
        ..set(2, 2, 'foo2')
        ..set(2, 3, 'bar2');
      expect(map.get(1, 2), 'foo');
      expect(map.get(1, 3), 'bar');
      expect(map.get(2, 2), 'foo2');
      expect(map.get(2, 3), 'bar2');
    });

    test('clear', () {
      expect(map.get(1, 2), isNull);
      map.set(1, 2, 'foo');
      expect(map.get(1, 2), 'foo');
      map.clear();
      expect(map.get(1, 2), isNull);
    });
  });

  group('FourKeyMap', () {
    late FourKeyMap<Object, Object, Object, Object, String> map;
    setUp(() => map = FourKeyMap<Object, Object, Object, Object, String>());

    test('set, get', () {
      expect(map.get(1, 2, 3, 4), isNull);
      map.set(1, 2, 3, 4, 'foo');
      expect(map.get(1, 2, 3, 4), 'foo');
      map.set(1, 3, 3, 4, 'bar');
      expect(map.get(1, 2, 3, 4), 'foo');
      expect(map.get(1, 3, 3, 4), 'bar');
      map
        ..set(2, 2, 3, 4, 'foo2')
        ..set(2, 3, 3, 4, 'bar2');
      expect(map.get(1, 2, 3, 4), 'foo');
      expect(map.get(1, 3, 3, 4), 'bar');
      expect(map.get(2, 2, 3, 4), 'foo2');
      expect(map.get(2, 3, 3, 4), 'bar2');
    });

    test('clear', () {
      expect(map.get(1, 2, 3, 4), isNull);
      map.set(1, 2, 3, 4, 'foo');
      expect(map.get(1, 2, 3, 4), 'foo');
      map.clear();
      expect(map.get(1, 2, 3, 4), isNull);
    });
  });
}
