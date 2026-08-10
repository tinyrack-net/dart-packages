import 'dart:async';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:vtworld/src/core/osc_parser.dart';

const _ident = 1234;

void main() {
  late OscParser parser;
  late List<Object?> reports;

  setUp(() {
    reports = <Object?>[];
    parser = OscParser()
      ..setHandlerFallback(
        (identifier, action, [payload]) =>
            reports.add(<Object?>[identifier, action, payload]),
      );
  });

  group('OscParser', () {
    group('identifier parsing', () {
      test('no report for illegal ids', () {
        final data = _utf32('hello world!');
        parser.put(data, 0, data.length);
        _endSync(parser, true);
        expect(reports, isEmpty);
      });

      test('no payload', () {
        parser.start();
        _put(parser, '12');
        _put(parser, '34');
        _endSync(parser, true);
        expect(reports, <Object?>[
          <Object?>[_ident, 'START', null],
          <Object?>[_ident, 'END', true],
        ]);
      });

      test('with payload', () {
        parser.start();
        _put(parser, '12');
        _put(parser, '34');
        _put(parser, ';h');
        _put(parser, 'ello');
        _endSync(parser, true);
        expect(reports, <Object?>[
          <Object?>[_ident, 'START', null],
          <Object?>[_ident, 'PUT', 'h'],
          <Object?>[_ident, 'PUT', 'ello'],
          <Object?>[_ident, 'END', true],
        ]);
      });
    });

    group('handler registration', () {
      test('setOscHandler', () {
        parser.registerHandler(_ident, _TestHandler(reports, 'th'));
        _send(parser, 'Here comes', 'the mouse!');
        _endSync(parser, true);
        expect(reports, _singleReports('th'));
      });

      test('clearOscHandler', () {
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

      test('addOscHandler', () {
        _registerPair(parser, reports, bubbles: false);
        _send(parser, 'Here comes', 'the mouse!');
        _endSync(parser, true);
        expect(reports, _pairReports(false));
      });

      test('addOscHandler with return false', () {
        _registerPair(parser, reports, bubbles: true);
        _send(parser, 'Here comes', 'the mouse!');
        _endSync(parser, true);
        expect(reports, _pairReports(true));
      });

      test('dispose handlers', () {
        parser.registerHandler(_ident, _TestHandler(reports, 'th1'));
        parser
            .registerHandler(
              _ident,
              _TestHandler(reports, 'th2', returnFalse: true),
            )
            .dispose();
        _send(parser, 'Here comes', 'the mouse!');
        _endSync(parser, true);
        expect(reports, _singleReports('th1'));
      });
    });

    group('OscHandlerFactory', () {
      late int originalPayloadLimit;
      setUp(() {
        originalPayloadLimit = OscHandler.payloadLimit;
        OscHandler.payloadLimit = 100;
      });
      tearDown(() => OscHandler.payloadLimit = originalPayloadLimit);

      test('should be called once on end(true)', () {
        _registerFactory(parser, reports, returns: true);
        _send(parser, 'Here comes', ' the mouse!');
        _endSync(parser, true);
        expect(reports, <Object?>['Here comes the mouse!']);
      });

      test('should not be called on end(false)', () {
        _registerFactory(parser, reports, returns: true);
        _send(parser, 'Here comes', ' the mouse!');
        _endSync(parser, false);
        expect(reports, isEmpty);
      });

      test('should be disposable', () async {
        await _factoryDisposable(parser, reports, asynchronous: false);
        expect(reports, <Object?>[
          <Object?>['two', 'Here comes the mouse!'],
          <Object?>['one', 'some other data'],
        ]);
      });

      test('should respect return false', () {
        _registerFactoryPair(parser, reports, asynchronous: false);
        _send(parser, 'Here comes', ' the mouse!');
        _endSync(parser, true);
        expect(reports, _factoryPairReports);
      });

      test('should work up to payload limit', () {
        _registerFactory(parser, reports, returns: true);
        _sendLimit(parser, extra: false);
        _endSync(parser, true);
        expect(reports, <Object?>['A' * 100]);
      });

      test('should abort for payload limit +1', () {
        _registerFactory(parser, reports, returns: true);
        _sendLimit(parser, extra: true);
        _endSync(parser, true);
        expect(reports, isEmpty);
      });
    });
  });

  group('OscParser - async tests', () {
    group('sync and async mixed', () {
      group('sync | async | sync', () {
        test('first should run, cleanup action for others', () async {
          _registerMixed(parser, reports, asyncOutside: false, bubbles: false);
          _send(parser, 'Here comes', 'the mouse!');
          await _end(parser, true);
          expect(reports, _mixedReports(<String>['s2', 'a1', 's1'], false));
        });

        test('all should run', () async {
          _registerMixed(parser, reports, asyncOutside: false, bubbles: true);
          _send(parser, 'Here comes', 'the mouse!');
          await _end(parser, true);
          expect(reports, _mixedReports(<String>['s2', 'a1', 's1'], true));
        });
      });

      group('async | sync | async', () {
        test('first should run, cleanup action for others', () async {
          _registerMixed(parser, reports, asyncOutside: true, bubbles: false);
          _send(parser, 'Here comes', 'the mouse!');
          await _end(parser, true);
          expect(reports, _mixedReports(<String>['a2', 's1', 'a1'], false));
        });

        test('all should run', () async {
          _registerMixed(parser, reports, asyncOutside: true, bubbles: true);
          _send(parser, 'Here comes', 'the mouse!');
          await _end(parser, true);
          expect(reports, _mixedReports(<String>['a2', 's1', 'a1'], true));
        });
      });

      group('OscHandlerFactory', () {
        test('should be called once on end(true)', () async {
          _registerFactory(parser, reports, returns: true, asynchronous: true);
          _send(parser, 'Here comes', ' the mouse!');
          await _end(parser, true);
          expect(reports, <Object?>['Here comes the mouse!']);
        });

        test('should not be called on end(false)', () async {
          _registerFactory(parser, reports, returns: true, asynchronous: true);
          _send(parser, 'Here comes', ' the mouse!');
          await _end(parser, false);
          expect(reports, isEmpty);
        });

        test('should be disposable', () async {
          await _factoryDisposable(parser, reports, asynchronous: true);
          expect(reports, <Object?>[
            <Object?>['two', 'Here comes the mouse!'],
            <Object?>['one', 'some other data'],
          ]);
        });

        test('should respect return false', () async {
          _registerFactoryPair(parser, reports, asynchronous: true);
          _send(parser, 'Here comes', ' the mouse!');
          await _end(parser, true);
          expect(reports, _factoryPairReports);
        });
      });
    });

    group('reset', () {
      test(
        // Pinned upstream test identity.
        // ignore: lines_longer_than_80_chars
        'should abort active handlers with end(false) when reset during payload',
        () {
          parser.registerHandler(_ident, _TestHandler(reports, 'th'));
          _sendOne(parser, 'partial');
          parser.reset();
          expect(reports, <Object?>[
            <Object?>['th', _ident, 'START'],
            <Object?>['th', _ident, 'PUT', 'partial'],
            <Object?>['th', _ident, 'END', false],
          ]);
          reports.clear();
          _sendOne(parser, 'complete');
          _endSync(parser, true);
          expect(reports, <Object?>[
            <Object?>['th', _ident, 'START'],
            <Object?>['th', _ident, 'PUT', 'complete'],
            <Object?>['th', _ident, 'END', true],
          ]);
        },
      );
    });
  });
}

class _TestHandler implements OscSubHandler {
  _TestHandler(this.output, this.message, {this.returnFalse = false});
  final List<Object?> output;
  final String message;
  final bool returnFalse;

  @override
  void start() => output.add(<Object?>[message, _ident, 'START']);

  @override
  void put(Uint32List data, int start, int end) => output.add(<Object?>[
    message,
    _ident,
    'PUT',
    String.fromCharCodes(data, start, end),
  ]);

  @override
  FutureOr<bool> end(bool success) {
    output.add(<Object?>[message, _ident, 'END', success]);
    return !returnFalse;
  }
}

final class _AsyncTestHandler extends _TestHandler {
  _AsyncTestHandler(super.output, super.message, {super.returnFalse});

  @override
  Future<bool> end(bool success) async {
    await Future<void>.value();
    output.add(<Object?>[message, _ident, 'END', success]);
    return !returnFalse;
  }
}

Uint32List _utf32(String value) => Uint32List.fromList(value.runes.toList());

void _put(OscParser parser, String value) {
  final data = _utf32(value);
  parser.put(data, 0, data.length);
}

void _send(OscParser parser, String first, String second) {
  parser.start();
  _put(parser, '$_ident;$first');
  _put(parser, second);
}

void _sendOne(OscParser parser, String value) {
  parser.start();
  _put(parser, '$_ident;$value');
}

void _sendLimit(OscParser parser, {required bool extra}) {
  parser.start();
  _put(parser, '$_ident;');
  for (var index = 0; index < 100; index += 10) {
    _put(parser, 'A' * 10);
  }
  if (extra) _put(parser, 'A');
}

void _endSync(OscParser parser, bool success) {
  if (parser.end(success) != null) {
    throw StateError('Expected a synchronous OSC handler');
  }
}

Future<void> _end(OscParser parser, bool success) async {
  var previous = true;
  while (true) {
    final pending = parser.end(success, promiseResult: previous);
    if (pending == null) return;
    previous = await pending;
  }
}

void _registerPair(
  OscParser parser,
  List<Object?> reports, {
  required bool bubbles,
}) {
  parser
    ..registerHandler(_ident, _TestHandler(reports, 'th1'))
    ..registerHandler(
      _ident,
      _TestHandler(reports, 'th2', returnFalse: bubbles),
    );
}

void _registerMixed(
  OscParser parser,
  List<Object?> reports, {
  required bool asyncOutside,
  required bool bubbles,
}) {
  if (asyncOutside) {
    parser
      ..registerHandler(
        _ident,
        _AsyncTestHandler(reports, 'a1', returnFalse: bubbles),
      )
      ..registerHandler(
        _ident,
        _TestHandler(reports, 's1', returnFalse: bubbles),
      )
      ..registerHandler(
        _ident,
        _AsyncTestHandler(reports, 'a2', returnFalse: bubbles),
      );
  } else {
    parser
      ..registerHandler(
        _ident,
        _TestHandler(reports, 's1', returnFalse: bubbles),
      )
      ..registerHandler(
        _ident,
        _AsyncTestHandler(reports, 'a1', returnFalse: bubbles),
      )
      ..registerHandler(
        _ident,
        _TestHandler(reports, 's2', returnFalse: bubbles),
      );
  }
}

void _registerFactory(
  OscParser parser,
  List<Object?> reports, {
  required bool returns,
  bool asynchronous = false,
  String? label,
}) {
  parser.registerHandler(
    _ident,
    OscHandler(
      asynchronous
          ? (data) async {
              reports.add(label == null ? data : <Object?>[label, data]);
              return returns;
            }
          : (data) {
              reports.add(label == null ? data : <Object?>[label, data]);
              return returns;
            },
    ),
  );
}

void _registerFactoryPair(
  OscParser parser,
  List<Object?> reports, {
  required bool asynchronous,
}) {
  _registerFactory(
    parser,
    reports,
    returns: true,
    asynchronous: asynchronous,
    label: 'one',
  );
  _registerFactory(
    parser,
    reports,
    returns: false,
    asynchronous: asynchronous,
    label: 'two',
  );
}

Future<void> _factoryDisposable(
  OscParser parser,
  List<Object?> reports, {
  required bool asynchronous,
}) async {
  _registerFactory(
    parser,
    reports,
    returns: true,
    asynchronous: asynchronous,
    label: 'one',
  );
  final second = OscHandler(
    asynchronous
        ? (data) async {
            reports.add(<Object?>['two', data]);
            return true;
          }
        : (data) {
            reports.add(<Object?>['two', data]);
            return true;
          },
  );
  final disposable = parser.registerHandler(_ident, second);
  _send(parser, 'Here comes', ' the mouse!');
  if (asynchronous) {
    await _end(parser, true);
  } else {
    _endSync(parser, true);
  }
  disposable.dispose();
  _send(parser, 'some other', ' data');
  if (asynchronous) {
    await _end(parser, true);
  } else {
    _endSync(parser, true);
  }
}

List<Object?> _singleReports(String name) => <Object?>[
  <Object?>[name, _ident, 'START'],
  <Object?>[name, _ident, 'PUT', 'Here comes'],
  <Object?>[name, _ident, 'PUT', 'the mouse!'],
  <Object?>[name, _ident, 'END', true],
];

List<Object?> _pairReports(bool bubbles) => <Object?>[
  <Object?>['th2', _ident, 'START'],
  <Object?>['th1', _ident, 'START'],
  <Object?>['th2', _ident, 'PUT', 'Here comes'],
  <Object?>['th1', _ident, 'PUT', 'Here comes'],
  <Object?>['th2', _ident, 'PUT', 'the mouse!'],
  <Object?>['th1', _ident, 'PUT', 'the mouse!'],
  <Object?>['th2', _ident, 'END', true],
  <Object?>['th1', _ident, 'END', bubbles],
];

List<Object?> _mixedReports(List<String> order, bool bubbles) => <Object?>[
  for (final name in order) <Object?>[name, _ident, 'START'],
  for (final name in order) <Object?>[name, _ident, 'PUT', 'Here comes'],
  for (final name in order) <Object?>[name, _ident, 'PUT', 'the mouse!'],
  <Object?>[order.first, _ident, 'END', true],
  for (final name in order.skip(1)) <Object?>[name, _ident, 'END', bubbles],
];

final List<Object?> _factoryPairReports = <Object?>[
  <Object?>['two', 'Here comes the mouse!'],
  <Object?>['one', 'Here comes the mouse!'],
];
