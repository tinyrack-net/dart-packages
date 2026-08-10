import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  test('xterm SerializeAddon unit 40', () async {
    final setup = _setup();
    await setup.terminal.writeAndWait(' <a>&pi; ');
    setup.terminal.select(1, 0, 7);
    expect(
      setup.addon.serializeAsHtml(
        options: const TerminalHtmlSerializeOptions(onlySelection: true),
      ),
      contains('<div><span>&lt;a>&amp;pi;</span></div>'),
    );
  });

  test('xterm SerializeAddon unit 41', () async {
    final setup = _setup();
    await setup.terminal.writeAndWait(' terminal ');
    setup.terminal.select(1, 0, 8);
    expect(
      setup.addon.serializeAsHtml(
        options: const TerminalHtmlSerializeOptions(onlySelection: true),
      ),
      contains('<div><span>terminal</span></div>'),
    );
  });

  test('xterm SerializeAddon unit 42', () async {
    expect(
      await _styledHtml('48;5;46'),
      contains("background-color: #00ff00;'>terminal"),
    );
  });

  test('xterm SerializeAddon unit 43', () async {
    expect(await _styledHtml('1'), contains("font-weight: bold;'>terminal"));
  });

  test('xterm SerializeAddon unit 44', () async {
    expect(await _styledHtml('38;5;46'), contains("color: #00ff00;'>terminal"));
  });

  test('xterm SerializeAddon unit 45', () async {
    expect(await _styledHtml('38;5;46'), contains("color: #00ff00;'>terminal"));
  });

  test('xterm SerializeAddon unit 46', () async {
    final setup = _setup();
    await setup.terminal.writeAndWait(
      '\u001b[1m \u001b[9mtermi\u001b[22mnal\u001b[29m ',
    );
    final html = setup.addon.serializeAsHtml();
    expect(html, contains("font-weight: bold;'> </span>"));
    expect(
      html,
      contains(
        "font-weight: bold; text-decoration: line-through;'>termi</span>",
      ),
    );
    expect(html, contains("text-decoration: line-through;'>nal</span>"));
  });

  test('xterm SerializeAddon unit 47', () async {
    expect(
      await _styledHtml('4:3'),
      contains("text-decoration: underline wavy;'>terminal"),
    );
  });

  test('xterm SerializeAddon unit 48', () async {
    final setup = _setup(theme: const TerminalColorTheme(black: '#ffa500'));
    await setup.terminal.writeAndWait(' \u001b[38;5;0mterminal\u001b[39m ');
    expect(
      setup.addon.serializeAsHtml(),
      contains("color: #ffa500;'>terminal"),
    );
  });

  test('xterm SerializeAddon unit 49', () async {
    expect(
      await _styledHtml('4:5'),
      contains("text-decoration: underline dashed;'>terminal"),
    );
  });

  test('xterm SerializeAddon unit 50', () async {
    expect(await _styledHtml('2'), contains("opacity: 0.5;'>terminal"));
  });

  test('xterm SerializeAddon unit 51', () async {
    expect(
      await _styledHtml('4:4'),
      contains("text-decoration: underline dotted;'>terminal"),
    );
  });

  test('xterm SerializeAddon unit 52', () async {
    expect(
      await _styledHtml('4:2'),
      contains("text-decoration: underline double;'>terminal"),
    );
  });

  test('xterm SerializeAddon unit 53', () async {
    expect(
      await _styledHtml('7'),
      contains("color: #000000; background-color: #BFBFBF;'>terminal"),
    );
  });

  test('xterm SerializeAddon unit 54', () async {
    expect(await _styledHtml('8'), contains("visibility: hidden;'>terminal"));
  });

  test('xterm SerializeAddon unit 55', () async {
    expect(await _styledHtml('3'), contains("font-style: italic;'>terminal"));
  });

  test('xterm SerializeAddon unit 56', () async {
    expect(
      await _styledHtml('9'),
      contains("text-decoration: line-through;'>terminal"),
    );
  });

  test('xterm SerializeAddon unit 57', () async {
    final html = await _styledHtml('4;58;2;255;128;64');
    expect(html, contains('text-decoration: underline;'));
    expect(html, contains('text-decoration-color: #ff8040;'));
  });

  test('xterm SerializeAddon unit 58', () async {
    final html = await _styledHtml('4;58;5;46');
    expect(html, contains('text-decoration: underline;'));
    expect(html, contains('text-decoration-color: #00ff00;'));
  });

  test('xterm SerializeAddon unit 59', () async {
    expect(
      await _styledHtml('4'),
      contains("text-decoration: underline;'>terminal"),
    );
  });

  test('xterm SerializeAddon unit 60', () {
    final setup = _setup();
    expect(
      setup.addon.serializeAsHtml(
        options: const TerminalHtmlSerializeOptions(
          includeGlobalBackground: true,
        ),
      ),
      contains(
        'color: #ffffff; background-color: #000000; '
        'font-family: monospace; font-size: 15px;',
      ),
    );
  });

  test('xterm SerializeAddon unit 61', () {
    final setup = _setup(
      fontFamily: 'verdana',
      fontSize: 20,
      theme: const TerminalColorTheme(
        foreground: '#ff00ff',
        background: '#00ff00',
      ),
    );
    expect(
      setup.addon.serializeAsHtml(
        options: const TerminalHtmlSerializeOptions(
          includeGlobalBackground: true,
        ),
      ),
      contains(
        'color: #ff00ff; background-color: #00ff00; '
        'font-family: verdana; font-size: 20px;',
      ),
    );
  });

  test('xterm SerializeAddon unit 62', () {
    final setup = _setup();
    expect(
      setup.addon.serializeAsHtml(),
      contains(
        'color: #000000; background-color: #ffffff; '
        'font-family: monospace; font-size: 15px;',
      ),
    );
  });

  test('xterm SerializeAddon unit 63', () {
    final setup = _setup();
    expect(
      setup.addon.serializeAsHtml(
        options: const TerminalHtmlSerializeOptions(onlySelection: true),
      ),
      isEmpty,
    );
  });

  test('xterm SerializeAddon unit 64', () {
    final setup = _setup();
    final html = setup.addon.serializeAsHtml();
    expect(
      RegExp('<div><span> {10}</span></div>').allMatches(html),
      hasLength(2),
    );
  });

  test('xterm SerializeAddon unit 65', () async {
    final setup = _setup();
    await setup.terminal.writeAndWait('bye hello\r\nworld');
    final html = setup.addon.serializeAsHtml(
      options: const TerminalHtmlSerializeOptions(
        range: TerminalHtmlSerializeRange(
          startLine: 0,
          endLine: 0,
          startColumn: 4,
        ),
      ),
    );
    expect(html, contains('hello'));
    expect(html, isNot(contains('bye')));
    expect(html, isNot(contains('world')));
  });

  test('xterm SerializeAddon unit 66', () async {
    final setup = _setup();
    await setup.terminal.writeAndWait('hello\r\nworld');
    expect(
      setup.addon.serialize(
        options: const TerminalSerializeOptions(
          range: TerminalSerializeRange(start: 1, end: 1),
        ),
      ),
      'world',
    );
  });

  test('xterm SerializeAddon unit 67', () async {
    final setup = _setup();
    await setup.terminal.writeAndWait('hello\r\nworld');
    expect(
      setup.addon.serialize(
        options: const TerminalSerializeOptions(
          range: TerminalSerializeRange(start: 0, end: 1),
        ),
      ),
      'hello\r\nworld',
    );
  });

  test('xterm SerializeAddon unit 68', () async {
    final setup = _setup();
    await setup.terminal.writeAndWait('hello\r\nworld');
    expect(
      setup.addon.serialize(
        options: const TerminalSerializeOptions(
          range: TerminalSerializeRange(start: 0, end: 0),
        ),
      ),
      'hello',
    );
  });

  test('xterm SerializeAddon unit 69', () async {
    final setup = _setup();
    await setup.terminal.writeAndWait('hello\u001b[?25l');
    expect(
      setup.addon.serialize(
        options: const TerminalSerializeOptions(excludeModes: true),
      ),
      isNot(contains('\u001b[?25l')),
    );
  });

  test('xterm SerializeAddon unit 70', () async {
    final setup = _setup();
    await setup.terminal.writeAndWait('hello');
    final value = setup.addon.serialize();
    expect(value, isNot(contains('\u001b[?25l')));
    expect(value, isNot(contains('\u001b[?25h')));
  });

  test('xterm SerializeAddon unit 71', () async {
    final setup = _setup();
    await setup.terminal.writeAndWait('hello\u001b[?25l');
    final serialized = setup.addon.serialize();
    final restored = _setup();
    await restored.terminal.writeAndWait(serialized);
    expect(restored.terminal.modes.showCursor, isFalse);
  });

  test('xterm SerializeAddon unit 72', () async {
    final setup = _setup();
    await setup.terminal.writeAndWait('hello\u001b[?25l');
    expect(setup.addon.serialize(), contains('\u001b[?25l'));
  });

  test('xterm SerializeAddon unit 73', () async {
    final setup = _setup();
    await setup.terminal.writeAndWait('\u001b[32m> \u001b[0m');
    expect(setup.addon.serialize(), '\u001b[32m> \u001b[0m');
  });

  test('xterm SerializeAddon unit 74', () async {
    final setup = _setup(rows: 5);
    await setup.terminal.writeAndWait('\u001b[2;4r');
    expect(
      setup.addon.serialize(
        options: const TerminalSerializeOptions(excludeModes: true),
      ),
      isNot(contains('\u001b[2;4r')),
    );
  });

  test('xterm SerializeAddon unit 75', () async {
    final setup = _setup(rows: 5);
    await setup.terminal.writeAndWait('\u001b[2;4r');
    final restored = _setup(rows: 5);
    await restored.terminal.writeAndWait(setup.addon.serialize());
    expect(
      (restored.terminal.modes.scrollTop, restored.terminal.modes.scrollBottom),
      (1, 3),
    );
  });

  test('xterm SerializeAddon unit 76', () async {
    final setup = _setup(rows: 5);
    await setup.terminal.writeAndWait('\u001b[2;4r');
    expect(setup.addon.serialize(), contains('\u001b[2;4r'));
  });

  test('xterm SerializeAddon unit 77', () => _expectUnderline('4:3', '4:3'));
  test('xterm SerializeAddon unit 78', () => _expectUnderline('4:5', '4:5'));
  test('xterm SerializeAddon unit 79', () => _expectUnderline('4:4', '4:4'));
  test('xterm SerializeAddon unit 80', () => _expectUnderline('4:2', '4:2'));
  test('xterm SerializeAddon unit 81', () => _expectUnderline('4:1', '4'));

  test('xterm SerializeAddon unit 82', () async {
    final setup = _setup();
    await setup.terminal.writeAndWait(
      '\u001b[4;58;2;255;128;64mtest\u001b[24m',
    );
    final value = setup.addon.serialize();
    expect(value, contains('4:1'));
    expect(value, contains('58:2::255:128:64'));
  });

  test('xterm SerializeAddon unit 83', () async {
    final setup = _setup();
    await setup.terminal.writeAndWait('\u001b[4;58;5;46mtest\u001b[24m');
    final value = setup.addon.serialize();
    expect(value, contains('4:1'));
    expect(value, contains('58:5:46'));
  });
}

Future<String> _styledHtml(String sgr) async {
  final setup = _setup();
  await setup.terminal.writeAndWait(' \u001b[${sgr}mterminal\u001b[0m ');
  return setup.addon.serializeAsHtml();
}

Future<void> _expectUnderline(String input, String output) async {
  final setup = _setup();
  await setup.terminal.writeAndWait('\u001b[${input}mtest\u001b[24m');
  expect(setup.addon.serialize(), '\u001b[${output}mtest\u001b[0m');
}

({Terminal terminal, SerializeAddon addon}) _setup({
  int rows = 2,
  String fontFamily = 'monospace',
  double fontSize = 15,
  TerminalColorTheme theme = const TerminalColorTheme(),
}) {
  final terminal = Terminal(
    options: TerminalOptions(
      cols: 10,
      rows: rows,
      fontFamily: fontFamily,
      fontSize: fontSize,
      theme: theme,
    ),
  );
  final addon = SerializeAddon();
  terminal.loadAddon(addon);
  addTearDown(terminal.dispose);
  return (terminal: terminal, addon: addon);
}
