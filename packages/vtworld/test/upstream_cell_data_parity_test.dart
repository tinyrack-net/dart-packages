import 'package:test/test.dart';
import 'package:vtworld/src/core/buffer.dart';

void main() {
  group('CellData', () {
    group('attributesEquals', () {
      test('returns true for same attributes with different chars', () {
        final cells = _styledCells(
          TerminalUnderlineStyle.double,
          45,
          TerminalUnderlineStyle.double,
          45,
        );
        expect(cells.$1.attributesEqual(cells.$2), isTrue);
      });

      test('detects underline style changes', () {
        final cells = _styledCells(
          TerminalUnderlineStyle.double,
          45,
          TerminalUnderlineStyle.single,
          45,
        );
        expect(cells.$1.attributesEqual(cells.$2), isFalse);
      });

      test('detects underline color changes', () {
        final cells = _styledCells(
          TerminalUnderlineStyle.single,
          45,
          TerminalUnderlineStyle.single,
          46,
        );
        expect(cells.$1.attributesEqual(cells.$2), isFalse);
      });

      test('ignores underline variant offsets', () {
        final cells = _styledCells(
          TerminalUnderlineStyle.single,
          45,
          TerminalUnderlineStyle.single,
          45,
        );
        // Flutter's renderer has no underline variant offset; its absence is
        // the equivalent of xterm excluding that field from this comparison.
        expect(cells.$1.attributesEqual(cells.$2), isTrue);
      });

      test('ignores url ids', () {
        final line = TerminalBufferLine(2)
          ..setCell(0, 'A', 1, _attributes(45, hyperlinkId: 1))
          ..setCell(1, 'B', 1, _attributes(45, hyperlinkId: 2));
        expect(line.getCell(0)!.attributesEqual(line.getCell(1)!), isTrue);
      });
    });
  });
}

(TerminalCell, TerminalCell) _styledCells(
  TerminalUnderlineStyle firstStyle,
  int firstColor,
  TerminalUnderlineStyle secondStyle,
  int secondColor,
) {
  final line = TerminalBufferLine(2)
    ..setCell(0, 'A', 1, _attributes(firstColor, style: firstStyle))
    ..setCell(1, 'B', 1, _attributes(secondColor, style: secondStyle));
  return (line.getCell(0)!, line.getCell(1)!);
}

TerminalCellAttributes _attributes(
  int underlineColor, {
  TerminalUnderlineStyle style = TerminalUnderlineStyle.single,
  int hyperlinkId = 0,
}) => TerminalCellAttributes(
  foreground: const TerminalCellColor.palette(12),
  background: const TerminalCellColor.palette(2),
  underlineColor: TerminalCellColor.palette(underlineColor),
  bold: true,
  italic: true,
  underline: style,
  hyperlinkId: hyperlinkId,
);
