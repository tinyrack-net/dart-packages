-- lua_tool_runtime privileged protocol bootstrap.
--
-- This file runs in the privileged host environment. User chunks are loaded
-- with `safe_env` below and therefore cannot reach these locals or Lua's I/O,
-- process, package, debug, or dynamic-library facilities.

local protocol_version = 2
local input = io.stdin
local output = io.stdout
local traceback = debug.traceback
local JSON_NULL = setmetatable({}, {__tostring=function() return 'null' end})

local function json_escape(value)
  return value:gsub('[%z\1-\31\\"]', function(char)
    local escapes = {
      ['"'] = '\\"', ['\\'] = '\\\\', ['\b'] = '\\b', ['\f'] = '\\f',
      ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t',
    }
    return escapes[char] or string.format('\\u%04x', string.byte(char))
  end)
end

local function json_encode(value, seen)
  if value == JSON_NULL then return 'null' end
  local kind = type(value)
  if kind == 'nil' then return 'null' end
  if kind == 'boolean' then return value and 'true' or 'false' end
  if kind == 'number' then
    if value ~= value or value == math.huge or value == -math.huge then
      error('non-finite number is not JSON serializable')
    end
    return tostring(value)
  end
  if kind == 'string' then return '"' .. json_escape(value) .. '"' end
  if kind ~= 'table' then error(kind .. ' is not JSON serializable') end
  seen = seen or {}
  if seen[value] then error('cyclic table is not JSON serializable') end
  seen[value] = true
  local count, maximum, array = 0, 0, true
  for key in pairs(value) do
    count = count + 1
    if type(key) ~= 'number' or key < 1 or key % 1 ~= 0 then
      array = false
    else
      maximum = math.max(maximum, key)
    end
  end
  if array and maximum ~= count then array = false end
  local parts = {}
  if array then
    for index = 1, maximum do
      parts[index] = json_encode(value[index], seen)
    end
    seen[value] = nil
    return '[' .. table.concat(parts, ',') .. ']'
  end
  for key, item in pairs(value) do
    if type(key) ~= 'string' then error('JSON object keys must be strings') end
    parts[#parts + 1] = json_encode(key) .. ':' .. json_encode(item, seen)
  end
  table.sort(parts)
  seen[value] = nil
  return '{' .. table.concat(parts, ',') .. '}'
end

local function json_decode(source)
  local position = 1
  local function skip_space()
    local _, finish = source:find('^[ \t\r\n]*', position)
    position = (finish or position - 1) + 1
  end
  local parse_value
  local function parse_string()
    position = position + 1
    local parts = {}
    while position <= #source do
      local char = source:sub(position, position)
      if char == '"' then position = position + 1; return table.concat(parts) end
      if char == '\\' then
        local escaped = source:sub(position + 1, position + 1)
        local simple = {['"']='"', ['\\']='\\', ['/']='/', b='\b', f='\f', n='\n', r='\r', t='\t'}
        if simple[escaped] then
          parts[#parts + 1] = simple[escaped]
          position = position + 2
        elseif escaped == 'u' then
          local code = tonumber(source:sub(position + 2, position + 5), 16)
          if not code then error('invalid JSON unicode escape') end
          parts[#parts + 1] = utf8.char(code)
          position = position + 6
        else error('invalid JSON escape') end
      else
        parts[#parts + 1] = char
        position = position + 1
      end
    end
    error('unterminated JSON string')
  end
  local function parse_array()
    position = position + 1
    local result = {}
    skip_space()
    if source:sub(position, position) == ']' then position = position + 1; return result end
    while true do
      result[#result + 1] = parse_value()
      skip_space()
      local char = source:sub(position, position)
      if char == ']' then position = position + 1; return result end
      if char ~= ',' then error('expected JSON array comma') end
      position = position + 1
    end
  end
  local function parse_object()
    position = position + 1
    local result = {}
    skip_space()
    if source:sub(position, position) == '}' then position = position + 1; return result end
    while true do
      skip_space()
      if source:sub(position, position) ~= '"' then error('expected JSON object key') end
      local key = parse_string()
      skip_space()
      if source:sub(position, position) ~= ':' then error('expected JSON colon') end
      position = position + 1
      result[key] = parse_value()
      skip_space()
      local char = source:sub(position, position)
      if char == '}' then position = position + 1; return result end
      if char ~= ',' then error('expected JSON object comma') end
      position = position + 1
    end
  end
  function parse_value()
    skip_space()
    local char = source:sub(position, position)
    if char == '"' then return parse_string() end
    if char == '[' then return parse_array() end
    if char == '{' then return parse_object() end
    local literals = {['true']=true, ['false']=false}
    for literal, value in pairs(literals) do
      if source:sub(position, position + #literal - 1) == literal then
        position = position + #literal
        return value
      end
    end
    if source:sub(position, position + 3) == 'null' then position = position + 4; return JSON_NULL end
    local token = source:match('^-?%d+%.?%d*[eE]?[+-]?%d*', position)
    if token and #token > 0 then position = position + #token; return assert(tonumber(token)) end
    error('invalid JSON value at byte ' .. position)
  end
  local result = parse_value()
  skip_space()
  if position <= #source then error('trailing JSON data') end
  return result
end

local sequence = 0
local cell_id
local function send(kind, payload)
  sequence = sequence + 1
  local frame = {
    version = protocol_version,
    cell_id = cell_id,
    sequence_id = sequence,
    type = kind,
    payload = payload or {},
  }
  output:write(json_encode(frame), '\n')
  output:flush()
end

local input_sequence = 1
local function receive(expected)
  local line = input:read('*l')
  if not line then error('host input closed') end
  local frame = json_decode(line)
  if frame.version ~= protocol_version or frame.cell_id ~= cell_id or
      frame.sequence_id ~= input_sequence then
    error('protocol identity mismatch')
  end
  input_sequence = input_sequence + 1
  if expected and frame.type ~= expected and frame.type ~= 'terminate' then
    error('unexpected protocol frame: ' .. tostring(frame.type))
  end
  return frame
end

local first_line = input:read('*l')
if not first_line then return end
local ok_init, initial = pcall(json_decode, first_line)
if not ok_init or initial.version ~= protocol_version or
    initial.sequence_id ~= 0 or initial.type ~= 'invoke' then
  output:write('{"version":2,"cell_id":"unknown","sequence_id":1,"type":"error","payload":{"message":"invalid invoke frame"}}\n')
  output:flush()
  return
end
cell_id = initial.cell_id
local init = initial.payload
local bundle = init.bundle or {}

local tasks, runnable, waiting, next_task = {}, {}, {}, 0
local session_store = init.store or {}
local cancelled_timers = {}

local function enqueue(task, ...)
  runnable[#runnable + 1] = {task = task, values = table.pack(...)}
end

local function spawn_task(fn, ...)
  if type(fn) ~= 'function' then error('spawn expects a function', 2) end
  next_task = next_task + 1
  local task = {id = next_task, coroutine = coroutine.create(fn), done = false}
  tasks[task.id] = task
  enqueue(task, ...)
  return task
end

local function await_task(task)
  if type(task) ~= 'table' or not task.id or tasks[task.id] ~= task then
    error('await expects a task returned by spawn', 2)
  end
  task.detached = false
  if task.done then
    if task.error then error(task.error, 2) end
    return table.unpack(task.values, 1, task.values.n)
  end
  local packed = table.pack(coroutine.yield({kind = 'await', task_id = task.id}))
  if packed[1] == false then error(packed[2], 2) end
  return table.unpack(packed, 2, packed.n)
end

local tools = {}
function tools.call(name, arguments)
  if type(name) ~= 'string' then error('tools.call expects a tool name', 2) end
  return coroutine.yield({kind = 'tool', name = name, arguments = arguments or {}})
end
setmetatable(tools, {__index = function(_, name)
  return function(arguments) return tools.call(name, arguments) end
end, __metatable = false})

local host = {}
function host.call(name, arguments)
  if type(name) ~= 'string' then error('host.call expects a callback name', 2) end
  return coroutine.yield({kind = 'host_call', name = name, arguments = arguments or {}})
end
function host.open(name, arguments)
  if type(name) ~= 'string' then error('host.open expects a callback name', 2) end
  return coroutine.yield({kind = 'host_open', name = name, arguments = arguments or {}})
end
function host.next(stream_handle)
  if type(stream_handle) ~= 'string' then error('host.next expects a stream handle', 2) end
  return coroutine.yield({kind = 'host_next', stream_handle = stream_handle})
end
function host.close(stream_handle)
  if type(stream_handle) ~= 'string' then error('host.close expects a stream handle', 2) end
  return coroutine.yield({kind = 'host_close', stream_handle = stream_handle})
end

local function emit(kind, value)
  coroutine.yield({kind = kind, value = value})
end

local safe_require
local safe_env = {
  assert=assert, error=error, ipairs=ipairs, next=next, pairs=pairs,
  pcall=pcall, select=select, tonumber=tonumber, tostring=tostring,
  type=type, utf8=utf8, xpcall=xpcall,
  math=math, string=string, table=table,
  tools=tools, host=host, spawn=spawn_task, await=await_task,
  await_all=function(list)
    local results = {}
    for index, task in ipairs(list) do results[index] = table.pack(await_task(task)) end
    return results
  end,
  text=function(value) emit('text', value) end,
  image=function(value) emit('image', value) end,
  audio=function(value) emit('audio', value) end,
  generated_image=function(value) emit('generated_image', value) end,
  notify=function(value) emit('notify', value) end,
  store=function(key, value)
    if type(key) ~= 'string' then error('store key must be a string', 2) end
    -- Validate now so a bad value cannot poison a later protocol frame.
    json_encode(value)
    session_store[key] = value
  end,
  load=function(key) return session_store[key] end,
  yield_control=function() return coroutine.yield({kind = 'yield_control'}) end,
  exit=function() return coroutine.yield({kind = 'exit'}) end,
  clear_timeout=function(timer) if timer then cancelled_timers[timer.id] = true end end,
  NULL=JSON_NULL,
}
safe_env.set_timeout = function(fn, milliseconds)
  local timer
  timer = spawn_task(function()
    coroutine.yield({kind = 'sleep', milliseconds = milliseconds or 0})
    if not cancelled_timers[timer.id] then fn() end
  end)
  timer.detached = true
  return timer
end
safe_env.ALL_TOOLS = init.tools or {}
safe_env.assets = {
  read=function(path)
    if type(path) ~= 'string' then error('assets.read expects a path', 2) end
    local value = (bundle.markdown_assets or {})[path]
    if value == nil then error('Markdown asset not found: ' .. path, 2) end
    return value
  end,
}
local module_cache, module_loading = {}, {}
safe_require = function(name)
  if type(name) ~= 'string' or
      not name:match('^[a-z_][a-z0-9_%.]*$') or
      name:sub(-1) == '.' or name:find('..', 1, true) then
    error('invalid Lua module name: ' .. tostring(name), 2)
  end
  if module_cache[name] ~= nil then return module_cache[name] end
  if module_loading[name] then error('cyclic Lua module: ' .. name, 2) end
  local source = (bundle.modules or {})[name]
  if type(source) ~= 'string' then error('Lua module not found: ' .. name, 2) end
  module_loading[name] = true
  local chunk, compile_error = load(source, '@bundle/' .. name .. '.lua', 't', safe_env)
  if not chunk then module_loading[name] = nil; error(compile_error, 2) end
  local ok, value = pcall(chunk)
  module_loading[name] = nil
  if not ok then error(value, 2) end
  if value == nil then value = true end
  module_cache[name] = value
  return value
end
safe_env.require = safe_require
safe_env._G = safe_env

for _, preload in ipairs(bundle.preload_modules or {}) do
  local ok_preload, preload_error = pcall(safe_require, preload)
  if not ok_preload then send('error', {message = preload_error}); return end
end
local ok_entrypoint, entrypoint = pcall(safe_require, bundle.entrypoint)
if not ok_entrypoint then send('error', {message = entrypoint}); return end
if type(entrypoint) ~= 'table' then
  send('error', {message = 'entrypoint module must return a handler table'}); return
end
local handler = entrypoint[init.handler]
if type(handler) ~= 'function' then
  send('error', {message = 'named handler not found: ' .. tostring(init.handler)}); return
end
spawn_task(handler, init.arguments or {})

local function finish_task(task, resumed)
  task.done = true
  if resumed[1] then
    task.values = table.pack(table.unpack(resumed, 2, resumed.n))
  else
    local message = tostring(resumed[2])
    if message:lower():find('memory', 1, true) then
      task.error = message
    else
      task.error = traceback(task.coroutine, message)
    end
    task.values = table.pack()
  end
  task.coroutine = nil
  collectgarbage('collect')
  local waiters = waiting[task.id] or {}
  waiting[task.id] = nil
  for _, waiter in ipairs(waiters) do
    if task.error then enqueue(waiter, false, task.error)
    else enqueue(waiter, true, table.unpack(task.values, 1, task.values.n)) end
  end
end

local function completed_payload()
  local root = tasks[1]
  local result = JSON_NULL
  if root and root.values and root.values.n > 0 then result = root.values[1] end
  json_encode(result)
  return {store = session_store, result = result}
end

while true do
  local calls, call_tasks = {}, {}
  while #runnable > 0 do
    local selected = 1
    for index, candidate in ipairs(runnable) do
      if not candidate.task.detached then selected = index; break end
    end
    local current = table.remove(runnable, selected)
    local task = current.task
    if task.detached and #calls > 0 then
      table.insert(runnable, 1, current)
      break
    end
    local resumed = table.pack(coroutine.resume(task.coroutine, table.unpack(current.values, 1, current.values.n)))
    if not resumed[1] or coroutine.status(task.coroutine) == 'dead' then
      finish_task(task, resumed)
      if task.id == 1 and task.error then
        local category = task.error:find('__LUA_LIMIT_', 1, true) and 'limit' or 'script'
        send('error', {message = task.error, category = category, store = session_store}); return
      end
    else
      local operation = resumed[2]
      if type(operation) ~= 'table' or not operation.kind then
        send('error', {message = 'invalid coroutine yield'}); return
      elseif operation.kind == 'tool' then
        local request_id = tostring(task.id) .. ':' .. tostring(sequence + #calls + 1)
        calls[#calls + 1] = {request_id=request_id, operation='tool_call', name=operation.name, arguments=operation.arguments}
        call_tasks[request_id] = task
      elseif operation.kind == 'host_call' or operation.kind == 'host_open' then
        local request_id = tostring(task.id) .. ':' .. tostring(sequence + #calls + 1)
        calls[#calls + 1] = {request_id=request_id, operation=operation.kind, name=operation.name, arguments=operation.arguments}
        call_tasks[request_id] = task
      elseif operation.kind == 'host_next' or operation.kind == 'host_close' then
        local request_id = tostring(task.id) .. ':' .. tostring(sequence + #calls + 1)
        calls[#calls + 1] = {request_id=request_id, operation=operation.kind, stream_handle=operation.stream_handle}
        call_tasks[request_id] = task
      elseif operation.kind == 'await' then
        waiting[operation.task_id] = waiting[operation.task_id] or {}
        waiting[operation.task_id][#waiting[operation.task_id] + 1] = task
      elseif operation.kind == 'sleep' then
        local request_id = 'timer:' .. tostring(task.id)
        calls[#calls + 1] = {request_id=request_id, sleep_ms=operation.milliseconds}
        call_tasks[request_id] = task
      elseif operation.kind == 'yield_control' then
        send('yielded', {store = session_store})
        local control = receive('continue')
        if control.type == 'terminate' then send('terminated', {store=session_store}); return end
        enqueue(task)
      elseif operation.kind == 'exit' then
        send('completed', completed_payload()); return
      else
        send('output', {kind=operation.kind, value=operation.value})
        enqueue(task)
      end
    end
  end
  if #calls > 0 then
    local attached_live = false
    for _, task in pairs(tasks) do
      if not task.done and not task.detached then attached_live = true; break end
    end
    if not attached_live then send('completed', completed_payload()); return end
    send('callback_batch', {calls = calls})
    local response = receive('callback_results')
    if response.type == 'terminate' then send('terminated', {store=session_store}); return end
    for _, result in ipairs(response.payload.results or {}) do
      local task = call_tasks[result.request_id]
      if task then enqueue(task, result.value) end
    end
  else
    local live = false
    for _, task in pairs(tasks) do if not task.done then live = true; break end end
    if not live then send('completed', completed_payload()); return end
    if #runnable == 0 then send('error', {message='scheduler deadlock', store=session_store}); return end
  end
end
