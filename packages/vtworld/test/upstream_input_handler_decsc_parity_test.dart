import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  group('InputHandler DECSC DECRC', () {
    test('saves and restores origin mode', () async {
      final terminal = Terminal();
      addTearDown(terminal.dispose);
      expect(terminal.modes.originMode, isFalse);
      await terminal.writeAndWait('\x1b[?6h\x1b7\x1b[?6l');
      expect(terminal.modes.originMode, isFalse);
      await terminal.writeAndWait('\x1b8');
      expect(terminal.modes.originMode, isTrue);
    });

    test('saves and restores wraparound mode', () async {
      final terminal = Terminal();
      addTearDown(terminal.dispose);
      expect(terminal.modes.wraparoundMode, isTrue);
      await terminal.writeAndWait('\x1b[?7l\x1b7\x1b[?7h');
      expect(terminal.modes.wraparoundMode, isTrue);
      await terminal.writeAndWait('\x1b8');
      expect(terminal.modes.wraparoundMode, isFalse);
    });
  });
}
