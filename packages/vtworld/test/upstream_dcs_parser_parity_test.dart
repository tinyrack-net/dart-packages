import 'dart:async';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:vtworld/src/core/dcs_parser.dart';
import 'package:vtworld/src/core/params.dart';

const _ident = 0x2B70;

void main() {
  late DcsParser parser;
  late List<Object?> reports;

  setUp(() {
    reports = <Object?>[];
    parser = DcsParser()
      ..setHandlerFallback((identifier, action, [payload]) {
        final normalizedPayload = payload is Params
            ? payload.toArray()
            : payload;
        reports.add(<Object?>[identifier, action, normalizedPayload]);
      });
  });

  group('DcsParser', () {
    group('handler registration', () {
      test('setDcsHandler', () {
        parser.registerHandler(_ident, _TestHandler(reports, 'th'));
        _send(parser, 'Here comes', 'the mouse!');
        _unhookSync(parser, true);
        expect(reports, _singleReports('th'));
      });

      test('clearDcsHandler', () {
        parser
          ..registerHandler(_ident, _TestHandler(reports, 'th'))
          ..clearHandler(_ident);
        _send(parser, 'Here comes', 'the mouse!');
        _unhookSync(parser, true);
        expect(reports, <Object?>[
          <Object?>[
            _ident,
            'HOOK',
            <Object>[1, 2, 3],
          ],
          <Object?>[_ident, 'PUT', 'Here comes'],
          <Object?>[_ident, 'PUT', 'the mouse!'],
          <Object?>[_ident, 'UNHOOK', true],
        ]);
      });

      test('addDcsHandler', () {
        _registerPair(parser, reports, bubbles: false);
        _send(parser, 'Here comes', 'the mouse!');
        _unhookSync(parser, true);
        expect(reports, _pairReports(false));
      });

      test('addDcsHandler with return false', () {
        _registerPair(parser, reports, bubbles: true);
        _send(parser, 'Here comes', 'the mouse!');
        _unhookSync(parser, true);
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
        _unhookSync(parser, true);
        expect(reports, _singleReports('th1'));
      });
    });

    group('DcsHandlerFactory', () {
      late int originalPayloadLimit;

      setUp(() {
        originalPayloadLimit = DcsHandler.payloadLimit;
        DcsHandler.payloadLimit = 100;
      });
      tearDown(() => DcsHandler.payloadLimit = originalPayloadLimit);

      test('should be called once on end(true)', () {
        _registerFactory(parser, reports, returns: true);
        _send(parser, 'Here comes', ' the mouse!');
        _unhookSync(parser, true);
        expect(reports, <Object?>[
          <Object?>[
            <Object>[1, 2, 3],
            'Here comes the mouse!',
          ],
        ]);
      });

      test('should not be called on end(false)', () {
        _registerFactory(parser, reports, returns: true);
        _send(parser, 'Here comes', ' the mouse!');
        _unhookSync(parser, false);
        expect(reports, isEmpty);
      });

      test('should be disposable', () async {
        await _factoryDisposableScenario(parser, reports, asynchronous: false);
        expect(reports, <Object?>[
          <Object?>[
            'two',
            <Object>[1, 2, 3],
            'Here comes the mouse!',
          ],
          <Object?>[
            'one',
            <Object>[1, 2, 3],
            'some other data',
          ],
        ]);
      });

      test('should respect return false', () {
        _registerFactoryPair(parser, reports, asynchronous: false);
        _send(parser, 'Here comes', ' the mouse!');
        _unhookSync(parser, true);
        expect(reports, _factoryPairReports);
      });

      test('should work up to payload limit', () {
        _registerFactory(parser, reports, returns: true);
        _sendLimit(parser, extra: false);
        _unhookSync(parser, true);
        expect(reports, <Object?>[
          <Object?>[
            <Object>[1, 2, 3],
            'A' * 100,
          ],
        ]);
      });

      test('should abort for payload limit +1', () {
        _registerFactory(parser, reports, returns: true);
        _sendLimit(parser, extra: true);
        _unhookSync(parser, true);
        expect(reports, isEmpty);
      });
    });
  });

  group('DcsParser - async tests', () {
    group('sync and async mixed', () {
      group('sync | async | sync', () {
        test('first should run, cleanup action for others', () async {
          _registerMixed(parser, reports, asyncOutside: false, bubbles: false);
          _send(parser, 'Here comes', 'the mouse!');
          await _unhook(parser, true);
          expect(reports, _mixedReports(<String>['s2', 'a1', 's1'], false));
        });

        test('all should run', () async {
          _registerMixed(parser, reports, asyncOutside: false, bubbles: true);
          _send(parser, 'Here comes', 'the mouse!');
          await _unhook(parser, true);
          expect(reports, _mixedReports(<String>['s2', 'a1', 's1'], true));
        });
      });

      group('async | sync | async', () {
        test('first should run, cleanup action for others', () async {
          _registerMixed(parser, reports, asyncOutside: true, bubbles: false);
          _send(parser, 'Here comes', 'the mouse!');
          await _unhook(parser, true);
          expect(reports, _mixedReports(<String>['a2', 's1', 'a1'], false));
        });

        test('all should run', () async {
          _registerMixed(parser, reports, asyncOutside: true, bubbles: true);
          _send(parser, 'Here comes', 'the mouse!');
          await _unhook(parser, true);
          expect(reports, _mixedReports(<String>['a2', 's1', 'a1'], true));
        });
      });

      group('DcsHandlerFactory', () {
        test('should be called once on end(true)', () async {
          _registerFactory(parser, reports, returns: true, asynchronous: true);
          _send(parser, 'Here comes', ' the mouse!');
          await _unhook(parser, true);
          expect(reports, <Object?>[
            <Object?>[
              <Object>[1, 2, 3],
              'Here comes the mouse!',
            ],
          ]);
        });

        test('should not be called on end(false)', () async {
          _registerFactory(parser, reports, returns: true, asynchronous: true);
          _send(parser, 'Here comes', ' the mouse!');
          await _unhook(parser, false);
          expect(reports, isEmpty);
        });

        test('should be disposable', () async {
          await _factoryDisposableScenario(parser, reports, asynchronous: true);
          expect(reports, <Object?>[
            <Object?>[
              'two',
              <Object>[1, 2, 3],
              'Here comes the mouse!',
            ],
            <Object?>[
              'one',
              <Object>[1, 2, 3],
              'some other data',
            ],
          ]);
        });

        test('should respect return false', () async {
          _registerFactoryPair(parser, reports, asynchronous: true);
          _send(parser, 'Here comes', ' the mouse!');
          await _unhook(parser, true);
          expect(reports, _factoryPairReports);
        });
      });
    });

    group('reset', () {
      test(
        // Pinned upstream test identity.
        // ignore: lines_longer_than_80_chars
        'should abort active handlers with unhook(false) when reset during payload',
        () {
          parser
            ..registerHandler(_ident, _TestHandler(reports, 'th'))
            ..hook(_ident, _params());
          final partial = _utf32('partial');
          parser
            ..put(partial, 0, partial.length)
            ..reset();
          expect(reports, <Object?>[
            <Object?>[
              'th',
              'HOOK',
              <Object>[1, 2, 3],
            ],
            <Object?>['th', 'PUT', 'partial'],
            <Object?>['th', 'UNHOOK', false],
          ]);
          reports.clear();
          parser.hook(_ident, _params());
          final complete = _utf32('complete');
          parser.put(complete, 0, complete.length);
          _unhookSync(parser, true);
          expect(reports, <Object?>[
            <Object?>[
              'th',
              'HOOK',
              <Object>[1, 2, 3],
            ],
            <Object?>['th', 'PUT', 'complete'],
            <Object?>['th', 'UNHOOK', true],
          ]);
        },
      );
    });
  });
}

