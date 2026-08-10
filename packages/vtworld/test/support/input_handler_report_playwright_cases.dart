import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

Future<void> verifyInputHandlerReportPlaywrightCase(String name) async {
  final light = name.contains('(light theme)');
  final disabled = name.contains('disabled via');
  final terminal = Terminal(
    options: TerminalOptions(
      theme: light
          ? const TerminalColorTheme(
              foreground: '#000000',
              background: '#ffffff',
            )
          : const TerminalColorTheme(),
      vtExtensions: TerminalVtExtensions(colorSchemeQuery: !disabled),
      windowOptions: TerminalWindowOptions(
        getWinSizePixels: name == '14 - GetWinSizePixels',
        getCellSizePixels: name == '16 - GetCellSizePixels',
      ),
    ),
  );
  addTearDown(terminal.dispose);
  final data = <String>[];
  terminal.onData.listen(data.add);
  if (name == 'CSI Ps c - ') {
    await terminal.writeAndWait('\x1b[c');
    return expect(data, <String>['\x1b[?1;2c']);
  }
  if (name == 'CSI > Ps c - ') {
    await terminal.writeAndWait('\x1b[>c');
    return expect(data, <String>['\x1b[>0;276;0c']);
  }
  if (name == 'CSI = Ps c - ') {
    await terminal.writeAndWait('\x1b[=c');
    return expect(data, isEmpty);
  }
  if (name.contains('XTVERSION')) {
    await terminal.writeAndWait('\x1b[>q');
    return expect(data, <String>['\x1bP>|xterm.js(6.0.0)\x1b\\']);
  }
  if (name.startsWith('Status Report')) {
    await terminal.writeAndWait('\x1b[5n');
    return expect(data, <String>['\x1b[0n']);
  }
  if (name.startsWith('Report Cursor Position')) {
    final dec = name.contains('DECXCPR');
    await terminal.writeAndWait('\n\nfoo${dec ? '\x1b[?6n' : '\x1b[6n'}');
    final expected = dec ? '\x1b[?3;4R' : '\x1b[3;4R';
    return expect(data, <String>[expected]);
  }
  if (name.startsWith('Color Scheme Query')) {
    await terminal.writeAndWait('\x1b[?996n');
    if (disabled) {
      return expect(data, isEmpty);
    }
    return expect(data, <String>['\x1b[?997;${light ? 2 : 1}n']);
  }
  if (name == 'should be disabled by default') {
    await terminal.writeAndWait('\x1b[14t\x1b[16t\x1b[18t\x1b[20t\x1b[21t');
    return expect(data, isEmpty);
  }
  if (name == '14 - GetWinSizePixels' || name == '16 - GetCellSizePixels') {
    terminal.updateDimensions(
      const TerminalRenderDimensions(
        width: 800,
        height: 480,
        cellWidth: 10,
        cellHeight: 20,
        devicePixelRatio: 1,
      ),
    );
    await terminal.writeAndWait(
      name.startsWith('14') ? '\x1b[14t' : '\x1b[16t',
    );
    final expected = name.startsWith('14')
        ? '\x1b[4;480;800t'
        : '\x1b[6;20;10t';
    return expect(data, <String>[expected]);
  }
  throw StateError('unhandled report Playwright case: $name');
}
