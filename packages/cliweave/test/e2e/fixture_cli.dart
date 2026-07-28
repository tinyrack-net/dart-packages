import 'dart:io';

import 'package:cliweave/cliweave.dart';

const executableName = 'cliweave-fixture';
final scripts = CompletionScripts(executableName: executableName);
late final Application<ApplicationContext> application;

final modeFlag = EnumFlag.optional<String, ApplicationContext>(
  name: 'mode',
  brief: 'Deployment mode',
  values: const {'fast': 'fast', 'safe': 'safe'},
);
final projectFlag = ParsedFlag.optional<String, ApplicationContext>(
  name: 'project',
  brief: 'Project name',
  parse: stringParser,
  proposeCompletions: (context, partial) => ['alpha', 'beta'],
);
final targetArgument = Positional.required<String, ApplicationContext>(
  brief: 'Target directory',
  parse: stringParser,
  placeholder: 'target',
  proposeCompletions: (context, partial) => ['src/', 'test/'],
);

final deployCommand = buildCommand(
  docs: const CommandDocs(brief: 'Deploy a target'),
  parameters: CommandParameters(
    flags: FlagSet.one(
      modeFlag,
    ).and(projectFlag).map((values) => (mode: values.$1, project: values.$2)),
    positional: PositionalSet.one(targetArgument).map((target) => (target,)),
  ),
  func: (context, flags, args) {
    context.process.stdout.write(
      'deploy:${args.$1}:${flags.mode ?? 'default'}\n',
    );
  },
);

final streamCommand = buildCommand(
  docs: const CommandDocs(brief: 'Exercise the stdio adapter'),
  parameters: CommandParameters<NoFlags, NoArgs, ApplicationContext>(
    flags: FlagSet<NoFlags, ApplicationContext>.none(),
    positional: PositionalSet.none(),
  ),
  func: (context, flags, positional) {
    context.process.stdout
      ..clearLine(-1)
      ..clearLine(0)
      ..clearLine(1)
      ..cursorTo(2)
      ..write('stream\n');
  },
);

final shellArgument = Positional.required<String, ApplicationContext>(
  brief: 'Shell name',
  parse: stringParser,
  placeholder: 'shell',
);

final completionCommand = buildCommand(
  docs: const CommandDocs(brief: 'Print a shell completion script'),
  parameters: CommandParameters(
    flags: FlagSet<NoFlags, ApplicationContext>.none(),
    positional: PositionalSet.one(shellArgument).map((shell) => (shell,)),
  ),
  func: (context, flags, args) {
    final script = switch (args.$1) {
      'bash' => scripts.bash,
      'zsh' => scripts.zsh,
      'fish' => scripts.fish,
      'powershell' => scripts.powershell,
      final shell => throw ArgumentError('unsupported shell: $shell'),
    };
    context.process.stdout.write(script);
  },
);

final completionInput = Positional.optional<String, ApplicationContext>(
  brief: 'Input token',
  parse: stringParser,
);

final completeCommand = buildCommand(
  docs: const CommandDocs(brief: 'Compute completion candidates'),
  parameters: CommandParameters(
    flags: FlagSet<NoFlags, ApplicationContext>.none(),
    positional: PositionalSet.array(
      completionInput,
      minimum: 0,
    ).map((values) => values.whereType<String>().toList()),
  ),
  func: (context, flags, inputsFromShell) async {
    final inputs = scripts.resolveCompletionInputs(inputsFromShell);
    final completions = await proposeCompletions(
      application,
      inputs,
      RunContext.direct(context),
    );
    for (final completion in completions) {
      context.process.stdout.write(
        '${completion.completion}\t${completion.brief}\n',
      );
    }
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
  await run(
    application,
    routedArguments,
    RunContext.direct(ApplicationContext(process: process)),
  );
  exitCode = process.exitCode ?? 0;
}
