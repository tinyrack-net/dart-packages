import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  group('evaluatePastedTextProcessing', () {
    test(
      'should replace carriage return and/or line feed with carriage return',
      () {
        expect(prepareTextForTerminal('foo\nbar\n'), 'foo\rbar\r');
        expect(prepareTextForTerminal('foo\r\nbar\r\n'), 'foo\rbar\r');
      },
    );

    test('should bracket pasted text in bracketedPasteMode', () {
      expect(
        bracketTextForPaste('foo bar', bracketedPasteMode: false),
        'foo bar',
      );
      expect(
        bracketTextForPaste('foo bar', bracketedPasteMode: true),
        '\u001b[200~foo bar\u001b[201~',
      );
    });

    test(
      // Exact upstream test title is intentionally preserved for parity.
      // ignore: lines_longer_than_80_chars
      'should escape embedded escape sequences in pasted text only when bracketed',
      () {
        const text = '\u001b[201~foo\u001b[200~bar';
        expect(bracketTextForPaste(text, bracketedPasteMode: false), text);
        expect(
          bracketTextForPaste(text, bracketedPasteMode: true),
          '\u001b[200~␛[201~foo␛[200~bar\u001b[201~',
        );
      },
    );
  });
}
