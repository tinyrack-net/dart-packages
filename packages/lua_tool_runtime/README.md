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
    source: 'text(tools.read({path="README.md"}).output)',
    tools: [LuaToolDefinition(name: 'read', description: 'Read a file')],
    yieldTime: Duration(seconds: 10),
    maxOutputTokens: 10000,
  ),
  LuaExecutionContext(dispatcher: myDispatcher),
);
```

`LuaToolDispatcher<T>` remains responsible for authorization and actual tool
execution. The runtime preserves `T` without serializing it and only gives Lua
a cell-scoped handle.

## Testing

```console
dart test
```

The host-tagged contract suite builds and executes the real native helper. It
requires CMake and a C compiler.
