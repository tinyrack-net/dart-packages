#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <time.h>

#include "lauxlib.h"
#include "lualib.h"

#define DEFAULT_MEMORY_LIMIT (64u * 1024u * 1024u)
#define DEFAULT_INSTRUCTION_LIMIT 100000000ull
#define DEFAULT_HOOK_INTERVAL 10000

typedef struct RuntimeAllocator {
  size_t used;
  size_t limit;
} RuntimeAllocator;

typedef struct ExecutionBudget {
  unsigned long long used;
  unsigned long long limit;
  int interval;
} ExecutionBudget;

static void budget_hook(lua_State *state, lua_Debug *debug) {
  (void)debug;
  ExecutionBudget *budget = *(ExecutionBudget **)lua_getextraspace(state);
  if (budget == NULL) {
    luaL_error(state, "__LUA_LIMIT_INTERNAL__: missing execution budget");
    return;
  }
  budget->used += (unsigned long long)budget->interval;
  if (budget->used > budget->limit) {
    luaL_error(state, "__LUA_LIMIT_INSTRUCTIONS__: instruction budget exceeded");
  }
}

static int parse_positive_limit(const char *name, unsigned long long fallback,
                                unsigned long long minimum,
                                unsigned long long *result) {
  const char *configured = getenv(name);
  if (configured == NULL || configured[0] == '\0') {
    *result = fallback;
    return 1;
  }
  char *end = NULL;
  unsigned long long parsed = strtoull(configured, &end, 10);
  if (end == configured || *end != '\0' || parsed < minimum) {
    fprintf(stderr, "invalid %s\n", name);
    return 0;
  }
  *result = parsed;
  return 1;
}

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
  unsigned long long configured_memory = 0;
  unsigned long long instruction_limit = 0;
  unsigned long long hook_interval = 0;
  if (!parse_positive_limit("LUA_TOOL_RUNTIME_MEMORY_LIMIT_BYTES",
                            DEFAULT_MEMORY_LIMIT, 1024u * 1024u,
                            &configured_memory) ||
      configured_memory > SIZE_MAX ||
      !parse_positive_limit("LUA_TOOL_RUNTIME_INSTRUCTION_LIMIT",
                            DEFAULT_INSTRUCTION_LIMIT, 1000u,
                            &instruction_limit) ||
      !parse_positive_limit("LUA_TOOL_RUNTIME_HOOK_INTERVAL",
                            DEFAULT_HOOK_INTERVAL, 100u, &hook_interval) ||
      hook_interval > INT32_MAX) {
    return 64;
  }

  while (!feof(stdin)) {
    RuntimeAllocator allocator = {0, (size_t)configured_memory};
    ExecutionBudget budget = {0, instruction_limit, (int)hook_interval};
    unsigned seed = (unsigned)time(NULL) ^ (unsigned)(uintptr_t)&allocator;
    lua_State *state = lua_newstate(limited_alloc, &allocator, seed);
    if (state == NULL) {
      fputs("failed to allocate Lua state\n", stderr);
      return 70;
    }
    *(ExecutionBudget **)lua_getextraspace(state) = &budget;
    open_library(state, LUA_GNAME, luaopen_base);
    open_library(state, LUA_COLIBNAME, luaopen_coroutine);
    open_library(state, LUA_TABLIBNAME, luaopen_table);
    open_library(state, LUA_IOLIBNAME, luaopen_io);
    open_library(state, LUA_STRLIBNAME, luaopen_string);
    open_library(state, LUA_MATHLIBNAME, luaopen_math);
    open_library(state, LUA_UTF8LIBNAME, luaopen_utf8);
    open_library(state, LUA_DBLIBNAME, luaopen_debug);
    lua_sethook(state, budget_hook, LUA_MASKCOUNT, budget.interval);
    int status = luaL_loadfile(state, arguments[1]);
    if (status == LUA_OK) {
      status = lua_pcall(state, 0, 0, 0);
    }
    if (status != LUA_OK) {
      const char *message = lua_tostring(state, -1);
      fprintf(stderr, "%s\n", message != NULL ? message : "Lua host failed");
    }
    lua_close(state);
    if (status != LUA_OK) return 70;
  }
  return 0;
}
