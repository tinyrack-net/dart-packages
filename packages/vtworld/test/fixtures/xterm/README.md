# xterm.js fixtures

The files in `escape_sequence_files` are copied from xterm.js revision
`904ae935269eef5ec6a1415b64463c3d02eff1eb`. Their SHA-256 hashes are recorded
in `packages/termworld/tool/xterm_reference.json`. They remain available under
the adjacent xterm.js MIT license.

`issue-2444` is the exact addon-search regression fixture from the same pinned
revision. Its SHA-256 is
`06993b5124767fedb0d2a4aa1e2cafe5fee1ddb66a9da61acea0b81e3225f847`.

`kitty_keyboard_cases.json` captures every evaluation performed by
`src/common/input/KittyKeyboard.test.ts` at the same revision. It was produced
by instrumenting the pinned implementation in memory while running all 165
upstream tests. Its Git blob hash is verified by the parity gate.

`win32_input_mode_cases.json` similarly captures every event and result from
all 64 pinned `src/common/input/Win32InputMode.test.ts` cases.

`keyboard_cases.json` captures all 61 legacy keyboard tests and their 156
individual evaluations, including duplicate upstream test names.
