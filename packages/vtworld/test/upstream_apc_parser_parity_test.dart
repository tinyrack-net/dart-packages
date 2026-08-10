import 'dart:async';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:vtworld/src/core/apc_parser.dart';

const _ident = 0x2B70;

void main() {
  late ApcParser parser;
  late List<Object?> reports;

  setUp(() {
    reports = <Object?>[];
    parser = ApcParser()
      ..setHandlerFallback(
        (identifier, action, [payload]) =>
            reports.add(<Object?>[identifier, action, payload]),
      );
  });

  group('ApcParser', () {
    group('handler registration', () {
      test('setApcHandler', () {
        parser.registerHandler(_ident, _TestHandler(reports, 'th'));
        _send(parser, 'Here comes', 'the mouse!');
        _endSync(parser, true);
        expect(reports, <Object?>[
          <Object?>['th', 'START'],
          <Object?>['th', 'PUT', 'Here comes'],
          <Object?>['th', 'PUT', 'the mouse!'],
          <Object?>['th', 'END', true],
        ]);
      });

      test('clearApcHandler', () {
        parser
          ..registerHandler(_ident, _TestHandler(reports, 'th'))
          ..clearHandler(_ident);
        _send(parser, 'Here comes', 'the mouse!');
        _endSync(parser, true);
        expect(reports, <Object?>[
          <Object?>[_ident, 'START', null],
          <Object?>[_ident, 'PUT', 'Here comes'],
          <Object?>[_ident, 'PUT', 'the mouse!'],
          <Object?>[_ident, 'END', true],
        ]);
      });

      test('addApcHandler', () {
        parser
          ..registerHandler(_ident, _TestHandler(reports, 'th1'))
          ..registerHandler(_ident, _TestHandler(reports, 'th2'));
        _send(parser, 'Here comes', 'the mouse!');
        _endSync(parser, true);
        expect(reports, _twoHandlerReports(false));
      });

      test('addApcHandler with return false', () {
        parser
          ..registerHandler(_ident, _TestHandler(reports, 'th1'))
          ..registerHandler(
            _ident,
            _TestHandler(reports, 'th2', returnFalse: true),
          );
        _send(parser, 'Here comes', 'the mouse!');
        _endSync(parser, true);
        expect(reports, _twoHandlerReports(true));
      });

      test('dispose handlers', () {
        parser.registerHandler(_ident, _TestHandler(reports, 'th1'));
        final disposable = parser.registerHandler(
          _ident,
          _TestHandler(reports, 'th2', returnFalse: true),
        )..dispose();
        _send(parser, 'Here comes', 'the mouse!');
        _endSync(parser, true);
        expect(reports, <Object?>[
          <Object?>['th1', 'START'],
          <Object?>['th1', 'PUT', 'Here comes'],
          <Object?>['th1', 'PUT', 'the mouse!'],
          <Object?>['th1', 'END', true],
        ]);
        disposable.dispose();
      });
    });

    group('ApcHandlerFactory', () {
      late int originalPayloadLimit;

      setUp(() {
        originalPayloadLimit = ApcHandler.payloadLimit;
        ApcHandler.payloadLimit = 100;
      });

      tearDown(() => ApcHandler.payloadLimit = originalPayloadLimit);

      test('should be called once on end(true)', () {
        _registerStringHandler(parser, reports, returnValue: true);
        _send(parser, 'Here comes', ' the mouse!');
        _endSync(parser, true);
        expect(reports, <Object?>['Here comes the mouse!']);
      });

      test('should not be called on end(false)', () {
        _registerStringHandler(parser, reports, returnValue: true);
        _send(parser, 'Here comes', ' the mouse!');
        _endSync(parser, false);
        expect(reports, isEmpty);
      });

      test('should be disposable', () {
        parser.registerHandler(
          _ident,
          ApcHandler((data) {
            reports.add(<Object?>['one', data]);
            return true;
          }),
        );
        final disposable = parser.registerHandler(
          _ident,
          ApcHandler((data) {
            reports.add(<Object?>['two', data]);
            return true;
          }),
        );
        _send(parser, 'Here comes', ' the mouse!');
        _endSync(parser, true);
        disposable.dispose();
        _send(parser, 'some other', ' data');
        _endSync(parser, true);
        expect(reports, <Object?>[
          <Object?>['two', 'Here comes the mouse!'],
          <Object?>['one', 'some other data'],
        ]);
      });

      test('should respect return false', () {
        parser
          ..registerHandler(
            _ident,
            ApcHandler((data) {
              reports.add(<Object?>['one', data]);
              return true;
            }),
          )
          ..registerHandler(
            _ident,
            ApcHandler((data) {
              reports.add(<Object?>['two', data]);
              return false;
            }),
          );
        _send(parser, 'Here comes', ' the mouse!');
        _endSync(parser, true);
        expect(reports, <Object?>[
          <Object?>['two', 'Here comes the mouse!'],
          <Object?>['one', 'Here comes the mouse!'],
        ]);
      });

      test('should work up to payload limit', () {
        _registerStringHandler(parser, reports, returnValue: true);
        parser.start(_ident);
        final chunk = _utf32('A' * 10);
        for (var index = 0; index < 100; index += 10) {
          parser.put(chunk, 0, chunk.length);
        }
        _endSync(parser, true);
        expect(reports, <Object?>['A' * 100]);
      });

      test('should abort for payload limit +1', () {
        _registerStringHandler(parser, reports, returnValue: true);
        parser.start(_ident);
        final chunk = _utf32('A' * 10);
        for (var index = 0; index < 100; index += 10) {
          parser.put(chunk, 0, chunk.length);
        }
        final extra = _utf32('A');
        parser.put(extra, 0, extra.length);
        _endSync(parser, true);
        expect(reports, isEmpty);
      });
    });
  });

  group('ApcParser - async tests', () {
    group('sync and async mixed', () {
      group('sync | async | sync', () {
        test('first should run, cleanup action for others', () async {
          parser
            ..registerHandler(_ident, _TestHandler(reports, 's1'))
            ..registerHandler(_ident, _AsyncTestHandler(reports, 'a1'))
            ..registerHandler(_ident, _TestHandler(reports, 's2'));
          _send(parser, 'Here comes', 'the mouse!');
          await _unhook(parser, true);
          expect(reports, _mixedReports(<String>['s2', 'a1', 's1'], false));
        });

        test('all should run', () async {
          parser
            ..registerHandler(
              _ident,
              _TestHandler(reports, 's1', returnFalse: true),
            )
            ..registerHandler(
              _ident,
              _AsyncTestHandler(reports, 'a1', returnFalse: true),
            )
            ..registerHandler(
              _ident,
              _TestHandler(reports, 's2', returnFalse: true),
            );
          _send(parser, 'Here comes', 'the mouse!');
          await _unhook(parser, true);
          expect(reports, _mixedReports(<String>['s2', 'a1', 's1'], true));
        });
      });

      group('async | sync | async', () {
        test('first should run, cleanup action for others', () async {
          parser
            ..registerHandler(_ident, _AsyncTestHandler(reports, 'a1'))
            ..registerHandler(_ident, _TestHandler(reports, 's1'))
            ..registerHandler(_ident, _AsyncTestHandler(reports, 'a2'));
          _send(parser, 'Here comes', 'the mouse!');
          await _unhook(parser, true);
          expect(reports, _mixedReports(<String>['a2', 's1', 'a1'], false));
        });

        test('all should run', () async {
          parser
            ..registerHandler(
              _ident,
              _AsyncTestHandler(reports, 'a1', returnFalse: true),
            )
            ..registerHandler(
              _ident,
              _TestHandler(reports, 's1', returnFalse: true),
            )
            ..registerHandler(
              _ident,
              _AsyncTestHandler(reports, 'a2', returnFalse: true),
            );
          _send(parser, 'Here comes', 'the mouse!');
          await _unhook(parser, true);
          expect(reports, _mixedReports(<String>['a2', 's1', 'a1'], true));
        });
      });

      group('ApcHandlerFactory', () {
        test('should be called once on end(true)', () async {
          _registerAsyncStringHandler(parser, reports, returnValue: true);
          _send(parser, 'Here comes', ' the mouse!');
          await _unhook(parser, true);
          expect(reports, <Object?>['Here comes the mouse!']);
        });

        test('should not be called on end(false)', () async {
          _registerAsyncStringHandler(parser, reports, returnValue: true);
          _send(parser, 'Here comes', ' the mouse!');
          await _unhook(parser, false);
          expect(reports, isEmpty);
        });

        test('should be disposable', () async {
          parser.registerHandler(
            _ident,
            ApcHandler((data) async {
              reports.add(<Object?>['one', data]);
              return true;
            }),
          );
          final disposable = parser.registerHandler(
            _ident,
            ApcHandler((data) async {
              reports.add(<Object?>['two', data]);
              return true;
            }),
          );
          _send(parser, 'Here comes', ' the mouse!');
          await _unhook(parser, true);
          disposable.dispose();
          _send(parser, 'some other', ' data');
          await _unhook(parser, true);
          expect(reports, <Object?>[
            <Object?>['two', 'Here comes the mouse!'],
            <Object?>['one', 'some other data'],
          ]);
        });

        test('should respect return false', () async {
          parser
            ..registerHandler(
              _ident,
              ApcHandler((data) async {
                reports.add(<Object?>['one', data]);
                return true;
              }),
            )
            ..registerHandler(
              _ident,
              ApcHandler((data) async {
                reports.add(<Object?>['two', data]);
                return false;
              }),
            );
          _send(parser, 'Here comes', ' the mouse!');
          await _unhook(parser, true);
          expect(reports, <Object?>[
            <Object?>['two', 'Here comes the mouse!'],
            <Object?>['one', 'Here comes the mouse!'],
          ]);
        });
      });
    });

    group('reset', () {
      test(
        // Pinned upstream test identity.
        // ignore: lines_longer_than_80_chars
        'should abort active handlers with end(false) when reset during payload',
        () {
          parser
            ..registerHandler(_ident, _TestHandler(reports, 'th'))
            ..start(_ident);
          final partial = _utf32('partial');
          parser
            ..put(partial, 0, partial.length)
            ..reset();
          expect(reports, <Object?>[
            <Object?>['th', 'START'],
            <Object?>['th', 'PUT', 'partial'],
            <Object?>['th', 'END', false],
          ]);
          reports.clear();
          parser.start(_ident);
          final complete = _utf32('complete');
          parser.put(complete, 0, complete.length);
          _endSync(parser, true);
          expect(reports, <Object?>[
            <Object?>['th', 'START'],
            <Object?>['th', 'PUT', 'complete'],
            <Object?>['th', 'END', true],
          ]);
        },
      );
    });
  });
}

