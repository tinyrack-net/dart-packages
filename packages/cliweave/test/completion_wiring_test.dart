import 'package:cliweave/cliweave.dart';
import 'package:test/test.dart';

import 'helpers/capture_stream.dart';

const _executableName = 'dw';
final _scripts = CompletionScripts(executableName: _executableName);

Application<ApplicationContext> _buildApplication() {
  late final Application<ApplicationContext> application;

  final pushCommand = buildCommand(
    docs: const CommandDocs(brief: 'Push local configuration'),
    parameters: CommandParameters(
      flags: FlagSet.one(
        BooleanFlag.optional<ApplicationContext>(
          name: 'withGit',
          brief: 'Also commit and push to the git remote',
        ),
      ),
      positional: PositionalSet.none<ApplicationContext>(),
    ),
    func: (context, flags, args) => null,
  );

  final completeCommand = buildCommand(
    docs: const CommandDocs(brief: 'Compute completion candidates'),
    parameters: CommandParameters(
      flags: FlagSet<NoFlags, ApplicationContext>.none(),
      positional: PositionalSet.array(
        Positional.required<String, ApplicationContext>(
          brief: 'Completion input token',
          parse: stringParser,
          placeholder: 'input',
        ),
        minimum: 0,
      ),
    ),
    func: (context, flags, inputsFromShell) async {
      final inputs = _scripts.resolveCompletionInputs(
        inputsFromShell,
        readEnv: context.process.readEnv,
      );
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

  application = buildApplication(
    buildRouteMap(
      docs: const RouteMapDocs(
        brief: 'Completion wiring fixture',
        hideRoute: {'__complete': true},
      ),
      routes: {'push': pushCommand, '__complete': completeCommand},
    ),
    ApplicationConfiguration(
      name: _executableName,
      completion: const CompletionConfiguration(includeAliases: false),
      documentation: const DocumentationConfiguration(disableAnsiColor: true),
      scanner: const ScannerConfiguration(
        caseStyle: ScannerCaseStyle.allowKebabForCamel,
      ),
    ),
  );

  return application;
}

Future<({int exitCode, String stdout, String stderr})> _run(
  List<String> inputs, {
  String? completionLine,
}) async {
  final stdout = CaptureStream();
  final stderr = CaptureStream();
  final process = RunProcess(
    stdout: stdout,
    stderr: stderr,
    readEnv: (name) => name == 'COMP_LINE' ? completionLine : null,
  );
  final context = RunContext.direct(ApplicationContext(process: process));

  await run(_buildApplication(), inputs, context);

  return (
    exitCode: process.exitCode ?? 0,
    stdout: stdout.text,
    stderr: stderr.text,
  );
}

void main() {
  test(
    'completes long flag prefixes without parsing them as CLI flags',
    () async {
      // Generated scripts pass the raw line through COMP_LINE and invoke the
      // hidden command without forwarding its flag-like words as argv.
      final result = await _run([
        '__complete',
      ], completionLine: 'dw push --wit');
      printOnFailure(
        'exitCode=${result.exitCode}\n'
        'stdout=${result.stdout}\n'
        'stderr=${result.stderr}',
      );

      expect(result.exitCode, 0);
      expect(result.stderr, isEmpty);
      expect(result.stdout, contains('--with-git'));
    },
  );
}
