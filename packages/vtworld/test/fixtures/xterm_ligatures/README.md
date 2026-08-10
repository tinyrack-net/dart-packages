# xterm.js ligature conformance fixtures

These are the four font fixtures and the 216-case corpus used by
`addons/addon-ligatures/src/fontLigatures/index.test.ts` at xterm.js revision
`904ae935269eef5ec6a1415b64463c3d02eff1eb`.

The font binaries are stored as deterministic gzip streams encoded with
base64 so they can be committed and restored without a binary patch. Tests
decode them in memory. Their decoded SHA-256 digests are:

- `FiraCode-Regular.otf`: `baa4dc8673dba72061481507e8480b09c1cbf9a7884c9989cf206c56bff388fe`
- `iosevka-regular.ttf`: `806642aae15244a2e7b706f135b4da5231302b5612205e1a6592952cd2d8bd36`
- `Monoid-Regular.ttf`: `fd119e732472cc35803480668f316160b0cfa4d5217e7c995dbe91bd9cf19706`
- `UbuntuMono-Regular.ttf`: `b35dd9d2131d5d83a9b87fe9ad22c6288fa3d17688d43302c14da29812417d63`

The files originate from the xterm.js repository and retain their upstream
font licenses. The xterm.js test and fixture arrangement is covered by the
MIT license recorded in `xterm_parity.yaml`.
