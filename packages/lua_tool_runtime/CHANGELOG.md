## 0.3.0

- Add immutable revision-pinned `LuaProgramBundle` snapshots with safe module
  map `require`, Markdown-only assets, and a filesystem loader that rejects
  links, junction escapes, unsafe names, and unsupported source files.
- Add ordered, revision-hashed preload modules from the same safe module map so
  hosts can install a versioned SDK global before the entrypoint runs.
- Add named handler invocation and JSON-compatible handler results. Native
  workers are reused by bundle revision while every invocation receives a
  fresh Lua VM.
- Add the protocol-v2 `host.call/open/next/close` bridge for unary callbacks
  and pull-based streams such as provider-neutral model events.
- Add instruction hooks, wall deadlines, per-revision worker quotas,
  invocation-scoped callback cancellation, and a minimal native-host process
  environment.
- Protocol v2 is not wire-compatible with the 0.2.x native helper. Stage and
  ship the helper and `bootstrap.lua` from the same package revision.

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
