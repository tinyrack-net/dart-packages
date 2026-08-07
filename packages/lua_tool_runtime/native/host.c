#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <time.h>

#include "lauxlib.h"
#include "lualib.h"

#define DEFAULT_MEMORY_LIMIT (64u * 1024u * 1024u)

typedef struct RuntimeAllocator {
  size_t used;
  size_t limit;
} RuntimeAllocator;

static void open_library(lua_State *state, const char *name,
                         lua_CFunction function) {
  luaL_requiref(state, name, function, 1);
  lua_pop(state, 1);
}

static void *limited_alloc(void *user_data, void *pointer, size_t old_size,
                           size_t new_size) {
  RuntimeAllocator *allocator = (RuntimeAllocator *)user_data;
  if (pointer == NULL) {
    old_size = 0;
  }
  if (new_size == 0) {
    free(pointer);
    allocator->used -= old_size;
    return NULL;
  }
  if (new_size > old_size &&
      (allocator->used >= allocator->limit ||
       new_size - old_size > allocator->limit - allocator->used)) {
    return NULL;
  }
  void *replacement = realloc(pointer, new_size);
  if (replacement != NULL) {
    allocator->used = allocator->used - old_size + new_size;
  }
  return replacement;
}

int main(int argument_count, char **arguments) {
  if (argument_count != 2) {
    fputs("usage: lua-tool-runtime-host <bootstrap.lua>\n", stderr);
    return 64;
  }
  size_t memory_limit = DEFAULT_MEMORY_LIMIT;
  const char *configured_limit = getenv("LUA_TOOL_RUNTIME_MEMORY_LIMIT_BYTES");
  if (configured_limit != NULL && configured_limit[0] != '\0') {
    char *end = NULL;
    unsigned long long parsed = strtoull(configured_limit, &end, 10);
    if (end == configured_limit || *end != '\0' || parsed > SIZE_MAX ||
        parsed < 1024u * 1024u) {
      fputs("invalid LUA_TOOL_RUNTIME_MEMORY_LIMIT_BYTES\n", stderr);
      return 64;
    }
    memory_limit = (size_t)parsed;
  }
  RuntimeAllocator allocator = {0, memory_limit};
  unsigned seed = (unsigned)time(NULL) ^ (unsigned)(uintptr_t)&allocator;
  lua_State *state = lua_newstate(limited_alloc, &allocator, seed);
  if (state == NULL) {
    fputs("failed to allocate Lua state\n", stderr);
    return 70;
  }
  open_library(state, LUA_GNAME, luaopen_base);
  open_library(state, LUA_COLIBNAME, luaopen_coroutine);
  open_library(state, LUA_TABLIBNAME, luaopen_table);
  open_library(state, LUA_IOLIBNAME, luaopen_io);
  open_library(state, LUA_STRLIBNAME, luaopen_string);
  open_library(state, LUA_MATHLIBNAME, luaopen_math);
  open_library(state, LUA_UTF8LIBNAME, luaopen_utf8);
  open_library(state, LUA_DBLIBNAME, luaopen_debug);
  int status = luaL_loadfile(state, arguments[1]);
  if (status == LUA_OK) {
    status = lua_pcall(state, 0, 0, 0);
  }
  if (status != LUA_OK) {
    const char *message = lua_tostring(state, -1);
    fprintf(stderr, "%s\n", message != NULL ? message : "Lua host failed");
  }
  lua_close(state);
  return status == LUA_OK ? 0 : 70;
}