class _TestHandler implements DcsSubHandler {
  _TestHandler(this.output, this.message, {this.returnFalse = false});

  final List<Object?> output;
  final String message;
  final bool returnFalse;

  @override
  void hook(Params params) =>
      output.add(<Object?>[message, 'HOOK', params.toArray()]);

  @override
  void put(Uint32List data, int start, int end) => output.add(<Object?>[
    message,
    'PUT',
    String.fromCharCodes(data, start, end),
  ]);

  @override
  FutureOr<bool> unhook(bool success) {
    output.add(<Object?>[message, 'UNHOOK', success]);
    return !returnFalse;
  }
}

final class _AsyncTestHandler extends _TestHandler {
  _AsyncTestHandler(super.output, super.message, {super.returnFalse});

  @override
  Future<bool> unhook(bool success) async {
    await Future<void>.value();
    output.add(<Object?>[message, 'UNHOOK', success]);
    return !returnFalse;
  }
}

Params _params() => Params.fromArray(<Object>[1, 2, 3]);

Uint32List _utf32(String value) => Uint32List.fromList(value.runes.toList());

void _send(DcsParser parser, String first, String second) {
  parser.hook(_ident, _params());
  final firstData = _utf32(first);
  parser.put(firstData, 0, firstData.length);
  final secondData = _utf32(second);
  parser.put(secondData, 0, secondData.length);
}

