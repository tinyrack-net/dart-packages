import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  test('xterm EscapeSequenceParser 21', () async {
    final parser = _parser();
    final osc = <String>[];
    parser.registerOscHandler(123, (data) {
      osc.add(data);
      return true;
    });
    expect(await parser.filter('abc\u009d123;tzf\u001b\\defg'), 'abcdefg');
    expect(osc, <String>['tzf']);
  });

  test('xterm EscapeSequenceParser 22', () async {
    final parser = _parser();
    final calls = <String>[];
    parser.registerApcHandler(_id('X'), (data) {
      calls.add(data);
      return true;
    });
    expect(await parser.filter('abc\u009fXbc;de\u0018'), 'abc');
    expect(calls, isEmpty);
  });

  test('xterm EscapeSequenceParser 23', () async {
    final parser = _parser();
    final calls = <String>[];
    parser.registerDcsHandler(_id('a', intermediates: r'+$'), (data, _) {
      calls.add(data);
      return true;
    });
    expect(await parser.filter('abc\u00901;2::55;3+\$abc;de\u0018'), 'abc');
    expect(calls, isEmpty);
  });

  test('xterm EscapeSequenceParser 24', () async {
    final parser = _parser();
    final calls = <String>[];
    parser.registerOscHandler(0, (data) {
      calls.add(data);
      return true;
    });
    expect(await parser.filter('\u001b]0;abc123€öäü\u0018'), isEmpty);
    expect(calls, isEmpty);
  });

  test('xterm EscapeSequenceParser 25', () async {
    final parser = _parser();
    final calls = <Object>[];
    parser.registerCsiHandler(_id('m', prefix: '<'), (parameters) {
      calls.add(parameters);
      return true;
    });
    expect(
      await parser.filter('\u001b[<31;5mHello World! öäü€\nabc'),
      'Hello World! öäü€\nabc',
    );
    expect(calls, <Object>[
      <TerminalParameter>[31, 5],
    ]);
  });

  test('xterm EscapeSequenceParser 26', () async {
    final parser = _parser();
    final calls = <String>[];
    parser.registerOscHandler(0, (data) {
      calls.add(data);
      return true;
    });
    expect(await parser.filter('\u001b]0;abc123€öäü\u0007'), isEmpty);
    expect(calls, <String>['abc123€öäü']);
  });

  test('xterm EscapeSequenceParser 27', () async {
    final parser = _parser();
    final calls = <String>[];
    parser.registerApcHandler(_id('X'), (data) {
      calls.add(data);
      return true;
    });
    expect(await parser.filter('abc\u009fXbc;de\u001a'), 'abc');
    expect(calls, isEmpty);
  });

  test('xterm EscapeSequenceParser 28', () async {
    final parser = _parser();
    final calls = <String>[];
    parser.registerDcsHandler(_id('a', intermediates: r'+$'), (data, _) {
      calls.add(data);
      return true;
    });
    expect(await parser.filter('abc\u00901;2::55;3+\$abc;de\u001a'), 'abc');
    expect(calls, isEmpty);
  });

  test('xterm EscapeSequenceParser 29', () async {
    final parser = _parser();
    final calls = <String>[];
    parser.registerOscHandler(0, (data) {
      calls.add(data);
      return true;
    });
    expect(await parser.filter('\u001b]0;abc123€öäü\u001a'), isEmpty);
    expect(calls, isEmpty);
  });

  test('xterm EscapeSequenceParser 30', () async {
    final parser = _parser();
    final calls = <Object>[];
    parser.registerCsiHandler(_id('m', prefix: '<'), (parameters) {
      calls.add(parameters);
      return true;
    });
    expect(
      await parser.filter('\u001b[<31;5::123:;8mHello World!'),
      'Hello World!',
    );
    expect(calls, <Object>[
      <TerminalParameter>[
        31,
        5,
        <int>[-1, 123, -1],
        8,
      ],
    ]);
  });

  test('xterm EscapeSequenceParser 31', () async {
    final parser = _parser();
    final calls = <Object>[];
    parser.registerDcsHandler(_id('a', intermediates: r'+$'), (
      data,
      parameters,
    ) {
      calls.add(<Object>[parameters, data]);
      return true;
    });
    expect(await parser.filter('abc\u00901;2::55;3+\$abc;de\u009c'), 'abc');
    expect(calls, <Object>[
      <Object>[
        <TerminalParameter>[
          1,
          2,
          <int>[-1, 55],
          3,
        ],
        'bc;de',
      ],
    ]);
  });

  test('xterm EscapeSequenceParser 32', () async {
    final parser = _parser();
    final calls = <Object>[];
    parser.registerCsiHandler(_id('c', prefix: '<'), (parameters) {
      calls.add(parameters);
      return true;
    });
    expect(await parser.filter('\u001b[1€abcdefg\u009b<;c'), 'abcdefg');
    expect(calls, <Object>[
      <TerminalParameter>[0, 0],
    ]);
  });

  test('xterm EscapeSequenceParser 33', () async {
    final parser = _parser();
    final calls = <String>[];
    parser.registerApcHandler(_id('X'), (data) {
      calls.add(data);
      return true;
    });
    expect(await parser.filter('\u001b_Xabc;de'), isEmpty);
    expect(calls, isEmpty);
    expect(await parser.filter('abc\u009c'), isEmpty);
    expect(calls, <String>['abc;deabc']);
  });

  test('xterm EscapeSequenceParser 34', () async {
    final parser = _parser();
    final calls = <String>[];
    parser.registerDcsHandler(_id('a', intermediates: r'+$'), (data, _) {
      calls.add(data);
      return true;
    });
    expect(await parser.filter('\u001bP1;2;3+\$abc;de'), isEmpty);
    expect(calls, isEmpty);
    expect(await parser.filter('abc\u009c'), isEmpty);
    expect(calls, <String>['bc;deabc']);
  });

  test('xterm EscapeSequenceParser 35', () async {
    final parser = _parser();
    final calls = <String>[];
    parser.registerApcHandler(_id('A'), (data) {
      calls.add(data);
      return true;
    });
    expect(await parser.filter('abc\u001b_Abc;de\u001b\\xyz'), 'abcxyz');
    expect(calls, <String>['bc;de']);
  });

  test('xterm EscapeSequenceParser 36', () async {
    final parser = _parser();
    final calls = <Object>[];
    parser.registerDcsHandler(_id('a', intermediates: r'+$'), (
      data,
      parameters,
    ) {
      calls.add(<Object>[parameters, data]);
      return true;
    });
    expect(await parser.filter('abc\u00901;2;3+\$abc;de\u009c'), 'abc');
    expect(calls, <Object>[
      <Object>[
        <TerminalParameter>[1, 2, 3],
        'bc;de',
      ],
    ]);
  });

  test('xterm EscapeSequenceParser 37', () async {
    final parser = _parser();
    final calls = <String>[];
    parser.registerApcHandler(_id('A'), (data) {
      calls.add(data);
      return true;
    });
    expect(await parser.filter('abc\u009fAbc;de\u009cxyz'), 'abcxyz');
    expect(calls, <String>['bc;de']);
  });

  test('xterm EscapeSequenceParser 38', () async {
    final parser = _parser();
    final calls = <String>[];
    parser.registerOscHandler(123, (data) {
      calls.add(data);
      return true;
    });
    expect(await parser.filter('abc\u009d123;tzf\u009cdefg'), 'abcdefg');
    expect(calls, <String>['tzf']);
  });

  test('xterm EscapeSequenceParser 39', () async {
    final parser = _parser();
    expect(await parser.filter('abc\u0098123tzf\u009cdefg'), 'abcdefg');
  });

  test('xterm EscapeSequenceParser 40', () async {
    final parser = _parser();
    final calls = <String>[];
    parser.registerApcHandler(_id('X'), (data) {
      calls.add(data);
      return true;
    });
    expect(await parser.filter('\u001b_X3+\$aäbc;däe\u009c'), isEmpty);
    expect(calls, <String>[r'3+$aäbc;däe']);
  });

  test('xterm EscapeSequenceParser 41', () async {
    final parser = _parser();
    final calls = <Object>[];
    parser.registerDcsHandler(_id('a', intermediates: r'+$'), (
      data,
      parameters,
    ) {
      calls.add(<Object>[parameters, data]);
      return true;
    });
    expect(await parser.filter('\u001bP1;2;3+\$aäbc;däe\u009c'), isEmpty);
    expect(calls, <Object>[
      <Object>[
        <TerminalParameter>[1, 2, 3],
        'äbc;däe',
      ],
    ]);
  });
}

TerminalParser _parser() {
  final parser = TerminalParser();
  addTearDown(parser.dispose);
  return parser;
}

TerminalFunctionIdentifier _id(
  String finalByte, {
  String prefix = '',
  String intermediates = '',
}) => TerminalFunctionIdentifier(
  prefix: prefix,
  intermediates: intermediates,
  finalByte: finalByte,
);
