import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  group('RendererUtils', () {
    test('computeNextVariantOffset', () {
      const cellWidth = 11;
      const doubleCellWidth = 22;
      for (final scenario in <(double, List<int>)>[
        (1, <int>[1, 0, 0, 0]),
        (2, <int>[3, 2, 0, 2]),
        (3, <int>[5, 4, 2, 0]),
      ]) {
        var offset = 0;
        final cells = <int>[
          cellWidth,
          cellWidth,
          doubleCellWidth,
          doubleCellWidth,
        ];
        for (var index = 0; index < cells.length; index++) {
          offset = computeNextVariantOffset(cells[index], scenario.$1, offset);
          expect(offset, scenario.$2[index]);
        }
      }
    });

    test('renderer glyph classifications and dimensions match xterm', () {
      expect(throwIfFalsy(1), 1);
      expect(() => throwIfFalsy(null), throwsStateError);
      expect(() => throwIfFalsy(false), throwsStateError);
      expect(() => throwIfFalsy(''), throwsStateError);
      expect(isPowerlineGlyph(0xe0a4), isTrue);
      expect(isPowerlineGlyph(0xe0a3), isFalse);
      expect(isPowerlineGlyph(0xe0d7), isFalse);
      expect(isRestrictedPowerlineGlyph(0xe0b0), isTrue);
      expect(isRestrictedPowerlineGlyph(0xe0af), isFalse);
      expect(isRestrictedPowerlineGlyph(0xe0b8), isFalse);
      expect(isRendererEmoji(0x1f600), isTrue);
      for (final codepoint in <int>[
        0x1f300,
        0x1f680,
        0x2600,
        0x2700,
        0xfe00,
        0x1f900,
        0x1f1e6,
      ]) {
        expect(isRendererEmoji(codepoint), isTrue);
      }
      expect(isRendererEmoji(0x100), isFalse);
      expect(treatGlyphAsBackgroundColor(0x2500), isTrue);
      expect(treatGlyphAsBackgroundColor(0x100), isFalse);
      expect(allowGlyphRescaling(0x100, 1, 20, 10), isTrue);
      expect(allowGlyphRescaling(null, 1, 20, 10), isFalse);
      expect(allowGlyphRescaling(0x100, 2, 20, 10), isFalse);
      expect(allowGlyphRescaling(0x100, 1, 15, 10), isFalse);
      expect(allowGlyphRescaling(0xff, 1, 20, 10), isFalse);
      expect(allowGlyphRescaling(0x1f600, 1, 20, 10), isFalse);
      expect(allowGlyphRescaling(0xe0a4, 1, 20, 10), isFalse);
      expect(allowGlyphRescaling(0xe000, 1, 20, 10), isFalse);
      final dimensions = createRenderDimensions();
      expect(dimensions.cssCanvas.width, 0);
      expect(dimensions.cssCell.height, 0);
      expect(dimensions.deviceCanvas.width, 0);
      expect(dimensions.deviceCell.height, 0);
      expect(dimensions.deviceCharacter.width, 0);
      expect(() => throwIfFalsy(0), throwsStateError);
    });
  });
}
