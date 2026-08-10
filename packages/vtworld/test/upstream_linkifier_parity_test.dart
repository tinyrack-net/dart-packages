import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  test('xterm Linkifier 00', () {
    _expectRange(_underline(_singleLineLink));
  });

  test('xterm Linkifier 01', () {
    _expectWrappedRange(_underline(_wrappedLink));
  });

  test('xterm Linkifier 02', () {
    _expectRange(_underline(_singleLineLink));
  });

  test('xterm Linkifier 03', () {
    _expectWrappedRange(_underline(_wrappedLink));
  });
}

final TerminalLink _singleLineLink = TerminalLink(
  text: 'foo',
  range: const TerminalBufferRange(
    start: TerminalBufferPosition(5, 1),
    end: TerminalBufferPosition(7, 1),
  ),
  activate: (_, _) {},
);

final TerminalLink _wrappedLink = TerminalLink(
  text: 'foo',
  range: const TerminalBufferRange(
    start: TerminalBufferPosition(2, 1),
    end: TerminalBufferPosition(4, 2),
  ),
  activate: (_, _) {},
);

TerminalLinkUnderlineEvent _underline(TerminalLink link) =>
    TerminalLinkUnderlineEvent.fromLink(link, columns: 100);

void _expectRange(TerminalLinkUnderlineEvent event) {
  expect(event.x1, 4);
  expect(event.y1, 0);
  expect(event.x2, 7);
  expect(event.y2, 0);
  expect(event.columns, 100);
  expect(event.foreground, isNull);
}

void _expectWrappedRange(TerminalLinkUnderlineEvent event) {
  expect(event.x1, 1);
  expect(event.y1, 0);
  expect(event.x2, 4);
  expect(event.y2, 1);
  expect(event.columns, 100);
  expect(event.foreground, isNull);
}
