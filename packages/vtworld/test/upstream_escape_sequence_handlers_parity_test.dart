import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  test(
    'xterm EscapeSequenceParser 51',
    () => _verify(_Family.apc, _Mode.allow),
  );
  test(
    'xterm EscapeSequenceParser 52',
    () => _verify(_Family.apc, _Mode.dispose),
  );
  test(
    'xterm EscapeSequenceParser 53',
    () => _verify(_Family.apc, _Mode.order),
  );
  test(
    'xterm EscapeSequenceParser 54',
    () => _verify(_Family.apc, _Mode.fallbackOnce),
  );
  test(
    'xterm EscapeSequenceParser 55',
    () => _verify(_Family.apc, _Mode.noFallback),
  );
  test(
    'xterm EscapeSequenceParser 56',
    () => _verify(_Family.apc, _Mode.prevent),
  );
  test(
    'xterm EscapeSequenceParser 57',
    () => _verify(_Family.apc, _Mode.doubleDispose),
  );
  test(
    'xterm EscapeSequenceParser 58',
    () => _verify(_Family.apc, _Mode.clear),
  );

  test(
    'xterm EscapeSequenceParser 59',
    () => _verify(_Family.csi, _Mode.allow),
  );
  test(
    'xterm EscapeSequenceParser 60',
    () => _verify(_Family.csi, _Mode.dispose),
  );
  test(
    'xterm EscapeSequenceParser 61',
    () => _verify(_Family.csi, _Mode.order),
  );
  test(
    'xterm EscapeSequenceParser 62',
    () => _verify(_Family.csi, _Mode.fallbackOnce),
  );
  test(
    'xterm EscapeSequenceParser 63',
    () => _verify(_Family.csi, _Mode.noFallback),
  );
  test(
    'xterm EscapeSequenceParser 64',
    () => _verify(_Family.csi, _Mode.prevent),
  );
  test(
    'xterm EscapeSequenceParser 65',
    () => _verify(_Family.csi, _Mode.doubleDispose),
  );
  test(
    'xterm EscapeSequenceParser 66',
    () => _verify(_Family.csi, _Mode.clear),
  );

  test(
    'xterm EscapeSequenceParser 67',
    () => _verify(_Family.dcs, _Mode.allow),
  );
  test(
    'xterm EscapeSequenceParser 68',
    () => _verify(_Family.dcs, _Mode.dispose),
  );
  test(
    'xterm EscapeSequenceParser 69',
    () => _verify(_Family.dcs, _Mode.order),
  );
  test(
    'xterm EscapeSequenceParser 70',
    () => _verify(_Family.dcs, _Mode.fallbackOnce),
  );
  test(
    'xterm EscapeSequenceParser 71',
    () => _verify(_Family.dcs, _Mode.noFallback),
  );
  test(
    'xterm EscapeSequenceParser 72',
    () => _verify(_Family.dcs, _Mode.prevent),
  );
  test(
    'xterm EscapeSequenceParser 73',
    () => _verify(_Family.dcs, _Mode.doubleDispose),
  );
  test(
    'xterm EscapeSequenceParser 74',
    () => _verify(_Family.dcs, _Mode.clear),
  );

  test('xterm EscapeSequenceParser 75', () async {
    final parser = TerminalParser();
    addTearDown(parser.dispose);
    TerminalParsingState? error;
    parser.setErrorHandler((state) => error = state);
    await parser.filter('\u001b[1;2;€;3m');
    expect(error, isNotNull);
    expect(
      (
        error!.position,
        error!.code,
        error!.currentState,
        error!.collect,
        error!.abort,
      ),
      (6, '€'.codeUnitAt(0), 4, '', false),
    );
    expect(error!.parameters, <TerminalParameter>[1, 2, 0]);
    parser
      ..clearErrorHandler()
      ..clearErrorHandler();
    error = null;
    await parser.filter('\u001b[1;2;a;3m');
    expect(error, isNull);
  });

  test(
    'xterm EscapeSequenceParser 76',
    () => _verify(_Family.esc, _Mode.dispose),
  );
  test(
    'xterm EscapeSequenceParser 77',
    () => _verify(_Family.esc, _Mode.order),
  );
  test(
    'xterm EscapeSequenceParser 78',
    () => _verify(_Family.esc, _Mode.fallbackOnce),
  );
  test(
    'xterm EscapeSequenceParser 79',
    () => _verify(_Family.esc, _Mode.noFallback),
  );
  test(
    'xterm EscapeSequenceParser 80',
    () => _verify(_Family.esc, _Mode.doubleDispose),
  );
  test(
    'xterm EscapeSequenceParser 81',
    () => _verify(_Family.esc, _Mode.allow),
  );
  test(
    'xterm EscapeSequenceParser 82',
    () => _verify(_Family.esc, _Mode.prevent),
  );
  test(
    'xterm EscapeSequenceParser 83',
    () => _verify(_Family.esc, _Mode.clear),
  );

  test('xterm EscapeSequenceParser 84', () async {
    final parser = TerminalParser();
    addTearDown(parser.dispose);
    final calls = <String>[];
    parser
      ..setExecuteHandler('\n', (code) => calls.add(String.fromCharCode(code)))
      ..setExecuteHandler('\r', (code) => calls.add(String.fromCharCode(code)));
    expect(await parser.filter('a\r\nb'), 'ab');
    expect(calls, <String>['\r', '\n']);
    parser
      ..clearExecuteHandler('\r')
      ..clearExecuteHandler('\r');
    calls.clear();
    expect(await parser.filter('a\r\nb'), 'a\rb');
    expect(calls, <String>['\n']);
  });

  test(
    'xterm EscapeSequenceParser 85',
    () => _verify(_Family.osc, _Mode.allow),
  );
  test(
    'xterm EscapeSequenceParser 86',
    () => _verify(_Family.osc, _Mode.dispose),
  );
  test(
    'xterm EscapeSequenceParser 87',
    () => _verify(_Family.osc, _Mode.order),
  );
  test(
    'xterm EscapeSequenceParser 88',
    () => _verify(_Family.osc, _Mode.fallbackOnce),
  );
  test(
    'xterm EscapeSequenceParser 89',
    () => _verify(_Family.osc, _Mode.noFallback),
  );
  test(
    'xterm EscapeSequenceParser 90',
    () => _verify(_Family.osc, _Mode.prevent),
  );
  test(
    'xterm EscapeSequenceParser 91',
    () => _verify(_Family.osc, _Mode.doubleDispose),
  );
  test(
    'xterm EscapeSequenceParser 92',
    () => _verify(_Family.osc, _Mode.clear),
  );

  test('xterm EscapeSequenceParser 93', () async {
    final parser = TerminalParser();
    addTearDown(parser.dispose);
    final printed = StringBuffer();
    parser.setPrintHandler(printed.write);
    expect(await parser.filter('hello\r\nworld'), '\r\n');
    expect(printed.toString(), 'helloworld');
    parser
      ..clearPrintHandler()
      ..clearPrintHandler();
    printed.clear();
    expect(await parser.filter('hello'), 'hello');
    expect(printed.toString(), isEmpty);
  });
}

