import 'package:test/test.dart';
import 'package:vtworld/src/core/x_parse_color.dart';

void main() {
  group('XParseColor', () {
    group('parseColor', () {
      test('rgb:<r>/<g>/<b> scheme in 4/8/12/16 bit', _expectRgbSchemes);

      test('#RGB scheme in 4/8/12/16 bit', () {
        expect(parseXColor('#000'), (0, 0, 0));
        expect(parseXColor('#fff'), (240, 240, 240));
        expect(parseXColor('#123'), (16, 32, 48));
        expect(parseXColor('#000000'), (0, 0, 0));
        expect(parseXColor('#ffffff'), (255, 255, 255));
        expect(parseXColor('#112233'), (17, 34, 51));
        expect(parseXColor('#000000000'), (0, 0, 0));
        expect(parseXColor('#fffffffff'), (255, 255, 255));
        expect(parseXColor('#111222333'), (17, 34, 51));
        expect(parseXColor('#000000000000'), (0, 0, 0));
        expect(parseXColor('#ffffffffffff'), (255, 255, 255));
        expect(parseXColor('#111122223333'), (17, 34, 51));
      });

      test('supports upper case', () {
        expect(parseXColor('RGB:0/A/F'), (0, 170, 255));
        expect(parseXColor('#FFF'), (240, 240, 240));
      });

      test('does not parse illegal combinations', () {
        for (final value in <String>[
          'rgb:0/11/222',
          'rgbi:00/11/22',
          '#aabbbcc',
          '#aabbgg',
          'rgb:aa/bb/gg',
        ]) {
          expect(parseXColor(value), isNull);
        }
      });
    });

    group('toXColorRgb', () {
      test('rgb:<r>/<g>/<b> scheme in 4/8/12/16 bit', () {
        for (final bits in <int>[4, 8, 12, 16]) {
          final digits = bits ~/ 4;
          for (final value in <String>['0/0/0', 'f/f/f', '1/2/3']) {
            final channels = <String>[
              for (final channel in value.split('/')) channel * digits,
            ].join('/');
            final parsed = parseXColor('rgb:$channels')!;
            expect(toXColorRgb(parsed, bits: bits), 'rgb:$channels');
          }
        }
      });

      test('defaults to 16 bit output', () {
        expect(toXColorRgb(parseXColor('rgb:1/2/3')!), 'rgb:1111/2222/3333');
        expect(toXColorRgb(parseXColor('rgb:11/22/33')!), 'rgb:1111/2222/3333');
        expect(
          toXColorRgb(parseXColor('rgb:111/222/333')!),
          'rgb:1111/2222/3333',
        );
        expect(
          toXColorRgb(parseXColor('rgb:123/123/123')!),
          'rgb:1212/1212/1212',
        );
      });

      test('reduces colors to 8 bit resolution', () {
        expect(
          toXColorRgb(parseXColor('rgb:123/123/123')!, bits: 12),
          'rgb:121/121/121',
        );
        expect(
          toXColorRgb(parseXColor('rgb:1234/1234/1234')!),
          'rgb:1212/1212/1212',
        );
      });
    });
  });
}

void _expectRgbSchemes() {
  for (final data in <(String, (int, int, int))>[
    ('rgb:0/0/0', (0, 0, 0)),
    ('rgb:f/f/f', (255, 255, 255)),
    ('rgb:1/2/3', (17, 34, 51)),
    ('rgb:00/00/00', (0, 0, 0)),
    ('rgb:ff/ff/ff', (255, 255, 255)),
    ('rgb:11/22/33', (17, 34, 51)),
    ('rgb:000/000/000', (0, 0, 0)),
    ('rgb:fff/fff/fff', (255, 255, 255)),
    ('rgb:111/222/333', (17, 34, 51)),
    ('rgb:0000/0000/0000', (0, 0, 0)),
    ('rgb:ffff/ffff/ffff', (255, 255, 255)),
    ('rgb:1111/2222/3333', (17, 34, 51)),
  ]) {
    expect(parseXColor(data.$1), data.$2);
  }
}
