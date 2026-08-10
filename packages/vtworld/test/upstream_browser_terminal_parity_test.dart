import 'package:test/test.dart';

import 'support/browser_terminal_cases.dart';

void main() {
  test(
    // Exact pinned identity must remain one literal for parity.
    // ignore: lines_longer_than_80_chars
    'Terminal Third level shift On MS Windows should emit key with alt + ctrl + key on keyPress',
    () => verifyBrowserTerminalCase(
      'Terminal Third level shift On MS Windows should emit '
      'key with alt + ctrl + key on keyPress',
    ),
  );
  test(
    // Exact pinned identity must remain one literal for parity.
    // ignore: lines_longer_than_80_chars
    'Terminal Third level shift On MS Windows should interfere with the alt + ctrl + arrow keys',
    () => verifyBrowserTerminalCase(
      'Terminal Third level shift On MS Windows should '
      'interfere with the alt + ctrl + arrow keys',
    ),
  );
  test(
    // Exact pinned identity must remain one literal for parity.
    // ignore: lines_longer_than_80_chars
    'Terminal Third level shift On MS Windows should not interfere with the alt + ctrl key on keyDown',
    () => verifyBrowserTerminalCase(
      'Terminal Third level shift On MS Windows should not '
      'interfere with the alt + ctrl key on keyDown',
    ),
  );
  test(
    // Exact pinned identity must remain one literal for parity.
    // ignore: lines_longer_than_80_chars
    'Terminal Third level shift On Mac OS should emit key with alt + key on keyPress',
    () => verifyBrowserTerminalCase(
      'Terminal Third level shift On Mac OS should emit key '
      'with alt + key on keyPress',
    ),
  );
  test(
    // Exact pinned identity must remain one literal for parity.
    // ignore: lines_longer_than_80_chars
    'Terminal Third level shift On Mac OS should interfere with the alt + arrow keys',
    () => verifyBrowserTerminalCase(
      'Terminal Third level shift On Mac OS should '
      'interfere with the alt + arrow keys',
    ),
  );
  test(
    // Exact pinned identity must remain one literal for parity.
    // ignore: lines_longer_than_80_chars
    'Terminal Third level shift On Mac OS should not interfere with the alt key on keyDown',
    () => verifyBrowserTerminalCase(
      'Terminal Third level shift On Mac OS should not '
      'interfere with the alt key on keyDown',
    ),
  );
  test(
    // Exact pinned identity must remain one literal for parity.
    // ignore: lines_longer_than_80_chars
    'Terminal Third level shift with macOptionIsMeta should interfere with the alt key on keyDown',
    () => verifyBrowserTerminalCase(
      'Terminal Third level shift with macOptionIsMeta '
      'should interfere with the alt key on keyDown',
    ),
  );
  test(
    // Exact pinned identity must remain one literal for parity.
    // ignore: lines_longer_than_80_chars
    'Terminal Windows Pty should mark lines as wrapped when the line ends in a non-null character after a CUP',
    () => verifyBrowserTerminalCase(
      'Terminal Windows Pty should mark lines as wrapped '
      'when the line ends in a non-null character after a '
      'CUP',
    ),
  );
  test(
    // Exact pinned identity must remain one literal for parity.
    // ignore: lines_longer_than_80_chars
    'Terminal Windows Pty should mark lines as wrapped when the line ends in a non-null character after a LF',
    () => verifyBrowserTerminalCase(
      'Terminal Windows Pty should mark lines as wrapped '
      'when the line ends in a non-null character after a '
      'LF',
    ),
  );
  test(
    // Exact pinned identity must remain one literal for parity.
    // ignore: lines_longer_than_80_chars
    'Terminal attachCustomKeyEventHandler should alive after reset(ESC c Full Reset (RIS))',
    () => verifyBrowserTerminalCase(
      'Terminal attachCustomKeyEventHandler should alive '
      'after reset(ESC c Full Reset (RIS))',
    ),
  );
  test(
    'Terminal attachCustomKeyEventHandler should process the keydown/keypress event based on what the handler returns',
    () => verifyBrowserTerminalCase(
      'Terminal attachCustomKeyEventHandler should process '
      'the keydown/keypress event based on what the handler '
      'returns',
    ),
  );
  test(
    'Terminal clear should clear a buffer equal to rows',
    () => verifyBrowserTerminalCase(
      'Terminal clear should clear a buffer equal to rows',
    ),
  );
  test(
    'Terminal clear should clear a buffer larger than rows',
    () => verifyBrowserTerminalCase(
      'Terminal clear should clear a buffer larger than '
      'rows',
    ),
  );
  test(
    'Terminal clear should not break the prompt when cleared twice',
    () => verifyBrowserTerminalCase(
      'Terminal clear should not break the prompt when '
      'cleared twice',
    ),
  );
  test(
    'Terminal convertEol setting',
    () => verifyBrowserTerminalCase('Terminal convertEol setting'),
  );
  test(
    'Terminal events should fire a key event after a keydown DOM event',
    () => verifyBrowserTerminalCase(
      'Terminal events should fire a key event after a '
      'keydown DOM event',
    ),
  );
  test(
    'Terminal events should fire a key event after a keypress DOM event',
    () => verifyBrowserTerminalCase(
      'Terminal events should fire a key event after a '
      'keypress DOM event',
    ),
  );
  test(
    'Terminal events should fire a scroll event when scrollback is cleared',
    () => verifyBrowserTerminalCase(
      'Terminal events should fire a scroll event when '
      'scrollback is cleared',
    ),
  );
  test(
    'Terminal events should fire a scroll event when scrollback is created',
    () => verifyBrowserTerminalCase(
      'Terminal events should fire a scroll event when '
      'scrollback is created',
    ),
  );
  test(
    'Terminal events should fire the onBell event',
    () => verifyBrowserTerminalCase(
      'Terminal events should fire the onBell event',
    ),
  );
  test(
    'Terminal events should fire the onCursorMove event',
    () => verifyBrowserTerminalCase(
      'Terminal events should fire the onCursorMove event',
    ),
  );
  test(
    'Terminal events should fire the onData evnet',
    () => verifyBrowserTerminalCase(
      'Terminal events should fire the onData evnet',
    ),
  );
  test(
    'Terminal events should fire the onLineFeed event',
    () => verifyBrowserTerminalCase(
      'Terminal events should fire the onLineFeed event',
    ),
  );
  test(
    'Terminal events should fire the onResize event',
    () => verifyBrowserTerminalCase(
      'Terminal events should fire the onResize event',
    ),
  );
  test(
    'Terminal events should fire the onScroll event',
    () => verifyBrowserTerminalCase(
      'Terminal events should fire the onScroll event',
    ),
  );
  test(
    'Terminal events should fire the onTitleChange event',
    () => verifyBrowserTerminalCase(
      'Terminal events should fire the onTitleChange event',
    ),
  );
  test(
    'Terminal insert mode fullwidth - insert',
    () => verifyBrowserTerminalCase('Terminal insert mode fullwidth - insert'),
  );
  test(
    'Terminal insert mode fullwidth - right border',
    () => verifyBrowserTerminalCase(
      'Terminal insert mode fullwidth - right border',
    ),
  );
  test(
    'Terminal insert mode halfwidth - all',
    () => verifyBrowserTerminalCase('Terminal insert mode halfwidth - all'),
  );
  test(
    'Terminal marker lifecycle initial',
    () => verifyBrowserTerminalCase('Terminal marker lifecycle initial'),
  );
  test(
    'Terminal marker lifecycle should dispose on DL',
    () => verifyBrowserTerminalCase(
      'Terminal marker lifecycle should dispose on DL',
    ),
  );
  test(
    'Terminal marker lifecycle should dispose on IL',
    () => verifyBrowserTerminalCase(
      'Terminal marker lifecycle should dispose on IL',
    ),
  );
  test(
    'Terminal marker lifecycle should dispose on normal trim off the top',
    () => verifyBrowserTerminalCase(
      'Terminal marker lifecycle should dispose on normal '
      'trim off the top',
    ),
  );
  test(
    'Terminal marker lifecycle should dispose on resize',
    () => verifyBrowserTerminalCase(
      'Terminal marker lifecycle should dispose on resize',
    ),
  );
  test(
    'Terminal options get options',
    () => verifyBrowserTerminalCase('Terminal options get options'),
  );
  test(
    'Terminal options set options',
    () => verifyBrowserTerminalCase('Terminal options set options'),
  );
  test(
    'Terminal paste should fire data event',
    () => verifyBrowserTerminalCase('Terminal paste should fire data event'),
  );
  test(
    'Terminal paste should respect bracketed paste mode',
    () => verifyBrowserTerminalCase(
      'Terminal paste should respect bracketed paste mode',
    ),
  );
  test(
    r'Terminal paste should sanitize \n chars',
    () => verifyBrowserTerminalCase(r'Terminal paste should sanitize \n chars'),
  );
  test(
    // Exact pinned identity must remain one literal for parity.
    // ignore: lines_longer_than_80_chars
    'Terminal scroll keyDown should not scroll down on modifier-only input in win32 input mode',
    () => verifyBrowserTerminalCase(
      'Terminal scroll keyDown should not scroll down on '
      'modifier-only input in win32 input mode',
    ),
  );
  test(
    // Exact pinned identity must remain one literal for parity.
    // ignore: lines_longer_than_80_chars
    'Terminal scroll keyPress should not scroll down, when a custom keydown handler prevents the event',
    () => verifyBrowserTerminalCase(
      'Terminal scroll keyPress should not scroll down, '
      'when a custom keydown handler prevents the event',
    ),
  );
  test(
    // Exact pinned identity must remain one literal for parity.
    // ignore: lines_longer_than_80_chars
    'Terminal scroll keyPress should scroll down, when a key is pressed and terminal is scrolled up',
    () => verifyBrowserTerminalCase(
      'Terminal scroll keyPress should scroll down, when a '
      'key is pressed and terminal is scrolled up',
    ),
  );
  test(
    // Exact pinned identity must remain one literal for parity.
    // ignore: lines_longer_than_80_chars
    'Terminal scroll scroll() function when scrollback === 0 should create a new line and shift everything up',
    () => verifyBrowserTerminalCase(
      'Terminal scroll scroll() function when scrollback '
      '=== 0 should create a new line and shift everything '
      'up',
    ),
  );
  test(
    // Exact pinned identity must remain one literal for parity.
    // ignore: lines_longer_than_80_chars
    'Terminal scroll scroll() function when scrollback === 0 should properly scroll inside a scroll region (scrollBottom set)',
    () => verifyBrowserTerminalCase(
      'Terminal scroll scroll() function when scrollback '
      '=== 0 should properly scroll inside a scroll region '
      '(scrollBottom set)',
    ),
  );
  test(
    // Exact pinned identity must remain one literal for parity.
    // ignore: lines_longer_than_80_chars
    'Terminal scroll scroll() function when scrollback === 0 should properly scroll inside a scroll region (scrollTop and scrollBottom set)',
    () => verifyBrowserTerminalCase(
      'Terminal scroll scroll() function when scrollback '
      '=== 0 should properly scroll inside a scroll region '
      '(scrollTop and scrollBottom set)',
    ),
  );
  test(
    // Exact pinned identity must remain one literal for parity.
    // ignore: lines_longer_than_80_chars
    'Terminal scroll scroll() function when scrollback === 0 should properly scroll inside a scroll region (scrollTop set)',
    () => verifyBrowserTerminalCase(
      'Terminal scroll scroll() function when scrollback '
      '=== 0 should properly scroll inside a scroll region '
      '(scrollTop set)',
    ),
  );
  test(
    // Exact pinned identity must remain one literal for parity.
    // ignore: lines_longer_than_80_chars
    'Terminal scroll scroll() function when scrollback > 0 should create a new line and scroll',
    () => verifyBrowserTerminalCase(
      'Terminal scroll scroll() function when scrollback > '
      '0 should create a new line and scroll',
    ),
  );
  test(
    // Exact pinned identity must remain one literal for parity.
    // ignore: lines_longer_than_80_chars
    'Terminal scroll scroll() function when scrollback > 0 should properly scroll inside a scroll region (scrollBottom set)',
    () => verifyBrowserTerminalCase(
      'Terminal scroll scroll() function when scrollback > '
      '0 should properly scroll inside a scroll region '
      '(scrollBottom set)',
    ),
  );
  test(
    // Exact pinned identity must remain one literal for parity.
    // ignore: lines_longer_than_80_chars
    'Terminal scroll scroll() function when scrollback > 0 should properly scroll inside a scroll region (scrollTop and scrollBottom set)',
    () => verifyBrowserTerminalCase(
      'Terminal scroll scroll() function when scrollback > '
      '0 should properly scroll inside a scroll region '
      '(scrollTop and scrollBottom set)',
    ),
  );
  test(
    // Exact pinned identity must remain one literal for parity.
    // ignore: lines_longer_than_80_chars
    'Terminal scroll scroll() function when scrollback > 0 should properly scroll inside a scroll region (scrollTop set)',
    () => verifyBrowserTerminalCase(
      'Terminal scroll scroll() function when scrollback > '
      '0 should properly scroll inside a scroll region '
      '(scrollTop set)',
    ),
  );
  test(
    // Exact pinned identity must remain one literal for parity.
    // ignore: lines_longer_than_80_chars
    'Terminal scroll scrollLines should not scroll beyond the bounds of the buffer',
    () => verifyBrowserTerminalCase(
      'Terminal scroll scrollLines should not scroll beyond '
      'the bounds of the buffer',
    ),
  );
  test(
    'Terminal scroll scrollLines should scroll a single line',
    () => verifyBrowserTerminalCase(
      'Terminal scroll scrollLines should scroll a single '
      'line',
    ),
  );
  test(
    'Terminal scroll scrollLines should scroll multiple lines',
    () => verifyBrowserTerminalCase(
      'Terminal scroll scrollLines should scroll multiple '
      'lines',
    ),
  );
  test(
    'Terminal scroll scrollPages should scroll a multiple pages',
    () => verifyBrowserTerminalCase(
      'Terminal scroll scrollPages should scroll a multiple '
      'pages',
    ),
  );
  test(
    'Terminal scroll scrollPages should scroll a single page',
    () => verifyBrowserTerminalCase(
      'Terminal scroll scrollPages should scroll a single '
      'page',
    ),
  );
  test(
    'Terminal scroll scrollToBottom should scroll to the bottom',
    () => verifyBrowserTerminalCase(
      'Terminal scroll scrollToBottom should scroll to the '
      'bottom',
    ),
  );
  test(
    'Terminal scroll scrollToLine should not scroll beyond boundary lines',
    () => verifyBrowserTerminalCase(
      'Terminal scroll scrollToLine should not scroll '
      'beyond boundary lines',
    ),
  );
  test(
    'Terminal scroll scrollToLine should scroll to requested line',
    () => verifyBrowserTerminalCase(
      'Terminal scroll scrollToLine should scroll to '
      'requested line',
    ),
  );
  test(
    'Terminal scroll scrollToTop should scroll to the top',
    () => verifyBrowserTerminalCase(
      'Terminal scroll scrollToTop should scroll to the top',
    ),
  );
  test(
    'Terminal should not mutate the options parameter',
    () => verifyBrowserTerminalCase(
      'Terminal should not mutate the options parameter',
    ),
  );
}
