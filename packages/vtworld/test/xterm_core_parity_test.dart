import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:vtworld/vtworld.dart';

import 'support/fixture_paths.dart';

void main() {
  group('xterm options', () {
    test('uses the pinned xterm defaults', () {
      final options = TerminalOptions();

      expect(options.cols, 80);
      expect(options.rows, 24);
      expect(options.scrollback, 1000);
      expect(options.fontFamily, 'monospace');
      expect(options.fontSize, 15);
      expect(options.termName, 'xterm');
      expect(options.cursorStyle, TerminalCursorStyle.block);
      expect(options.tabStopWidth, 8);
      expect(options.wordSeparator, ' ()[]{}\',"`');
      expect(options.rightClickSelectsWord, Platform.isMacOS);
    });

    test('matches option validation and clamping', () {
      expect(TerminalOptions(scrollback: -1).scrollback, 1000);
      expect(TerminalOptions(cursorWidth: 0).cursorWidth, 1);
      expect(TerminalOptions(scrollSensitivity: 0).scrollSensitivity, 1);
      expect(
        TerminalOptions(minimumContrastRatio: 30).minimumContrastRatio,
        21,
      );
      expect(TerminalOptions(scrollback: 0x1ffffffff).scrollback, 0xffffffff);
    });
  });

  group('write buffer and events', () {
    test('writeln queues data and CRLF as two ordered writes', () async {
      final terminal = Terminal(options: TerminalOptions(cols: 8, rows: 2));
      addTearDown(terminal.dispose);
      final renders = <TerminalRenderEvent>[];
      final completed = Completer<void>();
      terminal.onRender.listen(renders.add);

      terminal.writeln(
        Uint8List.fromList(<int>[0x61]),
        onParsed: completed.complete,
      );
      await completed.future;

      expect(renders, hasLength(2));
      expect(
        terminal.buffer.active.getLine(0)!.translateToString(trimRight: true),
        'a',
      );
      expect(terminal.buffer.active.cursorY, 1);
      expect(terminal.buffer.active.cursorX, 0);
    });

    test(
      'preserves callbacks, event order, and UTF-8 chunk boundaries',
      () async {
        final terminal = Terminal(options: TerminalOptions(cols: 8, rows: 2));
        addTearDown(terminal.dispose);
        final events = <String>[];
        terminal
          ..onCursorMove.listen((_) => events.add('cursor'))
          ..onRender.listen((_) => events.add('render'))
          ..onWriteParsed.listen((_) => events.add('parsed'));

        // Separate calls assert queue ordering across distinct writes.
        // ignore: cascade_invocations
        terminal.write(Uint8List.fromList(<int>[0xed, 0x95]));
        // This is the second independently queued chunk under test.
        // ignore: cascade_invocations
        terminal.write(
          Uint8List.fromList(<int>[0x9c]),
          onParsed: () {
            events.add('callback');
          },
        );
        await terminal.writeAndWait('!');

        expect(
          terminal.buffer.active.getLine(0)!.translateToString(),
          startsWith('한!'),
        );
        expect(
          events.indexOf('callback'),
          lessThan(events.lastIndexOf('parsed')),
        );
        expect(events.where((event) => event == 'render'), hasLength(3));
      },
    );

    test('matches xterm UTF-8 BOM and malformed byte handling', () async {
      final terminal = Terminal(options: TerminalOptions(cols: 20, rows: 2));
      addTearDown(terminal.dispose);

      terminal
        ..write(Uint8List.fromList(<int>[0xf0, 0xa0, 0x9c]))
        ..write(Uint8List.fromList(<int>[0x8e, 0xef, 0xbb]))
        ..write(Uint8List.fromList(<int>[0xbf, 0xc0, 0x80]))
        ..write(Uint8List.fromList(<int>[0xed, 0xa0, 0x80]))
        ..write(Uint8List.fromList(<int>[0xf4, 0x90, 0x80, 0x80]))
        ..write(Uint8List.fromList(<int>[0xe2, 0x28, 0xa1]));
      await terminal.writeAndWait('X');

      expect(
        terminal.buffer.active.getLine(0)!.translateToString(trimRight: true),
        '𠜎(X',
      );
    });

    test('streams split UTF-16 surrogates and drops string BOMs', () async {
      final terminal = Terminal(options: TerminalOptions(cols: 10, rows: 2));
      addTearDown(terminal.dispose);

      terminal
        ..write(String.fromCharCode(0xd834))
        ..write('${String.fromCharCode(0xdd1e)}\ufeff');
      await terminal.writeAndWait('X');

      expect(
        terminal.buffer.active.getLine(0)!.translateToString(trimRight: true),
        '𝄞X',
      );
    });

    test('fires synchronous data listeners in registration order', () {
      final terminal = Terminal();
      addTearDown(terminal.dispose);
      final values = <String>[];
      final first = terminal.onData.listen((value) => values.add('a$value'));
      terminal.onData.listen((value) => values.add('b$value'));

      terminal.input('1');
      first.dispose();
      terminal.input('2');

      expect(values, <String>['a1', 'b1', 'b2']);
    });
  });

  group('custom parser', () {
    test(
      'observes preceding terminal output before invoking a handler',
      () async {
        final terminal = Terminal();
        addTearDown(terminal.dispose);
        String? lineSeenByHandler;
        terminal.parser.registerOscHandler(777, (data) {
          lineSeenByHandler = terminal.buffer.active
              .getLine(0)!
              .translateToString(trimRight: true);
          return true;
        });

        await terminal.writeAndWait('before\u001b]777;payload\u001b\\after');

        expect(lineSeenByHandler, 'before');
        expect(
          terminal.buffer.active.getLine(0)!.translateToString(trimRight: true),
          'beforeafter',
        );
      },
    );

    test(
      'tries newest handlers first and blocks until async completion',
      () async {
        final terminal = Terminal();
        addTearDown(terminal.dispose);
        final calls = <String>[];
        terminal.parser.registerOscHandler(777, (data) {
          calls.add('old:$data');
          return true;
        });
        terminal.parser.registerOscHandler(777, (data) async {
          await Future<void>.delayed(Duration.zero);
          calls.add('new:$data');
          return false;
        });

        terminal.write('\u001b]777;pay');
        await terminal.writeAndWait('load\u001b\\X');

        expect(calls, <String>['new:payload', 'old:payload']);
        expect(
          terminal.buffer.active.getLine(0)!.translateToString(),
          startsWith('X'),
        );
      },
    );

    test('handles CSI, DCS, ESC and APC identifiers', () async {
      final terminal = Terminal();
      addTearDown(terminal.dispose);
      final calls = <String>[];
      terminal.parser.registerCsiHandler(
        const TerminalFunctionIdentifier(prefix: '?', finalByte: 'z'),
        (params) {
          calls.add('csi:$params');
          return true;
        },
      );
      terminal.parser.registerDcsHandler(
        const TerminalFunctionIdentifier(finalByte: 'q'),
        (data, params) {
          calls.add('dcs:$data');
          return true;
        },
      );
      terminal.parser.registerEscHandler(
        const TerminalFunctionIdentifier(intermediates: '%', finalByte: 'G'),
        () {
          calls.add('esc');
          return true;
        },
      );
      terminal.parser.registerApcHandler(
        const TerminalFunctionIdentifier(finalByte: 'G'),
        (data) {
          calls.add('apc:$data');
          return true;
        },
      );

      await terminal.writeAndWait(
        '\u001b[?1;2:3z\u001bP1qDATA\u001b\\\u001b%G\u001b_Gkitty\u001b\\',
      );

      expect(calls, <String>[
        'csi:[1, 2, [3]]',
        'dcs:DATA',
        'esc',
        'apc:kitty',
      ]);
    });

    test(
      'uses xterm ZDM, subparameter defaults, limits, and clamping',
      () async {
        final terminal = Terminal();
        addTearDown(terminal.dispose);
        final calls = <List<TerminalParameter>>[];
        terminal.parser.registerCsiHandler(
          const TerminalFunctionIdentifier(finalByte: 'z'),
          (params) {
            calls.add(params);
            return true;
          },
        );

        await terminal.writeAndWait(
          '\u001b[4::123:5;6;7z'
          '\u001b[2147483648;:2147483648z',
        );

        expect(calls, <List<TerminalParameter>>[
          <TerminalParameter>[
            4,
            <int>[-1, 123, 5],
            6,
            7,
          ],
          <TerminalParameter>[
            0x7fffffff,
            0,
            <int>[0x7fffffff],
          ],
        ]);
      },
    );

    test(
      'OSC accepts arbitrary registration IDs and APC ignores prefix',
      () async {
        final terminal = Terminal();
        addTearDown(terminal.dispose);
        var apcPayload = '';
        terminal.parser
          ..registerOscHandler(-1, (_) => true)
          ..registerApcHandler(
            const TerminalFunctionIdentifier(
              prefix: '?',
              intermediates: '+',
              finalByte: 'p',
            ),
            (data) {
              apcPayload = data;
              return true;
            },
          );

        await terminal.writeAndWait('\u001b_+pvalue\u001b\\');
        expect(apcPayload, 'value');
      },
    );

    test(
      'Kitty keyboard set, query, push, pop and buffer state match xterm',
      () async {
        final terminal = Terminal(
          options: TerminalOptions(
            vtExtensions: const TerminalVtExtensions(kittyKeyboard: true),
          ),
        );
        addTearDown(terminal.dispose);
        final reports = <String>[];
        terminal.onData.listen(reports.add);

        await terminal.writeAndWait(
          '\u001b[=3u'
          '\u001b[=4;2u'
          '\u001b[?u'
          '\u001b[>2u'
          '\u001b[?u'
          '\u001b[<u'
          '\u001b[?u'
          '\u001b[>5u'
          '\u001b[?1049h'
          '\u001b[?u'
          '\u001b[>7u'
          '\u001b[?1049l'
          '\u001b[?u',
        );

        expect(reports, <String>[
          '\u001b[?7u',
          '\u001b[?2u',
          '\u001b[?0u',
          '\u001b[?0u',
          '\u001b[?5u',
        ]);
      },
    );

    test(
      'accepts the exact parser payload limit and rejects limit + 1',
      () async {
        final terminal = Terminal(options: TerminalOptions(cols: 1, rows: 1));
        addTearDown(terminal.dispose);
        final lengths = <int>[];
        terminal.parser.registerOscHandler(777, (data) {
          lengths.add(data.length);
          return true;
        });
        final payload = 'A' * 10000000;

        await terminal.writeAndWait('\u001b]777;$payload\u001b\\');
        await terminal.writeAndWait('\u001b]777;${payload}A\u001b\\');

        expect(lengths, <int>[10000000]);
      },
    );

    test('dispatches 8-bit C1 CSI, OSC, DCS, and APC forms', () async {
      final terminal = Terminal();
      addTearDown(terminal.dispose);
      final calls = <String>[];
      terminal.parser.registerCsiHandler(
        const TerminalFunctionIdentifier(finalByte: 'z'),
        (params) {
          calls.add('csi:$params');
          return true;
        },
      );
      terminal.parser.registerOscHandler(777, (data) {
        calls.add('osc:$data');
        return true;
      });
      terminal.parser.registerDcsHandler(
        const TerminalFunctionIdentifier(finalByte: 'q'),
        (data, params) {
          calls.add('dcs:$data');
          return true;
        },
      );
      terminal.parser.registerApcHandler(
        const TerminalFunctionIdentifier(finalByte: 'G'),
        (data) {
          calls.add('apc:$data');
          return true;
        },
      );

      await terminal.writeAndWait(
        '\u009b1z\u009d777;title\u009c\u00901qdata\u009c'
        '\u009fGpayload\u009c',
      );

      expect(calls, <String>[
        'csi:[1]',
        'osc:title',
        'dcs:data',
        'apc:payload',
      ]);
    });

    test(
      'matches string cancellation, ESC termination, and control filtering',
      () async {
        final terminal = Terminal();
        addTearDown(terminal.dispose);
        final calls = <String>[];
        terminal.parser.registerOscHandler(777, (data) {
          calls.add('osc:$data');
          return true;
        });
        terminal.parser.registerDcsHandler(
          const TerminalFunctionIdentifier(finalByte: 'q'),
          (data, params) {
            calls.add('dcs:$data');
            return true;
          },
        );
        terminal.parser.registerApcHandler(
          const TerminalFunctionIdentifier(finalByte: 'G'),
          (data) {
            calls.add('apc:$data');
            return true;
          },
        );
        terminal.parser.registerEscHandler(
          const TerminalFunctionIdentifier(intermediates: '%', finalByte: 'G'),
          () {
            calls.add('esc');
            return true;
          },
        );

        await terminal.writeAndWait(
          '\u001b]777;cancelled\u0018'
          '\u001bPqcancelled\u001a'
          '\u001b_Gcancelled\u0018'
          '\u001b]777;a\u0001b\u007f\u0007'
          '\u001bPqA\u0007B\u001b\\'
          '\u001b_GA\u0008B\u0001C\u007fD\u001b\\'
          '\u001b]777;x\u001b%G'
          'X',
        );

        expect(calls, <String>[
          'osc:ab\u007f',
          'dcs:A\u0007B',
          'apc:A\u0008BCD',
          'osc:x',
          'esc',
        ]);
        expect(
          terminal.buffer.active.getLine(0)!.translateToString(trimRight: true),
          'X',
        );
      },
    );

    test('executes C1 IND, NEL, and HTS controls', () async {
      final terminal = Terminal(options: TerminalOptions(cols: 10, rows: 3));
      addTearDown(terminal.dispose);

      await terminal.writeAndWait('ab\u0084c\u0085d');
      expect(terminal.buffer.active.cursorY, 2);
      expect(terminal.buffer.active.cursorX, 1);
      expect(
        terminal.buffer.active.getLine(1)!.translateToString(trimRight: true),
        '  c',
      );
      expect(
        terminal.buffer.active.getLine(2)!.translateToString(trimRight: true),
        'd',
      );

      terminal.reset();
      await terminal.writeAndWait('abc\u0088\r\tX');
      expect(
        terminal.buffer.active.getLine(0)!.translateToString(trimRight: true),
        'abcX',
      );
    });

    test('device attributes and XTVERSION honor xterm parameters', () async {
      final terminal = Terminal();
      addTearDown(terminal.dispose);
      final reports = <String>[];
      terminal.onData.listen(reports.add);

      await terminal.writeAndWait(
        '\u001b[c\u001b[1c'
        '\u001b[>c\u001b[>1c'
        '\u001b[>q\u001b[>1q',
      );

      expect(reports, <String>[
        '\u001b[?1;2c',
        '\u001b[>0;276;0c',
        '\u001bP>|xterm.js(6.0.0)\u001b\\',
      ]);

      terminal.options.termName = 'linux';
      await terminal.writeAndWait('\u001b[c\u001b[>c');
      expect(reports.skip(3), <String>['\u001b[?6c', '0c']);
    });

    test('window reports and title stacks honor capability gates', () async {
      final terminal = Terminal(
        options: TerminalOptions(
          windowOptions: const TerminalWindowOptions(
            getWinSizePixels: true,
            getCellSizePixels: true,
            getWinSizeChars: true,
            getIconTitle: true,
            getWinTitle: true,
            pushTitle: true,
            popTitle: true,
          ),
        ),
      );
      addTearDown(terminal.dispose);
      terminal.updateDimensions(
        const TerminalRenderDimensions(
          width: 800,
          height: 480,
          cellWidth: 10,
          cellHeight: 20,
          devicePixelRatio: 1,
        ),
      );
      final reports = <String>[];
      final titles = <String>[];
      terminal.onData.listen(reports.add);
      terminal.onTitleChange.listen(titles.add);

      await terminal.writeAndWait(
        '\u001b]1;icon\u001b\\'
        '\u001b]2;title\u001b\\'
        '\u001b[22;0t'
        '\u001b]1;other-icon\u001b\\'
        '\u001b]2;other-title\u001b\\'
        '\u001b[23;0t'
        '\u001b[14t\u001b[16t\u001b[18t\u001b[20t\u001b[21t',
      );

      expect(titles, <String>['title', 'other-title', 'title']);
      expect(reports, <String>[
        '\u001b[4;480;800t',
        '\u001b[6;20;10t',
        '\u001b[8;24;80t',
        '\u001b]Licon\u001b\\',
        '\u001b]ltitle\u001b\\',
      ]);

      final denied = Terminal();
      addTearDown(denied.dispose);
      var customCalls = 0;
      denied.parser.registerCsiHandler(
        const TerminalFunctionIdentifier(finalByte: 't'),
        (_) {
          customCalls++;
          return true;
        },
      );
      await denied.writeAndWait('\u001b[18t');
      expect(customCalls, 0);
    });

    test('OSC 8 stores hyperlinks and resolves wrapped ranges', () async {
      final activated = <String>[];
      final terminal = Terminal(
        options: TerminalOptions(
          cols: 8,
          rows: 3,
          linkHandler: TerminalLinkHandler(
            activate: (_, text, _) => activated.add(text),
          ),
        ),
      );
      addTearDown(terminal.dispose);
      await terminal.writeAndWait(
        '\u001b]8;id=shared;https://example.com/a;b\u001b\\'
        '1234567890'
        '\u001b]8;;\u001b\\',
      );

      final first = await terminal.linkProviders.first.provideLinks(1);
      final second = await terminal.linkProviders.first.provideLinks(2);
      expect(first, hasLength(1));
      expect(second, hasLength(1));
      expect(first.single.text, 'https://example.com/a;b');
      expect(
        first.single.range,
        const TerminalBufferRange(
          start: TerminalBufferPosition(1, 1),
          end: TerminalBufferPosition(2, 2),
        ),
      );
      expect(second.single.range, first.single.range);
      first.single.activate(null, first.single.text);
      expect(activated, <String>['https://example.com/a;b']);
    });

    test(
      'OSC colors set, report, stack, and restore xterm color state',
      () async {
        final terminal = Terminal(
          options: TerminalOptions(
            theme: const TerminalColorTheme(
              foreground: '#123456',
              background: '#010203',
              cursor: '#abcdef',
              red: '#112233',
            ),
          ),
        );
        addTearDown(terminal.dispose);
        final reports = <String>[];
        terminal.onData.listen(reports.add);

        await terminal.writeAndWait(
          '\u001b]4;1;?;2;#abc\u001b\\'
          '\u001b]10;#fff;rgb:00/11/22;#123456\u001b\\'
          '\u001b]4;2;?\u001b\\'
          '\u001b]10;?;?;?\u001b\\',
        );

        expect(reports, <String>[
          '\u001b]4;1;rgb:1111/2222/3333\u001b\\',
          '\u001b]4;2;rgb:a0a0/b0b0/c0c0\u001b\\',
          '\u001b]10;rgb:f0f0/f0f0/f0f0\u001b\\',
          '\u001b]11;rgb:0000/1111/2222\u001b\\',
          '\u001b]12;rgb:1212/3434/5656\u001b\\',
        ]);
        expect(terminal.colorOverrides.indexed[2], 0xa0b0c0);
        expect(terminal.colorOverrides.foreground, 0xf0f0f0);
        expect(terminal.colorOverrides.background, 0x001122);
        expect(terminal.colorOverrides.cursor, 0x123456);

        await terminal.writeAndWait(
          '\u001b]104;2\u001b\\'
          '\u001b]110\u0007\u001b]111\u0007\u001b]112\u0007',
        );
        expect(terminal.colorOverrides.indexed, isEmpty);
        expect(terminal.colorOverrides.foreground, isNull);
        expect(terminal.colorOverrides.background, isNull);
        expect(terminal.colorOverrides.cursor, isNull);
      },
    );

    test('XParseColor accepts all widths and rejects invalid forms', () async {
      final terminal = Terminal();
      addTearDown(terminal.dispose);
      final cases = <String, int>{
        'rgb:0/0/0': 0x000000,
        'rgb:f/f/f': 0xffffff,
        'rgb:1/2/3': 0x112233,
        'rgb:00/00/00': 0x000000,
        'rgb:ff/ff/ff': 0xffffff,
        'rgb:11/22/33': 0x112233,
        'rgb:000/000/000': 0x000000,
        'rgb:fff/fff/fff': 0xffffff,
        'rgb:111/222/333': 0x112233,
        'rgb:0000/0000/0000': 0x000000,
        'rgb:ffff/ffff/ffff': 0xffffff,
        'rgb:1111/2222/3333': 0x112233,
        '#000': 0x000000,
        '#fff': 0xf0f0f0,
        '#123': 0x102030,
        '#000000': 0x000000,
        '#ffffff': 0xffffff,
        '#112233': 0x112233,
        '#000000000': 0x000000,
        '#fffffffff': 0xffffff,
        '#111222333': 0x112233,
        '#000000000000': 0x000000,
        '#ffffffffffff': 0xffffff,
        '#111122223333': 0x112233,
        'RGB:0/A/F': 0x00aaff,
        '#FFF': 0xf0f0f0,
      };
      var index = 0;
      for (final entry in cases.entries) {
        await terminal.writeAndWait('\u001b]4;$index;${entry.key}\u001b\\');
        expect(terminal.colorOverrides.indexed[index], entry.value);
        index++;
      }
      for (final invalid in <String>[
        '',
        'rgb:0/11/222',
        'rgb:/1/2',
        'rgb:00000/1/2',
        'rgbi:00/11/22',
        '#aabbbcc',
        '#aabbgg',
        'rgb:aa/bb/gg',
      ]) {
        await terminal.writeAndWait('\u001b]4;$index;$invalid\u001b\\');
        expect(terminal.colorOverrides.indexed, isNot(contains(index)));
        index++;
      }
    });

    test('OSC color reports resolve all default palette regions', () async {
      final terminal = Terminal(
        options: TerminalOptions(
          theme: const TerminalColorTheme(
            foreground: '#abc',
            background: 'rgb(1, 2, 3)',
            cursor: '#11223344',
            extendedAnsi: <String>['#040506'],
          ),
        ),
      );
      addTearDown(terminal.dispose);
      final reports = <String>[];
      terminal.onData.listen(reports.add);
      await terminal.writeAndWait(
        '\u001b]4;0;?;16;?;17;?;231;?;232;?;255;?\u001b\\'
        '\u001b]10;?;?;?\u001b\\',
      );
      expect(reports, <String>[
        '\u001b]4;0;rgb:2e2e/3434/3636\u001b\\',
        '\u001b]4;16;rgb:0404/0505/0606\u001b\\',
        '\u001b]4;17;rgb:0000/0000/5f5f\u001b\\',
        '\u001b]4;231;rgb:ffff/ffff/ffff\u001b\\',
        '\u001b]4;232;rgb:0808/0808/0808\u001b\\',
        '\u001b]4;255;rgb:eeee/eeee/eeee\u001b\\',
        '\u001b]10;rgb:aaaa/bbbb/cccc\u001b\\',
        '\u001b]11;rgb:0101/0202/0303\u001b\\',
        '\u001b]12;rgb:1111/2222/3333\u001b\\',
      ]);

      await terminal.writeAndWait('\u001b]4;1;#123456;2;#654321\u001b\\');
      terminal.options.theme = const TerminalColorTheme();
      expect(terminal.colorOverrides.indexed, isEmpty);
    });

    test('OSC 8 rejects unsafe protocols unless explicitly allowed', () async {
      final terminal = Terminal(options: TerminalOptions(cols: 20, rows: 2));
      addTearDown(terminal.dispose);
      await terminal.writeAndWait(
        '\u001b]8;;file:///tmp/value\u0007value\u001b]8;;\u0007',
      );
      expect(await terminal.linkProviders.first.provideLinks(1), isEmpty);

      terminal.options.linkHandler = TerminalLinkHandler(
        activate: (_, _, _) {},
        allowNonHttpProtocols: true,
      );
      expect(await terminal.linkProviders.first.provideLinks(1), hasLength(1));
    });

    test('mouse protocols emit default binary and SGR data reports', () async {
      final terminal = Terminal();
      addTearDown(terminal.dispose);
      final binary = <String>[];
      final data = <String>[];
      terminal
        ..onBinary.listen(binary.add)
        ..onData.listen(data.add);
      await terminal.writeAndWait('\u001b[?1000h');
      expect(
        terminal.reportMouseEvent(
          const TerminalMouseEvent(
            column: 4,
            row: 2,
            button: TerminalMouseButton.left,
            action: TerminalMouseAction.down,
            shift: true,
          ),
        ),
        isTrue,
      );
      expect(binary.single, '\u001b[M\u0024\u0025\u0023');

      await terminal.writeAndWait('\u001b[?1006h');
      expect(
        terminal.reportMouseEvent(
          const TerminalMouseEvent(
            column: 4,
            row: 2,
            button: TerminalMouseButton.left,
            action: TerminalMouseAction.up,
            control: true,
          ),
        ),
        isTrue,
      );
      expect(data.last, '\u001b[<16;5;3m');
    });

    test(
      'mouse protocol restrictions and pixel debounce match xterm',
      () async {
        final terminal = Terminal(
          options: TerminalOptions(
            cols: 10,
            rows: 5,
            mouseEventsRequireAlt: true,
          ),
        );
        addTearDown(terminal.dispose);
        final data = <String>[];
        terminal.onData.listen(data.add);
        await terminal.writeAndWait('\u001b[?1003h\u001b[?1016h');
        const event = TerminalMouseEvent(
          column: 1,
          row: 1,
          pixelX: 12,
          pixelY: 30,
          button: TerminalMouseButton.none,
          action: TerminalMouseAction.move,
          alt: true,
        );
        expect(terminal.reportMouseEvent(event), isTrue);
        expect(terminal.reportMouseEvent(event), isFalse);
        expect(data.single, '\u001b[<35;12;30M');
      },
    );

    test('DECRQSS reports protected, margins, SGR and cursor style', () async {
      final terminal = Terminal(
        options: TerminalOptions(
          cursorStyle: TerminalCursorStyle.underline,
          cursorBlink: true,
        ),
      );
      addTearDown(terminal.dispose);
      final reports = <String>[];
      terminal.onData.listen(reports.add);

      await terminal.writeAndWait(
        <String>[
          '\u001b[2;10r',
          '\u001b[1"q',
          '\u001bP\u0024q"q\u001b\\',
          '\u001bP\u0024q"p\u001b\\',
          '\u001bP\u0024qr\u001b\\',
          '\u001bP\u0024qm\u001b\\',
          '\u001bP\u0024q q\u001b\\',
          '\u001bP\u0024qbad\u001b\\',
        ].join(),
      );

      expect(reports, <String>[
        '\u001bP1\u0024r1"q\u001b\\',
        '\u001bP1\u0024r61;1"p\u001b\\',
        '\u001bP1\u0024r2;10r\u001b\\',
        '\u001bP1\u0024r0m\u001b\\',
        '\u001bP1\u0024r3 q\u001b\\',
        '\u001bP0\u0024r\u001b\\',
      ]);
    });

    test(
      'executes CSI controls before dispatch and honors cancellation',
      () async {
        final terminal = Terminal(options: TerminalOptions(cols: 10, rows: 3));
        addTearDown(terminal.dispose);
        final rows = <int>[];
        terminal.parser.registerCsiHandler(
          const TerminalFunctionIdentifier(finalByte: 'z'),
          (params) {
            rows.add(terminal.buffer.active.cursorY);
            return true;
          },
        );

        await terminal.writeAndWait('a\u001b[1\n;2zX');
        expect(rows, <int>[1]);
        expect(
          terminal.buffer.active.getLine(1)!.translateToString(trimRight: true),
          ' X',
        );

        await terminal.writeAndWait('\u001b[1\u0018z\u001b[2CX');
        expect(rows, <int>[1]);
        expect(terminal.buffer.active.cursorX, 6);
      },
    );

    test('executes controls in ESC state before custom dispatch', () async {
      final terminal = Terminal(options: TerminalOptions(cols: 10, rows: 3));
      addTearDown(terminal.dispose);
      final rows = <int>[];
      terminal.parser.registerEscHandler(
        const TerminalFunctionIdentifier(intermediates: '%', finalByte: 'G'),
        () {
          rows.add(terminal.buffer.active.cursorY);
          return true;
        },
      );

      await terminal.writeAndWait('a\u001b\n%GX');

      expect(rows, <int>[1]);
      expect(
        terminal.buffer.active.getLine(1)!.translateToString(trimRight: true),
        ' X',
      );
    });
  });

  group('terminal public behavior', () {
    test('initial dimensions and resize clamp to xterm minimums', () {
      final terminal = Terminal(options: TerminalOptions(cols: -10, rows: -10));
      addTearDown(terminal.dispose);
      final events = <TerminalResizeEvent>[];
      terminal.onResize.listen(events.add);

      expect((terminal.cols, terminal.rows), (2, 1));
      terminal.resize(0, 0);
      expect((events.single.cols, events.single.rows), (2, 1));
      terminal.resize(3, 0);
      expect((terminal.cols, terminal.rows), (3, 1));
      expect((events.last.cols, events.last.rows), (3, 1));
    });

    test('selection endpoints and line clamping match xterm', () async {
      final terminal = Terminal(options: TerminalOptions(cols: 5, rows: 5));
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('\n\nfoo\n\n\rbar\n\n\rbaz');

      terminal.selectAll();
      expect(terminal.hasSelection(), isTrue);
      expect(
        terminal.getSelectionPosition(),
        const TerminalBufferRange(
          start: TerminalBufferPosition(0, 0),
          end: TerminalBufferPosition(5, 6),
        ),
      );
      expect(terminal.getSelection(), '\n\nfoo\n\nbar\n\nbaz');

      terminal.selectLines(-1, 999);
      expect(
        terminal.getSelectionPosition(),
        const TerminalBufferRange(
          start: TerminalBufferPosition(0, 0),
          end: TerminalBufferPosition(5, 6),
        ),
      );
      terminal.select(1, 2, 2);
      expect(terminal.getSelection(), 'oo');
      terminal.select(0, 0, 0);
      expect(terminal.hasSelection(), isFalse);
      expect(terminal.getSelectionPosition(), isNull);
    });

    test('column selection preserves rectangular text boundaries', () async {
      final terminal = Terminal(options: TerminalOptions(cols: 10, rows: 3));
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('abcdefghij\r\nklmnopqrst\r\nuvwxyz');

      terminal.selectColumns(2, 0, 4, 2);

      expect(terminal.selectionColumnMode, isTrue);
      expect(terminal.getSelection(), 'cd\nmn\nwx');
      expect(
        terminal.getSelectionPosition(),
        const TerminalBufferRange(
          start: TerminalBufferPosition(2, 0),
          end: TerminalBufferPosition(4, 2),
        ),
      );
      terminal.selectColumns(4, 2, 2, 0);
      expect(terminal.getSelection(), 'cd\nmn\nwx');
      terminal.select(0, 0, 1);
      expect(terminal.selectionColumnMode, isFalse);
    });

    test('tracks buffers, modes, marker, decoration, and selection', () async {
      final terminal = Terminal(options: TerminalOptions(cols: 5, rows: 2));
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('hello\r\nworld');
      final marker = terminal.registerMarker();
      expect(marker, isNotNull);
      final decoration = terminal.registerDecoration(marker: marker!);
      expect(decoration, isNotNull);
      terminal.select(0, 0, 5);
      expect(terminal.getSelection(), 'hello');
      var ownedDisposableWasDisposed = false;
      marker
        ..register(
          toDisposable(() {
            ownedDisposableWasDisposed = true;
          }),
        )
        ..dispose();
      expect(marker.line, -1);
      expect(ownedDisposableWasDisposed, isTrue);
      expect(terminal.markers, isEmpty);

      await terminal.writeAndWait('\u001b[?1;45;1004;2004h\u001b[?1049hALT');

      expect(terminal.buffer.active.type, TerminalBufferType.alternate);
      expect(terminal.modes.applicationCursorKeysMode, isTrue);
      expect(terminal.modes.reverseWraparoundMode, isTrue);
      expect(terminal.modes.sendFocusMode, isTrue);
      expect(terminal.modes.bracketedPasteMode, isTrue);
      expect(terminal.registerMarker(), isNotNull);
    });

    test('normalizes and sanitizes bracketed paste', () async {
      final terminal = Terminal();
      addTearDown(terminal.dispose);
      final output = <String>[];
      terminal.onData.listen(output.add);
      await terminal.writeAndWait('\u001b[?2004h');

      terminal.paste('a\nb\u001b[201~');

      expect(output.single, '\u001b[200~a\rb\u241b[201~\u001b[201~');
    });

    test('scrollPages moves by rows minus one and clamps boundaries', () async {
      final terminal = Terminal(options: TerminalOptions(cols: 5, rows: 5));
      addTearDown(terminal.dispose);
      await terminal.writeAndWait('test\r\n' * 15);
      final bottom = terminal.viewportY;

      terminal.scrollPages(-1);
      expect(terminal.viewportY, bottom - 4);
      terminal.scrollPages(1);
      expect(terminal.viewportY, bottom);
      terminal.scrollToLine(-1);
      expect(terminal.viewportY, 0);
      terminal.scrollToLine(bottom + 1);
      expect(terminal.viewportY, bottom);
    });

    test(
      'implements cursor backward tab without exceeding the viewport',
      () async {
        final terminal = Terminal(options: TerminalOptions(cols: 20, rows: 2));
        addTearDown(terminal.dispose);

        await terminal.writeAndWait('\u001b[20G\u001b[2Z#');

        expect(terminal.buffer.active.cursorX, 9);
        expect(
          terminal.buffer.active.getLine(0)!.translateToString(trimRight: true),
          '${List.filled(8, ' ').join()}#',
        );
      },
    );

    test('reverse wraparound crosses only soft-wrapped lines', () async {
      const ttyBackspace = '\b \b';
      final terminal = Terminal(options: TerminalOptions(cols: 5, rows: 3));
      addTearDown(terminal.dispose);

      await terminal.writeAndWait(
        '\u001b[?45h1234512345${List.filled(8, ttyBackspace).join()}',
      );

      expect(
        terminal.buffer.active.getLine(0)!.translateToString(trimRight: true),
        '12   ',
      );
      expect(
        terminal.buffer.active.getLine(1)!.translateToString(trimRight: true),
        '     ',
      );
      expect(terminal.buffer.active.cursorX, 2);
      expect(terminal.buffer.active.cursorY, 0);
    });

    test('DECSET 1049 restores the normal cursor and attributes', () async {
      final terminal = Terminal(options: TerminalOptions(cols: 10, rows: 3));
      addTearDown(terminal.dispose);

      await terminal.writeAndWait(
        '\u001b[?1049h\r\n\u001b[31mJUNK\u001b[?1049lTEST',
      );

      expect(terminal.buffer.active.type, TerminalBufferType.normal);
      expect(
        terminal.buffer.active.getLine(0)!.translateToString(trimRight: true),
        'TEST',
      );
      expect(
        terminal.buffer.active.getLine(1)!.translateToString(trimRight: true),
        '',
      );
    });

    test(
      'accessibility events follow print, tab, and line feed order',
      () async {
        final terminal = Terminal(
          options: TerminalOptions(cols: 20, rows: 3, screenReaderMode: true),
        );
        addTearDown(terminal.dispose);
        final characters = <String>[];
        final tabs = <int>[];
        var lineFeeds = 0;
        terminal.onA11yChar.listen(characters.add);
        terminal.onA11yTab.listen(tabs.add);
        terminal.onLineFeed.listen((_) => lineFeeds++);

        await terminal.writeAndWait('a\tb\n\n');

        expect(characters, <String>['a', 'b']);
        expect(tabs, <int>[7]);
        expect(lineFeeds, 2);
      },
    );
  });

  final fixtureRoot = fixtureDirectory(
    'test/fixtures/xterm/escape_sequence_files',
  );
  if (fixtureRoot.existsSync()) {
    final inputs =
        fixtureRoot
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.in'))
            .toList()
          ..sort((left, right) => left.path.compareTo(right.path));
    group('xterm VT fixtures', () {
      for (final input in inputs) {
        final name = input.uri.pathSegments.last.replaceAll('.in', '');
        final pinnedOutputRoot = fixturePath(
          'test/fixtures/xterm_pinned_outputs',
        );
        final pinnedOutput = File('$pinnedOutputRoot/$name.text');
        final expected = pinnedOutput.existsSync()
            ? pinnedOutput
            : File('${fixtureRoot.path}/$name.text');
        if (!expected.existsSync()) continue;
        test(name, () async {
          final terminal = Terminal(
            options: TerminalOptions(rows: 25, scrollback: 0),
          );
          addTearDown(terminal.dispose);
          // The upstream fixtures are written through a PTY with OPOST/ONLCR,
          // so each source LF reaches the terminal as CRLF.
          await terminal.writeAndWait(
            input.readAsStringSync().replaceAll('\n', '\r\n'),
          );

          final actual = StringBuffer();
          final start = terminal.buffer.active.baseY;
          for (var row = 0; row < 25; row++) {
            actual.writeln(
              terminal.buffer.active
                  .getLine(start + row)!
                  .translateToString(trimRight: true)
                  .trimRight(),
            );
          }
          final expectedRightTrimmed = expected
              .readAsStringSync()
              .split('\n')
              .map((line) => line.trimRight())
              .join('\n');
          expect(actual.toString(), expectedRightTrimmed);
        });
      }
    });
  }
}
