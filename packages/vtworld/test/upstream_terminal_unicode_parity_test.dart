import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  group('Terminal unicode pinned upstream corpus', () {
    test('unicode - combining characters café', _combiningCafe);
    test('unicode - combining characters café - end of line', _combiningAtEnd);
    test(
      'unicode - combining characters multiple combined é',
      _multipleCombining,
    );
    test(
      'unicode - combining characters multiple surrogate with combined',
      _multipleSurrogateCombining,
    );
    test(
      'unicode - fullwidth characters cursor movement even',
      _fullwidthCursorEven,
    );
    test(
      'unicode - fullwidth characters cursor movement odd',
      _fullwidthCursorOdd,
    );
    test(
      // Exact pinned identity must remain one literal for parity.
      // ignore: lines_longer_than_80_chars
      'unicode - fullwidth characters line of surrogate fullwidth with combining even',
      _surrogateFullwidthCombiningEven,
    );
    test(
      // Exact pinned identity must remain one literal for parity.
      // ignore: lines_longer_than_80_chars
      'unicode - fullwidth characters line of surrogate fullwidth with combining odd',
      _surrogateFullwidthCombiningOdd,
    );
    test('unicode - fullwidth characters line of ￥ even', _fullwidthLineEven);
    test('unicode - fullwidth characters line of ￥ odd', _fullwidthLineOdd);
    test(
      'unicode - fullwidth characters line of ￥ with combining even',
      _fullwidthCombiningEven,
    );
    test(
      'unicode - fullwidth characters line of ￥ with combining odd',
      _fullwidthCombiningOdd,
    );
    test(
      'unicode - surrogates 0xDC00-0xDC0F: 2 characters at last cell',
      () => _verifySurrogates(0xDC00, _SurrogateCase.lastCell),
    );
    test(
      'unicode - surrogates 0xDC00-0xDC0F: 2 characters per cell',
      () => _verifySurrogates(0xDC00, _SurrogateCase.perCell),
    );
    test(
      // Exact pinned identity must remain one literal for parity.
      // ignore: lines_longer_than_80_chars
      'unicode - surrogates 0xDC00-0xDC0F: 2 characters per cell over line end with autowrap',
      () => _verifySurrogates(0xDC00, _SurrogateCase.autowrap),
    );
    test(
      // Exact pinned identity must remain one literal for parity.
      // ignore: lines_longer_than_80_chars
      'unicode - surrogates 0xDC00-0xDC0F: 2 characters per cell over line end without autowrap',
      () => _verifySurrogates(0xDC00, _SurrogateCase.noWrap),
    );
    test(
      'unicode - surrogates 0xDC00-0xDC0F: splitted surrogates',
      () => _verifySurrogates(0xDC00, _SurrogateCase.splitWrites),
    );
    test(
      'unicode - surrogates 0xDC10-0xDC1F: 2 characters at last cell',
      () => _verifySurrogates(0xDC10, _SurrogateCase.lastCell),
    );
    test(
      'unicode - surrogates 0xDC10-0xDC1F: 2 characters per cell',
      () => _verifySurrogates(0xDC10, _SurrogateCase.perCell),
    );
    test(
      // Exact pinned identity must remain one literal for parity.
      // ignore: lines_longer_than_80_chars
      'unicode - surrogates 0xDC10-0xDC1F: 2 characters per cell over line end with autowrap',
      () => _verifySurrogates(0xDC10, _SurrogateCase.autowrap),
    );
    test(
      // Exact pinned identity must remain one literal for parity.
      // ignore: lines_longer_than_80_chars
      'unicode - surrogates 0xDC10-0xDC1F: 2 characters per cell over line end without autowrap',
      () => _verifySurrogates(0xDC10, _SurrogateCase.noWrap),
    );
    test(
      'unicode - surrogates 0xDC10-0xDC1F: splitted surrogates',
      () => _verifySurrogates(0xDC10, _SurrogateCase.splitWrites),
    );
    test(
      'unicode - surrogates 0xDC20-0xDC2F: 2 characters at last cell',
      () => _verifySurrogates(0xDC20, _SurrogateCase.lastCell),
    );
    test(
      'unicode - surrogates 0xDC20-0xDC2F: 2 characters per cell',
      () => _verifySurrogates(0xDC20, _SurrogateCase.perCell),
    );
    test(
      // Exact pinned identity must remain one literal for parity.
      // ignore: lines_longer_than_80_chars
      'unicode - surrogates 0xDC20-0xDC2F: 2 characters per cell over line end with autowrap',
      () => _verifySurrogates(0xDC20, _SurrogateCase.autowrap),
    );
    test(
      // Exact pinned identity must remain one literal for parity.
      // ignore: lines_longer_than_80_chars
      'unicode - surrogates 0xDC20-0xDC2F: 2 characters per cell over line end without autowrap',
      () => _verifySurrogates(0xDC20, _SurrogateCase.noWrap),
    );
    test(
      'unicode - surrogates 0xDC20-0xDC2F: splitted surrogates',
      () => _verifySurrogates(0xDC20, _SurrogateCase.splitWrites),
    );
    test(
      'unicode - surrogates 0xDC30-0xDC3F: 2 characters at last cell',
      () => _verifySurrogates(0xDC30, _SurrogateCase.lastCell),
    );
    test(
      'unicode - surrogates 0xDC30-0xDC3F: 2 characters per cell',
      () => _verifySurrogates(0xDC30, _SurrogateCase.perCell),
    );
    test(
      // Exact pinned identity must remain one literal for parity.
      // ignore: lines_longer_than_80_chars
      'unicode - surrogates 0xDC30-0xDC3F: 2 characters per cell over line end with autowrap',
      () => _verifySurrogates(0xDC30, _SurrogateCase.autowrap),
    );
    test(
      // Exact pinned identity must remain one literal for parity.
      // ignore: lines_longer_than_80_chars
      'unicode - surrogates 0xDC30-0xDC3F: 2 characters per cell over line end without autowrap',
      () => _verifySurrogates(0xDC30, _SurrogateCase.noWrap),
    );
    test(
      'unicode - surrogates 0xDC30-0xDC3F: splitted surrogates',
      () => _verifySurrogates(0xDC30, _SurrogateCase.splitWrites),
    );
    test(
      'unicode - surrogates 0xDC40-0xDC4F: 2 characters at last cell',
      () => _verifySurrogates(0xDC40, _SurrogateCase.lastCell),
    );
    test(
      'unicode - surrogates 0xDC40-0xDC4F: 2 characters per cell',
      () => _verifySurrogates(0xDC40, _SurrogateCase.perCell),
    );
    test(
      // Exact pinned identity must remain one literal for parity.
      // ignore: lines_longer_than_80_chars
      'unicode - surrogates 0xDC40-0xDC4F: 2 characters per cell over line end with autowrap',
      () => _verifySurrogates(0xDC40, _SurrogateCase.autowrap),
    );
    test(
      // Exact pinned identity must remain one literal for parity.
      // ignore: lines_longer_than_80_chars
      'unicode - surrogates 0xDC40-0xDC4F: 2 characters per cell over line end without autowrap',
      () => _verifySurrogates(0xDC40, _SurrogateCase.noWrap),
    );
    test(
      'unicode - surrogates 0xDC40-0xDC4F: splitted surrogates',
      () => _verifySurrogates(0xDC40, _SurrogateCase.splitWrites),
    );
    test(
      'unicode - surrogates 0xDC50-0xDC5F: 2 characters at last cell',
      () => _verifySurrogates(0xDC50, _SurrogateCase.lastCell),
    );
    test(
      'unicode - surrogates 0xDC50-0xDC5F: 2 characters per cell',
      () => _verifySurrogates(0xDC50, _SurrogateCase.perCell),
    );
    test(
      // Exact pinned identity must remain one literal for parity.
      // ignore: lines_longer_than_80_chars
      'unicode - surrogates 0xDC50-0xDC5F: 2 characters per cell over line end with autowrap',
      () => _verifySurrogates(0xDC50, _SurrogateCase.autowrap),
    );
    test(
      // Exact pinned identity must remain one literal for parity.
      // ignore: lines_longer_than_80_chars
      'unicode - surrogates 0xDC50-0xDC5F: 2 characters per cell over line end without autowrap',
      () => _verifySurrogates(0xDC50, _SurrogateCase.noWrap),
    );
    test(
      'unicode - surrogates 0xDC50-0xDC5F: splitted surrogates',
      () => _verifySurrogates(0xDC50, _SurrogateCase.splitWrites),
    );
    test(
      'unicode - surrogates 0xDC60-0xDC6F: 2 characters at last cell',
      () => _verifySurrogates(0xDC60, _SurrogateCase.lastCell),
    );
    test(
      'unicode - surrogates 0xDC60-0xDC6F: 2 characters per cell',
      () => _verifySurrogates(0xDC60, _SurrogateCase.perCell),
    );
    test(
      // Exact pinned identity must remain one literal for parity.
      // ignore: lines_longer_than_80_chars
      'unicode - surrogates 0xDC60-0xDC6F: 2 characters per cell over line end with autowrap',
      () => _verifySurrogates(0xDC60, _SurrogateCase.autowrap),
    );
    test(
      // Exact pinned identity must remain one literal for parity.
      // ignore: lines_longer_than_80_chars
      'unicode - surrogates 0xDC60-0xDC6F: 2 characters per cell over line end without autowrap',
      () => _verifySurrogates(0xDC60, _SurrogateCase.noWrap),
    );
    test(
      'unicode - surrogates 0xDC60-0xDC6F: splitted surrogates',
      () => _verifySurrogates(0xDC60, _SurrogateCase.splitWrites),
    );
    test(
      'unicode - surrogates 0xDC70-0xDC7F: 2 characters at last cell',
      () => _verifySurrogates(0xDC70, _SurrogateCase.lastCell),
    );
    test(
      'unicode - surrogates 0xDC70-0xDC7F: 2 characters per cell',
      () => _verifySurrogates(0xDC70, _SurrogateCase.perCell),
    );
    test(
      // Exact pinned identity must remain one literal for parity.
      // ignore: lines_longer_than_80_chars
      'unicode - surrogates 0xDC70-0xDC7F: 2 characters per cell over line end with autowrap',
      () => _verifySurrogates(0xDC70, _SurrogateCase.autowrap),
    );
    test(
      // Exact pinned identity must remain one literal for parity.
      // ignore: lines_longer_than_80_chars
      'unicode - surrogates 0xDC70-0xDC7F: 2 characters per cell over line end without autowrap',
      () => _verifySurrogates(0xDC70, _SurrogateCase.noWrap),
    );
    test(
      'unicode - surrogates 0xDC70-0xDC7F: splitted surrogates',
      () => _verifySurrogates(0xDC70, _SurrogateCase.splitWrites),
    );
    test(
      'unicode - surrogates 0xDC80-0xDC8F: 2 characters at last cell',
      () => _verifySurrogates(0xDC80, _SurrogateCase.lastCell),
    );
    test(
      'unicode - surrogates 0xDC80-0xDC8F: 2 characters per cell',
      () => _verifySurrogates(0xDC80, _SurrogateCase.perCell),
    );
    test(
      // Exact pinned identity must remain one literal for parity.
      // ignore: lines_longer_than_80_chars
      'unicode - surrogates 0xDC80-0xDC8F: 2 characters per cell over line end with autowrap',
      () => _verifySurrogates(0xDC80, _SurrogateCase.autowrap),
    );
    test(
      // Exact pinned identity must remain one literal for parity.
      // ignore: lines_longer_than_80_chars
      'unicode - surrogates 0xDC80-0xDC8F: 2 characters per cell over line end without autowrap',
      () => _verifySurrogates(0xDC80, _SurrogateCase.noWrap),
    );
    test(
      'unicode - surrogates 0xDC80-0xDC8F: splitted surrogates',
      () => _verifySurrogates(0xDC80, _SurrogateCase.splitWrites),
    );
    test(
      'unicode - surrogates 0xDC90-0xDC9F: 2 characters at last cell',
      () => _verifySurrogates(0xDC90, _SurrogateCase.lastCell),
    );
    test(
      'unicode - surrogates 0xDC90-0xDC9F: 2 characters per cell',
      () => _verifySurrogates(0xDC90, _SurrogateCase.perCell),
    );
    test(
      // Exact pinned identity must remain one literal for parity.
      // ignore: lines_longer_than_80_chars
      'unicode - surrogates 0xDC90-0xDC9F: 2 characters per cell over line end with autowrap',
      () => _verifySurrogates(0xDC90, _SurrogateCase.autowrap),
    );
    test(
      // Exact pinned identity must remain one literal for parity.
      // ignore: lines_longer_than_80_chars
      'unicode - surrogates 0xDC90-0xDC9F: 2 characters per cell over line end without autowrap',
      () => _verifySurrogates(0xDC90, _SurrogateCase.noWrap),
    );
    test(
      'unicode - surrogates 0xDC90-0xDC9F: splitted surrogates',
      () => _verifySurrogates(0xDC90, _SurrogateCase.splitWrites),
    );
    test(
      'unicode - surrogates 0xDCA0-0xDCAF: 2 characters at last cell',
      () => _verifySurrogates(0xDCA0, _SurrogateCase.lastCell),
    );
    test(
      'unicode - surrogates 0xDCA0-0xDCAF: 2 characters per cell',
      () => _verifySurrogates(0xDCA0, _SurrogateCase.perCell),
    );
    test(
      // Exact pinned identity must remain one literal for parity.
      // ignore: lines_longer_than_80_chars
      'unicode - surrogates 0xDCA0-0xDCAF: 2 characters per cell over line end with autowrap',
      () => _verifySurrogates(0xDCA0, _SurrogateCase.autowrap),
    );
    test(
      // Exact pinned identity must remain one literal for parity.
      // ignore: lines_longer_than_80_chars
      'unicode - surrogates 0xDCA0-0xDCAF: 2 characters per cell over line end without autowrap',
      () => _verifySurrogates(0xDCA0, _SurrogateCase.noWrap),
    );
    test(
      'unicode - surrogates 0xDCA0-0xDCAF: splitted surrogates',
      () => _verifySurrogates(0xDCA0, _SurrogateCase.splitWrites),
    );
    test(
      'unicode - surrogates 0xDCB0-0xDCBF: 2 characters at last cell',
      () => _verifySurrogates(0xDCB0, _SurrogateCase.lastCell),
    );
    test(
      'unicode - surrogates 0xDCB0-0xDCBF: 2 characters per cell',
      () => _verifySurrogates(0xDCB0, _SurrogateCase.perCell),
    );
    test(
      // Exact pinned identity must remain one literal for parity.
      // ignore: lines_longer_than_80_chars
      'unicode - surrogates 0xDCB0-0xDCBF: 2 characters per cell over line end with autowrap',
      () => _verifySurrogates(0xDCB0, _SurrogateCase.autowrap),
    );
    test(
      // Exact pinned identity must remain one literal for parity.
      // ignore: lines_longer_than_80_chars
      'unicode - surrogates 0xDCB0-0xDCBF: 2 characters per cell over line end without autowrap',
      () => _verifySurrogates(0xDCB0, _SurrogateCase.noWrap),
    );
    test(
      'unicode - surrogates 0xDCB0-0xDCBF: splitted surrogates',
      () => _verifySurrogates(0xDCB0, _SurrogateCase.splitWrites),
    );
    test(
      'unicode - surrogates 0xDCC0-0xDCCF: 2 characters at last cell',
      () => _verifySurrogates(0xDCC0, _SurrogateCase.lastCell),
    );
    test(
      'unicode - surrogates 0xDCC0-0xDCCF: 2 characters per cell',
      () => _verifySurrogates(0xDCC0, _SurrogateCase.perCell),
    );
    test(
      // Exact pinned identity must remain one literal for parity.
      // ignore: lines_longer_than_80_chars
      'unicode - surrogates 0xDCC0-0xDCCF: 2 characters per cell over line end with autowrap',
      () => _verifySurrogates(0xDCC0, _SurrogateCase.autowrap),
    );
    test(
      // Exact pinned identity must remain one literal for parity.
      // ignore: lines_longer_than_80_chars
      'unicode - surrogates 0xDCC0-0xDCCF: 2 characters per cell over line end without autowrap',
      () => _verifySurrogates(0xDCC0, _SurrogateCase.noWrap),
    );
    test(
      'unicode - surrogates 0xDCC0-0xDCCF: splitted surrogates',
      () => _verifySurrogates(0xDCC0, _SurrogateCase.splitWrites),
    );
    test(
      'unicode - surrogates 0xDCD0-0xDCDF: 2 characters at last cell',
      () => _verifySurrogates(0xDCD0, _SurrogateCase.lastCell),
    );
    test(
      'unicode - surrogates 0xDCD0-0xDCDF: 2 characters per cell',
      () => _verifySurrogates(0xDCD0, _SurrogateCase.perCell),
    );
    test(
      // Exact pinned identity must remain one literal for parity.
      // ignore: lines_longer_than_80_chars
      'unicode - surrogates 0xDCD0-0xDCDF: 2 characters per cell over line end with autowrap',
      () => _verifySurrogates(0xDCD0, _SurrogateCase.autowrap),
    );
    test(
      // Exact pinned identity must remain one literal for parity.
      // ignore: lines_longer_than_80_chars
      'unicode - surrogates 0xDCD0-0xDCDF: 2 characters per cell over line end without autowrap',
      () => _verifySurrogates(0xDCD0, _SurrogateCase.noWrap),
    );
    test(
      'unicode - surrogates 0xDCD0-0xDCDF: splitted surrogates',
      () => _verifySurrogates(0xDCD0, _SurrogateCase.splitWrites),
    );
    test(
      'unicode - surrogates 0xDCE0-0xDCEF: 2 characters at last cell',
      () => _verifySurrogates(0xDCE0, _SurrogateCase.lastCell),
    );
    test(
      'unicode - surrogates 0xDCE0-0xDCEF: 2 characters per cell',
      () => _verifySurrogates(0xDCE0, _SurrogateCase.perCell),
    );
    test(
      // Exact pinned identity must remain one literal for parity.
      // ignore: lines_longer_than_80_chars
      'unicode - surrogates 0xDCE0-0xDCEF: 2 characters per cell over line end with autowrap',
      () => _verifySurrogates(0xDCE0, _SurrogateCase.autowrap),
    );
    test(
      // Exact pinned identity must remain one literal for parity.
      // ignore: lines_longer_than_80_chars
      'unicode - surrogates 0xDCE0-0xDCEF: 2 characters per cell over line end without autowrap',
      () => _verifySurrogates(0xDCE0, _SurrogateCase.noWrap),
    );
    test(
      'unicode - surrogates 0xDCE0-0xDCEF: splitted surrogates',
      () => _verifySurrogates(0xDCE0, _SurrogateCase.splitWrites),
    );
    test(
      'unicode - surrogates 0xDCF0-0xDCFF: 2 characters at last cell',
      () => _verifySurrogates(0xDCF0, _SurrogateCase.lastCell),
    );
    test(
      'unicode - surrogates 0xDCF0-0xDCFF: 2 characters per cell',
      () => _verifySurrogates(0xDCF0, _SurrogateCase.perCell),
    );
    test(
      // Exact pinned identity must remain one literal for parity.
      // ignore: lines_longer_than_80_chars
      'unicode - surrogates 0xDCF0-0xDCFF: 2 characters per cell over line end with autowrap',
      () => _verifySurrogates(0xDCF0, _SurrogateCase.autowrap),
    );
    test(
      // Exact pinned identity must remain one literal for parity.
      // ignore: lines_longer_than_80_chars
      'unicode - surrogates 0xDCF0-0xDCFF: 2 characters per cell over line end without autowrap',
      () => _verifySurrogates(0xDCF0, _SurrogateCase.noWrap),
    );
    test(
      'unicode - surrogates 0xDCF0-0xDCFF: splitted surrogates',
      () => _verifySurrogates(0xDCF0, _SurrogateCase.splitWrites),
    );
  });
}

