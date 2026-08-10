import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  group('OptionsService', () {
    group('constructor', () {
      test(
        'uses default value if invalid constructor option values passed for cols/rows',
        () {
          final options = TerminalOptions();
          expect(options.rows, 24);
          expect(options.cols, 80);
        },
      );

      test(
        'uses values from constructor option values if correctly passed',
        () {
          // The upstream fixture explicitly passes xterm's default column
          // count.
          // ignore: avoid_redundant_argument_values
          final options = TerminalOptions(cols: 80, rows: 25);
          expect(options.rows, 25);
          expect(options.cols, 80);
        },
      );

      test('uses default value if invalid constructor option value passed', () {
        expect(TerminalOptions(tabStopWidth: 0).tabStopWidth, 8);
      });

      test('object.keys return the correct number of options', () {
        expect(TerminalOptions().optionNames, isNotEmpty);
      });
    });

    group('setOption', () {
      test('applies valid fontWeight option values', () {
        final options = TerminalOptions();
        for (final value in <Object>['bold', 'normal', '600', 350, 1, 1000]) {
          options.fontWeight = value;
          expect(options.fontWeight, value);
        }
      });

      test('normalizes invalid fontWeight option values', () {
        final options = TerminalOptions(fontWeight: 350);
        for (final value in <Object>[10000, -10, 'bold700']) {
          options.fontWeight = value;
          expect(options.fontWeight, 'normal');
          options.fontWeight = 350;
        }
      });
    });

    group('onOptionChange', () {
      test('should fire on any option change', () {
        final options = TerminalOptions();
        final changes = <String>[];
        options.onChange.listen(changes.add);
        options
          ..cursorWidth = 10
          ..scrollback = 20;
        expect(changes, <String>['cursorWidth', 'scrollback']);
      });
    });

    group('onSpecificOptionChange', () {
      test('should fire only on a specific option change', () {
        final options = TerminalOptions();
        final changes = <Object?>[];
        options
          ..onSpecificOptionChange('scrollback', changes.add)
          ..cursorWidth = 10
          ..scrollback = 20;
        expect(changes, <Object?>[20]);
      });
    });

    group('onSpecificOptionChange duplicate', () {
      test('should fire only on a specific option change', () {
        final options = TerminalOptions();
        final changes = <Object?>[];
        options
          ..onSpecificOptionChange('scrollback', changes.add)
          ..cursorWidth = 10
          ..scrollback = 20;
        expect(changes, <Object?>[20]);
      });
    });

    group('onMultipleOptionChange', () {
      test('should fire only for specific options', () {
        final options = TerminalOptions();
        var called = false;
        options
          ..onMultipleOptionChange(<String>['scrollback'], () {
            called = true;
          })
          ..cursorWidth = 10;
        expect(called, isFalse);
        options.scrollback = 20;
        expect(called, isTrue);
      });
    });
  });
}
