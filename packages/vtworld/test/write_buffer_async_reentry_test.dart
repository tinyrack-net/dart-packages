import 'dart:async';

import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

/// A synchronous flush can land on any tick, including one where the parser is
/// suspended on an asynchronous handler. xterm.js can flush there because its
/// parser is synchronous and resumable; this one is genuinely asynchronous and
/// refuses re-entry, so a flush that re-entered it threw and abandoned the
/// chunk the parser was holding. A terminal resize is the caller that reaches
/// this: it flushes before it changes the geometry, from a frame callback.
void main() {
  test('flushSync waits out a chunk still awaiting its handler', () async {
    final parser = _AsyncParser(awaiting: 'awaits');
    final buffer = WriteBuffer(parser.call);
    addTearDown(buffer.dispose);

    buffer.write('awaits');
    await Future<void>.delayed(Duration.zero);
    expect(parser.parsed, <Object>[
      'awaits',
    ], reason: 'the handler should be awaiting');
    final parsedWhileAwaiting = parser.parsed.length;

    buffer
      ..write('queued')
      ..flushSync();
    expect(
      parser.parsed.length,
      parsedWhileAwaiting,
      reason: 'the flush must not re-enter the parser',
    );

    parser.release();
    await _settle();

    expect(parser.parsed, <Object>['awaits', 'queued']);
  });

  test('writeSync waits out a chunk still awaiting its handler', () async {
    final parser = _AsyncParser(awaiting: 'awaits');
    final buffer = WriteBuffer(parser.call);
    addTearDown(buffer.dispose);

    buffer.write('awaits');
    await Future<void>.delayed(Duration.zero);
    final parsedWhileAwaiting = parser.parsed.length;

    buffer.writeSync('sync');
    expect(parser.parsed.length, parsedWhileAwaiting);

    parser.release();
    await _settle();

    expect(parser.parsed, <Object>['awaits', 'sync']);
  });

  test('flushSync still drains when no handler is awaiting', () {
    final parser = _AsyncParser();
    final buffer = WriteBuffer(parser.call);
    addTearDown(buffer.dispose);

    buffer
      ..write('first')
      ..flushSync();

    expect(parser.parsed, <Object>['first']);
  });
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

/// A parser action that suspends on one chunk, the way a registered handler does.
///
/// Follows xterm's continuation contract: the action is called again for the
/// same chunk once its future resolves, and answers that second call with null
/// so the buffer advances.
final class _AsyncParser {
  _AsyncParser({this.awaiting});

  /// Chunk whose parse suspends until [release].
  final Object? awaiting;

  /// Chunks that reached the parser, in order.
  final List<Object> parsed = <Object>[];

  final Completer<bool> _gate = Completer<bool>();
  bool _continuationPending = false;

  /// Resolves the suspended handler.
  void release() => _gate.complete(true);

  // The positional boolean is fixed by xterm's continuation contract.
  // ignore: avoid_positional_boolean_parameters
  Object? call(Object data, [bool? promiseResult]) {
    if (promiseResult != null && _continuationPending) {
      _continuationPending = false;
      return null;
    }
    parsed.add(data);
    if (data != awaiting) return null;
    if (promiseResult != null) _continuationPending = true;
    return _gate.future;
  }
}
