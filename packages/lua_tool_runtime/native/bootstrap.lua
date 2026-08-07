-- lua_tool_runtime privileged protocol bootstrap.
--
-- This file runs in the privileged host environment. User chunks are loaded
-- with `safe_env` below and therefore cannot reach these locals or Lua's I/O,
-- process, package, debug, or dynamic-library facilities.

local protocol_version = 1
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

local function receive(expected)
  local line = input:read('*l')
  if not line then error('host input closed') end
  local frame = json_decode(line)
  if frame.version ~= protocol_version or frame.cell_id ~= cell_id then
    error('protocol identity mismatch')
  end
  if expected and frame.type ~= expected and frame.type ~= 'terminate' then
    error('unexpected protocol frame: ' .. tostring(frame.type))
  end
  return frame
end

local first_line = input:read('*l')
if not first_line then return end
local ok_init, initial = pcall(json_decode, first_line)
if not ok_init or initial.version ~= protocol_version or initial.type ~= 'init' then
  output:write('{"version":1,"cell_id":"unknown","sequence_id":1,"type":"error","payload":{"message":"invalid init frame"}}\n')
  output:flush()
  return
end
cell_id = initial.cell_id
local init = initial.payload

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

local function emit(kind, value)
  coroutine.yield({kind = kind, value = value})
end

local safe_env = {
  assert=assert, error=error, ipairs=ipairs, next=next, pairs=pairs,
  pcall=pcall, select=select, tonumber=tonumber, tostring=tostring,
  type=type, utf8=utf8, xpcall=xpcall,
  math=math, string=string, table=table,
  tools=tools, spawn=spawn_task, await=await_task,
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
  return timer
end
safe_env.ALL_TOOLS = init.tools or {}
safe_env._G = safe_env

local chunk, compile_error = load(init.source, '=code-mode', 't', safe_env)
if not chunk then send('error', {message = compile_error}); return end
spawn_task(chunk)

local function finish_task(task, resumed)
  task.done = true
  if resumed[1] then
    task.values = table.pack(table.unpack(resumed, 2, resumed.n))
  else
    task.error = traceback(task.coroutine, tostring(resumed[2]))
    task.values = table.pack()
  end
  local waiters = waiting[task.id] or {}
  waiting[task.id] = nil
  for _, waiter in ipairs(waiters) do
    if task.error then enqueue(waiter, false, task.error)
    else enqueue(waiter, true, table.unpack(task.values, 1, task.values.n)) end
  end
end

while true do
  local calls, call_tasks = {}, {}
  while #runnable > 0 do
    local current = table.remove(runnable, 1)
    local task = current.task
    local resumed = table.pack(coroutine.resume(task.coroutine, table.unpack(current.values, 1, current.values.n)))
    if not resumed[1] or coroutine.status(task.coroutine) == 'dead' then
      finish_task(task, resumed)
      if task.id == 1 and task.error then send('error', {message = task.error, store = session_store}); return end
    else
      local operation = resumed[2]
      if type(operation) ~= 'table' or not operation.kind then
        send('error', {message = 'invalid coroutine yield'}); return
      elseif operation.kind == 'tool' then
        local request_id = tostring(task.id) .. ':' .. tostring(sequence + #calls + 1)
        calls[#calls + 1] = {request_id=request_id, name=operation.name, arguments=operation.arguments}
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
        send('completed', {store = session_store}); return
      else
        send('output', {kind=operation.kind, value=operation.value})
        enqueue(task)
      end
    end
  end
  if #calls > 0 then
    send('tool_batch', {calls = calls})
    local response = receive('tool_results')
    if response.type == 'terminate' then send('terminated', {store=session_store}); return end
    for _, result in ipairs(response.payload.results or {}) do
      local task = call_tasks[result.request_id]
      if task then enqueue(task, result.value) end
    end
  else
    local live = false
    for _, task in pairs(tasks) do if not task.done then live = true; break end end
    if not live then send('completed', {store = session_store}); return end
    if #runnable == 0 then send('error', {message='scheduler deadlock', store=session_store}); return end
  end
end
