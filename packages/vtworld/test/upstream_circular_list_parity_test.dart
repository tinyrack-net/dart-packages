import 'package:test/test.dart';
import 'package:vtworld/src/core/circular_list.dart';

void main() {
  group('CircularList', () {
    group('push', () {
      test('should push values onto the array', () {
        final list = CircularList<String>(5);
        <String>['1', '2', '3', '4', '5'].forEach(list.push);
        _expectValues(list, <String>['1', '2', '3', '4', '5']);
      });

      test(
        // ignore: lines_longer_than_80_chars, pinned upstream test identity.
        'should push old values from the start out of the array when max length is reached',
        () {
          final list = CircularList<String>(2)
            ..push('1')
            ..push('2');
          _expectValues(list, <String>['1', '2']);
          list.push('3');
          _expectValues(list, <String>['2', '3']);
          list.push('4');
          _expectValues(list, <String>['3', '4']);
        },
      );
    });

    group('maxLength', () {
      test('should increase the size of the list', () {
        final list = CircularList<String>(2)
          ..push('1')
          ..push('2');
        _expectValues(list, <String>['1', '2']);
        list
          ..maxLength = 4
          ..push('3')
          ..push('4');
        _expectValues(list, <String>['1', '2', '3', '4']);
        list.push('wrapped');
        _expectValues(list, <String>['2', '3', '4', 'wrapped']);
      });

      test('should return the maximum length of the list', () {
        final list = CircularList<String>(2);
        expect(list.maxLength, 2);
        list
          ..push('1')
          ..push('2');
        expect(list.maxLength, 2);
        list.push('3');
        expect(list.maxLength, 2);
        list.maxLength = 4;
        expect(list.maxLength, 4);
      });
    });

    group('length', () {
      test(
        // ignore: lines_longer_than_80_chars, pinned upstream test identity.
        'should return the current length of the list, capped at the maximum length',
        () {
          final list = CircularList<String>(2);
          expect(list.length, 0);
          list.push('1');
          expect(list.length, 1);
          list.push('2');
          expect(list.length, 2);
          list.push('3');
          expect(list.length, 2);
        },
      );
    });

    group('splice', () {
      test('should delete items', () {
        final list = CircularList<String>(2)
          ..push('1')
          ..push('2')
          ..splice(0, 1);
        expect(list.length, 1);
        expect(list.get(0), '2');
        list
          ..push('3')
          ..splice(1, 1);
        expect(list.length, 1);
        expect(list.get(0), '2');
      });

      test('should insert items', () {
        final list = CircularList<String>(2)
          ..push('1')
          ..splice(0, 0, <String>['2']);
        _expectValues(list, <String>['2', '1']);
        list.splice(1, 0, <String>['3']);
        _expectValues(list, <String>['3', '1']);
      });

      test('should delete items then insert items', () {
        final list = CircularList<String>(3)
          ..push('1')
          ..push('2')
          ..splice(0, 1, <String>['3', '4']);
        expect(list.length, 3);
        _expectValues(list, <String>['3', '4', '2']);
      });

      test(
        // ignore: lines_longer_than_80_chars, pinned upstream test identity.
        'should wrap the array correctly when more items are inserted than deleted',
        () {
          final list = CircularList<String>(3)
            ..push('1')
            ..push('2')
            ..splice(1, 0, <String>['3', '4']);
          expect(list.length, 3);
          _expectValues(list, <String>['3', '4', '2']);
        },
      );
    });

    group('trimStart', () {
      test('should remove items from the beginning of the list', () {
        final list = CircularList<String>(5);
        <String>['1', '2', '3', '4', '5'].forEach(list.push);
        list.trimStart(1);
        expect(list.length, 4);
        _expectValues(list, <String>['2', '3', '4', '5']);
        list.trimStart(2);
        expect(list.length, 2);
        _expectValues(list, <String>['4', '5']);
      });

      test(
        // ignore: lines_longer_than_80_chars, pinned upstream test identity.
        "should remove all items if the requested trim amount is larger than the list's length",
        () {
          final list = CircularList<String>(5)
            ..push('1')
            ..trimStart(2);
          expect(list.length, 0);
        },
      );
    });

    group('shiftElements', () {
      test('should not mutate the list when count is 0', () {
        final list = CircularList<int>(5)
          ..push(1)
          ..push(2)
          ..shiftElements(0, 0, 1);
        expect(list.length, 2);
        _expectValues(list, <int>[1, 2]);
      });

      test('should throw for invalid args', () {
        final list = CircularList<int>(5)..push(1);
        expect(() => list.shiftElements(-1, 1, 1), throwsRangeError);
        expect(() => list.shiftElements(1, 1, 1), throwsRangeError);
        expect(() => list.shiftElements(0, 1, -1), throwsRangeError);
      });

      test('should shift an element forward', () {
        final list = CircularList<int>(5)
          ..push(1)
          ..push(2)
          ..shiftElements(0, 1, 1);
        expect(list.length, 2);
        _expectValues(list, <int>[1, 1]);
      });

      test('should shift elements forward', () {
        final list = _intList(<int>[1, 2, 3, 4])..shiftElements(0, 2, 2);
        expect(list.length, 4);
        _expectValues(list, <int>[1, 2, 1, 2]);
      });

      test('should shift elements forward, expanding the list if needed', () {
        final list = _intList(<int>[1, 2])..shiftElements(0, 2, 2);
        expect(list.length, 4);
        _expectValues(list, <int>[1, 2, 1, 2]);
      });

      test('should shift elements forward, wrapping the list if needed', () {
        final list = _intList(<int>[1, 2, 3, 4, 5])..shiftElements(2, 2, 3);
        expect(list.length, 5);
        _expectValues(list, <int>[3, 4, 5, 3, 4]);
      });

      test('should shift an element backwards', () {
        final list = _intList(<int>[1, 2])..shiftElements(1, 1, -1);
        expect(list.length, 2);
        _expectValues(list, <int>[2, 2]);
      });

      test('should shift elements backwards', () {
        final list = _intList(<int>[1, 2, 3, 4])..shiftElements(2, 2, -2);
        expect(list.length, 4);
        _expectValues(list, <int>[3, 4, 3, 4]);
      });
    });
  });
}

CircularList<int> _intList(List<int> values) {
  final list = CircularList<int>(5);
  values.forEach(list.push);
  return list;
}

void _expectValues<T>(CircularList<T> list, List<T> expected) {
  expect(<T?>[
    for (var index = 0; index < expected.length; index++) list.get(index),
  ], expected);
}
