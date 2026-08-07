cmake_minimum_required(VERSION 3.18)
project(lua_tool_runtime_host LANGUAGES C)

set(LUA_SOURCE_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/lua")
file(GLOB LUA_LIBRARY_SOURCES CONFIGURE_DEPENDS
  "${LUA_SOURCE_DIRECTORY}/*.c")
list(REMOVE_ITEM LUA_LIBRARY_SOURCES
  "${LUA_SOURCE_DIRECTORY}/lua.c"
  "${LUA_SOURCE_DIRECTORY}/luac.c"
  "${LUA_SOURCE_DIRECTORY}/onelua.c"
  "${LUA_SOURCE_DIRECTORY}/ltests.c")

add_library(lua_tool_runtime_lua STATIC ${LUA_LIBRARY_SOURCES})
target_include_directories(lua_tool_runtime_lua PUBLIC "${LUA_SOURCE_DIRECTORY}")
if(UNIX)
  target_link_libraries(lua_tool_runtime_lua PUBLIC m)
endif()

add_executable(lua-tool-runtime-host "${CMAKE_CURRENT_SOURCE_DIR}/host.c")
target_link_libraries(lua-tool-runtime-host PRIVATE lua_tool_runtime_lua)
set_target_properties(lua-tool-runtime-host PROPERTIES
  C_STANDARD 99
  C_STANDARD_REQUIRED YES
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/host"
  RUNTIME_OUTPUT_DIRECTORY_DEBUG "${CMAKE_BINARY_DIR}/host"
  RUNTIME_OUTPUT_DIRECTORY_RELEASE "${CMAKE_BINARY_DIR}/host")