enum _Family { apc, csi, dcs, esc, osc }

enum _Mode {
  allow,
  dispose,
  order,
  fallbackOnce,
  noFallback,
  prevent,
  doubleDispose,
  clear,
}

Future<void> _verify(_Family family, _Mode mode) async {
  final parser = TerminalParser();
  addTearDown(parser.dispose);
  final calls = <String>[];
  final first = _register(parser, family, 'A', true, calls);
  Disposable? second;
  switch (mode) {
    case _Mode.allow:
      second = _register(parser, family, 'B', false, calls);
    case _Mode.dispose || _Mode.doubleDispose:
      second = _register(parser, family, 'B', true, calls)..dispose();
      if (mode == _Mode.doubleDispose) second.dispose();
    case _Mode.order:
      _register(parser, family, 'B', false, calls);
      _register(parser, family, 'C', false, calls);
    case _Mode.fallbackOnce:
      _register(parser, family, 'B', true, calls);
      _register(parser, family, 'C', false, calls);
    case _Mode.noFallback:
      _register(parser, family, 'B', true, calls);
      _register(parser, family, 'C', true, calls);
    case _Mode.prevent:
      second = _register(parser, family, 'B', true, calls);
    case _Mode.clear:
      _clear(parser, family);
  }

  await parser.filter(_input(family));
  if (mode == _Mode.clear) {
    expect(calls, isEmpty);
    _register(parser, family, 'A', true, calls);
    await parser.filter(_input(family));
    _clear(parser, family);
    _clear(parser, family);
  }
  expect(calls, switch (mode) {
    _Mode.allow => <String>['B', 'A'],
    _Mode.dispose || _Mode.doubleDispose => <String>['A'],
    _Mode.order => <String>['C', 'B', 'A'],
    _Mode.fallbackOnce => <String>['C', 'B'],
    _Mode.noFallback => <String>['C'],
    _Mode.prevent => <String>['B'],
    _Mode.clear => <String>['A'],
  });
  expect(first.isDisposed, isFalse);
  if (mode == _Mode.dispose || mode == _Mode.doubleDispose) {
    expect(second!.isDisposed, isTrue);
  }
}

Disposable _register(
  TerminalParser parser,
  _Family family,
  String label,
  bool result,
  List<String> calls,
) => switch (family) {
  _Family.apc => parser.registerApcHandler(_identifier, (_) {
    calls.add(label);
    return result;
  }),
  _Family.csi => parser.registerCsiHandler(_identifier, (_) {
    calls.add(label);
    return result;
  }),
  _Family.dcs => parser.registerDcsHandler(_identifier, (_, _) {
    calls.add(label);
    return result;
  }),
  _Family.esc => parser.registerEscHandler(_identifier, () {
    calls.add(label);
    return result;
  }),
  _Family.osc => parser.registerOscHandler(1, (_) {
    calls.add(label);
    return result;
  }),
};

void _clear(TerminalParser parser, _Family family) {
  switch (family) {
    case _Family.apc:
      parser.clearApcHandler(_identifier);
    case _Family.csi:
      parser.clearCsiHandler(_identifier);
    case _Family.dcs:
      parser.clearDcsHandler(_identifier);
    case _Family.esc:
      parser.clearEscHandler(_identifier);
    case _Family.osc:
      parser.clearOscHandler(1);
  }
}

const TerminalFunctionIdentifier _identifier = TerminalFunctionIdentifier(
  intermediates: '+',
  finalByte: 'p',
);

String _input(_Family family) => switch (family) {
  _Family.apc => '\u001b_+pabc\u001b\\',
  _Family.csi => '\u001b[1;+p',
  _Family.dcs => '\u001bP1;+pabc\u001b\\',
  _Family.esc => '\u001b+p',
  _Family.osc => '\u001b]1;abc\u001b\\',
};
