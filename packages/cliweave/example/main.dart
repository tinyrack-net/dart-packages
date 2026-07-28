// A minimal two-command application.
//
// Run it with:
//   dart run example/main.dart greet world
//   dart run example/main.dart greet --loud world
//   dart run example/main.dart --help

import 'dart:io';

import 'package:cliweave/cliweave.dart';

final loudFlag = BooleanFlag.optional<ApplicationContext>(
  name: 'loud',
  brief: 'Shout the greeting',
);
final nameArgument = Positional.required<String, ApplicationContext>(
  brief: 'Who to greet',
  parse: stringParser,
  placeholder: 'name',
);

final greetCommand = buildCommand(
  docs: const CommandDocs(brief: 'Greet someone'),
  parameters: CommandParameters(
    flags: FlagSet.one(loudFlag).map((loud) => (loud: loud)),
    positional: PositionalSet.one(nameArgument).map((name) => (name,)),
  ),
  func: (context, flags, args) {
    final greeting = 'Hello, ${args.$1}!';

    context.process.stdout.write(
      '${flags.loud == true ? greeting.toUpperCase() : greeting}\n',
    );
  },
);

Future<void> main(List<String> args) async {
  final app = buildApplication(
    buildRouteMap(
      docs: const RouteMapDocs(brief: 'Example CLI'),
      routes: {'greet': greetCommand},
    ),
    ApplicationConfiguration(
      name: 'example',
      // Lets `--dry-run` bind to a `dryRun` flag, and vice versa.
      scanner: const ScannerConfiguration(
        caseStyle: ScannerCaseStyle.allowKebabForCamel,
      ),
    ),
  );

  final process = RunProcess(
    stdout: StdioWriteStream(stdout),
    stderr: StdioWriteStream(stderr),
  );

  await run(app, args, RunContext.direct(ApplicationContext(process: process)));

  exitCode = process.exitCode ?? 0;
}