enum _SurrogateCase { perCell, lastCell, autowrap, noWrap, splitWrites }

Future<void> _verifySurrogates(int lowStart, _SurrogateCase variant) async {
  final terminal = Terminal(options: TerminalOptions(rows: 40));
  try {
    final values = <String>[
      for (var low = lowStart; low <= lowStart + 0x0f; low++)
        String.fromCharCode(0x10000 + low - 0xdc00),
    ];
    switch (variant) {
      case _SurrogateCase.perCell:
        await terminal.writeAndWait(values.join('\r\n'));
        for (var index = 0; index < values.length; index++) {
          _expectCell(terminal, index, 0, values[index], 1);
          _expectCell(terminal, index, 1, '', 1);
        }
      case _SurrogateCase.lastCell:
        await terminal.writeAndWait(
          [
            for (var index = 0; index < values.length; index++)
              '\x1b[${index + 1};${terminal.cols}H${values[index]}',
          ].join(),
        );
        for (var index = 0; index < values.length; index++) {
          _expectCell(terminal, index, terminal.cols - 1, values[index], 1);
          _expectCell(terminal, index + 1, 0, '', 1);
        }
      case _SurrogateCase.autowrap:
        await terminal.writeAndWait(
          [
            for (var index = 0; index < values.length; index++)
              '\x1b[${index * 2 + 1};${terminal.cols}Ha${values[index]}',
          ].join(),
        );
        for (var index = 0; index < values.length; index++) {
          _expectCell(terminal, index * 2, terminal.cols - 1, 'a', 1);
          _expectCell(terminal, index * 2 + 1, 0, values[index], 1);
          _expectCell(terminal, index * 2 + 1, 1, '', 1);
        }
      case _SurrogateCase.noWrap:
        final writes = StringBuffer('\x1b[?7l');
        for (var index = 0; index < values.length; index++) {
          writes.write(
            _cursorWrite(index + 1, terminal.cols, 'a${values[index]}'),
          );
        }
        await terminal.writeAndWait(writes.toString());
        for (var index = 0; index < values.length; index++) {
          _expectCell(terminal, index, terminal.cols - 1, values[index], 1);
        }
      case _SurrogateCase.splitWrites:
        for (var index = 0; index < values.length; index++) {
          final units = values[index].codeUnits;
          await terminal.writeAndWait(String.fromCharCode(units[0]));
          await terminal.writeAndWait(String.fromCharCode(units[1]));
          if (index != values.length - 1) await terminal.writeAndWait('\r\n');
        }
        for (var index = 0; index < values.length; index++) {
          _expectCell(terminal, index, 0, values[index], 1);
          _expectCell(terminal, index, 1, '', 1);
        }
    }
  } finally {
    terminal.dispose();
  }
}

