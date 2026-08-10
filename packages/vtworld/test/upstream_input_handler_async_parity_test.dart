import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  group('InputHandler async handlers', () {
    test('async CUP with CPR check', () async {
      final terminal = Terminal();
      addTearDown(terminal.dispose);
      final requested = <List<int>>[];
      final reported = <List<int>>[];
      terminal.parser.registerCsiHandler(
        const TerminalFunctionIdentifier(finalByte: 'H'),
        (parameters) async {
          requested.add(parameters.cast<int>());
          await Future<void>.value();
          return false;
        },
      );
      terminal.onData.listen((data) {
        final match = RegExp(r'\x1b\[(\d+);(\d+)R').firstMatch(data);
        if (match != null) {
          reported.add(<int>[
            int.parse(match.group(1)!),
            int.parse(match.group(2)!),
          ]);
        }
      });
      await terminal.writeAndWait('aaa\x1b[3;4H\x1b[6nbbb\x1b[6;8H\x1b[6n');
      expect(reported, requested);
    });

    test('async OSC between output', () async {
      final terminal = Terminal();
      addTearDown(terminal.dispose);
      terminal.parser.registerOscHandler(1000, (data) async {
        await Future<void>.value();
        expect(_lines(terminal), <String>['hello world!', '']);
        expect(data, 'some data');
        return true;
      });
      await terminal.writeAndWait(
        'hello world!\r\n\x1b]1000;some data\x07second line',
      );
      expect(_lines(terminal), <String>['hello world!', 'second line']);
    });

    test('async DCS between output', () async {
      final terminal = Terminal();
      addTearDown(terminal.dispose);
      terminal.parser.registerDcsHandler(
        const TerminalFunctionIdentifier(finalByte: 'a'),
        (data, parameters) async {
          await Future<void>.value();
          expect(_lines(terminal), <String>['hello world!', '']);
          expect(data, 'some data');
          expect(parameters.cast<int>(), <int>[1, 2]);
          return true;
        },
      );
      await terminal.writeAndWait(
        'hello world!\r\n\x1bP1;2asome data\x1b\\second line',
      );
      expect(_lines(terminal), <String>['hello world!', 'second line']);
    });
  });
}

List<String> _lines(Terminal terminal) => <String>[
  for (var row = 0; row < 2; row++)
    terminal.buffer.active.getLine(row)!.translateToString(trimRight: true),
];
