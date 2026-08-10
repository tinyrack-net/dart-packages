# Pinned xterm.js outputs

These four outputs cover VT fixtures that xterm.js intentionally excludes
from its generic terminal comparison. They were captured directly from the
headless terminal at commit `904ae935269eef5ec6a1415b64463c3d02eff1eb`, with
80 columns, 25 rows, no scrollback, and PTY-style LF-to-CRLF conversion.

The original inputs remain byte-for-byte copies under `../xterm/`; these files
only replace expectations whose generic `.text` describes behavior that the
pinned xterm.js implementation deliberately does not implement.