Future<void> _combiningCafe() async {
  final terminal = Terminal();
  try {
    await terminal.writeAndWait('cafe\u0301');
    _expectCell(terminal, 0, 3, 'e\u0301', 1);
  } finally {
    terminal.dispose();
  }
}

Future<void> _combiningAtEnd() async {
  final terminal = Terminal();
  try {
    await terminal.writeAndWait('\x1b[1;77Hcafe\u0301');
    _expectCell(terminal, 0, 79, 'e\u0301', 1);
    _expectCell(terminal, 0, 1, '', 1);
  } finally {
    terminal.dispose();
  }
}

Future<void> _multipleCombining() => _verifyRepeated('e\u0301', 1);

Future<void> _multipleSurrogateCombining() =>
    _verifyRepeated('${String.fromCharCode(0x10000)}\u0301', 1);

Future<void> _fullwidthCursorEven() async {
  final terminal = Terminal();
  try {
    await terminal.writeAndWait('￥');
    expect(terminal.buffer.active.cursorX, 2);
  } finally {
    terminal.dispose();
  }
}

Future<void> _fullwidthCursorOdd() async {
  final terminal = Terminal();
  try {
    await terminal.writeAndWait('\x1b[1;2H￥');
    expect(terminal.buffer.active.cursorX, 3);
  } finally {
    terminal.dispose();
  }
}

