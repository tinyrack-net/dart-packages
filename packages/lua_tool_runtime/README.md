# lua_tool_runtime

`lua_tool_runtime` runs untrusted Lua 5.5.1 chunks in a memory-limited helper
process and lets those chunks orchestrate typed Dart callbacks. Each execution
uses a fresh Lua VM. Session state is limited to JSON values, while files and
media remain opaque Dart resources.

The user environment includes Lua's safe base, coroutine, table, string, math,
and UTF-8 APIs plus `tools`, `spawn`, `await`, `await_all`, `text`, `image`,
`audio`, `generated_image`, `store`, `load`, timers, `yield_control`, and
`exit`. It does not expose `io`, `os`, `package`, `debug`, networking, process
creation, or dynamic-library loading.

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

final delta = await session.execute(
  const LuaExecuteRequest(
    source: 'text(tools.read({path="README.md"}))',
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
    yieldTime: Duration(seconds: 10),
    maxOutputTokens: 10000,
  ),
  LuaExecutionContext(dispatcher: myDispatcher),
);
```

`LuaToolDispatcher<T>` remains responsible for authorization and actual tool
execution. The runtime preserves `T` without serializing it and only gives Lua
a cell-scoped handle. Nested tools return strings, numbers, booleans, lists, and
objects directly to Lua. Enriched results retain their `value`, `content`,
`structured_content`, `_meta`, error state, and opaque attachment handles.
`notify(value)` is drained through `LuaCellDelta.notifications`, separately from
normal output. An unawaited timer is detached and does not keep the cell alive;
calling `await` on its task makes it part of the cell lifetime.

## Testing

```console
dart test
```

The host-tagged contract suite builds and executes the real native helper. It
requires CMake and a C compiler.