class _TestHandler implements ApcSubHandler {
  _TestHandler(this.output, this.message, {this.returnFalse = false});

  final List<Object?> output;
  final String message;
  final bool returnFalse;

  @override
  void start() => output.add(<Object?>[message, 'START']);

  @override
  void put(Uint32List data, int start, int end) => output.add(<Object?>[
    message,
    'PUT',
    String.fromCharCodes(data, start, end),
  ]);

  @override
  FutureOr<bool> end(bool success) {
    output.add(<Object?>[message, 'END', success]);
    return !returnFalse;
  }
}

final class _AsyncTestHandler extends _TestHandler {
  _AsyncTestHandler(super.output, super.message, {super.returnFalse});

  @override
  Future<bool> end(bool success) async {
    await Future<void>.value();
    output.add(<Object?>[message, 'END', success]);
    return !returnFalse;
  }
}

Uint32List _utf32(String value) => Uint32List.fromList(value.runes.toList());

void _send(ApcParser parser, String first, String second) {
  parser.start(_ident);
  final firstData = _utf32(first);
  parser.put(firstData, 0, firstData.length);
  final secondData = _utf32(second);
  parser.put(secondData, 0, secondData.length);
}

Future<void> _unhook(ApcParser parser, bool success) async {
  var previous = true;
  while (true) {
    final pending = parser.end(success, promiseResult: previous);
    if (pending == null) return;
    previous = await pending;
  }
}

