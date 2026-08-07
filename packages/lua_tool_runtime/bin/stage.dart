import 'dart:io';

import 'package:lua_tool_runtime/lua_tool_runtime.dart';

Future<void> main(List<String> arguments) async {
  final destination = _value(arguments, '--destination');
  final rawMode = _value(arguments, '--build-mode') ?? 'release';
  if (destination == null) {
    stderr.writeln(
      'usage: dart run lua_tool_runtime:stage '
      '--destination DIR [--build-mode debug|release]',
    );
    exitCode = 64;
    return;
  }
  try {
    await stageLuaToolRuntime(
      destination: destination,
      buildMode: LuaBuildMode.parse(rawMode),
    );
  } on Object catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}

String? _value(List<String> arguments, String flag) {
  final index = arguments.indexOf(flag);
  return index >= 0 && index + 1 < arguments.length
      ? arguments[index + 1]
      : null;
}
