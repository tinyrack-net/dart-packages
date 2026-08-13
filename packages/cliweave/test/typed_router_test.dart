import 'package:cliweave/cliweave.dart';
import 'package:test/test.dart';

import 'helpers/capture_stream.dart';

final class TestContext implements CommandContext {
  const TestContext(this.process, this.multiplier);

  @override
  final RunProcess process;
  final int multiplier;
}

Future<T> _runFlag<T>(
  FlagBinding<T, TestContext> binding,
  List<String> inputs,
) async {
  late T value;
  final process = RunProcess(stdout: CaptureStream(), stderr: CaptureStream());
  final command = buildCommand(
    docs: const CommandDocs(brief: 'Matrix'),
    parameters: CommandParameters(
      flags: FlagSet.one(binding),
      positional: PositionalSet.none<TestContext>(),
    ),
    func: (context, flags, args) => value = flags,
  );
  final app = buildApplication(
    command,
    const ApplicationConfiguration(name: 'typed'),
    integrations: const <CliIntegration<TestContext>>[],
  );
  expect(
    await runApplication(
      app,
      inputs,
      RunContext.direct(TestContext(process, 2)),
    ),
    ExitCode.success,
  );
  return value;
}

Future<T> _runPositional<T>(
  PositionalSet<T, TestContext> positional,
  List<String> inputs,
) async {
  late T value;
  final process = RunProcess(stdout: CaptureStream(), stderr: CaptureStream());
  final command = buildLazyCommand<TestContext, NoFlags, T>(
    docs: const CommandDocs(brief: 'Matrix'),
    parameters: CommandParameters(
      flags: FlagSet<NoFlags, TestContext>.none(),
      positional: positional,
    ),
    loader: () async =>
        (TestContext context, NoFlags flags, T args) => value = args,
  );
  final app = buildApplication(
    command,
    const ApplicationConfiguration(name: 'typed'),
    integrations: const <CliIntegration<TestContext>>[],
  );
  expect(
    await runApplication(
      app,
      inputs,
      RunContext.direct(TestContext(process, 2)),
    ),
    ExitCode.success,
  );
  return value;
}