Future<void> _fullwidthLineEven() => _verifyWideLine('￥', odd: false);
Future<void> _fullwidthLineOdd() => _verifyWideLine('￥', odd: true);
Future<void> _fullwidthCombiningEven() =>
    _verifyWideLine('￥\u0301', odd: false);
Future<void> _fullwidthCombiningOdd() => _verifyWideLine('￥\u0301', odd: true);
Future<void> _surrogateFullwidthCombiningEven() =>
    _verifyWideLine('${String.fromCharCode(0x20e6d)}\u0301', odd: false);
Future<void> _surrogateFullwidthCombiningOdd() =>
    _verifyWideLine('${String.fromCharCode(0x20e6d)}\u0301', odd: true);

Future<void> _verifyRepeated(String value, int width) async {
  final terminal = Terminal();
  try {
    await terminal.writeAndWait(List<String>.filled(99, value).join());
    for (var column = 0; column < terminal.cols; column++) {
      _expectCell(terminal, 0, column, value, width);
    }
    _expectCell(terminal, 1, 0, value, width);
  } finally {
    terminal.dispose();
  }
}

Future<void> _verifyWideLine(String value, {required bool odd}) async {
  final terminal = Terminal();
  try {
    if (odd) await terminal.writeAndWait('\x1b[1;2H');
    await terminal.writeAndWait(List<String>.filled(49, value).join());
    final first = odd ? 1 : 0;
    final last = odd ? terminal.cols - 1 : terminal.cols;
    for (var column = first; column < last; column++) {
      if ((column - first).isOdd) {
        _expectCell(terminal, 0, column, '', 0);
      } else {
        _expectCell(terminal, 0, column, value, 2);
      }
    }
    if (odd) _expectCell(terminal, 0, terminal.cols - 1, '', 1);
    _expectCell(terminal, 1, 0, value, 2);
  } finally {
    terminal.dispose();
  }
}

void _expectCell(
  Terminal terminal,
  int row,
  int column,
  String chars,
  int width,
) {
  final cell = terminal.buffer.active.getLine(row)!.getCell(column)!;
  expect(cell.chars, chars);
  expect(cell.width, width);
}

String _cursorWrite(int row, int column, String value) =>
    '\x1b[$row;${column}H$value';
