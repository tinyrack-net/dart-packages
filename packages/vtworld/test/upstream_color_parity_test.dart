import 'package:test/test.dart';
import 'package:vtworld/src/core/color.dart';

const _channels = <int>[
  0x00,
  0x10,
  0x20,
  0x30,
  0x40,
  0x50,
  0x60,
  0x70,
  0x80,
  0x90,
  0xa0,
  0xb0,
  0xc0,
  0xd0,
  0xe0,
  0xf0,
  0xff,
];

void main() {
  group('Color', () {
    group('channels', () {
      group('toCss', () {
        test('should convert an rgb array to css hex string', () {
          for (final value in _channels) {
            expect(
              channelsToCss(value, value, value),
              '#${toPaddedHex(value) * 3}',
            );
          }
        });
        test('should convert an rgba array to css hex string', () {
          for (final value in _channels) {
            expect(
              channelsToCss(value, value, value, value),
              '#${toPaddedHex(value) * 4}',
            );
          }
        });
      });
      group('toRgba', () {
        test('should convert an rgb array to an rgba number', () {
          for (final value in _channels) {
            expect(
              channelsToRgba(value, value, value),
              value * 0x1010100 + 0xff,
            );
          }
        });
        test('should convert an rgba array to an rgba number', () {
          for (final value in _channels) {
            expect(
              channelsToRgba(value, value, value, value),
              value * 0x1010101,
            );
          }
        });
      });
      group('toColor', () {
        test('should convert an rgb array to an IColor', () {
          for (final value in _channels) {
            _expectColor(
              channelsToColor(value, value, value),
              TerminalRgbaColor(
                '#${toPaddedHex(value) * 3}',
                value * 0x1010100 + 0xff,
              ),
            );
          }
        });
        test('should convert an rgba array to an IColor', () {
          for (final value in _channels) {
            _expectColor(
              channelsToColor(value, value, value, value),
              TerminalRgbaColor(
                '#${toPaddedHex(value) * 4}',
                value * 0x1010101,
              ),
            );
          }
        });
      });
    });

    group('color', () {
      test('should blend colors based on the alpha channel', () {
        for (final alpha in _channels) {
          final expected = alpha * 0x1010100 + 0xff;
          expect(
            blendColor(
              const TerminalRgbaColor('#000000', 0x000000ff),
              TerminalRgbaColor(
                '#FFFFFF${toPaddedHex(alpha)}',
                0xffffff00 | alpha,
              ),
            ).rgba,
            expected,
          );
        }
      });
      test('should make the color opaque', () {
        for (final value in _channels) {
          _expectColor(
            opaqueColor(TerminalRgbaColor('', value * 0x1010101)),
            TerminalRgbaColor(
              '#${toPaddedHex(value) * 3}',
              value * 0x1010100 + 0xff,
            ),
          );
        }
      });
      test('should return true for opaque colors', () {
        for (final css in <String>[
          '#000000',
          '#000000ff',
          '#808080',
          '#808080ff',
          '#ffffff',
          '#ffffffff',
        ]) {
          expect(isOpaqueColor(cssToColor(css)), isTrue);
        }
      });
      test('should return false for transparent colors', () {
        for (final rgb in <String>['000000', '808080', 'ffffff']) {
          for (final alpha in <String>['00', '80', 'fe']) {
            expect(isOpaqueColor(cssToColor('#$rgb$alpha')), isFalse);
          }
        }
      });
      test('should make the color transparent', () {
        final expected = <double, int>{
          0: 0x00,
          0.25: 0x40,
          0.5: 0x80,
          0.75: 0xbf,
          1: 0xff,
        };
        for (final entry in expected.entries) {
          expect(
            colorWithOpacity(cssToColor('#000000'), entry.key).rgba,
            entry.value,
          );
        }
      });
    });

    group('css', () {
      group('#rgb', () {
        test('should convert the #rgb format to an IColor', () {
          for (var value = 0; value < 16; value++) {
            final digit = value.toRadixString(16);
            _expectColor(
              cssToColor('#$digit$digit$digit'),
              channelsToColor(value * 17, value * 17, value * 17),
            );
          }
        });
      });
      group('#rgba', () {
        test('should convert the #rgb format to an IColor', () {
          for (var value = 0; value < 16; value++) {
            final digit = value.toRadixString(16);
            _expectColor(
              cssToColor('#$digit$digit$digit$digit'),
              channelsToColor(value * 17, value * 17, value * 17, value * 17),
            );
          }
        });
      });
      test('should convert the #rrggbb format to an IColor', () {
        for (final value in _channels) {
          final css = '#${toPaddedHex(value) * 3}';
          _expectColor(
            cssToColor(css),
            TerminalRgbaColor(css, value * 0x1010100 + 0xff),
          );
        }
      });
      test('should convert the #rrggbbaa format to an IColor', () {
        for (final value in _channels) {
          final css = '#${toPaddedHex(value) * 4}';
          _expectColor(
            cssToColor(css),
            TerminalRgbaColor(css, value * 0x1010101),
          );
        }
      });
      test('should convert the rgb() format to an IColor', () {
        expect(cssToColor('rgb(0, 0, 0)').rgba, 0x000000ff);
        expect(cssToColor('rgb(80, 0, 0)').rgba, 0x500000ff);
        expect(cssToColor('rgb(0, 80, 0)').rgba, 0x005000ff);
        expect(cssToColor('rgb(0, 0, 80)').rgba, 0x000050ff);
        expect(cssToColor('rgb(255, 255, 255)').rgba, 0xffffffff);
      });
      test('should convert the rgba() format to an IColor', () {
        expect(cssToColor('rgba(0, 0, 0, 0)').rgba, 0x00000000);
        expect(cssToColor('rgba(80, 0, 0, 0.5)').rgba, 0x50000080);
        expect(cssToColor('rgba(0, 80, 0, 0.5)').rgba, 0x00500080);
        expect(cssToColor('rgba(0, 0, 80, 0.5)').rgba, 0x00005080);
        expect(cssToColor('rgba(255, 255, 255, 1)').rgba, 0xffffffff);
      });
      test('should convert "transparent" to an IColor', () {
        _expectColor(
          cssToColor('transparent'),
          const TerminalRgbaColor('transparent', 0),
        );
      });
    });

    group('rgb', () {
      test('should calculate the relative luminance of the color', () {
        const expected = <String>[
          '0.0000',
          '0.0052',
          '0.0144',
          '0.0296',
          '0.0513',
          '0.0802',
          '0.1170',
          '0.1620',
          '0.2159',
          '0.2789',
          '0.3515',
          '0.4342',
          '0.5271',
          '0.6308',
          '0.7454',
          '0.8714',
          '1.0000',
        ];
        for (var index = 0; index < _channels.length; index++) {
          expect(
            relativeLuminance(_channels[index] * 0x010101).toStringAsFixed(4),
            expected[index],
          );
        }
      });
    });

    group('rgba', () {
      test('should blend colors based on the alpha channel', () {
        for (final alpha in _channels) {
          expect(
            blendRgba(0x000000ff, 0xffffff00 | alpha),
            alpha * 0x1010100 + 0xff,
          );
        }
      });
      test(
        // ignore: lines_longer_than_80_chars, pinned upstream test identity.
        'should return undefined if the color already meets the contrast ratio (black bg)',
        () {
          for (var ratio = 1; ratio <= 3; ratio++) {
            expect(
              ensureContrastRatio(0x000000ff, 0x606060ff, ratio.toDouble()),
              isNull,
            );
          }
        },
      );
      test(
        'should return a color that meets the contrast ratio (black bg)',
        () {
          const expected = <int>[
            0x707070ff,
            0x7f7f7fff,
            0x8c8c8cff,
            0x989898ff,
            0xa3a3a3ff,
            0xadadadff,
            0xb6b6b6ff,
            0xbebebeff,
            0xc5c5c5ff,
            0xd1d1d1ff,
            0xd6d6d6ff,
            0xdbdbdbff,
            0xe3e3e3ff,
            0xe9e9e9ff,
            0xeeeeeeff,
            0xf4f4f4ff,
            0xfafafaff,
            0xffffffff,
          ];
          for (var ratio = 4; ratio <= 21; ratio++) {
            expect(
              ensureContrastRatio(0x000000ff, 0x606060ff, ratio.toDouble()),
              expected[ratio - 4],
            );
          }
        },
      );
      test(
        // ignore: lines_longer_than_80_chars, pinned upstream test identity.
        'should return undefined if the color already meets the contrast ratio (white bg)',
        () {
          for (var ratio = 1; ratio <= 6; ratio++) {
            expect(
              ensureContrastRatio(0xffffffff, 0x606060ff, ratio.toDouble()),
              isNull,
            );
          }
        },
      );
      test(
        'should return a color that meets the contrast ratio (white bg)',
        () {
          const expected = <int>[
            0x565656ff,
            0x4d4d4dff,
            0x454545ff,
            0x3e3e3eff,
            0x373737ff,
            0x313131ff,
            0x313131ff,
            0x272727ff,
            0x232323ff,
            0x1f1f1fff,
            0x1b1b1bff,
            0x151515ff,
            0x101010ff,
            0x080808ff,
            0x000000ff,
          ];
          for (var ratio = 7; ratio <= 21; ratio++) {
            expect(
              ensureContrastRatio(0xffffffff, 0x606060ff, ratio.toDouble()),
              expected[ratio - 7],
            );
          }
        },
      );
      test('should convert an rgba number to an rgba array', () {
        for (final value in _channels) {
          expect(rgbaToChannels(value * 0x1010101), (
            value,
            value,
            value,
            value,
          ));
        }
      });
    });

    test('should convert numbers to 2-digit hex values', () {
      for (final value in _channels) {
        expect(toPaddedHex(value), value.toRadixString(16).padLeft(2, '0'));
      }
    });
    group('contrastRatio', () {
      test('should calculate the relative luminance of the color', () {
        expect(contrastRatio(0, 0), 1);
        expect(contrastRatio(0, 0.5), 11);
        expect(contrastRatio(0, 1), 21);
      });
      test('should work regardless of the parameter order', () {
        expect(contrastRatio(0, 1), 21);
        expect(contrastRatio(1, 0), 21);
      });
    });
  });
}

void _expectColor(TerminalRgbaColor actual, TerminalRgbaColor expected) {
  expect((actual.css, actual.rgba), (expected.css, expected.rgba));
}