void main() {
  test(
    'all typed flag result shapes decode without an open value bag',
    () async {
      expect(
        await _runFlag(
          BooleanFlag.required<TestContext>(name: 'value', brief: 'Value'),
          const [],
        ),
        isFalse,
      );
      expect(
        await _runFlag(
          BooleanFlag.optional<TestContext>(name: 'value', brief: 'Value'),
          const [],
        ),
        isNull,
      );
      expect(
        await _runFlag(
          BooleanFlag.defaulted<TestContext>(
            name: 'value',
            brief: 'Value',
            defaultValue: true,
          ),
          const [],
        ),
        isTrue,
      );
      expect(
        await _runFlag(
          CounterFlag.required<TestContext>(name: 'value', brief: 'Value'),
          const ['--value', '--value'],
        ),
        2,
      );
      expect(
        await _runFlag(
          CounterFlag.optional<TestContext>(name: 'value', brief: 'Value'),
          const [],
        ),
        isNull,
      );
      const choices = {'one': 1, 'two': 2};
      expect(
        await _runFlag(
          EnumFlag.required<int, TestContext>(
            name: 'value',
            brief: 'Value',
            values: choices,
          ),
          const ['--value', 'two'],
        ),
        2,
      );
      expect(
        await _runFlag(
          EnumFlag.optional<int, TestContext>(
            name: 'value',
            brief: 'Value',
            values: choices,
          ),
          const [],
        ),
        isNull,
      );
      expect(
        await _runFlag(
          EnumFlag.defaulted<int, TestContext>(
            name: 'value',
            brief: 'Value',
            values: choices,
            defaultValue: 'one',
          ),
          const [],
        ),
        1,
      );
      expect(
        await _runFlag(
          EnumFlag.variadic<int, TestContext>(
            name: 'value',
            brief: 'Value',
            values: choices,
            separator: ',',
          ),
          const ['--value', 'one,two'],
        ),
        [1, 2],
      );
      expect(
        await _runFlag(
          EnumFlag.strings<TestContext>(
            name: 'value',
            brief: 'Value',
            values: const ['one'],
          ),
          const ['--value', 'one'],
        ),
        'one',
      );
      int parser(TestContext context, String input) =>
          int.parse(input) * context.multiplier;
      expect(
        await _runFlag(
          ParsedFlag.optional<int, TestContext>(
            name: 'value',
            brief: 'Value',
            parse: parser,
          ),
          const [],
        ),
        isNull,
      );
      expect(
        await _runFlag(
          ParsedFlag.defaulted<int, TestContext>(
            name: 'value',
            brief: 'Value',
            parse: parser,
            defaultValue: '3',
          ),
          const [],
        ),
        6,
      );
      expect(
        await _runFlag(
          ParsedFlag.variadic<int, TestContext>(
            name: 'value',
            brief: 'Value',
            parse: parser,
            separator: ',',
          ),
          const ['--value', '2,3'],
        ),
        [4, 6],
      );
    },
  );

  test(
    'decoders carry context, flags, and positional types to the handler',
    () async {
      final stdout = CaptureStream();
      final stderr = CaptureStream();
      final process = RunProcess(stdout: stdout, stderr: stderr);
      final amount = ParsedFlag.required<int, TestContext>(
        name: 'amount',
        brief: 'Amount',
        parse: (context, input) => int.parse(input) * context.multiplier,
      );
      final label = Positional.required<String, TestContext>(
        brief: 'Label',
        parse: (context, input) => '$input:${context.multiplier}',
      );
      final command = buildCommand(
        docs: const CommandDocs(brief: 'Typed'),
        parameters: CommandParameters(
          flags: FlagSet.one(amount).map((value) => (amount: value)),
          positional: PositionalSet.one(label).map((value) => (label: value)),
        ),
        func: (context, flags, args) {
          context.process.stdout.write('${flags.amount}/${args.label}');
        },
      );
      final app = buildApplication(
        command,
        const ApplicationConfiguration(name: 'typed'),
        integrations: const <CliIntegration<TestContext>>[],
      );

      final code = await runApplication(app, [
        '--amount',
        '3',
        'item',
      ], RunContext.direct(TestContext(process, 2)));

      expect(code, ExitCode.success);
      expect(stdout.text, '6/item:2');
      expect(stderr.text, isEmpty);
    },
  );

  test(
    'ordered integrations run hooks and the first application flag',
    () async {
      final stdout = CaptureStream();
      final stderr = CaptureStream();
      final process = RunProcess(stdout: stdout, stderr: stderr);
      final events = <String>[];
      final command = buildCommand(
        docs: const CommandDocs(brief: 'Typed'),
        parameters: CommandParameters(
          flags: FlagSet<NoFlags, TestContext>.none(),
          positional: PositionalSet.none<TestContext>(),
        ),
        func: (context, flags, args) => events.add('command'),
      );
      final app = buildApplication(
        command,
        const ApplicationConfiguration(name: 'typed'),
        integrations: [
          CliIntegration(
            name: 'inspect',
            hooks: LifecycleHooks(
              appStart: (_) => events.add('app:start'),
              appEnd: (_) => events.add('app:end'),
            ),
            flag: ApplicationFlag(
              brief: 'Inspect',
              aliases: const ['i'],
              run: (arguments) {
                events.add('flag');
                arguments.context.process.stdout.write('inspected');
              },
            ),
          ),
        ],
      );

      final code = await runApplication(app, [
        '--inspect',
      ], RunContext.direct(TestContext(process, 1)));

      expect(code, ExitCode.success);
      expect(events, ['app:start', 'flag', 'app:end']);
      expect(stdout.text, 'inspected');
    },
  );

  test('dynamic context failures return contextLoadError', () async {
    final process = RunProcess(
      stdout: CaptureStream(),
      stderr: CaptureStream(),
    );
    final command = buildCommand(
      docs: const CommandDocs(brief: 'Typed'),
      parameters: CommandParameters(
        flags: FlagSet<NoFlags, TestContext>.none(),
        positional: PositionalSet.none<TestContext>(),
      ),
      func: (context, flags, args) {},
    );
    final app = buildApplication(
      command,
      const ApplicationConfiguration(name: 'typed'),
      integrations: const <CliIntegration<TestContext>>[],
    );

    final code = await runApplication(
      app,
      const [],
      RunContext.forCommands(
        application: ApplicationContext(process: process),
        load: (_) => throw StateError('load failed'),
      ),
    );

    expect(code, ExitCode.contextLoadError);
  });

  test('all typed positional result shapes and lazy loaders decode', () async {
    int parser(TestContext context, String input) =>
        int.parse(input) * context.multiplier;
    expect(
      await _runPositional(
        PositionalSet.one(
          Positional.required<int, TestContext>(brief: 'Value', parse: parser),
        ),
        const ['2'],
      ),
      4,
    );
    expect(
      await _runPositional(
        PositionalSet.one(
          Positional.optional<int, TestContext>(brief: 'Value', parse: parser),
        ),
        const [],
      ),
      isNull,
    );
    expect(
      await _runPositional(
        PositionalSet.one(
          Positional.defaulted<int, TestContext>(
            brief: 'Value',
            parse: parser,
            defaultValue: '3',
          ),
        ),
        const [],
      ),
      6,
    );
    expect(
      await _runPositional(
        PositionalSet.array(
          Positional.required<int, TestContext>(brief: 'Value', parse: parser),
          minimum: 1,
          maximum: 2,
        ),
        const ['2', '3'],
      ),
      [4, 6],
    );
  });

  test('help, version, completion, and all lifecycle hooks compose', () async {
    final stdout = CaptureStream();
    final stderr = CaptureStream();
    final process = RunProcess(
      stdout: stdout,
      stderr: stderr,
      readEnv: (_) => null,
    );
    final events = <String>[];
    final command = buildCommand(
      docs: const CommandDocs(brief: 'Run work'),
      parameters: CommandParameters(
        flags: FlagSet<NoFlags, TestContext>.none(),
        positional: PositionalSet.none<TestContext>(),
      ),
      func: (context, flags, args) => events.add('command'),
    );
    final root = buildRouteMap(
      docs: const RouteMapDocs(brief: 'Root'),
      routes: {'run': command},
    );
    final app = buildApplication(
      root,
      const ApplicationConfiguration(name: 'typed'),
      integrations: [
        helpIntegration<TestContext>(),
        versionIntegration<TestContext>(
          info: VersionInformation(
            getCurrentVersion: (_) async => '1.0.0',
            getLatestVersion: (_, current) async => '2.0.0',
            upgradeCommand: 'typed upgrade',
          ),
        ),
        CliIntegration<TestContext>(
          name: 'lifecycle',
          hooks: LifecycleHooks<TestContext>(
            appStart: (_) => events.add('app:start'),
            commandStart: (args) =>
                events.add('command:start:${args.context.multiplier}'),
            commandEnd: (args) => events.add('command:end:${args.exitCode}'),
            appEnd: (args) => events.add('app:end:${args.exitCode}'),
          ),
        ),
      ],
    );
    final context = RunContext.direct(TestContext(process, 3));

    expect(await runApplication(app, ['--help'], context), ExitCode.success);
    expect(stdout.text, contains('COMMANDS'));
    expect(
      (await proposeCompletions(app, [
        '--',
      ], context)).map((item) => item.completion),
      containsAll(['--help', '--version']),
    );
    expect(await runApplication(app, ['--version'], context), ExitCode.success);
    expect(stdout.text, contains('1.0.0'));
    expect(stderr.text, contains('2.0.0'));
    expect(await runApplication(app, ['run'], context), ExitCode.success);
    expect(
      events,
      containsAllInOrder(['command:start:3', 'command', 'command:end:0']),
    );
  });

  test('integration failures return integrationError', () async {
    final stderr = CaptureStream();
    final process = RunProcess(stdout: CaptureStream(), stderr: stderr);
    final command = buildCommand(
      docs: const CommandDocs(brief: 'Run'),
      parameters: CommandParameters(
        flags: FlagSet<NoFlags, TestContext>.none(),
        positional: PositionalSet.none<TestContext>(),
      ),
      func: (context, flags, args) {},
    );
    final hookApp = buildApplication(
      command,
      const ApplicationConfiguration(name: 'typed'),
      integrations: [
        CliIntegration<TestContext>(
          name: 'broken',
          hooks: LifecycleHooks<TestContext>(
            appStart: (_) => throw StateError('hook'),
          ),
        ),
      ],
    );
    expect(
      await runApplication(
        hookApp,
        const [],
        RunContext.direct(TestContext(process, 1)),
      ),
      ExitCode.integrationError,
    );
    final flagApp = buildApplication(
      command,
      const ApplicationConfiguration(name: 'typed'),
      integrations: [
        CliIntegration<TestContext>(
          name: 'broken',
          flag: ApplicationFlag(
            brief: 'Broken',
            run: (_) => throw StateError('flag'),
          ),
        ),
      ],
    );
    expect(
      await runApplication(flagApp, const [
        '--broken',
      ], RunContext.direct(TestContext(process, 1))),
      ExitCode.integrationError,
    );
    expect(stderr.text, contains('broken'));
  });

  test('integration build validation rejects every collision category', () {
    final command = buildCommand(
      docs: const CommandDocs(brief: 'Run'),
      parameters: CommandParameters(
        flags: FlagSet.one(
          BooleanFlag.required<TestContext>(name: 'verbose', brief: 'Verbose'),
        ),
        positional: PositionalSet.none<TestContext>(),
      ),
      func: (context, flags, args) {},
    );
    Application<TestContext> build(List<CliIntegration<TestContext>> values) =>
        buildApplication(
          command,
          const ApplicationConfiguration(name: 'typed'),
          integrations: values,
        );
    CliIntegration<TestContext> flag(
      String name, {
      List<String> aliases = const [],
      bool routeDefault = false,
    }) => CliIntegration(
      name: name,
      flag: ApplicationFlag(
        brief: name,
        aliases: aliases,
        defaultForRouteMap: routeDefault,
        run: (_) {},
      ),
    );

    expect(
      () => build([flag('same'), flag('same')]),
      throwsA(isA<RouterInternalError>()),
    );
    expect(
      () => build([
        flag('one', aliases: ['x']),
        flag('two', aliases: ['x']),
      ]),
      throwsA(isA<RouterInternalError>()),
    );
    expect(
      () => build([
        flag('one', routeDefault: true),
        flag('two', routeDefault: true),
      ]),
      throwsA(isA<RouterInternalError>()),
    );
    expect(() => build([flag('verbose')]), throwsA(isA<RouterInternalError>()));
    expect(
      () => build([
        CliIntegration<TestContext>(
          name: 'validate',
          validate: (_) => throw StateError('invalid'),
        ),
      ]),
      throwsA(isA<RouterInternalError>()),
    );
  });

  test('record composition, contextual completion, default version, and run facade', () async {
    final stdout = CaptureStream();
    final process = RunProcess(stdout: stdout, stderr: CaptureStream());
    final first = BooleanFlag.required<TestContext>(
      name: 'first',
      brief: 'First',
    );
    final second = ParsedFlag.required<int, TestContext>(
      name: 'second',
      brief: 'Second',
      parse: (context, input) => int.parse(input),
      proposeCompletions: (context, partial) => ['7'],
    );
    final left = Positional.required<String, TestContext>(
      brief: 'Left',
      parse: stringParser,
      proposeCompletions: (context, partial) => ['left'],
    );
    final right = Positional.optional<String, TestContext>(
      brief: 'Right',
      parse: stringParser,
    );
    final parameters = CommandParameters(
      flags: FlagSet.one(first)
          .and(second)
          .map((values) => (first: values.$1, second: values.$2)),
      positional: PositionalSet.one(left)
          .and(right)
          .map((values) => (left: values.$1, right: values.$2)),
    );
    final command = buildCommand(
      docs: const CommandDocs(brief: 'Compose'),
      parameters: parameters,
      func: (context, flags, args) {
        context.process.stdout.write('${flags.second}:${args.left}');
      },
    );
    final app = buildApplication(
      command,
      ApplicationConfiguration(
        name: 'typed',
        versionInfo: VersionInformation(
          getCurrentVersion: (_) => '3.0.0',
          getLatestVersion: (_, current) => current,
        ),
      ),
    );
    final context = RunContext.direct(TestContext(process, 1));
    expect(
      (await proposeCompletions(app, [
        '--second',
        '',
      ], context)).single.completion,
      '7',
    );
    expect(
      (await proposeCompletions(app, ['l'], context)).single.completion,
      'left',
    );
    await run(app, ['--second', '4', 'left'], context);
    expect(process.exitCode, ExitCode.success);
    expect(stdout.text, contains('4:left'));
    expect(await runApplication(app, ['--version'], context), ExitCode.success);
    expect(stdout.text, contains('3.0.0'));
    expect(stringParser(context._rawContextForTest, 'x'), 'x');
    expect(booleanParser(context._rawContextForTest, 'true'), isTrue);
    expect(looseBooleanParser(context._rawContextForTest, 'yes'), isTrue);
    expect(numberParser(context._rawContextForTest, '2'), 2);
  });
}

extension on RunContext<TestContext> {
  TestContext get _rawContextForTest {
    final process = RunProcess(
      stdout: CaptureStream(),
      stderr: CaptureStream(),
    );
    return TestContext(process, 1);
  }
}
