import 'package:test/test.dart';
import 'package:vtworld/src/core/charset_service.dart';

const _decSpecialGraphics = <int, int>{0x60: 0x25c6};

void main() {
  group('CharsetService', () {
    late CharsetService service;
    setUp(() => service = CharsetService());

    test(
      'should not update active charset when designating an inactive glevel',
      () {
        service.setGCharset(1, _decSpecialGraphics);
        expect(service.gLevel, 0);
        expect(service.charset, isNull);
      },
    );

    test('should expose the designated charset after setgLevel', () {
      service
        ..setGCharset(1, _decSpecialGraphics)
        ..setGLevel(1);
      expect(service.charset, same(_decSpecialGraphics));
    });

    test(
      'should update active charset when designating the current glevel',
      () {
        service
          ..setGLevel(1)
          ..setGCharset(1, _decSpecialGraphics);
        expect(service.charset, same(_decSpecialGraphics));
      },
    );

    test('should reset glevel, charsets, and active charset', () {
      service
        ..setGCharset(1, _decSpecialGraphics)
        ..setGLevel(1)
        ..reset();
      expect(service.gLevel, 0);
      expect(service.charsets, isEmpty);
      expect(service.charset, isNull);
    });
  });
}
