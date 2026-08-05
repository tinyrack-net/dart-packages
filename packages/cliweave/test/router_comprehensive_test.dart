import 'dart:async';

import 'package:cliweave/src/router.dart';
import 'package:cliweave/src/write_stream.dart';
import 'package:test/test.dart';

final class _Stream implements WriteStream {
  _Stream({this.isTTY = false});

  @override
  final bool isTTY;
  final buffer = StringBuffer();

  String get text => buffer.toString();

  @override
  void clearLine(int dir) {}

  @override
  void cursorTo(int column) {}

  @override
  void write(String chunk) => buffer.write(chunk);
}

({RunContext context, _Stream stdout, _Stream stderr}) _context({
  bool tty = false,
  String? locale,
  Map<String, String> environment = const {},
}) {
  final stdout = _Stream(isTTY: tty);
  final stderr = _Stream(isTTY: tty);
  return (
    context: RunContext(
      process: RunProcess(
        stdout: stdout,
        stderr: stderr,
        readEnv: environment.__lookup,
      ),
      locale: locale,
    ),
    stdout: stdout,
    stderr: stderr,
  );
}

extension on Map<String, String> {
  String? __lookup(String name) => this[name];
}

Command _command({
  CommandParameters parameters = const CommandParameters(),
  CommandFunction? func,
  String brief = 'Test command',
  String? fullDescription,
}) {
  return buildCommand(
    docs: CommandDocs(brief: brief, fullDescription: fullDescription),
    parameters: parameters,
    func: func ?? (context, flags, positional) => null,
  );
}

Application _application(
  RoutingTarget root, {
  String name = 'example',
  ScannerConfiguration? scanner,
  DocumentationConfiguration? documentation,
  CompletionConfiguration? completion,
  LocalizationConfiguration? localization,
  VersionInformation? versionInfo,
  int Function(Object? error)? determineExitCode,
}) {
  return buildApplication(
    root,
    ApplicationConfiguration(
      name: name,
      scanner: scanner,
      documentation: documentation,
      completion: completion,
      localization: localization,
      versionInfo: versionInfo,
      determineExitCode: determineExitCode,
    ),
  );
}

Future<({int code, String stdout, String stderr})> _run(
  Application app,
  List<String> inputs, {
  bool tty = false,
  String? locale,
  Map<String, String> environment = const {},
}) async {
  final capture = _context(tty: tty, locale: locale, environment: environment);
  final code = await runApplication(app, inputs, capture.context);
  return (code: code, stdout: capture.stdout.text, stderr: capture.stderr.text);
}

