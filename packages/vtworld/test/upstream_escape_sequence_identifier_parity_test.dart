import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  test('xterm EscapeSequenceParser 42', () async {
    final terminal = _terminal();
    final calls = <String>[];
    final disposables = <Disposable>[
      terminal.parser.registerApcHandler(_id(finalByte: 'z'), (data) {
        calls.add('z:$data');
        return true;
      }),
      terminal.parser.registerApcHandler(
        _id(intermediates: '!', finalByte: 'z'),
        (data) {
          calls.add('!z:$data');
          return true;
        },
      ),
      terminal.parser.registerApcHandler(
        _id(intermediates: '!!', finalByte: 'z'),
        (data) {
          calls.add('!!z:$data');
          return true;
        },
      ),
    ];
    await terminal.writeAndWait(
      '\u001b_zAB\u001b\\\u001b_!zAB\u001b\\\u001b_!!zAB\u001b\\',
    );
    for (final disposable in disposables) {
      disposable.dispose();
    }
    await terminal.writeAndWait(
      '\u001b_zAB\u001b\\\u001b_!zAB\u001b\\\u001b_!!zAB\u001b\\',
    );
    expect(calls, <String>['z:AB', '!z:AB', '!!z:AB']);
  });

  test('xterm EscapeSequenceParser 43', () async {
    final terminal = _terminal();
    final calls = <Object>[];
    final ids = <TerminalFunctionIdentifier>[
      _id(finalByte: 'z'),
      _id(intermediates: '!', finalByte: 'z'),
      _id(intermediates: '!!', finalByte: 'z'),
      _id(prefix: '?', finalByte: 'z'),
      _id(prefix: '?', intermediates: '!', finalByte: 'z'),
      _id(prefix: '?', intermediates: '!!', finalByte: 'z'),
    ];
    final labels = <String>['z', '!z', '!!z', '?z', '?!z', '?!!z'];
    final disposables = <Disposable>[
      for (var index = 0; index < ids.length; index++)
        terminal.parser.registerCsiHandler(ids[index], (parameters) {
          calls.add(<Object>[labels[index], parameters]);
          return true;
        }),
    ];
    const input =
        '\u001b[1;z\u001b[1;!z\u001b[1;!!z\u001b[?1;z\u001b[?1;!z\u001b[?1;!!z';
    await terminal.writeAndWait(input);
    for (final disposable in disposables) {
      disposable.dispose();
    }
    await terminal.writeAndWait(input);
    expect(calls, <Object>[
      for (final label in labels)
        <Object>[
          label,
          <TerminalParameter>[1, 0],
        ],
    ]);
  });

  test('xterm EscapeSequenceParser 44', () async {
    final terminal = _terminal();
    final calls = <Object>[];
    final ids = <TerminalFunctionIdentifier>[
      _id(finalByte: 'z'),
      _id(intermediates: '!', finalByte: 'z'),
      _id(intermediates: '!!', finalByte: 'z'),
      _id(prefix: '?', finalByte: 'z'),
      _id(prefix: '?', intermediates: '!', finalByte: 'z'),
      _id(prefix: '?', intermediates: '!!', finalByte: 'z'),
    ];
    final labels = <String>['z', '!z', '!!z', '?z', '?!z', '?!!z'];
    final disposables = <Disposable>[
      for (var index = 0; index < ids.length; index++)
        terminal.parser.registerDcsHandler(ids[index], (data, parameters) {
          calls.add(<Object>[labels[index], parameters, data]);
          return true;
        }),
    ];
    const input =
        '\u001bP1;zAB\u001b\\\u001bP1;!zAB\u001b\\\u001bP1;!!zAB\u001b\\'
        '\u001bP?1;zAB\u001b\\\u001bP?1;!zAB\u001b\\\u001bP?1;!!zAB\u001b\\';
    await terminal.writeAndWait(input);
    for (final disposable in disposables) {
      disposable.dispose();
    }
    await terminal.writeAndWait(input);
    expect(calls, <Object>[
      for (final label in labels)
        <Object>[
          label,
          <TerminalParameter>[1, 0],
          'AB',
        ],
    ]);
  });

  test('xterm EscapeSequenceParser 45', () async {
    final terminal = _terminal();
    final calls = <String>[];
    final disposables = <Disposable>[
      terminal.parser.registerEscHandler(_id(finalByte: 'z'), () {
        calls.add('z');
        return true;
      }),
      terminal.parser.registerEscHandler(
        _id(intermediates: '!', finalByte: 'z'),
        () {
          calls.add('!z');
          return true;
        },
      ),
      terminal.parser.registerEscHandler(
        _id(intermediates: '!!', finalByte: 'z'),
        () {
          calls.add('!!z');
          return true;
        },
      ),
    ];
    const input = '\u001bz\u001b!z\u001b!!z';
    await terminal.writeAndWait(input);
    for (final disposable in disposables) {
      disposable.dispose();
    }
    await terminal.writeAndWait(input);
    expect(calls, <String>['z', '!z', '!!z']);
  });

  test('xterm EscapeSequenceParser 46', () {
    final parser = TerminalParser();
    addTearDown(parser.dispose);
    for (var code = 0x40; code <= 0x7e; code++) {
      parser
          .registerCsiHandler(
            _id(finalByte: String.fromCharCode(code)),
            (_) => true,
          )
          .dispose();
      parser
          .registerDcsHandler(
            _id(finalByte: String.fromCharCode(code)),
            (_, _) => true,
          )
          .dispose();
    }
    for (final value in <String>['\x3f', '\x7f', 'zz']) {
      expect(
        () => parser.registerCsiHandler(_id(finalByte: value), (_) => true),
        throwsArgumentError,
      );
    }
  });

  test('xterm EscapeSequenceParser 47', () {
    final parser = TerminalParser();
    addTearDown(parser.dispose);
    for (var code = 0x30; code <= 0x7e; code++) {
      final id = _id(finalByte: String.fromCharCode(code));
      parser.registerEscHandler(id, () => true).dispose();
      parser.registerApcHandler(id, (_) => true).dispose();
    }
    for (final value in <String>['\x2f', '\x7f']) {
      expect(
        () => parser.registerEscHandler(_id(finalByte: value), () => true),
        throwsArgumentError,
      );
      expect(
        () => parser.registerApcHandler(_id(finalByte: value), (_) => true),
        throwsArgumentError,
      );
    }
  });

  test('xterm EscapeSequenceParser 48', () async {
    final terminal = _terminal();
    final calls = <String>[];
    for (final entry in <(TerminalFunctionIdentifier, String)>[
      (_id(finalByte: 'z'), 'z'),
      (_id(prefix: '?', finalByte: 'z'), '?z'),
      (_id(intermediates: '!', finalByte: 'z'), '!z'),
      (_id(prefix: '?', intermediates: '!', finalByte: 'z'), '?!z'),
      (_id(prefix: '?', intermediates: '!!', finalByte: 'z'), '?!!z'),
    ]) {
      terminal.parser.registerCsiHandler(entry.$1, (_) {
        calls.add(entry.$2);
        return true;
      });
    }
    await terminal.writeAndWait(
      '\u001b[z\u001b[?z\u001b[!z\u001b[?!z\u001b[?!!z',
    );
    expect(calls, <String>['z', '?z', '!z', '?!z', '?!!z']);
  });

  test('xterm EscapeSequenceParser 49', () {
    final parser = TerminalParser();
    addTearDown(parser.dispose);
    for (var code = 0x20; code <= 0x2f; code++) {
      parser
          .registerCsiHandler(
            _id(
              intermediates: String.fromCharCodes(<int>[code, code]),
              finalByte: 'z',
            ),
            (_) => true,
          )
          .dispose();
    }
    for (final value in <String>['\x1f', '\x30', '!!!']) {
      expect(
        () => parser.registerCsiHandler(
          _id(intermediates: value, finalByte: 'z'),
          (_) => true,
        ),
        throwsArgumentError,
      );
    }
  });

  test('xterm EscapeSequenceParser 50', () {
    final parser = TerminalParser();
    addTearDown(parser.dispose);
    for (var code = 0x3c; code <= 0x3f; code++) {
      parser
          .registerCsiHandler(
            _id(prefix: String.fromCharCode(code), finalByte: 'z'),
            (_) => true,
          )
          .dispose();
    }
    for (final value in <String>['\x3b', '\x40', '??']) {
      expect(
        () => parser.registerCsiHandler(
          _id(prefix: value, finalByte: 'z'),
          (_) => true,
        ),
        throwsArgumentError,
      );
    }
  });
}

Terminal _terminal() {
  final terminal = Terminal();
  addTearDown(terminal.dispose);
  return terminal;
}

TerminalFunctionIdentifier _id({
  required String finalByte,
  String prefix = '',
  String intermediates = '',
}) => TerminalFunctionIdentifier(
  prefix: prefix,
  intermediates: intermediates,
  finalByte: finalByte,
);
