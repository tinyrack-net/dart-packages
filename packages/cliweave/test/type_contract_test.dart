import 'dart:io';

import 'package:test/test.dart';

Future<ProcessResult> _analyze(String name, String source) async {
  final file = File.fromUri(
    Directory.current.uri.resolve('tool/_generated_${name}_contract.dart'),
  );
  await file.parent.create(recursive: true);
  await file.writeAsString(source);
  try {
    return await Process.run(Platform.resolvedExecutable, [
      'analyze',
      '--format',
      'machine',
      file.absolute.path,
    ]);
  } finally {
    if (await file.exists()) {
      await file.delete();
    }
  }
}

void main() {
  test(
    'valid record and class decoders satisfy the analyzer contract',
    () async {
      final result = await _analyze('valid', r'''
import 'package:cliweave/cliweave.dart';

final class _Context implements CommandContext {
  _Context(this.process);
  @override
  final RunProcess process;
}

final class _Options {
  const _Options(this.enabled);
  final bool enabled;
}

void main() {
  final enabled = BooleanFlag.required<_Context>(
    name: 'enabled',
    brief: 'Enabled',
  );
  final value = Positional.required<int, _Context>(
    brief: 'Value',
    parse: (context, input) => int.parse(input),
  );
  buildCommand(
    docs: const CommandDocs(brief: 'Valid'),
    parameters: CommandParameters(
      flags: FlagSet.one(enabled).map(_Options.new),
      positional: PositionalSet.one(value).map((value) => (value: value)),
    ),
    func: (_Context context, _Options flags, ({int value}) args) {},
  );
}
''');

      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    },
  );

  test(
    'wrong handler, parser, context, lazy loader, and fields fail analysis',
    () async {
      final result = await _analyze('invalid', r'''
import 'package:cliweave/cliweave.dart';

final class _Context implements CommandContext {
  _Context(this.process);
  @override
  final RunProcess process;
}

final class _OtherContext implements CommandContext {
  _OtherContext(this.process);
  @override
  final RunProcess process;
}

void main() {
  final enabled = BooleanFlag.required<_Context>(
    name: 'enabled',
    brief: 'Enabled',
  );
  final parameters = CommandParameters(
    flags: FlagSet.one(enabled).map((value) => (enabled: value)),
    positional: PositionalSet.none<_Context>(),
  );

  ParsedFlag.required<int, _Context>(
    name: 'bad',
    brief: 'Bad parser',
    parse: (context, input) => input,
  );

  buildCommand<_Context, String, NoArgs>(
    docs: const CommandDocs(brief: 'Wrong flags'),
    parameters: parameters,
    func: (context, flags, args) {},
  );

  buildCommand(
    docs: const CommandDocs(brief: 'Unknown field'),
    parameters: parameters,
    func: (context, flags, args) {
      print(flags.missing);
    },
  );

  buildLazyCommand<_Context, ({bool enabled}), NoArgs>(
    docs: const CommandDocs(brief: 'Wrong context'),
    parameters: parameters,
    loader: () => (_OtherContext context, flags, args) {},
  );
}
''');

      expect(result.exitCode, isNot(0));
      final errors = '${result.stdout}'
          .split('\n')
          .where((line) => line.startsWith('ERROR|'));
      expect(
        errors.length,
        greaterThanOrEqualTo(4),
        reason: '${result.stdout}',
      );
    },
  );
}
