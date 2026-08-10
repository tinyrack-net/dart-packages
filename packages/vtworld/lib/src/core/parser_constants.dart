/// Internal states of xterm's escape-sequence parser in transition-table order.
enum ParserState {
  /// Normal printable/control processing.
  ground,

  /// ESC introducer received.
  escape,

  /// ESC intermediate bytes.
  escapeIntermediate,

  /// CSI introducer received.
  csiEntry,

  /// CSI parameter bytes.
  csiParam,

  /// CSI intermediate bytes.
  csiIntermediate,

  /// Ignored malformed CSI sequence.
  csiIgnore,

  /// SOS or PM string payload.
  sosPmString,

  /// OSC string payload.
  oscString,

  /// DCS introducer received.
  dcsEntry,

  /// DCS parameter bytes.
  dcsParam,

  /// Ignored malformed DCS sequence.
  dcsIgnore,

  /// DCS intermediate bytes.
  dcsIntermediate,

  /// DCS handler payload.
  dcsPassthrough,

  /// APC introducer received.
  apcEntry,

  /// APC intermediate bytes.
  apcIntermediate,

  /// APC handler payload.
  apcPassthrough,
}

/// Actions stored in xterm's parser transition table.
enum ParserAction {
  /// Ignore the input byte.
  ignore,

  /// Invoke parser error recovery.
  error,

  /// Print a code point.
  print,

  /// Execute a control code.
  execute,

  /// Start an OSC sequence.
  oscStart,

  /// Append OSC payload.
  oscPut,

  /// End an OSC sequence.
  oscEnd,

  /// Dispatch a CSI sequence.
  csiDispatch,

  /// Collect a numeric parameter.
  param,

  /// Collect prefix or intermediate bytes.
  collect,

  /// Dispatch an ESC sequence.
  escDispatch,

  /// Clear sequence state.
  clear,

  /// Attach a DCS handler.
  dcsHook,

  /// Append DCS payload.
  dcsPut,

  /// Detach a DCS handler.
  dcsUnhook,

  /// Start an APC sequence.
  apcStart,

  /// Append APC payload.
  apcPut,

  /// End an APC sequence.
  apcEnd,
}

/// Internal states of the OSC sub-parser.
enum OscState {
  /// Waiting for an identifier.
  start,

  /// Reading the numeric identifier.
  id,

  /// Reading payload data.
  payload,

  /// Sequence has been aborted.
  abort,
}

/// Number of states in [ParserState].
const int parserStateLength = 17;

/// Maximum OSC, DCS, and APC payload length accepted by xterm.
const int parserPayloadLimit = 10000000;
