import 'package:vtworld/src/core/parser_constants.dart';

/// The packed action/state transition table used by xterm's VT500 parser.
final class ParserTransitionTable {
  /// Creates a zero-initialized transition table.
  ParserTransitionTable(int length) : table = List<int>.filled(length, 0);

  /// Packed transitions indexed by `(state << 8) | code`.
  final List<int> table;

  /// Sets every transition to [action] and [nextState].
  void setDefault(ParserAction action, ParserState nextState) {
    table.fillRange(0, table.length, _pack(action, nextState));
  }

  /// Sets one transition.
  void add(
    int code,
    ParserState state,
    ParserAction action,
    ParserState nextState,
  ) {
    table[(state.index << 8) | code] = _pack(action, nextState);
  }

  /// Sets the same transition for every code in [codes].
  void addMany(
    Iterable<int> codes,
    ParserState state,
    ParserAction action,
    ParserState nextState,
  ) {
    for (final code in codes) {
      add(code, state, action, nextState);
    }
  }

  /// Returns the packed transition for [state] and [code].
  int transition(ParserState state, int code) =>
      table[(state.index << 8) | code];

  /// Returns the action stored in [transition].
  static ParserAction actionOf(int transition) =>
      ParserAction.values[transition >> 8];

  /// Returns the next state stored in [transition].
  static ParserState stateOf(int transition) =>
      ParserState.values[transition & 0xff];

  static int _pack(ParserAction action, ParserState state) =>
      (action.index << 8) | state.index;
}

/// xterm's pinned VT500-compatible transition table.
final ParserTransitionTable vt500TransitionTable = _createVt500Table();

