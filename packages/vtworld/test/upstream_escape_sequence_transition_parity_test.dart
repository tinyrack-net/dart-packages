import 'package:test/test.dart';
import 'package:vtworld/src/core/parser_constants.dart';
import 'package:vtworld/src/core/parser_transition_table.dart';

void main() {
  test('xterm EscapeSequenceParser 94', () {
    _expect(
      ParserState.apcEntry,
      _range(0x20, 0x30),
      ParserAction.collect,
      ParserState.apcIntermediate,
    );
    _expect(
      ParserState.apcEntry,
      _range(0x30, 0x7f),
      ParserAction.apcStart,
      ParserState.apcPassthrough,
    );
  });
  test('xterm EscapeSequenceParser 95', () {
    _expect(
      ParserState.apcEntry,
      _executables,
      ParserAction.ignore,
      ParserState.apcEntry,
    );
    _expect(
      ParserState.apcEntry,
      <int>[0x7f],
      ParserAction.ignore,
      ParserState.apcEntry,
    );
  });
  test('xterm EscapeSequenceParser 96', () {
    _expect(
      ParserState.apcIntermediate,
      _executables,
      ParserAction.ignore,
      ParserState.apcIntermediate,
    );
    _expect(
      ParserState.apcIntermediate,
      <int>[0x7f],
      ParserAction.ignore,
      ParserState.apcIntermediate,
    );
  });
  test('xterm EscapeSequenceParser 97', () {
    _expect(
      ParserState.apcPassthrough,
      <int>[
        ..._range(0x00, 0x08),
        ..._range(0x0e, 0x18),
        0x19,
        ..._range(0x1c, 0x20),
      ],
      ParserAction.ignore,
      ParserState.apcPassthrough,
    );
    _expect(
      ParserState.apcPassthrough,
      <int>[0x7f],
      ParserAction.ignore,
      ParserState.apcPassthrough,
    );
  });
  test('xterm EscapeSequenceParser 98', () {
    _expect(
      ParserState.apcPassthrough,
      <int>[..._range(0x08, 0x0e), ..._range(0x20, 0x7f), 0xa0],
      ParserAction.apcPut,
      ParserState.apcPassthrough,
    );
  });
  test('xterm EscapeSequenceParser 99', () {
    _expect(
      ParserState.csiEntry,
      _executables,
      ParserAction.execute,
      ParserState.csiEntry,
    );
  });
  test('xterm EscapeSequenceParser 100', () {
    _expect(
      ParserState.csiEntry,
      <int>[0x7f],
      ParserAction.ignore,
      ParserState.csiEntry,
    );
  });
  test('xterm EscapeSequenceParser 101', () {
    _expect(
      ParserState.csiIgnore,
      _executables,
      ParserAction.execute,
      ParserState.csiIgnore,
    );
  });
  test('xterm EscapeSequenceParser 102', () {
    _expect(
      ParserState.csiIgnore,
      <int>[..._range(0x20, 0x40), 0x7f, 0xa0],
      ParserAction.ignore,
      ParserState.csiIgnore,
    );
  });
  test('xterm EscapeSequenceParser 103', () {
    _expect(
      ParserState.csiIntermediate,
      _range(0x20, 0x30),
      ParserAction.collect,
      ParserState.csiIntermediate,
    );
  });
  test('xterm EscapeSequenceParser 104', () {
    _expect(
      ParserState.csiIntermediate,
      _executables,
      ParserAction.execute,
      ParserState.csiIntermediate,
    );
  });
  test('xterm EscapeSequenceParser 105', () {
    _expect(
      ParserState.csiIntermediate,
      <int>[0x7f],
      ParserAction.ignore,
      ParserState.csiIntermediate,
    );
  });
  test('xterm EscapeSequenceParser 106', () {
    _expect(
      ParserState.csiParam,
      _executables,
      ParserAction.execute,
      ParserState.csiParam,
    );
  });
  test('xterm EscapeSequenceParser 107', () {
    _expect(
      ParserState.csiParam,
      <int>[0x7f],
      ParserAction.ignore,
      ParserState.csiParam,
    );
  });
  test('xterm EscapeSequenceParser 108', () {
    _expect(
      ParserState.csiParam,
      _range(0x30, 0x3c),
      ParserAction.param,
      ParserState.csiParam,
    );
  });
  test('xterm EscapeSequenceParser 109', () {
    _expect(
      ParserState.dcsEntry,
      _range(0x40, 0x7f),
      ParserAction.dcsHook,
      ParserState.dcsPassthrough,
    );
  });
  test('xterm EscapeSequenceParser 110', () {
    _expect(
      ParserState.dcsEntry,
      _range(0x30, 0x3c),
      ParserAction.param,
      ParserState.dcsParam,
    );
    _expect(
      ParserState.dcsEntry,
      <int>[0x3c, 0x3d, 0x3e, 0x3f],
      ParserAction.collect,
      ParserState.dcsParam,
    );
  });
  test('xterm EscapeSequenceParser 111', () {
    _expect(
      ParserState.dcsEntry,
      <int>[..._executables, 0x7f],
      ParserAction.ignore,
      ParserState.dcsEntry,
    );
  });
  test('xterm EscapeSequenceParser 112', () {
    _expect(
      ParserState.dcsIgnore,
      <int>[..._range(0x00, 0x18), 0x19, ..._range(0x1c, 0x80), 0xa0],
      ParserAction.ignore,
      ParserState.dcsIgnore,
    );
  });
  test('xterm EscapeSequenceParser 113', () {
    _expect(
      ParserState.dcsIntermediate,
      _range(0x20, 0x30),
      ParserAction.collect,
      ParserState.dcsIntermediate,
    );
  });
  test('xterm EscapeSequenceParser 114', () {
    _expect(
      ParserState.dcsIntermediate,
      <int>[..._executables, 0x7f],
      ParserAction.ignore,
      ParserState.dcsIntermediate,
    );
  });
  test('xterm EscapeSequenceParser 115', () {
    _expect(
      ParserState.dcsParam,
      <int>[..._executables, 0x7f],
      ParserAction.ignore,
      ParserState.dcsParam,
    );
  });
  test('xterm EscapeSequenceParser 116', () {
    _expect(
      ParserState.dcsParam,
      _range(0x30, 0x3c),
      ParserAction.param,
      ParserState.dcsParam,
    );
  });
  test('xterm EscapeSequenceParser 117', () {
    _expect(
      ParserState.dcsPassthrough,
      <int>[0x7f],
      ParserAction.ignore,
      ParserState.dcsPassthrough,
    );
  });
  test('xterm EscapeSequenceParser 118', () {
    _expect(
      ParserState.dcsPassthrough,
      <int>[..._executables, ..._range(0x20, 0x7f), 0xa0],
      ParserAction.dcsPut,
      ParserState.dcsPassthrough,
    );
  });
  test('xterm EscapeSequenceParser 119', () {
    _expect(
      ParserState.escape,
      _executables,
      ParserAction.execute,
      ParserState.escape,
    );
  });
  test('xterm EscapeSequenceParser 120', () {
    _expect(
      ParserState.escape,
      <int>[0x7f],
      ParserAction.ignore,
      ParserState.escape,
    );
  });
  test('xterm EscapeSequenceParser 121', () {
    _expect(
      ParserState.escapeIntermediate,
      _range(0x20, 0x30),
      ParserAction.collect,
      ParserState.escapeIntermediate,
    );
  });
  test('xterm EscapeSequenceParser 122', () {
    _expect(
      ParserState.escapeIntermediate,
      _executables,
      ParserAction.execute,
      ParserState.escapeIntermediate,
    );
  });
  test('xterm EscapeSequenceParser 123', () {
    _expect(
      ParserState.escapeIntermediate,
      <int>[0x7f],
      ParserAction.ignore,
      ParserState.escapeIntermediate,
    );
  });
  test('xterm EscapeSequenceParser 124', () {
    _expect(
      ParserState.ground,
      _executables,
      ParserAction.execute,
      ParserState.ground,
    );
  });
  test('xterm EscapeSequenceParser 125', () {
    _expect(
      ParserState.ground,
      <int>[..._range(0x20, 0x7f), 0xa0],
      ParserAction.print,
      ParserState.ground,
    );
  });
  test('xterm EscapeSequenceParser 126', () {
    _expect(
      ParserState.oscString,
      <int>[
        ..._range(0x00, 0x07),
        ..._range(0x08, 0x18),
        0x19,
        ..._range(0x1c, 0x20),
      ],
      ParserAction.ignore,
      ParserState.oscString,
    );
  });
  test('xterm EscapeSequenceParser 127', () {
    _expect(
      ParserState.oscString,
      <int>[..._range(0x20, 0x80), 0xa0],
      ParserAction.oscPut,
      ParserState.oscString,
    );
  });
  test('xterm EscapeSequenceParser 128', () {
    _expect(
      ParserState.sosPmString,
      <int>[..._executables, ..._range(0x20, 0x80)],
      ParserAction.ignore,
      ParserState.sosPmString,
    );
  });
  test('xterm EscapeSequenceParser 129', () {
    _expectAll(
      <int>[0x1b],
      ParserAction.clear,
      ParserState.escape,
      except: const <ParserState>{
        ParserState.oscString,
        ParserState.dcsPassthrough,
        ParserState.apcPassthrough,
      },
    );
    // The three streaming states finalize first. EscapeSequenceParser then
    // promotes their GROUND transition to ESCAPE for the same input byte.
    _expect(
      ParserState.oscString,
      const <int>[0x1b],
      ParserAction.oscEnd,
      ParserState.ground,
    );
    _expect(
      ParserState.dcsPassthrough,
      const <int>[0x1b],
      ParserAction.dcsUnhook,
      ParserState.ground,
    );
    _expect(
      ParserState.apcPassthrough,
      const <int>[0x1b],
      ParserAction.apcEnd,
      ParserState.ground,
    );
  });
  test('xterm EscapeSequenceParser 130', () {
    _expectAll(
      <int>[
        0x18,
        0x1a,
        ..._range(0x80, 0x90),
        ..._range(0x91, 0x98),
        0x99,
        0x9a,
      ],
      ParserAction.execute,
      ParserState.ground,
      except: <ParserState>{
        ParserState.oscString,
        ParserState.dcsPassthrough,
        ParserState.apcPassthrough,
      },
    );
    _expectAll(
      <int>[0x9c],
      ParserAction.ignore,
      ParserState.ground,
      except: <ParserState>{
        ParserState.oscString,
        ParserState.dcsPassthrough,
        ParserState.apcPassthrough,
      },
    );
  });
  test('xterm EscapeSequenceParser 131', () {
    _expect(
      ParserState.escape,
      <int>[0x5b],
      ParserAction.clear,
      ParserState.csiEntry,
    );
    _expectAll(<int>[0x9b], ParserAction.clear, ParserState.csiEntry);
  });
  test('xterm EscapeSequenceParser 132', () {
    _expect(
      ParserState.escape,
      <int>[0x5d],
      ParserAction.oscStart,
      ParserState.oscString,
    );
    _expectAll(<int>[0x9d], ParserAction.oscStart, ParserState.oscString);
  });
  test('xterm EscapeSequenceParser 133', () {
    _expect(
      ParserState.escape,
      <int>[0x58, 0x5e],
      ParserAction.ignore,
      ParserState.sosPmString,
    );
    _expectAll(<int>[0x98, 0x9e], ParserAction.ignore, ParserState.sosPmString);
  });
  test('xterm EscapeSequenceParser 134', () {
    _expect(
      ParserState.apcEntry,
      _range(0x20, 0x30),
      ParserAction.collect,
      ParserState.apcIntermediate,
    );
  });
  test('xterm EscapeSequenceParser 135', () {
    _expect(
      ParserState.apcEntry,
      _range(0x30, 0x7f),
      ParserAction.apcStart,
      ParserState.apcPassthrough,
    );
  });
  test('xterm EscapeSequenceParser 136', () {
    _expect(
      ParserState.apcIntermediate,
      _range(0x30, 0x7f),
      ParserAction.apcStart,
      ParserState.apcPassthrough,
    );
  });
  test('xterm EscapeSequenceParser 137', () {
    _expect(
      ParserState.apcPassthrough,
      <int>[0x1b, 0x9c, 0x18, 0x1a],
      ParserAction.apcEnd,
      ParserState.ground,
    );
  });
  test('xterm EscapeSequenceParser 138', () {
    _expect(
      ParserState.csiEntry,
      _range(0x20, 0x30),
      ParserAction.collect,
      ParserState.csiIntermediate,
    );
  });
  test('xterm EscapeSequenceParser 139', () {
    _expect(
      ParserState.csiEntry,
      <int>[0x3a],
      ParserAction.param,
      ParserState.csiParam,
    );
  });
  test('xterm EscapeSequenceParser 140', () {
    _expect(
      ParserState.csiEntry,
      _range(0x30, 0x3c),
      ParserAction.param,
      ParserState.csiParam,
    );
    _expect(
      ParserState.csiEntry,
      <int>[0x3c, 0x3d, 0x3e, 0x3f],
      ParserAction.collect,
      ParserState.csiParam,
    );
  });
  test('xterm EscapeSequenceParser 141', () {
    _expect(
      ParserState.csiEntry,
      _range(0x40, 0x7f),
      ParserAction.csiDispatch,
      ParserState.ground,
    );
  });
  test('xterm EscapeSequenceParser 142', () {
    _expect(
      ParserState.csiIgnore,
      _range(0x40, 0x7f),
      ParserAction.ignore,
      ParserState.ground,
    );
  });
  test('xterm EscapeSequenceParser 143', () {
    _expect(
      ParserState.csiIntermediate,
      _range(0x30, 0x40),
      ParserAction.ignore,
      ParserState.csiIgnore,
    );
  });
  test('xterm EscapeSequenceParser 144', () {
    _expect(
      ParserState.csiIntermediate,
      _range(0x40, 0x7f),
      ParserAction.csiDispatch,
      ParserState.ground,
    );
  });
  test('xterm EscapeSequenceParser 145', () {
    _expect(
      ParserState.csiParam,
      <int>[0x3c, 0x3d, 0x3e, 0x3f],
      ParserAction.ignore,
      ParserState.csiIgnore,
    );
  });
  test('xterm EscapeSequenceParser 146', () {
    _expect(
      ParserState.csiParam,
      <int>[0x3c, 0x3d, 0x3e, 0x3f],
      ParserAction.ignore,
      ParserState.csiIgnore,
    );
  });
  test('xterm EscapeSequenceParser 147', () {
    _expect(
      ParserState.csiParam,
      _range(0x20, 0x30),
      ParserAction.collect,
      ParserState.csiIntermediate,
    );
  });
  test('xterm EscapeSequenceParser 148', () {
    _expect(
      ParserState.csiParam,
      _range(0x40, 0x7f),
      ParserAction.csiDispatch,
      ParserState.ground,
    );
  });
  test('xterm EscapeSequenceParser 149', () {
    _expect(
      ParserState.dcsEntry,
      _range(0x20, 0x30),
      ParserAction.collect,
      ParserState.dcsIntermediate,
    );
  });
  test('xterm EscapeSequenceParser 150', () {
    _expect(
      ParserState.dcsEntry,
      <int>[0x3a],
      ParserAction.param,
      ParserState.dcsParam,
    );
  });
  test('xterm EscapeSequenceParser 151', () {
    _expect(
      ParserState.dcsEntry,
      _range(0x40, 0x7f),
      ParserAction.dcsHook,
      ParserState.dcsPassthrough,
    );
  });
  test('xterm EscapeSequenceParser 152', () {
    _expect(
      ParserState.dcsIntermediate,
      _range(0x30, 0x40),
      ParserAction.ignore,
      ParserState.dcsIgnore,
    );
  });
  test('xterm EscapeSequenceParser 153', () {
    _expect(
      ParserState.dcsIntermediate,
      _range(0x30, 0x40),
      ParserAction.ignore,
      ParserState.dcsIgnore,
    );
  });
  test('xterm EscapeSequenceParser 154', () {
    _expect(
      ParserState.dcsIntermediate,
      _range(0x40, 0x7f),
      ParserAction.dcsHook,
      ParserState.dcsPassthrough,
    );
  });
  test('xterm EscapeSequenceParser 155', () {
    _expect(
      ParserState.dcsParam,
      <int>[0x3c, 0x3d, 0x3e, 0x3f],
      ParserAction.ignore,
      ParserState.dcsIgnore,
    );
  });
  test('xterm EscapeSequenceParser 156', () {
    _expect(
      ParserState.dcsParam,
      _range(0x20, 0x30),
      ParserAction.collect,
      ParserState.dcsIntermediate,
    );
  });
  test('xterm EscapeSequenceParser 157', () {
    _expect(
      ParserState.dcsParam,
      _range(0x40, 0x7f),
      ParserAction.dcsHook,
      ParserState.dcsPassthrough,
    );
  });
  test('xterm EscapeSequenceParser 158', () {
    _expect(
      ParserState.escape,
      _range(0x20, 0x30),
      ParserAction.collect,
      ParserState.escapeIntermediate,
    );
  });
  test('xterm EscapeSequenceParser 159', () {
    _expect(
      ParserState.escape,
      <int>[
        ..._range(0x30, 0x50),
        ..._range(0x51, 0x58),
        0x59,
        0x5a,
        0x5c,
        ..._range(0x60, 0x7f),
      ],
      ParserAction.escDispatch,
      ParserState.ground,
    );
  });
  test('xterm EscapeSequenceParser 160', () {
    _expect(
      ParserState.escapeIntermediate,
      _range(0x30, 0x7f),
      ParserAction.escDispatch,
      ParserState.ground,
    );
  });
}

final List<int> _executables = <int>[
  ..._range(0x00, 0x18),
  0x19,
  ..._range(0x1c, 0x20),
];

List<int> _range(int start, int end) => <int>[
  for (var value = start; value < end; value++) value,
];

void _expect(
  ParserState state,
  Iterable<int> codes,
  ParserAction action,
  ParserState nextState,
) {
  for (final code in codes) {
    final transition = vt500TransitionTable.transition(state, code);
    expect(
      (
        ParserTransitionTable.actionOf(transition),
        ParserTransitionTable.stateOf(transition),
      ),
      (action, nextState),
      reason: '${state.name} code 0x${code.toRadixString(16)}',
    );
  }
}

void _expectAll(
  Iterable<int> codes,
  ParserAction action,
  ParserState nextState, {
  Set<ParserState> except = const <ParserState>{},
}) {
  for (final state in ParserState.values.where(
    (state) => !except.contains(state),
  )) {
    _expect(state, codes, action, nextState);
  }
}
