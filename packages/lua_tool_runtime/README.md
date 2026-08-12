# lua_tool_runtime

`lua_tool_runtime` runs untrusted Lua 5.5.1 program bundles in a memory-limited
helper process and lets named handlers orchestrate typed Dart callbacks. Native
workers are lazily reused by immutable bundle revision, but every invocation
uses a fresh Lua VM. Durable state therefore stays in typed host APIs instead
of Lua globals. Session state is limited to JSON values, while files and media
remain opaque Dart resources.

The user environment includes Lua's safe base, coroutine, table, string, math,
and UTF-8 APIs plus safe module-map `require`, Markdown `assets.read`, `tools`,
`host`, `spawn`, `await`, `await_all`, `text`, `image`, `audio`,
`generated_image`, `store`, `load`, timers, `yield_control`, and `exit`. It does
not expose `io`, `os`, `package`, `debug`, ambient environment variables,
networking, process creation, or dynamic-library loading.

## Program bundles

Create a bundle from already-validated source or snapshot the conventional
`main.lua`, `lua/**/*.lua`, and `prompts/**/*.md` layout. The loader never
follows a link or junction and rejects path escapes before reading source.

```dart
final bundle = await LuaProgramBundleLoader.load(
  root: pluginDirectory,
  revision: verifiedContentHash,
  preloadModules: const ['tinest.sdk'],
);
```

The entrypoint module must return a table of named handlers:

```lua
local prompt = require("prompt_builder")

return {
  run = function(input)
    local system = assets.read("prompts/system.md")
    return {prompt = prompt.build(system, input.message)}
  end,
}
```

`LuaProgramBundle` copies and freezes its module map, Markdown asset map, and
ordered `preloadModules`. Each preload is resolved from the same safe module
map before the entrypoint and may install a versioned SDK table such as the
global `tinest`; it is not an arbitrary host prelude or filesystem load. A
session rejects a revision identifier if later content differs, so a running
host cannot silently replace a pinned plugin revision.

## Staging the native host

Lua 5.5.1 is vendored, so staging is offline and reproducible:

```console
dart run lua_tool_runtime:stage \
  --destination build/runtime \
  --build-mode release
```

Pass `--cmake-executable PATH` when CMake is supplied by a parent build system
instead of being available on `PATH`. The Dart API exposes the same choice as
the optional `cmakeExecutable` argument to `stageLuaToolRuntime`. Parent build
systems can also pass `--build-directory DIR` to keep native intermediates in
their own build tree; this is especially useful for Windows path-length limits.

The destination contains `lua-tool-runtime-host` (or the Windows `.exe`) and a
`lua_tool_runtime` data directory. Include both in the application or CLI
bundle and sign the helper with the containing product.

## Runtime integration

```dart
final runtime = LuaToolRuntime<MyResource>(
  host: LuaHostCommand.fromDirectory('build/runtime'),
  processLauncher: const IoLuaHostProcessLauncher(),
  clock: const SystemLuaClock(),
  ids: myIdGenerator,
);
final session = runtime.createSession();

final delta = await session.invoke(
  LuaInvokeRequest(
    bundle: bundle,
    handler: 'run',
    arguments: const {'message': 'hello'},
    tools: [
      LuaToolDefinition(
        name: 'read',
        description: 'Read a file',
        namespace: 'files',
        inputSchema: {
          'type': 'object',
          'properties': {
            'path': {'type': 'string'},
          },
          'required': ['path'],
        },
        outputSchema: {'type': 'string'},
      ),
    ],
    yieldTime: const Duration(seconds: 10),
    maxOutputTokens: 10000,
  ),
  LuaExecutionContext(dispatcher: myDispatcher),
);
```

`execute(LuaExecuteRequest(...))` remains as a code-mode convenience and is
implemented as an immutable inline bundle plus named handler.

`LuaToolDispatcher<T>` remains responsible for authorization and actual tool
execution. The runtime preserves `T` without serializing it and only gives Lua
a cell-scoped handle. Nested tools return strings, numbers, booleans, lists, and
objects directly to Lua. Enriched results retain their `value`, `content`,
`structured_content`, `_meta`, error state, and opaque attachment handles.
`notify(value)` is drained through `LuaCellDelta.notifications`, separately from
normal output. An unawaited timer is detached and does not keep the cell alive;
calling `await` on its task makes it part of the cell lifetime.

## Host callbacks and streams

Implement `LuaHostCallbackDispatcher<T>` to expose capability-brokered unary
operations or event streams. The generic bridge keeps provider and product
types outside this package:

```lua
local stream = host.open("model.events", request)
while true do
  local item = host.next(stream)
  if item.done then break end
  text(item.value)
end
host.close(stream)
```

`host.call` invokes a unary callback. `host.open` creates a cell-scoped opaque
stream handle; `host.next` pulls one event; and `host.close` cancels it. Tool
and host invocations receive `LuaInvocationCancellation`, which is fired when
the cell, wall deadline, or owning consumer cancels the invocation.

## Isolation and limits

`LuaRuntimeLimits` bounds memory, source, protocol frame, output, live cells,
workers per revision, observation time, idle lifetime, wall time, and Lua VM
instructions. The native helper enforces the instruction budget with
`lua_sethook`; Dart enforces the wall deadline across both compute and host
awaits. The IO launcher starts the helper with no inherited environment except
the small Windows process-creation allowlist and explicitly configured values.

The subprocess wire protocol is versioned. Protocol v2 adds immutable bundles,
named handlers, results, and bidirectional callback streams. Always stage the
native helper and `bootstrap.lua` from the exact package revision used by Dart.

## Testing

```console
dart test
```

The host-tagged contract suite builds and executes the real native helper. It
requires CMake and a C compiler.
