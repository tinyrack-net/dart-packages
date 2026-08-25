## 0.1.1

- Keep draining Windows ConPTY output until it remains quiet after process
  exit, preventing buffered terminal output from being truncated.

## 0.1.0

- Initial release. Cross-platform pseudo-terminal processes built on `openpty`
  (Linux, macOS) and ConPTY (Windows), with raw output streaming, ordered
  non-blocking writes, window resizing, exact exit codes, and process-tree
  termination.
