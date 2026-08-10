import 'package:test/test.dart';
import 'package:vtworld/src/core/string_builder.dart';

void main() {
  group('StringBuilder', () {
    test('should start empty', () {
      final builder = TerminalStringBuilder();
      expect(builder.length, 0);
      expect(builder.toString(), '');
    });

    test('should append a single chunk', () {
      final builder = TerminalStringBuilder()..append('hello');
      expect(builder.length, 5);
      expect(builder.toString(), 'hello');
    });

    test('should join multiple chunks in order', () {
      final builder = TerminalStringBuilder()
        ..append('foo')
        ..append('bar')
        ..append('baz');
      expect(builder.length, 9);
      expect(builder.toString(), 'foobarbaz');
    });

    test('should handle empty chunks', () {
      final builder = TerminalStringBuilder()
        ..append('')
        ..append('a')
        ..append('');
      expect(builder.length, 1);
      expect(builder.toString(), 'a');
    });

    test('should reset accumulated data', () {
      final builder = TerminalStringBuilder()
        ..append('hello')
        ..reset();
      expect(builder.length, 0);
      expect(builder.toString(), '');
    });

    test('should allow appending after reset', () {
      final builder = TerminalStringBuilder()
        ..append('old')
        ..reset()
        ..append('new');
      expect(builder.toString(), 'new');
    });

    test(
      'should accumulate many small chunks without quadratic concatenation',
      () {
        final builder = TerminalStringBuilder();
        for (var index = 0; index < 10000; index++) {
          builder.append('x');
        }
        expect(builder.length, 10000);
        expect(builder.toString(), List<String>.filled(10000, 'x').join());
      },
    );
  });

  group('LimitedStringBuilder', () {
    test('should expose the configured limit', () {
      expect(LimitedStringBuilder(42).limit, 42);
    });

    test('should start empty', () {
      final builder = LimitedStringBuilder(10);
      expect(builder.length, 0);
      expect(builder.toString(), '');
    });

    test('should accept data up to the limit', () {
      final builder = LimitedStringBuilder(10);
      expect(builder.append('12345'), isFalse);
      expect(builder.append('67890'), isFalse);
      expect(builder.length, 10);
      expect(builder.toString(), '1234567890');
    });

    test('should accept a single chunk exactly at the limit', () {
      final builder = LimitedStringBuilder(5);
      expect(builder.append('abcde'), isFalse);
      expect(builder.length, 5);
      expect(builder.toString(), 'abcde');
    });

    test('should reject data exceeding the limit and clear the buffer', () {
      final builder = LimitedStringBuilder(5)..append('abc');
      expect(builder.append('def'), isTrue);
      expect(builder.length, 0);
      expect(builder.toString(), '');
    });

    test('should reject a single chunk larger than the limit', () {
      final builder = LimitedStringBuilder(3);
      expect(builder.append('toolong'), isTrue);
      expect(builder.length, 0);
      expect(builder.toString(), '');
    });

    test(
      'should allow appending again after reset following a limit breach',
      () {
        final builder = LimitedStringBuilder(3);
        expect(builder.append('abcd'), isTrue);
        builder.reset();
        expect(builder.append('ab'), isFalse);
        expect(builder.toString(), 'ab');
      },
    );

    test('should accumulate many chunks before hitting the limit', () {
      final builder = LimitedStringBuilder(100);
      for (var index = 0; index < builder.limit; index++) {
        expect(builder.append('A'), isFalse);
      }
      expect(
        builder.toString(),
        List<String>.filled(builder.limit, 'A').join(),
      );
      expect(builder.append('B'), isTrue);
      expect(builder.toString(), '');
    });

    test('should reject when limit is zero and any data is appended', () {
      final builder = LimitedStringBuilder(0);
      expect(builder.append('a'), isTrue);
      expect(builder.length, 0);
    });

    test('should allow zero-length appends at the limit', () {
      final builder = LimitedStringBuilder(0);
      expect(builder.append(''), isFalse);
      expect(builder.length, 0);
      expect(builder.toString(), '');
    });
  });
}
