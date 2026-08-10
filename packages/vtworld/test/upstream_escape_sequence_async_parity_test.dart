import 'dart:async';

import 'package:test/test.dart';
import 'package:vtworld/src/core/parser_constants.dart';
import 'package:vtworld/src/core/parser_transition_table.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  test('xterm EscapeSequenceParser 00', () async {
    final parser = _parser();
    final gate = Completer<void>();
    final calls = <Object>[];
    parser.registerCsiHandler(_id('m'), (parameters) async {
      calls.add(parameters);
      await gate.future;
      return true;
    });
    final result = parser.filter('\u001b[1;31mFIN');
    await Future<void>.delayed(Duration.zero);
    expect(calls, <Object>[
      <TerminalParameter>[1, 31],
    ]);
    gate.complete();
    expect(await result, 'FIN');
  });

  test('xterm EscapeSequenceParser 01', () async {
    final parser = _parser();
    final calls = <Object>[];
    parser.registerCsiHandler(_id('m'), (parameters) async {
      calls.add(parameters);
      return true;
    });
    final output = StringBuffer();
    for (final chunk in '\u001b[1;31mFIN'.split('')) {
      output.write(await parser.filter(chunk));
    }
    expect(calls, <Object>[
      <TerminalParameter>[1, 31],
    ]);
    expect(output.toString(), 'FIN');
  });

  test('xterm EscapeSequenceParser 02', () async {
    final parser = _parser();
    final gate = Completer<void>();
    parser.registerCsiHandler(_id('m'), (_) async {
      await gate.future;
      return true;
    });
    final first = parser.filter('\u001b[1mX');
    await Future<void>.delayed(Duration.zero);
    await expectLater(
      parser.filter('second'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('improper continuation'),
        ),
      ),
    );
    gate.complete();
    expect(await first, 'X');
    parser.reset();
    expect(await parser.filter('recovered'), 'recovered');
  });

  test('xterm EscapeSequenceParser 03', () async {
    final parser = _parser();
    final calls = <String>[];
    parser
      ..registerApcHandler(_id('X'), (data) async {
        calls.add('A:$data');
        return true;
      })
      ..registerApcHandler(_id('X'), (data) async {
        calls.add('B:$data');
        return false;
      });
    expect(await parser.filter('\u001b_Xabc\u001b\\'), isEmpty);
    expect(calls, <String>['B:abc', 'A:abc']);
  });

  test('xterm EscapeSequenceParser 04', () async {
    final parser = _parser();
    final calls = <String>[];
    parser
      ..registerDcsHandler(_id('a'), (data, _) async {
        calls.add('A:$data');
        return true;
      })
      ..registerDcsHandler(_id('a'), (data, _) async {
        calls.add('B:$data');
        return false;
      });
    expect(await parser.filter('\u001bP1;2axyz\u001b\\'), isEmpty);
    expect(calls, <String>['B:xyz', 'A:xyz']);
  });

  test('xterm EscapeSequenceParser 05', () async {
    final parser = _parser();
    final calls = <String>[];
    parser
      ..registerEscHandler(_id('E'), () async {
        calls.add('A');
        return true;
      })
      ..registerEscHandler(_id('E'), () async {
        calls.add('B');
        return false;
      });
    expect(await parser.filter('\u001bE'), isEmpty);
    expect(calls, <String>['B', 'A']);
  });

  test('xterm EscapeSequenceParser 06', () async {
    final parser = _parser();
    final calls = <String>[];
    parser
      ..registerOscHandler(1, (data) async {
        calls.add('A:$data');
        return true;
      })
      ..registerOscHandler(1, (data) async {
        calls.add('B:$data');
        return false;
      });
    expect(await parser.filter('\u001b]1;abc\u001b\\'), isEmpty);
    expect(calls, <String>['B:abc', 'A:abc']);
  });

  test('xterm EscapeSequenceParser 07', () async {
    final parser = _parser();
    final calls = <String>[];
    parser
      ..registerCsiHandler(_id('m'), (parameters) async {
        calls.add('A:$parameters');
        return true;
      })
      ..registerCsiHandler(_id('m'), (parameters) async {
        calls.add('B:$parameters');
        return false;
      });
    expect(await parser.filter('\u001b[1m'), isEmpty);
    expect(calls, <String>['B:[1]', 'A:[1]']);
  });

  test('xterm EscapeSequenceParser 08', () async {
    final parser = _parser();
    final gate = Completer<void>();
    final calls = <String>[];
    parser.registerCsiHandler(_id('m'), (_) async {
      calls.add('SGR');
      await gate.future;
      return true;
    });
    final result = parser.filter('\u001b[1mXY');
    await Future<void>.delayed(Duration.zero);
    parser.reset();
    expect(parser.currentState, parser.initialState);
    gate.complete();
    expect(await result, 'XY');
    expect(calls, <String>['SGR']);
  });

  test('xterm EscapeSequenceParser 09', () async {
    final parser = _parser();
    final gate = Completer<void>();
    var completed = false;
    parser.registerCsiHandler(_id('m'), (_) async {
      await gate.future;
      return true;
    });
    final result = parser.filter('\u001b[1mX');
    unawaited(result.then((_) => completed = true));
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);
    gate.complete();
    await result;
    expect(completed, isTrue);
  });

  test('xterm EscapeSequenceParser 10', () async {
    final parser = _parser();
    final calls = <String>[];
    parser
      ..registerCsiHandler(_id('m'), (_) {
        calls.add('base');
        return true;
      })
      ..registerCsiHandler(_id('m'), (_) {
        calls.add('sync');
        return false;
      })
      ..registerCsiHandler(_id('m'), (_) async {
        calls.add('async');
        return false;
      });
    expect(await parser.filter('\u001b[1m'), isEmpty);
    expect(calls, <String>['async', 'sync', 'base']);
  });

  test('xterm EscapeSequenceParser 11', () async {
    final parser = _parser();
    final calls = <String>[];
    parser
      ..setPrintHandler((data) => calls.add('PRINT:$data'))
      ..registerCsiHandler(_id('m'), (parameters) {
        calls.add('SGR:$parameters');
        return true;
      });
    expect(await parser.filter('\u001b[1mhello'), isEmpty);
    expect(calls, <String>['SGR:[1]', 'PRINT:hello']);
  });

  test('xterm EscapeSequenceParser 12', () async {
    final parser = _parser();
    final calls = <String>[];
    parser.registerCsiHandler(_id('m'), (parameters) {
      calls.add('SGR:$parameters');
      return true;
    });
    final future = parser.filter('\u001b[1m');
    expect(future, isA<Future<String>>());
    expect(await future, isEmpty);
    expect(calls, <String>['SGR:[1]']);
  });

  test('xterm EscapeSequenceParser 13', () async {
    final parser = _parser();
    final calls = <String>[];
    parser
      ..registerCsiHandler(_id('m'), (_) {
        calls.add('CSI');
        return true;
      })
      ..registerEscHandler(_id('E'), () {
        calls.add('ESC');
        return true;
      });
    expect(await parser.filter('\u001b[1m\u001bE'), isEmpty);
    expect(calls, <String>['CSI', 'ESC']);
  });

  test('xterm EscapeSequenceParser 14', () {
    final custom = ParserTransitionTable(10);
    expect(custom.table, hasLength(10));
    expect(vt500TransitionTable.table, hasLength(4257));
  });

  test('xterm EscapeSequenceParser 15', () {
    final parser = _parser();
    expect((parser.initialState, parser.currentState), (0, 0));
    expect(parser.isDisposed, isFalse);
  });

  test('xterm EscapeSequenceParser 16', () async {
    final parser = _parser();
    expect(await parser.filter('\u001b['), isEmpty);
    expect(parser.currentState, ParserState.csiEntry.index);
    parser.reset();
    expect(parser.currentState, ParserState.ground.index);
    expect(await parser.filter('text'), 'text');
  });

  test('xterm EscapeSequenceParser 17', () {
    _expectTransition(
      ParserState.csiIgnore,
      0xa0,
      ParserAction.ignore,
      ParserState.csiIgnore,
    );
  });

  test('xterm EscapeSequenceParser 18', () {
    _expectTransition(
      ParserState.dcsIgnore,
      0xa0,
      ParserAction.ignore,
      ParserState.dcsIgnore,
    );
  });

  test('xterm EscapeSequenceParser 19', () {
    _expectTransition(
      ParserState.dcsPassthrough,
      0xa0,
      ParserAction.dcsPut,
      ParserState.dcsPassthrough,
    );
  });

  test('xterm EscapeSequenceParser 20', () {
    _expectTransition(
      ParserState.ground,
      0x9c,
      ParserAction.ignore,
      ParserState.ground,
    );
  });
}

TerminalParser _parser() {
  final parser = TerminalParser();
  addTearDown(parser.dispose);
  return parser;
}

TerminalFunctionIdentifier _id(String finalByte) =>
    TerminalFunctionIdentifier(finalByte: finalByte);

void _expectTransition(
  ParserState state,
  int code,
  ParserAction action,
  ParserState nextState,
) {
  final transition = vt500TransitionTable.transition(state, code);
  expect(
    (
      ParserTransitionTable.actionOf(transition),
      ParserTransitionTable.stateOf(transition),
    ),
    (action, nextState),
  );
}
