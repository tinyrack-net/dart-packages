import 'package:cliweave/terminal.dart';
import 'package:test/test.dart';

/// Mirror of the vitest picocolors mock: each style tags its input with the
/// style name.
class _TagPicocolors implements Picocolors {
  String _tag(String name, String input) => '$name($input)';

  @override
  bool get isColorSupported => true;

  @override
  String bold(String input) => _tag('bold', input);

  @override
  String cyan(String input) => _tag('cyan', input);

  @override
  String dim(String input) => _tag('dim', input);

  @override
  String green(String input) => _tag('green', input);

  @override
  String red(String input) => _tag('red', input);

  @override
  String yellow(String input) => _tag('yellow', input);
}

void main() {
  group('theme', () {
    group('SYMBOLS constants', () {
      test('has expected symbol values', () {
        expect(SYMBOLS.success, '✔');
        expect(SYMBOLS.error, '✖');
        expect(SYMBOLS.warn, '⚠');
        expect(SYMBOLS.info, '~');
        expect(SYMBOLS.bullet, '·');
        expect(SYMBOLS.arrow, '→');
        expect(SYMBOLS.section, '▼');
      });

      test('has spinner frames array', () {
        expect(SYMBOLS.spinner, isA<List<String>>());
        expect(SYMBOLS.spinner.length, greaterThan(0));
      });
    });

    group('color functions', () {
      final color = ColorTheme(pc: _TagPicocolors());

      test('delegates success to green', () {
        expect(color.success('ok'), 'green(ok)');
      });

      test('delegates error to red', () {
        expect(color.error('fail'), 'red(fail)');
      });

      test('delegates warn to yellow', () {
        expect(color.warn('caution'), 'yellow(caution)');
      });

      test('delegates info to cyan', () {
        expect(color.info('note'), 'cyan(note)');
      });

      test('delegates dim to dim', () {
        expect(color.dim('faded'), 'dim(faded)');
      });

      test('delegates bold to bold', () {
        expect(color.bold('title'), 'bold(title)');
      });

      test('delegates header to bold', () {
        expect(color.header('heading'), 'bold(heading)');
      });

      test('delegates path to dim', () {
        expect(color.path('/some/path'), 'dim(/some/path)');
      });

      test('delegates label to dim', () {
        expect(color.label('key'), 'dim(key)');
      });

      test('delegates highlight to cyan', () {
        expect(color.highlight('item'), 'cyan(item)');
      });

      test('delegates action.add to green', () {
        expect(color.action.add('+'), 'green(+)');
      });

      test('delegates action.modify to yellow', () {
        expect(color.action.modify('~'), 'yellow(~)');
      });

      test('delegates action.delete to red', () {
        expect(color.action.delete('-'), 'red(-)');
      });
    });

    group('real picocolors behavior', () {
      test('resolves every supported environment and argument path', () {
        String? none(String name) => null;
        String? force(String name) => name == 'FORCE_COLOR' ? '1' : null;
        String? noColor(String name) => name == 'NO_COLOR' ? '1' : null;
        String? ci(String name) => name == 'CI' ? 'true' : null;
        String? dumb(String name) => name == 'TERM' ? 'dumb' : null;

        expect(
          resolveIsColorSupported(
            readEnv: none,
            platform: 'linux',
            stdoutIsTTY: false,
          ),
          isFalse,
        );
        expect(
          resolveIsColorSupported(
            readEnv: force,
            platform: 'linux',
            stdoutIsTTY: false,
          ),
          isTrue,
        );
        expect(
          resolveIsColorSupported(
            readEnv: ci,
            platform: 'linux',
            stdoutIsTTY: false,
          ),
          isTrue,
        );
        expect(
          resolveIsColorSupported(
            readEnv: none,
            argv: const ['--color'],
            platform: 'linux',
            stdoutIsTTY: false,
          ),
          isTrue,
        );
        expect(
          resolveIsColorSupported(
            readEnv: none,
            platform: 'win32',
            stdoutIsTTY: false,
          ),
          isTrue,
        );
        expect(
          resolveIsColorSupported(
            readEnv: none,
            platform: 'linux',
            stdoutIsTTY: true,
          ),
          isTrue,
        );
        expect(
          resolveIsColorSupported(
            readEnv: dumb,
            platform: 'linux',
            stdoutIsTTY: true,
          ),
          isFalse,
        );
        expect(
          resolveIsColorSupported(
            readEnv: noColor,
            argv: const ['--color'],
            platform: 'win32',
            stdoutIsTTY: true,
          ),
          isFalse,
        );
        expect(
          resolveIsColorSupported(
            readEnv: none,
            argv: const ['--no-color'],
            platform: 'win32',
            stdoutIsTTY: true,
          ),
          isFalse,
        );
      });

      test('emits exact ANSI styles and reopens nested styles', () {
        final colors = createColors(enabled: true);

        expect(colors.isColorSupported, isTrue);
        expect(colors.bold('x'), '\x1B[1mx\x1B[22m');
        expect(colors.dim('x'), '\x1B[2mx\x1B[22m');
        expect(colors.red('x'), '\x1B[31mx\x1B[39m');
        expect(colors.green('x'), '\x1B[32mx\x1B[39m');
        expect(colors.yellow('x'), '\x1B[33mx\x1B[39m');
        expect(colors.cyan('x'), '\x1B[36mx\x1B[39m');
        expect(
          colors.bold('outer \x1B[22m inner'),
          '\x1B[1mouter \x1B[22m\x1B[1m inner\x1B[22m',
        );
        expect(colors.bold(''), '\x1B[1m\x1B[22m');
      });

      test('disabled colors are identity functions', () {
        final colors = createColors(enabled: false);

        expect(colors.isColorSupported, isFalse);
        expect(colors.bold('plain'), 'plain');
        expect(ColorTheme(pc: colors).action.add('plain'), 'plain');
      });
    });
  });
}