void _endSync(ApcParser parser, bool success) {
  final pending = parser.end(success);
  if (pending != null) {
    throw StateError('Expected a synchronous APC handler');
  }
}

void _registerStringHandler(
  ApcParser parser,
  List<Object?> reports, {
  required bool returnValue,
}) {
  parser.registerHandler(
    _ident,
    ApcHandler((data) {
      reports.add(data);
      return returnValue;
    }),
  );
}

void _registerAsyncStringHandler(
  ApcParser parser,
  List<Object?> reports, {
  required bool returnValue,
}) {
  parser.registerHandler(
    _ident,
    ApcHandler((data) async {
      reports.add(data);
      return returnValue;
    }),
  );
}

List<Object?> _twoHandlerReports(bool bubbles) => <Object?>[
  <Object?>['th2', 'START'],
  <Object?>['th1', 'START'],
  <Object?>['th2', 'PUT', 'Here comes'],
  <Object?>['th1', 'PUT', 'Here comes'],
  <Object?>['th2', 'PUT', 'the mouse!'],
  <Object?>['th1', 'PUT', 'the mouse!'],
  <Object?>['th2', 'END', true],
  <Object?>['th1', 'END', bubbles],
];

List<Object?> _mixedReports(List<String> order, bool bubbles) => <Object?>[
  for (final name in order) <Object?>[name, 'START'],
  for (final name in order) <Object?>[name, 'PUT', 'Here comes'],
  for (final name in order) <Object?>[name, 'PUT', 'the mouse!'],
  <Object?>[order.first, 'END', true],
  for (final name in order.skip(1)) <Object?>[name, 'END', bubbles],
];