void main() {
  group('builder contracts', () {
    test('rejects actual integration flag and alias collisions', () {
      for (final name in ['help', 'helpAll']) {
        expect(
          () => _application(
            _command(
              parameters: CommandParameters(
                flags: {name: const BooleanFlag(brief: 'reserved')},
              ),
            ),
          ),
          throwsA(isA<RouterInternalError>()),
        );
      }
      for (final alias in ['h', 'H']) {
        expect(
          () => _application(
            _command(
              parameters: CommandParameters(
                aliases: {alias: 'value'},
                flags: const {
                  'value': BooleanFlag(brief: 'value', optional: true),
                },
              ),
            ),
          ),
          throwsA(isA<RouterInternalError>()),
        );
      }
    });

    test('rejects negation collisions and invalid separators', () {
      for (final collision in ['no-dry-run', 'noDryRun']) {
        expect(
          () => _command(
            parameters: CommandParameters(
              flags: {
                'dryRun': const BooleanFlag(brief: 'dry run'),
                collision: const BooleanFlag(
                  brief: 'collision',
                  optional: true,
                ),
              },
            ),
          ),
          throwsA(isA<RouterInternalError>()),
        );
      }
      for (final separator in ['', ' ']) {
        expect(
          () => _command(
            parameters: CommandParameters(
              flags: {
                'values': ParsedFlag(
                  brief: 'values',
                  parse: stringParser,
                  variadicSeparator: separator,
                ),
              },
            ),
          ),
          throwsA(isA<RouterInternalError>()),
        );
      }
    });

    test('validates route maps, aliases, and default commands', () {
      expect(
        () => buildRouteMap(
          docs: const RouteMapDocs(brief: 'empty'),
          routes: const {},
        ),
        throwsA(isA<RouterInternalError>()),
      );
      final leaf = _command();
      expect(
        () => buildRouteMap(
          docs: const RouteMapDocs(brief: 'alias collision'),
          routes: {'leaf': leaf},
          aliases: const {'leaf': 'leaf'},
        ),
        throwsA(isA<RouterInternalError>()),
      );
      final nested = buildRouteMap(
        docs: const RouteMapDocs(brief: 'nested'),
        routes: {'leaf': leaf},
      );
      expect(
        () => buildRouteMap(
          docs: const RouteMapDocs(brief: 'bad default'),
          routes: {'nested': nested},
          defaultCommand: 'nested',
        ),
        throwsA(isA<RouterInternalError>()),
      );
    });

    test('validates application display, localization, and version flags', () {
      final leaf = _command();
      expect(
        () => _application(
          leaf,
          documentation: const DocumentationConfiguration(
            caseStyle: DisplayCaseStyle.convertCamelToKebab,
          ),
        ),
        throwsA(isA<RouterInternalError>()),
      );
      expect(
        () => _application(
          leaf,
          localization: const LocalizationConfiguration(
            defaultLocale: 'xx',
            loadText: _noText,
          ),
        ),
        throwsA(isA<RouterInternalError>()),
      );
      for (final parameters in [
        const CommandParameters(
          flags: {'version': BooleanFlag(brief: 'version')},
        ),
        const CommandParameters(
          flags: {'other': BooleanFlag(brief: 'other')},
          aliases: {'v': 'other'},
        ),
      ]) {
        expect(
          () => _application(
            _command(parameters: parameters),
            versionInfo: const VersionInformation(currentVersion: '1.0.0'),
          ),
          throwsA(isA<RouterInternalError>()),
        );
      }
    });

    test('route map exposes names, aliases, hidden state, and defaults', () {
      final defaultLeaf = _command(brief: 'default');
      final other = _command(brief: 'other');
      final map = buildRouteMap(
        docs: const RouteMapDocs(
          brief: 'routes',
          hideRoute: {'otherRoute': true},
        ),
        routes: {'defaultRoute': defaultLeaf, 'otherRoute': other},
        aliases: const {'d': 'defaultRoute', 'o': 'otherRoute'},
        defaultCommand: 'defaultRoute',
      );

      expect(map.getDefaultCommand(), same(defaultLeaf));
      expect(map.getRoutingTargetForInput('d'), same(defaultLeaf));
      expect(map.getAllEntries().last.hidden, isTrue);
      expect(
        map.getAllEntries().first.name.byStyle(
          DisplayCaseStyle.convertCamelToKebab,
        ),
        'default-route',
      );
      expect(
        map
            .getOtherAliasesForInput(
              'default-route',
              ScannerCaseStyle.allowKebabForCamel,
            )
            .original,
        ['d'],
      );
      expect(
        map
            .getOtherAliasesForInput('missing', ScannerCaseStyle.original)
            .original,
        isEmpty,
      );
    });
  });

  group('help rendering', () {
    late Command rich;
    late RouteMap root;

    setUp(() {
      rich = _command(
        brief: 'short',
        fullDescription: 'A fully documented command.',
        parameters: const CommandParameters(
          aliases: {'q': 'quiet', 't': 'tags'},
          flags: {
            'quiet': BooleanFlag(brief: 'Silence output', defaultValue: true),
            'mode': EnumFlag(
              brief: 'Mode',
              values: ['fast', 'safe'],
              placeholder: 'kind',
            ),
            'tags': ParsedFlag(
              brief: 'Tags',
              parse: stringParser,
              optional: true,
              variadic: true,
              variadicSeparator: ',',
              defaultValue: ['one', 'two'],
            ),
            'hiddenValue': ParsedFlag(
              brief: 'Hidden value',
              parse: stringParser,
              hidden: true,
              defaultValue: '',
            ),
            'count': CounterFlag(brief: 'Count', optional: true),
          },
          positional: TuplePositionalParameters([
            PositionalParameter(
              brief: 'Required input',
              parse: stringParser,
              placeholder: 'input',
            ),
            PositionalParameter(
              brief: 'Optional output',
              parse: stringParser,
              placeholder: 'output',
              optional: true,
              defaultValue: 'dist',
            ),
          ]),
        ),
      );
      root = buildRouteMap(
        docs: const RouteMapDocs(
          brief: 'Short root',
          fullDescription: 'Root description.',
          hideRoute: {'hiddenRoute': true},
        ),
        routes: {
          'richCommand': rich,
          'hiddenRoute': _command(brief: 'Hidden command'),
        },
        aliases: const {'r': 'richCommand'},
      );
    });

    test(
      'renders flags, defaults, separators, positionals, and aliases',
      () async {
        final app = _application(
          root,
          scanner: const ScannerConfiguration(
            caseStyle: ScannerCaseStyle.allowKebabForCamel,
            allowArgumentEscapeSequence: true,
          ),
          documentation: const DocumentationConfiguration(
            useAliasInUsageLine: true,
            alwaysShowHelpAllFlag: true,
          ),
          versionInfo: const VersionInformation(currentVersion: '1.0.0'),
        );
        final result = await _run(app, ['r', '--help']);

        expect(result.stdout, contains('A fully documented command.'));
        expect(result.stdout, contains('ALIASES'));
        expect(result.stdout, contains('example r'));
        expect(result.stdout, contains('--quiet/--no-quiet'));
        expect(result.stdout, contains('[default = true]'));
        expect(result.stdout, contains('fast|safe'));
        expect(result.stdout, contains('separator = ,'));
        expect(result.stdout, contains('one,two'));
        expect(result.stdout, contains('<input> [<output>]'));
        expect(result.stdout, contains('[default = dist]'));
        expect(result.stdout, contains('--help-all'));
        expect(result.stdout, contains(' --'));
        expect(result.stdout, isNot(contains('Hidden value')));
      },
    );

    test('help-all renders hidden flags and routes with ANSI', () async {
      final app = _application(
        root,
        scanner: const ScannerConfiguration(
          caseStyle: ScannerCaseStyle.allowKebabForCamel,
        ),
      );
      final result = await _run(app, ['--help-all'], tty: true);

      expect(result.stdout, contains('hidden-route'));
      expect(result.stdout, contains('Hidden command'));
      expect(result.stdout, contains('\x1B['));
    });

    test('supports required-only usage and array positionals', () async {
      final arrayCommand = _command(
        parameters: const CommandParameters(
          flags: {
            'optional': ParsedFlag(
              brief: 'Optional',
              parse: stringParser,
              optional: true,
            ),
            'required': ParsedFlag(brief: 'Required', parse: stringParser),
          },
          positional: ArrayPositionalParameters(
            parameter: PositionalParameter(
              brief: 'Items',
              parse: stringParser,
              placeholder: 'item',
            ),
          ),
        ),
      );
      final app = _application(
        arrayCommand,
        documentation: const DocumentationConfiguration(
          onlyRequiredInUsageLine: true,
          disableAnsiColor: true,
        ),
      );
      final result = await _run(app, ['--help'], tty: true);

      expect(result.stdout, contains('(--required value) <item>...'));
      expect(result.stdout, isNot(contains('[--optional value] <item>...')));
      expect(result.stdout, contains('item...'));
      expect(result.stdout, isNot(contains('\x1B[')));
    });

    test(
      'renders original-case nested route and rich command ANSI branches',
      () async {
        final nested = buildRouteMap(
          docs: const RouteMapDocs(
            brief: 'Nested routes',
            fullDescription: 'Nested description.',
          ),
          routes: {'rich': rich},
          aliases: const {'n': 'rich'},
        );
        final app = _application(
          buildRouteMap(
            docs: const RouteMapDocs(brief: 'Root'),
            routes: {'nested': nested},
            aliases: const {'nest': 'nested'},
          ),
          scanner: const ScannerConfiguration(
            allowArgumentEscapeSequence: true,
          ),
          documentation: const DocumentationConfiguration(
            alwaysShowHelpAllFlag: true,
          ),
          versionInfo: const VersionInformation(currentVersion: '1'),
        );

        final rootHelp = await _run(app, ['--help'], tty: true);
        final nestedHelp = await _run(app, ['nest', '--help'], tty: true);
        final commandHelp = await _run(app, [
          'nested',
          'n',
          '--helpAll',
        ], tty: true);
        expect(rootHelp.stdout, contains('example nested rich ...'));
        expect(nestedHelp.stdout, contains('Nested description.'));
        expect(nestedHelp.stdout, contains('ALIASES'));
        expect(commandHelp.stdout, contains('\x1B[2mdefault =\x1B[22m'));
        expect(commandHelp.stdout, contains('\x1B[2mseparator =\x1B[22m'));
        expect(commandHelp.stdout, contains('\x1B[3mRequired input\x1B[23m'));
        expect(commandHelp.stdout, contains('Hidden value'));
      },
    );

    test('renders required variadic and default empty-list forms', () async {
      final command = _command(
        parameters: const CommandParameters(
          flags: {
            'requiredValues': ParsedFlag(
              brief: 'Required values',
              parse: stringParser,
              variadic: true,
            ),
            'emptyValues': EnumFlag(
              brief: 'Empty values',
              values: ['a'],
              variadic: true,
              defaultValue: <String>[],
            ),
          },
          positional: TuplePositionalParameters([
            PositionalParameter(brief: 'Unnamed', parse: stringParser),
          ]),
        ),
      );

      final result = await _run(_application(command), ['--help']);
      expect(result.stdout, contains('(--requiredValues value)...'));
      expect(result.stdout, contains('default = []'));
      expect(result.stdout, contains('<arg1>'));
    });
  });

  group('argument parsing', () {
    test(
      'parses every flag shape, defaults, aliases, and positionals',
      () async {
        Map<String, Object?>? flags;
        List<Object?>? positional;
        final command = _command(
          parameters: CommandParameters(
            aliases: const {'v': 'verbose', 'c': 'count'},
            flags: {
              'verbose': const BooleanFlag(brief: 'Verbose', optional: true),
              'count': const CounterFlag(brief: 'Count', optional: true),
              'mode': const EnumFlag(
                brief: 'Mode',
                values: ['fast', 'safe'],
                optional: true,
              ),
              'names': const ParsedFlag(
                brief: 'Names',
                parse: stringParser,
                variadicSeparator: ',',
                optional: true,
              ),
              'numbers': ParsedFlag(
                brief: 'Numbers',
                parse: (value) async => int.parse(value),
                variadic: true,
                optional: true,
              ),
              'inferred': const ParsedFlag(
                brief: 'Inferred',
                parse: stringParser,
                inferEmpty: true,
                optional: true,
              ),
              'defaulted': const ParsedFlag(
                brief: 'Defaulted',
                parse: stringParser,
                defaultValue: 'fallback',
              ),
              'defaultList': const EnumFlag(
                brief: 'Default list',
                values: ['a', 'b'],
                variadic: true,
                defaultValue: ['a', 'b'],
              ),
            },
            positional: const TuplePositionalParameters([
              PositionalParameter(
                brief: 'First',
                parse: stringParser,
                defaultValue: 'first-default',
              ),
              PositionalParameter(
                brief: 'Second',
                parse: stringParser,
                optional: true,
              ),
            ]),
          ),
          func: (context, parsedFlags, parsedPositional) {
            flags = parsedFlags;
            positional = parsedPositional;
            return null;
          },
        );
        final result = await _run(_application(command), [
          '-vc',
          '--count',
          '--mode=safe',
          '--names',
          'one,two',
          '--numbers',
          '1',
          '--numbers',
          '2',
          '--inferred',
        ]);

        expect(result.code, ExitCode.success);
        expect(flags, {
          'verbose': true,
          'count': 2,
          'mode': 'safe',
          'names': ['one', 'two'],
          'numbers': [1, 2],
          'inferred': '',
          'defaulted': 'fallback',
          'defaultList': ['a', 'b'],
        });
        expect(positional, ['first-default', null]);
      },
    );

    test(
      'supports negation, explicit booleans, and argument escaping',
      () async {
        Map<String, Object?>? flags;
        List<Object?>? positional;
        final command = _command(
          parameters: const CommandParameters(
            flags: {
              'feature': BooleanFlag(brief: 'Feature', defaultValue: true),
              'literal': BooleanFlag(brief: 'Literal', optional: true),
            },
            positional: ArrayPositionalParameters(
              parameter: PositionalParameter(
                brief: 'Values',
                parse: stringParser,
              ),
            ),
          ),
          func: (context, parsedFlags, parsedPositional) {
            flags = parsedFlags;
            positional = parsedPositional;
            return null;
          },
        );
        final app = _application(
          command,
          scanner: const ScannerConfiguration(
            allowArgumentEscapeSequence: true,
          ),
        );

        final result = await _run(app, [
          '--noFeature',
          '--literal=false',
          '--',
          '--feature',
        ]);
        expect(result.code, ExitCode.success);
        expect(flags!['feature'], isFalse);
        expect(flags!['literal'], isFalse);
        expect(positional, ['--feature']);
      },
    );

    test(
      'parses bounded arrays and reports too few and too many values',
      () async {
        final command = _command(
          parameters: const CommandParameters(
            positional: ArrayPositionalParameters(
              parameter: PositionalParameter(
                brief: 'Files',
                parse: stringParser,
                placeholder: 'file',
              ),
              minimum: 2,
              maximum: 3,
            ),
          ),
        );
        final app = _application(command);

        final none = await _run(app, []);
        final one = await _run(app, ['one']);
        final many = await _run(app, ['one', 'two', 'three', 'four']);
        expect(none.stderr, contains('but found none'));
        expect(one.stderr, contains('but only found 1'));
        expect(many.stderr, contains('Too many arguments'));
      },
    );

    test(
      'collects positional and flag parser failures in declaration order',
      () async {
        Object fail(String input) => throw FormatException('bad $input');
        final command = _command(
          parameters: CommandParameters(
            flags: {
              'firstFlag': ParsedFlag(brief: 'First', parse: fail),
              'secondFlag': ParsedFlag(brief: 'Second', parse: fail),
            },
            positional: TuplePositionalParameters([
              PositionalParameter(
                brief: 'Position',
                parse: fail,
                placeholder: 'position',
              ),
            ]),
          ),
        );
        final result = await _run(
          _application(
            command,
            scanner: const ScannerConfiguration(
              caseStyle: ScannerCaseStyle.allowKebabForCamel,
            ),
          ),
          ['value', '--first-flag', 'x', '--second-flag', 'y'],
        );

        expect(result.code, ExitCode.invalidArgument);
        expect(result.stderr, contains('bad value'));
        expect(result.stderr, contains('bad x'));
        expect(result.stderr, contains('bad y'));
      },
    );

    test('reports scanner edge cases', () async {
      final command = _command(
        parameters: const CommandParameters(
          aliases: {'p': 'path', 'x': 'toggle'},
          flags: {
            'path': ParsedFlag(brief: 'Path', parse: stringParser),
            'toggle': BooleanFlag(brief: 'Toggle', optional: true),
            'fixed': ParsedFlag(
              brief: 'Fixed',
              parse: stringParser,
              optional: true,
            ),
            'disabledNegation': BooleanFlag(
              brief: 'No negation',
              optional: true,
              withNegated: false,
            ),
          },
        ),
      );
      final app = _application(command);
      final cases = <List<String>>[
        ['--path', '--toggle'],
        ['--path', 'one', '--path', 'two'],
        ['--no-toggle=value'],
        ['--no-disabledNegation'],
        ['-px'],
        ['-z'],
      ];
      for (final inputs in cases) {
        final result = await _run(app, inputs);
        expect(result.code, ExitCode.invalidArgument, reason: '$inputs');
        expect(result.stderr, isNotEmpty, reason: '$inputs');
      }
    });

    test(
      'covers alias values, default variants, and invalid defaults',
      () async {
        Map<String, Object?>? captured;
        final command = _command(
          parameters: CommandParameters(
            aliases: const {'m': 'mode'},
            flags: {
              'mode': const EnumFlag(
                brief: 'Mode',
                values: ['fast', 'safe'],
                defaultValue: 'fast',
              ),
              'parsedList': ParsedFlag(
                brief: 'Parsed list',
                parse: int.parse,
                variadic: true,
                defaultValue: const ['1', '2'],
              ),
              'count': const CounterFlag(brief: 'Count', optional: true),
            },
          ),
          func: (context, flags, positional) => captured = flags,
        );
        final app = _application(command);

        expect((await _run(app, ['-m=safe'])).code, ExitCode.success);
        expect(captured!['mode'], 'safe');
        expect(captured!['parsedList'], [1, 2]);
        expect(
          (await _run(app, ['--count=bad'])).stderr,
          contains('Failed to parse'),
        );

        final badDefault = _command(
          parameters: const CommandParameters(
            flags: {
              'mode': EnumFlag(
                brief: 'Mode',
                values: ['fast'],
                variadic: true,
                defaultValue: ['slow'],
              ),
            },
          ),
        );
        expect(
          (await _run(_application(badDefault), [])).stderr,
          contains('Expected "slow"'),
        );
      },
    );

    test(
      'reports invalid aliases and active flags before equals or escape',
      () async {
        final badAlias = _command(
          parameters: const CommandParameters(aliases: {'x': 'missingFlag'}),
        );
        expect(
          (await _run(_application(badAlias), [])).stderr,
          contains('aliased from -x'),
        );

        final command = _command(
          parameters: const CommandParameters(
            flags: {
              'path': ParsedFlag(brief: 'Path', parse: stringParser),
              'other': ParsedFlag(
                brief: 'Other',
                parse: stringParser,
                optional: true,
              ),
            },
          ),
        );
        final app = _application(
          command,
          scanner: const ScannerConfiguration(
            allowArgumentEscapeSequence: true,
          ),
        );
        expect(
          (await _run(app, ['--path', '--other=value'])).stderr,
          contains('encountered --other instead'),
        );
        expect(
          (await _run(app, ['--path', '--'])).stderr,
          contains('Expected input for flag --path'),
        );
      },
    );

    test('reports array positional parser failures', () async {
      final command = _command(
        parameters: CommandParameters(
          positional: ArrayPositionalParameters(
            parameter: PositionalParameter(
              brief: 'Numbers',
              parse: int.parse,
              placeholder: 'number',
            ),
          ),
        ),
      );

      final result = await _run(_application(command), ['1', 'bad', '3']);
      expect(result.code, ExitCode.invalidArgument);
      expect(result.stderr, contains('Failed to parse "bad" for number'));
    });
  });

  group('run behavior and localization', () {
    test('runs default and aliased nested commands', () async {
      var calls = 0;
      final defaultCommand = _command(
        func: (context, flags, positional) => calls++,
      );
      final nested = buildRouteMap(
        docs: const RouteMapDocs(brief: 'nested'),
        routes: {
          'leafCommand': _command(
            func: (context, flags, positional) => calls++,
          ),
        },
        aliases: const {'leaf': 'leafCommand'},
      );
      final root = buildRouteMap(
        docs: const RouteMapDocs(brief: 'root'),
        routes: {'defaultCommand': defaultCommand, 'nestedRoute': nested},
        defaultCommand: 'defaultCommand',
      );
      final app = _application(
        root,
        scanner: const ScannerConfiguration(
          caseStyle: ScannerCaseStyle.allowKebabForCamel,
        ),
      );

      expect((await _run(app, [])).code, ExitCode.success);
      expect(
        (await _run(app, ['nested-route', 'leaf'])).code,
        ExitCode.success,
      );
      expect(calls, 2);
    });

    test(
      'formats returned and thrown command errors with custom exit codes',
      () async {
        final returned = _application(
          _command(func: (context, flags, positional) => Exception('returned')),
          determineExitCode: (error) => 12,
        );
        final thrown = _application(
          _command(
            func: (context, flags, positional) => throw StateError('thrown'),
          ),
          determineExitCode: (error) => 13,
        );

        final returnedResult = await _run(returned, [], tty: true);
        final thrownResult = await _run(thrown, [], tty: true);
        expect(returnedResult.code, 12);
        expect(returnedResult.stderr, contains('returned'));
        expect(returnedResult.stderr, contains('\x1B['));
        expect(thrownResult.code, 13);
        expect(thrownResult.stderr, contains('thrown'));
      },
    );

    test('preserves a command-set process exit code through run', () async {
      final capture = _context();
      final app = _application(
        _command(
          func: (context, flags, positional) {
            context.process.exitCode = 42;
            return null;
          },
        ),
      );

      await run(app, [], capture.context);
      expect(capture.context.process.exitCode, 42);
    });

    test('loads requested locale and warns on fallback', () async {
      final custom = textEn.copyWith(
        headers: const TextHeaders(
          usage: 'USO',
          aliases: 'ALIAS',
          commands: 'COMANDOS',
          flags: 'OPCIONES',
          arguments: 'ARGUMENTOS',
        ),
      );
      final app = _application(
        _command(),
        localization: LocalizationConfiguration(
          defaultLocale: 'en',
          loadText: (locale) => locale == 'es'
              ? custom
              : locale == 'en'
              ? textEn
              : null,
        ),
      );

      final translated = await _run(app, ['--help'], locale: 'es');
      final fallback = await _run(app, ['--help'], locale: 'fr');
      expect(translated.stdout, startsWith('USO'));
      expect(fallback.stderr, contains('does not support "fr" locale'));
      expect(fallback.stdout, startsWith('USAGE'));
    });

    test(
      'honors STRICLI_NO_COLOR and default English locale variants',
      () async {
        final app = _application(
          _command(),
          localization: const LocalizationConfiguration(defaultLocale: 'en-US'),
        );
        final result = await _run(
          app,
          ['--help'],
          tty: true,
          environment: const {'STRICLI_NO_COLOR': 'true'},
        );

        expect(result.stdout, isNot(contains('\x1B[')));
      },
    );
  });

  group('completion matrix', () {
    late Application app;
    late RunContext context;

    setUp(() {
      final command = _command(
        parameters: CommandParameters(
          aliases: const {'v': 'verbose', 'm': 'mode'},
          flags: {
            'verbose': const BooleanFlag(brief: 'Verbose', optional: true),
            'mode': const EnumFlag(
              brief: 'Mode',
              values: ['fast', 'safe'],
              optional: true,
            ),
            'targetName': ParsedFlag(
              brief: 'Target',
              parse: stringParser,
              optional: true,
              proposeCompletions: (partial) => ['alpha', 'beta'],
            ),
            'paths': ParsedFlag(
              brief: 'Paths',
              parse: stringParser,
              optional: true,
              variadicSeparator: ',',
              proposeCompletions: (partial) => ['one', 'two'],
            ),
            'noSuggest': const ParsedFlag(
              brief: 'No suggestions',
              parse: stringParser,
              optional: true,
            ),
          },
          positional: TuplePositionalParameters([
            PositionalParameter(
              brief: 'File',
              parse: stringParser,
              proposeCompletions: (partial) async => ['src/', 'test/'],
            ),
          ]),
        ),
      );
      final root = buildRouteMap(
        docs: const RouteMapDocs(
          brief: 'root',
          hideRoute: {'hiddenRoute': true},
        ),
        routes: {'mainCommand': command, 'hiddenRoute': _command()},
        aliases: const {'main': 'mainCommand'},
      );
      app = _application(
        root,
        scanner: const ScannerConfiguration(
          caseStyle: ScannerCaseStyle.allowKebabForCamel,
          allowArgumentEscapeSequence: true,
        ),
        completion: const CompletionConfiguration(
          includeAliases: true,
          includeHiddenRoutes: true,
        ),
        versionInfo: const VersionInformation(currentVersion: '1'),
      );
      context = _context().context;
    });

    test('completes routes, hidden routes, and aliases', () async {
      final values = await proposeCompletions(app, [''], context);
      expect(
        values.map((value) => value.completion),
        containsAll(['main-command', 'main', 'hidden-route']),
      );
      expect(values.first.kind, startsWith('routing-target:'));
    });

    test('completes flags, aliases, enum and callback values', () async {
      final flags = await proposeCompletions(app, ['main', '-'], context);
      final aliases = await proposeCompletions(app, ['main', '-v'], context);
      final enumValues = await proposeCompletions(app, [
        'main',
        '--mode',
        's',
      ], context);
      final callbackValues = await proposeCompletions(app, [
        'main',
        '--target-name',
        'a',
      ], context);
      final separatorValues = await proposeCompletions(app, [
        'main',
        '--paths',
        'one,',
      ], context);

      expect(
        flags.map((value) => value.completion),
        containsAll(['--', '--mode', '-v']),
      );
      expect(aliases.map((value) => value.completion), contains('-v'));
      expect(enumValues.single.completion, 'safe');
      expect(callbackValues.single.completion, 'alpha');
      expect(
        separatorValues.map((value) => value.completion),
        containsAll(['one', 'two']),
      );
    });

    test(
      'completes positional values and rejects invalid leading state',
      () async {
        final values = await proposeCompletions(app, ['main', 's'], context);
        expect(values.single.completion, 'src/');
        expect(await proposeCompletions(app, [], context), isEmpty);
        expect(
          await proposeCompletions(app, ['missing', ''], context),
          isEmpty,
        );
        expect(await proposeCompletions(app, ['--help', ''], context), isEmpty);
        expect(
          await proposeCompletions(app, ['main', '--missing', ''], context),
          isEmpty,
        );
      },
    );

    test('covers shorthand guards and flags without value proposals', () async {
      expect(
        (await proposeCompletions(app, [
          'main',
          '-h',
        ], context)).map((completion) => completion.completion),
        contains('-h'),
      );
      expect(
        (await proposeCompletions(app, [
          'main',
          '-v',
        ], context)).map((completion) => completion.completion),
        contains('-v'),
      );
      expect(await proposeCompletions(app, ['main', '-z'], context), isEmpty);
      expect(
        await proposeCompletions(app, ['main', '--no-suggest', ''], context),
        isEmpty,
      );
      final versionRoot = _application(
        _command(),
        versionInfo: const VersionInformation(currentVersion: '1'),
      );
      expect(await proposeCompletions(versionRoot, ['-v'], context), isEmpty);
    });

    test('completes bounded array positional callbacks', () async {
      final array = _command(
        parameters: CommandParameters(
          positional: ArrayPositionalParameters(
            parameter: PositionalParameter(
              brief: 'Items',
              parse: stringParser,
              proposeCompletions: (partial) => ['alpha', 'beta'],
            ),
            maximum: 1,
          ),
        ),
      );
      final arrayApp = _application(array);

      expect(
        (await proposeCompletions(arrayApp, ['a'], context)).single.completion,
        'alpha',
      );
      expect(
        await proposeCompletions(arrayApp, ['first', ''], context),
        isEmpty,
      );
    });
  });

  group('public error messages', () {
    test('covers error variants and arbitrary thrown values', () {
      final errors = <ArgumentScannerError>[
        FlagNotFoundError('unknown', const [], 'u'),
        FlagNotFoundError('unknown', const ['known']),
        AliasNotFoundError('x'),
        ArgumentParseError('value', 'x', const FormatException('bad')),
        ArgumentParseError('value', 'x', StateError('bad state')),
        ArgumentParseError('value', 'x', ArgumentError('bad argument')),
        EnumValidationError(
          'mode',
          'fase',
          const ['fast', 'safe'],
          const ['fast'],
        ),
        UnsatisfiedFlagError('path', 'other'),
        UnexpectedPositionalError(1, 'two'),
        UnsatisfiedPositionalError('file'),
        UnsatisfiedPositionalError('file', (2, 0)),
        UnsatisfiedPositionalError('file', (3, 1)),
        InvalidNegatedFlagSyntaxError('quiet', 'true'),
        UnexpectedFlagError('path', 'one', 'two'),
      ];

      for (final error in errors) {
        expect(error.toString(), isNotEmpty);
      }
      expect(RouterInternalError('router').toString(), 'router');
    });

    test('covers public documentation getters and default text formatters', () {
      final command = _command(
        brief: 'brief',
        fullDescription: 'full description',
      );
      final routeMap = buildRouteMap(
        docs: const RouteMapDocs(
          brief: 'route brief',
          fullDescription: 'route full description',
        ),
        routes: {'command': command},
      );

      expect(command.brief, 'brief');
      expect(command.fullDescription, 'full description');
      expect(routeMap.brief, 'route brief');
      expect(routeMap.fullDescription, 'route full description');
      expect(textEn.copyWith().headers, same(textEn.headers));
      expect(
        textEn.exceptionWhileParsingArguments(Exception('parse'), false),
        contains('parse'),
      );
      expect(
        textEn.exceptionWhileLoadingCommandFunction(Exception('load'), false),
        contains('load'),
      );
      expect(
        textEn.exceptionWhileLoadingCommandContext(Exception('context'), false),
        contains('context'),
      );
      expect(
        textEn.currentVersionIsNotLatest(
          const CurrentVersionNotLatestArguments(
            currentVersion: '1',
            latestVersion: '2',
            upgradeCommand: 'upgrade',
          ),
        ),
        contains('upgrade'),
      );
      expect(
        textEn.currentVersionIsNotLatest(
          const CurrentVersionNotLatestArguments(
            currentVersion: '1',
            latestVersion: '2',
          ),
        ),
        isNot(contains('upgrade with')),
      );
    });
  });

  group('hidden flag completion', () {
    Application application({bool? includeHiddenFlags}) {
      return _application(
        buildCommand(
          docs: const CommandDocs(brief: 'run'),
          parameters: CommandParameters(
            flags: {
              'apiKey': ParsedFlag(
                brief: 'Secret',
                parse: stringParser,
                optional: true,
                hidden: true,
              ),
              'method': ParsedFlag(
                brief: 'Method',
                parse: stringParser,
                optional: true,
              ),
            },
            aliases: const {'k': 'apiKey', 'm': 'method'},
            positional: const TuplePositionalParameters([]),
          ),
          func: (context, flags, positional) => null,
        ),
        scanner: const ScannerConfiguration(
          caseStyle: ScannerCaseStyle.allowKebabForCamel,
        ),
        completion: CompletionConfiguration(
          includeAliases: true,
          includeHiddenFlags: includeHiddenFlags,
        ),
      );
    }

    test('a hidden flag is not proposed by default', () async {
      final values = await proposeCompletions(application(), [
        '--',
      ], _context().context);

      final completions = values.map((value) => value.completion);
      expect(completions, contains('--method'));
      expect(completions, isNot(contains('--api-key')));
    });

    test('a hidden alias is not proposed by default', () async {
      final values = await proposeCompletions(application(), [
        '-',
      ], _context().context);

      final completions = values.map((value) => value.completion);
      expect(completions, contains('-m'));
      expect(completions, isNot(contains('-k')));
    });

    test('a hidden alias is not appended to a shorthand run', () async {
      final values = await proposeCompletions(application(), [
        '-m',
      ], _context().context);

      expect(values.map((value) => value.completion), isNot(contains('-mk')));
    });

    test('includeHiddenFlags opts back in', () async {
      final long = await proposeCompletions(
        application(includeHiddenFlags: true),
        ['--'],
        _context().context,
      );
      final short = await proposeCompletions(
        application(includeHiddenFlags: true),
        ['-'],
        _context().context,
      );

      expect(long.map((value) => value.completion), contains('--api-key'));
      expect(short.map((value) => value.completion), contains('-k'));
    });

    test('an explicitly typed hidden alias still completes', () async {
      // Hidden means undocumented, not disabled: a user who already knows the
      // flag must still be able to finish typing it.
      final values = await proposeCompletions(application(), [
        '-k',
      ], _context().context);

      expect(values.map((value) => value.completion), contains('-k'));
    });
  });
}

ApplicationText? _noText(String locale) => null;
