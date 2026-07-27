import 'dart:io';

import 'package:cliweave/cliweave.dart';

const executableName = 'cliweave-fixture';
final scripts = CompletionScripts(executableName: executableName);
late final Application application;

final deployCommand = buildCommand(
  docs: const CommandDocs(brief: 'Deploy a target'),
  parameters: CommandParameters(
    flags: {
      'mode': const EnumFlag(
        brief: 'Deployment mode',
        values: ['fast', 'safe'],
        optional: true,
      ),
      'project': ParsedFlag(
        brief: 'Project name',
        parse: stringParser,
        optional: true,
        proposeCompletions: (partial) => ['alpha', 'beta'],
      ),
    },
    positional: TuplePositionalParameters([
      PositionalParameter(
        brief: 'Target directory',
        parse: stringParser,
        placeholder: 'target',
        proposeCompletions: (partial) => ['src/', 'test/'],
      ),
    ]),
  ),
  func: (context, flags, positional) {
    context.process.stdout.write(
      'deploy:${positional.single}:${flags['mode'] ?? 'default'}\n',
    );
    return null;
  },
);

final streamCommand = buildCommand(
  docs: const CommandDocs(brief: 'Exercise the stdio adapter'),
  parameters: const CommandParameters(),
  func: (context, flags, positional) {
    context.process.stdout
      ..clearLine(-1)
      ..clearLine(0)
      ..clearLine(1)
      ..cursorTo(2)
      ..write('stream\n');
    return null;
  },
);

final completionCommand = buildCommand(
  docs: const CommandDocs(brief: 'Print a shell completion script'),
  parameters: const CommandParameters(
    positional: TuplePositionalParameters([
      PositionalParameter(
        brief: 'Shell name',
        parse: stringParser,
        placeholder: 'shell',
      ),
    ]),
  ),
  func: (context, flags, positional) {
    final script = switch (positional.single) {
      'bash' => scripts.bash,
      'zsh' => scripts.zsh,
      'fish' => scripts.fish,
      'powershell' => scripts.powershell,
      final shell => throw ArgumentError('unsupported shell: $shell'),
    };
    context.process.stdout.write(script);
    return null;
  },
);

final completeCommand = buildCommand(
  docs: const CommandDocs(brief: 'Compute completion candidates'),
  parameters: const CommandParameters(
    positional: ArrayPositionalParameters(
      parameter: PositionalParameter(
        brief: 'Input token',
        parse: stringParser,
        optional: true,
      ),
      minimum: 0,
    ),
  ),
  func: (context, flags, positional) async {
    final inputs = scripts.resolveCompletionInputs(positional.cast<String>());
    final completions = await proposeCompletions(application, inputs, context);
    for (final completion in completions) {
      context.process.stdout.write(
        '${completion.completion}\t${completion.brief}\n',
      );
    }
    return null;
  },
);

void _buildApplication() {
  application = buildApplication(
    buildRouteMap(
      docs: const RouteMapDocs(
        brief: 'Completion fixture',
        hideRoute: {'__complete': true},
      ),
      routes: {
        'deploy': deployCommand,
        'stream': streamCommand,
        'completion': completionCommand,
        '__complete': completeCommand,
      },
    ),
    ApplicationConfiguration(
      name: executableName,
      scanner: const ScannerConfiguration(
        caseStyle: ScannerCaseStyle.allowKebabForCamel,
        allowArgumentEscapeSequence: true,
      ),
      documentation: const DocumentationConfiguration(disableAnsiColor: true),
    ),
  );
}

Future<void> main(List<String> arguments) async {
  _buildApplication();
  final routedArguments =
      arguments.isNotEmpty && arguments.first == '__complete'
      ? ['__complete', '--', ...arguments.skip(1)]
      : arguments;
  final process = RunProcess(
    stdout: StdioWriteStream(stdout),
    stderr: StdioWriteStream(stderr),
  );
  await run(application, routedArguments, RunContext(process: process));
  exitCode = process.exitCode ?? 0;
}
