import 'dart:io';

import 'package:tinyrack_workspace/tinyrack_workspace.dart';

Future<void> main(List<String> arguments) async {
  exitCode = await runTinyrackWorkspace(
    arguments,
    out: stdout.writeln,
    error: stderr.writeln,
  );
}