void _sendLimit(DcsParser parser, {required bool extra}) {
  parser.hook(_ident, _params());
  final chunk = _utf32('A' * 10);
  for (var index = 0; index < 100; index += 10) {
    parser.put(chunk, 0, chunk.length);
  }
  if (extra) {
    final last = _utf32('A');
    parser.put(last, 0, last.length);
  }
}

void _unhookSync(DcsParser parser, bool success) {
  if (parser.unhook(success) != null) {
    throw StateError('Expected a synchronous DCS handler');
  }
}

Future<void> _unhook(DcsParser parser, bool success) async {
  var previous = true;
  while (true) {
    final pending = parser.unhook(success, promiseResult: previous);
    if (pending == null) return;
    previous = await pending;
  }
}

void _registerPair(
  DcsParser parser,
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
  DcsParser parser,
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
  DcsParser parser,
  List<Object?> reports, {
  required bool returns,
  bool asynchronous = false,
  String? label,
}) {
  if (asynchronous) {
    parser.registerHandler(
      _ident,
      DcsHandler((data, params) async {
        reports.add(<Object?>[?label, params.toArray(), data]);
        return returns;
      }),
    );
  } else {
    parser.registerHandler(
      _ident,
      DcsHandler((data, params) {
        reports.add(<Object?>[?label, params.toArray(), data]);
        return returns;
      }),
    );
  }
}

void _registerFactoryPair(
  DcsParser parser,
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

Future<void> _factoryDisposableScenario(
  DcsParser parser,
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
  final second = asynchronous
      ? DcsHandler((data, params) async {
          reports.add(<Object?>['two', params.toArray(), data]);
          return true;
        })
      : DcsHandler((data, params) {
          reports.add(<Object?>['two', params.toArray(), data]);
          return true;
        });
  final disposable = parser.registerHandler(_ident, second);
  _send(parser, 'Here comes', ' the mouse!');
  if (asynchronous) {
    await _unhook(parser, true);
  } else {
    _unhookSync(parser, true);
  }
  disposable.dispose();
  _send(parser, 'some other', ' data');
  if (asynchronous) {
    await _unhook(parser, true);
  } else {
    _unhookSync(parser, true);
  }
}

List<Object?> _singleReports(String name) => <Object?>[
  <Object?>[
    name,
    'HOOK',
    <Object>[1, 2, 3],
  ],
  <Object?>[name, 'PUT', 'Here comes'],
  <Object?>[name, 'PUT', 'the mouse!'],
  <Object?>[name, 'UNHOOK', true],
];

List<Object?> _pairReports(bool bubbles) => <Object?>[
  <Object?>[
    'th2',
    'HOOK',
    <Object>[1, 2, 3],
  ],
  <Object?>[
    'th1',
    'HOOK',
    <Object>[1, 2, 3],
  ],
  <Object?>['th2', 'PUT', 'Here comes'],
  <Object?>['th1', 'PUT', 'Here comes'],
  <Object?>['th2', 'PUT', 'the mouse!'],
  <Object?>['th1', 'PUT', 'the mouse!'],
  <Object?>['th2', 'UNHOOK', true],
  <Object?>['th1', 'UNHOOK', bubbles],
];

List<Object?> _mixedReports(List<String> order, bool bubbles) => <Object?>[
  for (final name in order)
    <Object?>[
      name,
      'HOOK',
      <Object>[1, 2, 3],
    ],
  for (final name in order) <Object?>[name, 'PUT', 'Here comes'],
  for (final name in order) <Object?>[name, 'PUT', 'the mouse!'],
  <Object?>[order.first, 'UNHOOK', true],
  for (final name in order.skip(1)) <Object?>[name, 'UNHOOK', bubbles],
];

final List<Object?> _factoryPairReports = <Object?>[
  <Object?>[
    'two',
    <Object>[1, 2, 3],
    'Here comes the mouse!',
  ],
  <Object?>[
    'one',
    <Object>[1, 2, 3],
    'Here comes the mouse!',
  ],
];
