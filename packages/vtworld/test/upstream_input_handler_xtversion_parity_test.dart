import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  group('InputHandler XTVERSION', () {
    test('reports xterm.js version', () async {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      await fixture.terminal.writeAndWait('\x1b[>q');
      expect(fixture.reports, <String>['\x1bP>|xterm.js(6.0.0)\x1b\\']);
    });

    test('reports xterm.js version for parameter zero', () async {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      await fixture.terminal.writeAndWait('\x1b[>0q');
      expect(fixture.reports, <String>['\x1bP>|xterm.js(6.0.0)\x1b\\']);
    });

    test('does not report for parameter one', () async {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      await fixture.terminal.writeAndWait('\x1b[>1q');
      expect(fixture.reports, isEmpty);
    });
  });
}

final class _Fixture {
  _Fixture() {
    _listener = terminal.onData.listen(reports.add);
  }

  final Terminal terminal = Terminal();
  final List<String> reports = <String>[];
  late final Disposable _listener;

  void dispose() {
    _listener.dispose();
    terminal.dispose();
  }
}
