import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  test('xterm Parser 00', () async {
    final terminal = _terminal();
    final parameters = <List<TerminalParameter>>[];
    terminal.parser.registerCsiHandler(
      const TerminalFunctionIdentifier(finalByte: 'm'),
      (params) {
        parameters.add(params);
        return false;
      },
    );

    await terminal.writeAndWait(
      '\u001b[38;5;123mparams\u001b[38:2::50:100:150msubparams',
    );

    expect(parameters, <List<TerminalParameter>>[
      <TerminalParameter>[38, 5, 123],
      <TerminalParameter>[
        38,
        <int>[2, -1, 50, 100, 150],
      ],
    ]);
  });

  test('xterm Parser 01', () async {
    final terminal = _terminal();
    final calls = <String>[];
    final parameters = <List<TerminalParameter>>[];
    terminal.parser
      ..registerCsiHandler(_id('+', 'Z'), (params) {
        calls.add('A');
        parameters.add(params);
        return false;
      })
      ..registerCsiHandler(_id('+', 'Z'), (params) async {
        await Future<void>.delayed(Duration.zero);
        calls.add('B');
        parameters.add(params);
        return false;
      })
      ..registerCsiHandler(_id('+', 'Z'), (params) {
        calls.add('C');
        parameters.add(params);
        return false;
      });

    await terminal.writeAndWait('\u001b[1;2+Z');

    expect(calls, <String>['C', 'B', 'A']);
    expect(parameters, <List<TerminalParameter>>[
      <TerminalParameter>[1, 2],
      <TerminalParameter>[1, 2],
      <TerminalParameter>[1, 2],
    ]);
  });

  test('xterm Parser 02', () async {
    final terminal = _terminal();
    final calls = <String>[];
    terminal.parser
      ..registerDcsHandler(_id('+', 'p'), (data, params) {
        calls.add('A:$params:$data');
        return false;
      })
      ..registerDcsHandler(_id('+', 'p'), (data, params) {
        calls.add('B:$params:$data');
        return true;
      })
      ..registerDcsHandler(_id('+', 'p'), (data, params) {
        calls.add('C:$params:$data');
        return false;
      });

    await terminal.writeAndWait('\u001bP1;2+psome data\u001b\\');

    expect(calls, <String>['C:[1, 2]:some data', 'B:[1, 2]:some data']);
  });

  test('xterm Parser 03', () async {
    final terminal = _terminal();
    final calls = <String>[];
    terminal.parser
      ..registerDcsHandler(_id('+', 'q'), (data, params) {
        calls.add('A:$params:$data');
        return false;
      })
      ..registerDcsHandler(_id('+', 'q'), (data, params) async {
        await Future<void>.delayed(Duration.zero);
        calls.add('B:$params:$data');
        return false;
      })
      ..registerDcsHandler(_id('+', 'q'), (data, params) {
        calls.add('C:$params:$data');
        return false;
      });

    await terminal.writeAndWait('\u001bP1;2+qsome data\u001b\\');

    expect(calls, <String>[
      'C:[1, 2]:some data',
      'B:[1, 2]:some data',
      'A:[1, 2]:some data',
    ]);
  });

  test('xterm Parser 04', () async {
    final terminal = _terminal();
    final calls = <String>[];
    terminal.parser
      ..registerEscHandler(_id('(', 'B'), () {
        calls.add('A');
        return false;
      })
      ..registerEscHandler(_id('(', 'B'), () {
        calls.add('B');
        return true;
      })
      ..registerEscHandler(_id('(', 'B'), () {
        calls.add('C');
        return false;
      });

    await terminal.writeAndWait('\u001b(B');

    expect(calls, <String>['C', 'B']);
  });

  test('xterm Parser 05', () async {
    final terminal = _terminal();
    final calls = <String>[];
    terminal.parser
      ..registerEscHandler(_id('(', 'Z'), () {
        calls.add('A');
        return false;
      })
      ..registerEscHandler(_id('(', 'Z'), () async {
        await Future<void>.delayed(Duration.zero);
        calls.add('B');
        return false;
      })
      ..registerEscHandler(_id('(', 'Z'), () {
        calls.add('C');
        return false;
      });

    await terminal.writeAndWait('\u001b(Z');

    expect(calls, <String>['C', 'B', 'A']);
  });

  test('xterm Parser 06', () async {
    final terminal = _terminal();
    final calls = <String>[];
    terminal.parser
      ..registerOscHandler(1234, (data) {
        calls.add('A:$data');
        return false;
      })
      ..registerOscHandler(1234, (data) {
        calls.add('B:$data');
        return true;
      })
      ..registerOscHandler(1234, (data) {
        calls.add('C:$data');
        return false;
      });

    await terminal.writeAndWait('\u001b]1234;some data\u0007');

    expect(calls, <String>['C:some data', 'B:some data']);
  });

  test('xterm Parser 07', () async {
    final terminal = _terminal();
    final calls = <String>[];
    terminal.parser
      ..registerOscHandler(666, (data) {
        calls.add('A:$data');
        return false;
      })
      ..registerOscHandler(666, (data) async {
        await Future<void>.delayed(Duration.zero);
        calls.add('B:$data');
        return false;
      })
      ..registerOscHandler(666, (data) {
        calls.add('C:$data');
        return false;
      });

    await terminal.writeAndWait('\u001b]666;some data\u0007');

    expect(calls, <String>['C:some data', 'B:some data', 'A:some data']);
  });

  test('xterm Parser 08', () async {
    final terminal = _terminal();
    final calls = <String>[];
    terminal.parser.registerApcHandler(_finalId('A'), (data) {
      calls.add('handler:$data');
      return true;
    });

    await terminal.writeAndWait('\u001b_Asome data here\u001b\\');

    expect(calls, <String>['handler:some data here']);
  });

  test('xterm Parser 09', () async {
    final terminal = _terminal();
    final calls = <String>[];
    terminal.parser.registerApcHandler(_finalId('B'), (data) {
      calls.add('handler:$data');
      return true;
    });

    await terminal.writeAndWait('\u001b_Bhi\u001b\\');

    expect(calls, <String>['handler:hi']);
  });

  test('xterm Parser 10', () async {
    final terminal = _terminal();
    final calls = <String>[];
    terminal.parser
      ..registerApcHandler(_finalId('C'), (data) {
        calls.add('A:$data');
        return false;
      })
      ..registerApcHandler(_finalId('C'), (data) {
        calls.add('B:$data');
        return true;
      })
      ..registerApcHandler(_finalId('C'), (data) {
        calls.add('C:$data');
        return false;
      });

    await terminal.writeAndWait('\u001b_Csome data\u001b\\');

    expect(calls, <String>['C:some data', 'B:some data']);
  });

  test('xterm Parser 11', () async {
    final terminal = _terminal();
    final calls = <String>[];
    terminal.parser
      ..registerApcHandler(_finalId('D'), (data) {
        calls.add('A:$data');
        return false;
      })
      ..registerApcHandler(_finalId('D'), (data) async {
        await Future<void>.delayed(Duration.zero);
        calls.add('B:$data');
        return false;
      })
      ..registerApcHandler(_finalId('D'), (data) {
        calls.add('C:$data');
        return false;
      });

    await terminal.writeAndWait('\u001b_Dsome data\u001b\\');

    expect(calls, <String>['C:some data', 'B:some data', 'A:some data']);
  });

  test('xterm Parser 12', () async {
    final terminal = _terminal();
    final calls = <String>[];
    terminal.parser
      ..registerApcHandler(_finalId('F'), (data) {
        calls.add('F:$data');
        return true;
      })
      ..registerApcHandler(_finalId('X'), (data) {
        calls.add('X:$data');
        return true;
      });

    await terminal.writeAndWait('\u001b_Ffirst data\u001b\\');
    await terminal.writeAndWait('\u001b_Xsecond data\u001b\\');

    expect(calls, <String>['F:first data', 'X:second data']);
  });
}

Terminal _terminal() {
  final terminal = Terminal();
  addTearDown(terminal.dispose);
  return terminal;
}

TerminalFunctionIdentifier _id(String intermediates, String finalByte) =>
    TerminalFunctionIdentifier(
      intermediates: intermediates,
      finalByte: finalByte,
    );

TerminalFunctionIdentifier _finalId(String finalByte) =>
    TerminalFunctionIdentifier(finalByte: finalByte);