ParserTransitionTable _createVt500Table() {
  const nonAsciiPrintable = 0xa0;
  final table = ParserTransitionTable(4257);
  final printables = _range(0x20, 0x7f);
  final executables = <int>[..._range(0x00, 0x18), 0x19, ..._range(0x1c, 0x20)];

  table
    ..setDefault(ParserAction.error, ParserState.ground)
    ..addMany(
      printables,
      ParserState.ground,
      ParserAction.print,
      ParserState.ground,
    );
  for (final state in ParserState.values) {
    table
      ..addMany(
        <int>[0x18, 0x1a, 0x99, 0x9a],
        state,
        ParserAction.execute,
        ParserState.ground,
      )
      ..addMany(
        _range(0x80, 0x90),
        state,
        ParserAction.execute,
        ParserState.ground,
      )
      ..addMany(
        _range(0x90, 0x98),
        state,
        ParserAction.execute,
        ParserState.ground,
      )
      ..add(0x9c, state, ParserAction.ignore, ParserState.ground)
      ..add(0x1b, state, ParserAction.clear, ParserState.escape)
      ..add(0x9d, state, ParserAction.oscStart, ParserState.oscString)
      ..addMany(
        <int>[0x98, 0x9e],
        state,
        ParserAction.ignore,
        ParserState.sosPmString,
      )
      ..add(0x9f, state, ParserAction.clear, ParserState.apcEntry)
      ..add(0x9b, state, ParserAction.clear, ParserState.csiEntry)
      ..add(0x90, state, ParserAction.clear, ParserState.dcsEntry);
  }

  table
    ..addMany(
      executables,
      ParserState.ground,
      ParserAction.execute,
      ParserState.ground,
    )
    ..addMany(
      executables,
      ParserState.escape,
      ParserAction.execute,
      ParserState.escape,
    )
    ..add(0x7f, ParserState.escape, ParserAction.ignore, ParserState.escape)
    ..addMany(
      executables,
      ParserState.oscString,
      ParserAction.ignore,
      ParserState.oscString,
    )
    ..addMany(
      executables,
      ParserState.csiEntry,
      ParserAction.execute,
      ParserState.csiEntry,
    )
    ..add(0x7f, ParserState.csiEntry, ParserAction.ignore, ParserState.csiEntry)
    ..addMany(
      executables,
      ParserState.csiParam,
      ParserAction.execute,
      ParserState.csiParam,
    )
    ..add(0x7f, ParserState.csiParam, ParserAction.ignore, ParserState.csiParam)
    ..addMany(
      executables,
      ParserState.csiIgnore,
      ParserAction.execute,
      ParserState.csiIgnore,
    )
    ..addMany(
      executables,
      ParserState.csiIntermediate,
      ParserAction.execute,
      ParserState.csiIntermediate,
    )
    ..add(
      0x7f,
      ParserState.csiIntermediate,
      ParserAction.ignore,
      ParserState.csiIntermediate,
    )
    ..addMany(
      executables,
      ParserState.escapeIntermediate,
      ParserAction.execute,
      ParserState.escapeIntermediate,
    )
    ..add(
      0x7f,
      ParserState.escapeIntermediate,
      ParserAction.ignore,
      ParserState.escapeIntermediate,
    )
    ..add(
      0x5d,
      ParserState.escape,
      ParserAction.oscStart,
      ParserState.oscString,
    )
    ..addMany(
      printables,
      ParserState.oscString,
      ParserAction.oscPut,
      ParserState.oscString,
    )
    ..add(
      0x7f,
      ParserState.oscString,
      ParserAction.oscPut,
      ParserState.oscString,
    )
    ..addMany(
      <int>[0x9c, 0x1b, 0x18, 0x1a, 0x07],
      ParserState.oscString,
      ParserAction.oscEnd,
      ParserState.ground,
    )
    ..addMany(
      _range(0x1c, 0x20),
      ParserState.oscString,
      ParserAction.ignore,
      ParserState.oscString,
    )
    ..addMany(
      <int>[0x58, 0x5e],
      ParserState.escape,
      ParserAction.ignore,
      ParserState.sosPmString,
    )
    ..addMany(
      printables,
      ParserState.sosPmString,
      ParserAction.ignore,
      ParserState.sosPmString,
    )
    ..addMany(
      executables,
      ParserState.sosPmString,
      ParserAction.ignore,
      ParserState.sosPmString,
    )
    ..add(
      0x9c,
      ParserState.sosPmString,
      ParserAction.ignore,
      ParserState.ground,
    )
    ..add(
      0x7f,
      ParserState.sosPmString,
      ParserAction.ignore,
      ParserState.sosPmString,
    )
    ..add(0x5f, ParserState.escape, ParserAction.clear, ParserState.apcEntry)
    ..addMany(
      executables,
      ParserState.apcEntry,
      ParserAction.ignore,
      ParserState.apcEntry,
    )
    ..add(0x7f, ParserState.apcEntry, ParserAction.ignore, ParserState.apcEntry)
    ..addMany(
      _range(0x20, 0x30),
      ParserState.apcEntry,
      ParserAction.collect,
      ParserState.apcIntermediate,
    )
    ..addMany(
      _range(0x30, 0x7f),
      ParserState.apcEntry,
      ParserAction.apcStart,
      ParserState.apcPassthrough,
    )
    ..addMany(
      _range(0x30, 0x7f),
      ParserState.apcIntermediate,
      ParserAction.apcStart,
      ParserState.apcPassthrough,
    )
    ..addMany(
      executables,
      ParserState.apcIntermediate,
      ParserAction.ignore,
      ParserState.apcIntermediate,
    )
    ..addMany(
      _range(0x20, 0x30),
      ParserState.apcIntermediate,
      ParserAction.collect,
      ParserState.apcIntermediate,
    )
    ..add(
      0x7f,
      ParserState.apcIntermediate,
      ParserAction.ignore,
      ParserState.apcIntermediate,
    )
    ..addMany(
      printables,
      ParserState.apcPassthrough,
      ParserAction.apcPut,
      ParserState.apcPassthrough,
    )
    ..addMany(
      executables,
      ParserState.apcPassthrough,
      ParserAction.ignore,
      ParserState.apcPassthrough,
    )
    ..addMany(
      _range(0x08, 0x0e),
      ParserState.apcPassthrough,
      ParserAction.apcPut,
      ParserState.apcPassthrough,
    )
    ..add(
      0x7f,
      ParserState.apcPassthrough,
      ParserAction.ignore,
      ParserState.apcPassthrough,
    )
    ..addMany(
      <int>[0x1b, 0x9c, 0x18, 0x1a],
      ParserState.apcPassthrough,
      ParserAction.apcEnd,
      ParserState.ground,
    )
    ..add(0x5b, ParserState.escape, ParserAction.clear, ParserState.csiEntry)
    ..addMany(
      _range(0x40, 0x7f),
      ParserState.csiEntry,
      ParserAction.csiDispatch,
      ParserState.ground,
    )
    ..addMany(
      _range(0x30, 0x3c),
      ParserState.csiEntry,
      ParserAction.param,
      ParserState.csiParam,
    )
    ..addMany(
      <int>[0x3c, 0x3d, 0x3e, 0x3f],
      ParserState.csiEntry,
      ParserAction.collect,
      ParserState.csiParam,
    )
    ..addMany(
      _range(0x30, 0x3c),
      ParserState.csiParam,
      ParserAction.param,
      ParserState.csiParam,
    )
    ..addMany(
      _range(0x40, 0x7f),
      ParserState.csiParam,
      ParserAction.csiDispatch,
      ParserState.ground,
    )
    ..addMany(
      <int>[0x3c, 0x3d, 0x3e, 0x3f],
      ParserState.csiParam,
      ParserAction.ignore,
      ParserState.csiIgnore,
    )
    ..addMany(
      _range(0x20, 0x40),
      ParserState.csiIgnore,
      ParserAction.ignore,
      ParserState.csiIgnore,
    )
    ..add(
      0x7f,
      ParserState.csiIgnore,
      ParserAction.ignore,
      ParserState.csiIgnore,
    )
    ..addMany(
      _range(0x40, 0x7f),
      ParserState.csiIgnore,
      ParserAction.ignore,
      ParserState.ground,
    )
    ..addMany(
      _range(0x20, 0x30),
      ParserState.csiEntry,
      ParserAction.collect,
      ParserState.csiIntermediate,
    )
    ..addMany(
      _range(0x20, 0x30),
      ParserState.csiIntermediate,
      ParserAction.collect,
      ParserState.csiIntermediate,
    )
    ..addMany(
      _range(0x30, 0x40),
      ParserState.csiIntermediate,
      ParserAction.ignore,
      ParserState.csiIgnore,
    )
    ..addMany(
      _range(0x40, 0x7f),
      ParserState.csiIntermediate,
      ParserAction.csiDispatch,
      ParserState.ground,
    )
    ..addMany(
      _range(0x20, 0x30),
      ParserState.csiParam,
      ParserAction.collect,
      ParserState.csiIntermediate,
    )
    ..addMany(
      _range(0x20, 0x30),
      ParserState.escape,
      ParserAction.collect,
      ParserState.escapeIntermediate,
    )
    ..addMany(
      _range(0x20, 0x30),
      ParserState.escapeIntermediate,
      ParserAction.collect,
      ParserState.escapeIntermediate,
    )
    ..addMany(
      _range(0x30, 0x7f),
      ParserState.escapeIntermediate,
      ParserAction.escDispatch,
      ParserState.ground,
    )
    ..addMany(
      _range(0x30, 0x50),
      ParserState.escape,
      ParserAction.escDispatch,
      ParserState.ground,
    )
    ..addMany(
      _range(0x51, 0x58),
      ParserState.escape,
      ParserAction.escDispatch,
      ParserState.ground,
    )
    ..addMany(
      <int>[0x59, 0x5a, 0x5c],
      ParserState.escape,
      ParserAction.escDispatch,
      ParserState.ground,
    )
    ..addMany(
      _range(0x60, 0x7f),
      ParserState.escape,
      ParserAction.escDispatch,
      ParserState.ground,
    )
    ..add(0x50, ParserState.escape, ParserAction.clear, ParserState.dcsEntry)
    ..addMany(
      executables,
      ParserState.dcsEntry,
      ParserAction.ignore,
      ParserState.dcsEntry,
    )
    ..add(0x7f, ParserState.dcsEntry, ParserAction.ignore, ParserState.dcsEntry)
    ..addMany(
      _range(0x20, 0x30),
      ParserState.dcsEntry,
      ParserAction.collect,
      ParserState.dcsIntermediate,
    )
    ..addMany(
      _range(0x30, 0x3c),
      ParserState.dcsEntry,
      ParserAction.param,
      ParserState.dcsParam,
    )
    ..addMany(
      <int>[0x3c, 0x3d, 0x3e, 0x3f],
      ParserState.dcsEntry,
      ParserAction.collect,
      ParserState.dcsParam,
    )
    ..addMany(
      executables,
      ParserState.dcsIgnore,
      ParserAction.ignore,
      ParserState.dcsIgnore,
    )
    ..addMany(
      _range(0x20, 0x80),
      ParserState.dcsIgnore,
      ParserAction.ignore,
      ParserState.dcsIgnore,
    )
    ..addMany(
      executables,
      ParserState.dcsParam,
      ParserAction.ignore,
      ParserState.dcsParam,
    )
    ..add(0x7f, ParserState.dcsParam, ParserAction.ignore, ParserState.dcsParam)
    ..addMany(
      _range(0x30, 0x3c),
      ParserState.dcsParam,
      ParserAction.param,
      ParserState.dcsParam,
    )
    ..addMany(
      <int>[0x3c, 0x3d, 0x3e, 0x3f],
      ParserState.dcsParam,
      ParserAction.ignore,
      ParserState.dcsIgnore,
    )
    ..addMany(
      _range(0x20, 0x30),
      ParserState.dcsParam,
      ParserAction.collect,
      ParserState.dcsIntermediate,
    )
    ..addMany(
      executables,
      ParserState.dcsIntermediate,
      ParserAction.ignore,
      ParserState.dcsIntermediate,
    )
    ..add(
      0x7f,
      ParserState.dcsIntermediate,
      ParserAction.ignore,
      ParserState.dcsIntermediate,
    )
    ..addMany(
      _range(0x20, 0x30),
      ParserState.dcsIntermediate,
      ParserAction.collect,
      ParserState.dcsIntermediate,
    )
    ..addMany(
      _range(0x30, 0x40),
      ParserState.dcsIntermediate,
      ParserAction.ignore,
      ParserState.dcsIgnore,
    )
    ..addMany(
      _range(0x40, 0x7f),
      ParserState.dcsIntermediate,
      ParserAction.dcsHook,
      ParserState.dcsPassthrough,
    )
    ..addMany(
      _range(0x40, 0x7f),
      ParserState.dcsParam,
      ParserAction.dcsHook,
      ParserState.dcsPassthrough,
    )
    ..addMany(
      _range(0x40, 0x7f),
      ParserState.dcsEntry,
      ParserAction.dcsHook,
      ParserState.dcsPassthrough,
    )
    ..addMany(
      executables,
      ParserState.dcsPassthrough,
      ParserAction.dcsPut,
      ParserState.dcsPassthrough,
    )
    ..addMany(
      printables,
      ParserState.dcsPassthrough,
      ParserAction.dcsPut,
      ParserState.dcsPassthrough,
    )
    ..add(
      0x7f,
      ParserState.dcsPassthrough,
      ParserAction.ignore,
      ParserState.dcsPassthrough,
    )
    ..addMany(
      <int>[0x1b, 0x9c, 0x18, 0x1a],
      ParserState.dcsPassthrough,
      ParserAction.dcsUnhook,
      ParserState.ground,
    )
    ..add(
      nonAsciiPrintable,
      ParserState.ground,
      ParserAction.print,
      ParserState.ground,
    )
    ..add(
      nonAsciiPrintable,
      ParserState.oscString,
      ParserAction.oscPut,
      ParserState.oscString,
    )
    ..add(
      nonAsciiPrintable,
      ParserState.csiIgnore,
      ParserAction.ignore,
      ParserState.csiIgnore,
    )
    ..add(
      nonAsciiPrintable,
      ParserState.dcsIgnore,
      ParserAction.ignore,
      ParserState.dcsIgnore,
    )
    ..add(
      nonAsciiPrintable,
      ParserState.dcsPassthrough,
      ParserAction.dcsPut,
      ParserState.dcsPassthrough,
    )
    ..add(
      nonAsciiPrintable,
      ParserState.apcPassthrough,
      ParserAction.apcPut,
      ParserState.apcPassthrough,
    );
  return table;
}

Iterable<int> _range(int start, int end) sync* {
  for (var value = start; value < end; value++) {
    yield value;
  }
}
