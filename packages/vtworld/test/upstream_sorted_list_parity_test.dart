import 'package:test/test.dart';
import 'package:vtworld/src/core/sorted_list.dart';

void main() {
  late SortedList<int> list;

  setUp(() => list = SortedList<int>((value) => value));

  void expectList(List<int> expected) =>
      expect(list.values(), orderedEquals(expected));

  group('SortedList', () {
    group('insert', () {
      test('should maintain sorted values', () {
        list.insert(10);
        expectList(<int>[10]);
        list.insert(8);
        expectList(<int>[8, 10]);
        list.insert(15);
        expectList(<int>[8, 10, 15]);
        list.insert(2);
        expectList(<int>[2, 8, 10, 15]);
        list.insert(1);
        expectList(<int>[1, 2, 8, 10, 15]);
        list.insert(6);
        expectList(<int>[1, 2, 6, 8, 10, 15]);
      });

      test('should allow duplicates of the same key', () {
        list.insert(5);
        expectList(<int>[5]);
        list.insert(5);
        expectList(<int>[5, 5]);
        list.insert(8);
        expectList(<int>[5, 5, 8]);
        list.insert(5);
        expectList(<int>[5, 5, 5, 8]);
        list.insert(8);
        expectList(<int>[5, 5, 5, 8, 8]);
        list.insert(6);
        expectList(<int>[5, 5, 5, 6, 8, 8]);
      });
    });

    test('delete', () {
      <int>[1, 2, 4, 3, 5].forEach(list.insert);
      expectList(<int>[1, 2, 3, 4, 5]);
      for (final expectation in <(int, List<int>)>[
        (1, <int>[2, 3, 4, 5]),
        (3, <int>[2, 4, 5]),
        (4, <int>[2, 5]),
        (5, <int>[2]),
        (2, <int>[]),
      ]) {
        list.delete(expectation.$1);
        expectList(expectation.$2);
      }
    });

    test('getKeyIterator', () {
      <int>[5, 5, 8, 5, 8, 6].forEach(list.insert);
      expectList(<int>[5, 5, 5, 6, 8, 8]);
      expect(list.getKeyIterator(1), isEmpty);
      expect(list.getKeyIterator(5), orderedEquals(<int>[5, 5, 5]));
      expect(list.getKeyIterator(6), orderedEquals(<int>[6]));
      expect(list.getKeyIterator(8), orderedEquals(<int>[8, 8]));
      expect(list.getKeyIterator(9), isEmpty);
    });

    test('clear', () {
      <int>[1, 2, 4, 3, 5].forEach(list.insert);
      list.clear();
      expectList(<int>[]);
    });

    test('custom key', () {
      final customList = SortedList<_Keyed>((value) => value.key);
      <int>[5, 2, 10, 5, 6].map(_Keyed.new).forEach(customList.insert);
      expect(
        customList.values().map((value) => value.key),
        orderedEquals(<int>[2, 5, 5, 6, 10]),
      );
    });

    group('values', () {
      test(
        'should iterate correctly when list items change during iteration',
        () {
          <int>[1, 2, 3, 4].forEach(list.insert);
          final visited = <int>[];
          list.values().forEach((item) {
            visited.add(item);
            list.delete(item);
          });
          expect(visited, <int>[1, 2, 3, 4]);
        },
      );
    });
  });
}

final class _Keyed {
  const _Keyed(this.key);

  final int key;
}
