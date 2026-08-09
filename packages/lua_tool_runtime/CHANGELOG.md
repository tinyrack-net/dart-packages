## 0.2.0

- Return nested tool values to Lua in their natural JSON-compatible shape while
  preserving structured content, metadata, media blocks, and opaque resources.
- Include tool kind, namespace, exposure, and output schema in the runtime tool
  catalog.
- Drain `notify` values separately from normal textual output.
- Let unawaited timers remain detached so they do not keep a Lua cell alive.

## 0.1.1

- Allow native-host staging to use an explicitly supplied CMake executable and
  build directory.

## 0.1.0

- Initial release with sandboxed Lua 5.5.1 execution, resumable cells, parallel
  tool dispatch, JSON session storage, opaque resources, runtime limits, and
  offline native-host staging for Linux, macOS, and Windows.
