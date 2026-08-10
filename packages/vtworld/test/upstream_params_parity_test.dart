import 'package:test/test.dart';
import 'package:vtworld/src/core/params.dart';

void main() {
  group('Params', () {
    test('should respect ctor args', () {
      final params = Params(maxLength: 12, maxSubParamsLength: 23);
      expect(params.params.length, 12);
      expect(params.subParams.length, 23);
      expect(params.toArray(), isEmpty);
    });

    test('addParam', () {
      final params = Params()..addParam(1);
      expect(params.length, 1);
      expect(params.toArray(), <Object>[1]);
      params.addParam(23);
      expect(params.length, 2);
      expect(params.toArray(), <Object>[1, 23]);
      expect(params.subParamsLength, 0);
    });

    test('addSubParam', () {
      final params = Params()
        ..addParam(1)
        ..addSubParam(2)
        ..addSubParam(3);
      expect(params.length, 1);
      expect(params.subParamsLength, 2);
      expect(params.toArray(), <Object>[
        1,
        <int>[2, 3],
      ]);
      params
        ..addParam(12345)
        ..addSubParam(-1);
      expect(params.length, 2);
      expect(params.subParamsLength, 3);
      expect(params.toArray(), <Object>[
        1,
        <int>[2, 3],
        12345,
        <int>[-1],
      ]);
    });

    test('should not add sub params without previous param', () {
      final params = Params()
        ..addSubParam(2)
        ..addSubParam(3);
      expect(params.length, 0);
      expect(params.subParamsLength, 0);
      expect(params.toArray(), isEmpty);
      params
        ..addParam(1)
        ..addSubParam(2)
        ..addSubParam(3);
      expect(params.toArray(), <Object>[
        1,
        <int>[2, 3],
      ]);
    });

    test('reset', () {
      final params = Params()
        ..addParam(1)
        ..addSubParam(2)
        ..addSubParam(3)
        ..addParam(12345)
        ..addSubParam(-1)
        ..reset();
      expect(params.length, 0);
      expect(params.subParamsLength, 0);
      expect(params.toArray(), isEmpty);
      params
        ..addParam(1)
        ..addSubParam(2)
        ..addSubParam(3)
        ..addParam(12345)
        ..addSubParam(-1);
      expect(params.toArray(), <Object>[
        1,
        <int>[2, 3],
        12345,
        <int>[-1],
      ]);
    });

    test('Params.fromArray --> toArray', () {
      final cases = <List<Object>>[
        <Object>[],
        <Object>[
          1,
          <int>[2, 3],
          12345,
          <int>[-1],
        ],
        <Object>[38, 2, 50, 100, 150],
        <Object>[
          38,
          2,
          50,
          100,
          <int>[150],
        ],
        <Object>[
          38,
          <int>[2, 50, 100, 150],
        ],
      ];
      for (final values in cases) {
        expect(Params.fromArray(values).toArray(), values);
      }
      expect(
        Params.fromArray(<Object>[
          38,
          <int>[2, 50, 100, 150],
          5,
          <int>[],
          6,
        ]).toArray(),
        <Object>[
          38,
          <int>[2, 50, 100, 150],
          5,
          6,
        ],
      );
    });

    test('clone', () {
      final params = Params.fromArray(<Object>[
        38,
        <int>[2, 50, 100, 150],
        5,
        <int>[],
        6,
        1,
        <int>[2, 3],
        12345,
        <int>[-1],
      ]);
      final clone = params.clone();
      expect(clone.toArray(), params.toArray());
      expect(clone.maxLength, params.maxLength);
      expect(clone.maxSubParamsLength, params.maxSubParamsLength);
    });

    test('hasSubParams / getSubParams', () {
      final params = Params.fromArray(<Object>[
        38,
        <int>[2, 50, 100, 150],
        5,
        <int>[],
        6,
      ]);
      expect(params.hasSubParams(0), isTrue);
      expect(params.getSubParams(0), <int>[2, 50, 100, 150]);
      expect(params.hasSubParams(1), isFalse);
      expect(params.getSubParams(1), isNull);
      expect(params.hasSubParams(2), isFalse);
      expect(params.getSubParams(2), isNull);
    });

    test('getSubParamsAll', () {
      final params = Params.fromArray(<Object>[
        1,
        <int>[2, 3],
        7,
        12345,
        <int>[-1],
      ]);
      expect(params.getSubParamsAll(), <int, List<int>>{
        0: <int>[2, 3],
        2: <int>[-1],
      });
    });

    group('parse tests', () {
      test('param defaults to 0 (ZDM - zero default mode)', () {
        final params = Params();
        _parse(params, '');
        expect(params.toArray(), <Object>[0]);
      });
      test('sub param defaults to -1', () {
        final params = Params();
        _parse(params, ':');
        expect(params.toArray(), <Object>[
          0,
          <int>[-1],
        ]);
      });
      test('should correctly reset on new sequence', () {
        final params = Params();
        _parse(params, '1;2;3');
        expect(params.toArray(), <Object>[1, 2, 3]);
        _parse(params, '4');
        expect(params.toArray(), <Object>[4]);
        _parse(params, '4::123:5;6;7');
        expect(params.toArray(), <Object>[
          4,
          <int>[-1, 123, 5],
          6,
          7,
        ]);
        _parse(params, '');
        expect(params.toArray(), <Object>[0]);
      });
      test('should handle length restrictions correctly', () {
        final params = Params(maxLength: 3, maxSubParamsLength: 3);
        _parse(params, '1;2;3;4;5;6;7');
        expect(params.toArray(), <Object>[1, 2, 3]);
        _parse(params, '4;38:2::50:100:150;48:5:22');
        expect(params.toArray(), <Object>[
          4,
          38,
          <int>[2, -1, 50],
          48,
        ]);
      });
      test('typical sequences', () {
        final params = Params();
        _parse(params, '0;4;38;2;50;100;150;48;5;22');
        expect(params.toArray(), <Object>[
          0,
          4,
          38,
          2,
          50,
          100,
          150,
          48,
          5,
          22,
        ]);
        _parse(params, '0;4;38;2;50:100:150;48;5:22');
        expect(params.toArray(), <Object>[
          0,
          4,
          38,
          2,
          50,
          <int>[100, 150],
          48,
          5,
          <int>[22],
        ]);
        _parse(params, '0;4;38:2::50:100:150;48:5:22');
        expect(params.toArray(), <Object>[
          0,
          4,
          38,
          <int>[2, -1, 50, 100, 150],
          48,
          <int>[5, 22],
        ]);
      });
    });

    group('should not overflow to negative', () {
      test('reject params lesser -1', () {
        final params = Params()..addParam(-1);
        expect(() => params.addParam(-2), throwsArgumentError);
      });
      test('reject subparams lesser -1', () {
        final params = Params()
          ..addParam(-1)
          ..addSubParam(-1);
        expect(() => params.addSubParam(-2), throwsArgumentError);
        expect(params.toArray(), <Object>[
          -1,
          <int>[-1],
        ]);
      });
      test('clamp parsed params', () {
        final params = Params();
        _parse(params, '2147483648');
        expect(params.toArray(), <Object>[0x7fffffff]);
      });
      test('clamp parsed subparams', () {
        final params = Params();
        _parse(params, ':2147483648');
        expect(params.toArray(), <Object>[
          0,
          <int>[0x7fffffff],
        ]);
      });
    });

    group('issue 2389', () {
      test('should cancel subdigits if beyond params limit', () {
        final params = Params();
        _parse(
          params,
          ';;;;;;;;;10;;;;;;;;;;20;;;;;;;;;;30;31;32;33;34;35::::::::',
        );
        expect(params.toArray(), <Object>[
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          10,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          20,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          30,
          31,
          32,
        ]);
      });
      test('should carry forward isSub state', () {
        final params = Params();
        _parse(params, <String>['1:22:33', '44']);
        expect(params.toArray(), <Object>[
          1,
          <int>[22, 3344],
        ]);
      });
    });
  });
}

void _parse(Params params, Object source) {
  params
    ..reset()
    ..addParam(0);
  final chunks = source is String ? <String>[source] : source as List<String>;
  for (final chunk in chunks) {
    for (final code in chunk.codeUnits) {
      switch (code) {
        case 0x3b:
          params.addParam(0);
        case 0x3a:
          params.addSubParam(-1);
        default:
          params.addDigit(code - 48);
      }
    }
  }
}
