import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  test('xterm WriteBuffer 00', () async {
    final state = _State();
    final buffer = state.createBuffer()
      ..write('a._')
      ..write('b.x', () => state.callbacks.add('b'))
      ..write('c._')
      ..write('d.x', () => state.callbacks.add('d'));
    await _writeAndWait(buffer, 'e');
    expect(state.values, <Object>['a._', 'b.x', 'c._', 'd.x', 'e']);
    expect(state.callbacks, <String>['b', 'd']);
  });

  test('xterm WriteBuffer 01', () async {
    final state = _State();
    final buffer = state.createBuffer()
      ..write(_bytes('a._'))
      ..write(_bytes('b.x'), () => state.callbacks.add('b'))
      ..write(_bytes('c._'))
      ..write(_bytes('d.x'), () => state.callbacks.add('d'));
    await _writeAndWait(buffer, _bytes('e'));
    expect(state.decodedValues, <String>['a._', 'b.x', 'c._', 'd.x', 'e']);
    expect(state.callbacks, <String>['b', 'd']);
  });

  test('xterm WriteBuffer 02', () async {
    final state = _State();
    final buffer = state.createBuffer()
      ..write('a._')
      ..write('b.x', () => state.callbacks.add('b'))
      ..write(_bytes('c._'))
      ..write(_bytes('d.x'), () => state.callbacks.add('d'));
    await _writeAndWait(buffer, _bytes('e'));
    expect(state.decodedValues, <String>['a._', 'b.x', 'c._', 'd.x', 'e']);
    expect(state.callbacks, <String>['b', 'd']);
  });

  test('xterm WriteBuffer 03', () async {
    final state = _State();
    final buffer = state.createBuffer()
      ..write('a', () => state.callbacks.add('a'))
      ..write('', () => state.callbacks.add('b'))
      ..write(_bytes('c'), () => state.callbacks.add('c'))
      ..write(Uint8List(0), () => state.callbacks.add('d'));
    await _writeAndWait(buffer, 'e');
    expect(state.decodedValues, <String>['a', '', 'c', '', 'e']);
    expect(state.callbacks, <String>['a', 'b', 'c', 'd']);
  });

  test('xterm WriteBuffer 04', () async {
    final state = _State();
    final buffer = state.createBuffer()
      ..write('a', () => state.callbacks.add('a'))
      ..write('b', () => state.callbacks.add('b'))
      ..write('c', () => state.callbacks.add('c'))
      ..writeSync('d');
    expect(state.values, <Object>['a', 'b', 'c', 'd']);
    expect(state.callbacks, <String>['a', 'b', 'c']);
    buffer.write('x', () => state.callbacks.add('x'));
    await _writeAndWait(buffer, '');
    expect(state.values, <Object>['a', 'b', 'c', 'd', 'x', '']);
    expect(state.callbacks, <String>['a', 'b', 'c', 'x']);
  });

  test('xterm WriteBuffer 05', () {
    late WriteBuffer buffer;
    buffer = WriteBuffer((data, [promiseResult]) {
      final value = int.parse(data as String);
      if (value < 10000) buffer.writeSync('${value + 1}');
      return null;
    });
    // The buffer must be assigned before its recursive action can run.
    // ignore: cascade_invocations
    buffer.writeSync('1');
  });

  test('xterm WriteBuffer 06', () {
    var last = '';
    late WriteBuffer buffer;
    buffer = WriteBuffer((data, [promiseResult]) {
      last = data as String;
      final value = int.parse(data);
      if (value < 1000000) buffer.writeSync('${value + 1}', 10);
      return null;
    });
    // The buffer must be assigned before its recursive action can run.
    // ignore: cascade_invocations
    buffer.writeSync('1', 10);
    expect(last, '11');
  });

  test('xterm WriteBuffer 07', () async {
    final state = _State();
    final buffer = state.createBuffer()
      ..write('a', () => state.callbacks.add('a'))
      ..write('b', () => state.callbacks.add('b'))
      ..write('c', () => state.callbacks.add('c'))
      ..flushSync();
    expect(state.values, <Object>['a', 'b', 'c']);
    expect(state.callbacks, <String>['a', 'b', 'c']);
    buffer.write('x', () => state.callbacks.add('x'));
    await _writeAndWait(buffer, '');
    expect(state.values, <Object>['a', 'b', 'c', 'x', '']);
    expect(state.callbacks, <String>['a', 'b', 'c', 'x']);
  });

  test('xterm WriteBuffer 08', () {
    final state = _State();
    state.createBuffer().flushSync();
    expect(state.values, isEmpty);
    expect(state.callbacks, isEmpty);
  });

  test('xterm WriteBuffer 09', () {
    final state = _State();
    final buffer = state.createBuffer();
    var parsed = 0;
    buffer
      ..onWriteParsed.listen((_) => parsed++)
      ..write('a')
      ..write('b');
    expect(parsed, 0);
    buffer.flushSync();
    expect(parsed, 1);
  });

  test('xterm WriteBuffer 10', () {
    final state = _State();
    final buffer = state.createBuffer();
    var parsed = 0;
    buffer.onWriteParsed.listen((_) => parsed++);
    buffer.flushSync();
    expect(parsed, 0);
  });

  test('xterm WriteBuffer 11', () async {
    final state = _State();
    state.createBuffer()
      ..write('a')
      ..dispose();
    await _timerTurn();
    expect(state.values, isEmpty);
  });

  test('xterm WriteBuffer 12', () async {
    final state = _State();
    final buffer = state.createBuffer()..write('a');
    var parsed = 0;
    buffer.onWriteParsed.listen((_) => parsed++);
    buffer.dispose();
    await _timerTurn();
    expect(parsed, 0);
  });

  test('xterm WriteBuffer 13', () async {
    final state = _State();
    state.createBuffer()
      ..dispose()
      ..write('a');
    await _timerTurn();
    expect(state.values, isEmpty);
  });

  test('xterm WriteBuffer 14', () async {
    final state = _State();
    state.createBuffer()
      ..write('a')
      ..dispose()
      ..dispose();
    await _timerTurn();
    expect(state.values, isEmpty);
  });

  test('xterm WriteBuffer 15', () async {
    final completer = Completer<bool>();
    final buffer = WriteBuffer((data, [promiseResult]) => completer.future)
      ..write('a')
      ..dispose();
    completer.complete(true);
    await _timerTurn();
    expect(buffer.isDisposed, isTrue);
  });

  test('xterm WriteBuffer 16', () {
    final state = _State();
    state.createBuffer()
      ..handleUserInput()
      ..write('a');
    expect(state.values, <Object>['a']);
  });

  test('xterm WriteBuffer 17', () async {
    final state = _State();
    state.createBuffer()
      ..write('a')
      ..dispose()
      ..flushSync();
    await _timerTurn();
    expect(state.values, isEmpty);
  });

  test('xterm WriteBuffer 18', () {
    final state = _State();
    state.createBuffer()
      ..dispose()
      ..writeSync('a');
    expect(state.values, isEmpty);
  });
}

final class _State {
  final List<Object> values = <Object>[];
  final List<String> callbacks = <String>[];

  List<String> get decodedValues => values
      .map((value) => value is String ? value : utf8.decode(value as Uint8List))
      .toList();

  WriteBuffer createBuffer() => WriteBuffer((data, [promiseResult]) {
    values.add(data);
    return null;
  });
}

Uint8List _bytes(String value) => Uint8List.fromList(utf8.encode(value));

Future<void> _writeAndWait(WriteBuffer buffer, Object data) {
  final completer = Completer<void>();
  buffer.write(data, completer.complete);
  return completer.future;
}

Future<void> _timerTurn() =>
    Future<void>.delayed(const Duration(milliseconds: 20));
