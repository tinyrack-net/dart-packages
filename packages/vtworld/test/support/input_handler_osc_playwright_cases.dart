import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

Future<void> verifyInputHandlerOscPlaywrightCase(String name) async {
  final terminal = Terminal();
  addTearDown(terminal.dispose);
  final data = <String>[];
  terminal.onData.listen(data.add);
  if (name == 'query single color') {
    await terminal.writeAndWait('\x1b]4;0;?\x07\x1b]4;77;?\x07');
    return expect(data, <String>[
      _color(4, 0, '2e2e/3434/3636'),
      _color(4, 77, '5f5f/d7d7/5f5f'),
    ]);
  }
  if (name == 'query multiple colors') {
    await terminal.writeAndWait('\x1b]4;0;?;77;?\x07');
    return expect(data, <String>[
      _color(4, 0, '2e2e/3434/3636'),
      _color(4, 77, '5f5f/d7d7/5f5f'),
    ]);
  }
  if (name == 'set & query single color') {
    await terminal.writeAndWait('\x1b]4;0;?\x07');
    final restore = data.single;
    await terminal.writeAndWait('\x1b]4;0;rgb:01/02/03\x07\x1b]4;0;?\x07');
    expect(data, <String>[restore, _color(4, 0, '0101/0202/0303')]);
    await terminal.writeAndWait('$restore\x1b]4;0;?\x07');
    return expect(data, <String>[
      restore,
      _color(4, 0, '0101/0202/0303'),
      restore,
    ]);
  }
  if (name == 'query & set colors mixed') {
    return _mixed(terminal, data);
  }
  if (name == 'change & restore single color') {
    return _restoreOne(terminal, data);
  }
  if (name == 'restore multiple at once' || name == 'restore full table') {
    return _restoreTable(terminal, data, all: name == 'restore full table');
  }
  if (name == 'query FG color') {
    return _query(terminal, data, 10, 'ffff/ffff/ffff');
  }
  if (name == 'query BG color') {
    return _query(terminal, data, 11, '0000/0000/0000');
  }
  if (name == 'query FG & BG color in one call') {
    await terminal.writeAndWait('\x1b]10;?;?\x07');
    return expect(data, <String>[
      _dynamic(10, 'ffff/ffff/ffff'),
      _dynamic(11, '0000/0000/0000'),
    ]);
  }
  if (name == 'set & query FG') {
    return _setDynamic(terminal, data, 10, '#ffffff', 'ffff/ffff/ffff');
  }
  if (name == 'set & query BG') {
    return _setDynamic(terminal, data, 11, '#000000', '0000/0000/0000');
  }
  if (name == 'set & query cursor color') {
    return _setDynamic(terminal, data, 12, '#ffffff', 'ffff/ffff/ffff');
  }
  if (name == 'set & query FG & BG color in one call') {
    await terminal.writeAndWait(
      '\x1b]10;#123456;rgb:aa/bb/cc\x07\x1b]10;?;?\x07',
    );
    return expect(data, <String>[
      _dynamic(10, '1212/3434/5656'),
      _dynamic(11, 'aaaa/bbbb/cccc'),
    ]);
  }
  if (name.startsWith('OSC 110:')) {
    return _restoreDynamic(terminal, data, 10, 110, 'ffff/ffff/ffff');
  }
  if (name.startsWith('OSC 111:')) {
    return _restoreDynamic(terminal, data, 11, 111, '0000/0000/0000');
  }
  if (name.startsWith('OSC 112:')) {
    return _restoreDynamic(terminal, data, 12, 112, 'ffff/ffff/ffff');
  }
  throw StateError('unhandled OSC Playwright case: $name');
}

Future<void> _mixed(Terminal terminal, List<String> data) async {
  await terminal.writeAndWait('\x1b]4;0;?;77;?\x07');
  final restore = List<String>.of(data);
  data.clear();
  await terminal.writeAndWait('\x1b]4;0;rgb:01/02/03;43;?;77;#aabbcc\x07');
  expect(data, <String>[_color(4, 43, '0000/d7d7/afaf')]);
  data.clear();
  await terminal.writeAndWait('\x1b]4;0;?;77;?\x07');
  expect(data, <String>[
    _color(4, 0, '0101/0202/0303'),
    _color(4, 77, 'aaaa/bbbb/cccc'),
  ]);
  data.clear();
  await terminal.writeAndWait('${restore.join()}\x1b]4;0;?;77;?\x07');
  expect(data, restore);
}

Future<void> _restoreOne(Terminal terminal, List<String> data) async {
  for (final index in <int>[0, 43, 77, 255]) {
    await terminal.writeAndWait('\x1b]4;$index;?\x07');
    final restore = data.single;
    await terminal.writeAndWait(
      '\x1b]4;$index;rgb:01/02/03\x07\x1b]4;$index;?\x07',
    );
    expect(data, <String>[restore, _color(4, index, '0101/0202/0303')]);
    await terminal.writeAndWait('\x1b]104;$index\x07\x1b]4;$index;?\x07');
    expect(data, <String>[
      restore,
      _color(4, index, '0101/0202/0303'),
      restore,
    ]);
    data.clear();
  }
}

Future<void> _restoreTable(
  Terminal terminal,
  List<String> data, {
  required bool all,
}) async {
  await terminal.writeAndWait('\x1b]4;0;?;43;?;77;?\x07');
  final restore = List<String>.of(data);
  data.clear();
  await terminal.writeAndWait(
    '\x1b]4;0;rgb:01/02/03;43;#aabbcc;77;#123456\x07',
  );
  await terminal.writeAndWait(
    '${all ? '\x1b]104\x07' : '\x1b]104;0;43;77\x07'}\x1b]4;0;?;43;?;77;?\x07',
  );
  expect(data, restore);
}

Future<void> _query(
  Terminal terminal,
  List<String> data,
  int osc,
  String rgb,
) async {
  await terminal.writeAndWait('\x1b]$osc;?\x07');
  expect(data, <String>[_dynamic(osc, rgb)]);
}

Future<void> _setDynamic(
  Terminal terminal,
  List<String> data,
  int osc,
  String second,
  String secondRgb,
) async {
  await terminal.writeAndWait('\x1b]$osc;rgb:1/2/3\x07\x1b]$osc;?\x07');
  expect(data, <String>[_dynamic(osc, '1111/2222/3333')]);
  await terminal.writeAndWait('\x1b]$osc;$second\x07\x1b]$osc;?\x07');
  expect(data, <String>[
    _dynamic(osc, '1111/2222/3333'),
    _dynamic(osc, secondRgb),
  ]);
}

Future<void> _restoreDynamic(
  Terminal terminal,
  List<String> data,
  int osc,
  int restore,
  String original,
) async {
  await terminal.writeAndWait('\x1b]$osc;rgb:1/2/3\x07\x1b]$osc;?\x07');
  expect(data, <String>[_dynamic(osc, '1111/2222/3333')]);
  data.clear();
  await terminal.writeAndWait('\x1b]$restore\x07\x1b]$osc;?\x07');
  expect(data, <String>[_dynamic(osc, original)]);
}

String _color(int osc, int index, String rgb) =>
    '\x1b]$osc;$index;rgb:$rgb\x1b\\';
String _dynamic(int osc, String rgb) => '\x1b]$osc;rgb:$rgb\x1b\\';
