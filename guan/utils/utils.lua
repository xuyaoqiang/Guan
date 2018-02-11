-- general utility functions.
-- some functions is from [kong](getkong.org)
local require = require
local  date = require("guan.lib.date")
local type = type
local pcall = pcall
local pairs = pairs
local tostring = tostring
local fmt = string.format
local string_gsub = string.gsub
local string_find = string.find
local sort = table.sort
local concat = table.concat

local ffi = require "ffi"
local ffi_cdef = ffi.cdef
local ffi_typeof = ffi.typeof
local ffi_new = ffi.new
local ffi_str = ffi.string
local C = ffi.C

ffi_cdef[[
typedef unsigned char u_char;
int RAND_bytes(u_char *buf, int num);
]]

local _M = {}

do
  local url = require "socket.url"

  --- URL escape and format key and value
  -- values should be already decoded or the `raw` option should be passed to prevent double-encoding
  local function encode_args_value(key, value, raw)
    if not raw then
      key = url.escape(key)
    end
    if value ~= nil then
      if not raw then
        value = url.escape(value)
      end
      return fmt("%s=%s", key, value)
    else
      return key
    end
  end

  --- Encode a Lua table to a querystring
  -- Tries to mimic ngx_lua's `ngx.encode_args`, but also percent-encode querystring values.
  -- Supports multi-value query args, boolean values.
  -- It also supports encoding for bodies (only because it is used in http_client for specs.
  -- @TODO drop and use `ngx.encode_args` once it implements percent-encoding.
  -- @see https://github.com/Kong/kong/issues/749
  -- @param[type=table] args A key/value table containing the query args to encode.
  -- @param[type=boolean] raw If true, will not percent-encode any key/value and will ignore special boolean rules.
  -- @treturn string A valid querystring (without the prefixing '?')
  function _M.encode_args(args, raw)
    local query = {}
    local keys = {}

    for k in pairs(args) do
      keys[#keys+1] = k
    end

    sort(keys)

    for _, key in ipairs(keys) do
      local value = args[key]
      if type(value) == "table" then
        for _, sub_value in ipairs(value) do
          query[#query+1] = encode_args_value(key, sub_value, raw)
        end
      elseif value == true then
        query[#query+1] = encode_args_value(key, raw and true or nil, raw)
      elseif value ~= false and value ~= nil or raw then
        value = tostring(value)
        if value ~= "" then
          query[#query+1] = encode_args_value(key, value, raw)
        elseif raw or value == "" then
          query[#query+1] = key
        end
      end
    end

    return concat(query, "&")
  end
end


function _M.now()
    local n = date()
    local result = n:fmt("%Y-%m-%d %H:%M:%S")
    return result
end

function _M.current_timetable()
    local n = date()
    local yy, mm, dd = n:getdate()
    local h = n:gethours()
    local m = n:getminutes()
    local s = n:getseconds()
    local day = yy .. "-" .. mm .. "-" .. dd
    local hour = day .. " " .. h
    local minute = hour .. ":" .. m
    local second = minute .. ":" .. s

    return {
        Day = day,
        Hour = hour,
        Minute = minute,
        Second = second
    }
end

function _M.current_second()
    local n = date()
    local result = n:fmt("%Y-%m-%d %H:%M:%S")
    return result
end

function _M.current_minute()
    local n = date()
    local result = n:fmt("%Y-%m-%d %H:%M")
    return result
end

function _M.current_hour()
    local n = date()
    local result = n:fmt("%Y-%m-%d %H")
    return result
end

function _M.current_day()
    local n = date()
    local result = n:fmt("%Y-%m-%d")
    return result
end

function _M.table_is_array(t)
    if type(t) ~= "table" then return false end
    local i = 0
    for _ in pairs(t) do
        i = i + 1
        if t[i] == nil then return false end
    end
    return true
end

--- Retrieves the hostname of the local machine
-- @return string  The hostname
function _M.get_hostname()
    local f = io.popen ("/bin/hostname")
    local hostname = f:read("*a") or ""
    f:close()
    hostname = string_gsub(hostname, "\n$", "")
    return hostname
end

--- Calculates a table size.
-- All entries both in array and hash part.
-- @param t The table to use
-- @return number The size
function _M.table_size(t)
    local res = 0
    if t then
        for _ in pairs(t) do
            res = res + 1
        end
    end
    return res
end

--- Merges two table together.
-- A new table is created with a non-recursive copy of the provided tables
-- @param t1 The first table
-- @param t2 The second table
-- @return The (new) merged table
function _M.table_merge(t1, t2)
    local res = {}
    for k,v in pairs(t1) do res[k] = v end
    for k,v in pairs(t2) do res[k] = v end
    return res
end

--- Checks if a value exists in a table.
-- @param arr The table to use
-- @param val The value to check
-- @return Returns `true` if the table contains the value, `false` otherwise
function _M.table_contains(arr, val)
    if arr then
        for _, v in pairs(arr) do
            if v == val then
                return true
            end
        end
    end
    return false
end

--- Checks if a table is an array and not an associative array.
-- *** NOTE *** string-keys containing integers are considered valid array entries!
-- @param t The table to check
-- @return Returns `true` if the table is an array, `false` otherwise
function _M.is_array(t)
    if type(t) ~= "table" then return false end
    local i = 0
    for _ in pairs(t) do
        i = i + 1
        if t[i] == nil and t[tostring(i)] == nil then return false end
    end
    return true
end

--- Deep copies a table into a new table.
-- Tables used as keys are also deep copied, as are metatables
-- @param orig The table to copy
-- @return Returns a copy of the input table
function _M.deep_copy(orig)
    local copy
    if type(orig) == "table" then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[_M.deep_copy(orig_key)] = _M.deep_copy(orig_value)
        end
        setmetatable(copy, _M.deep_copy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

--- Try to load a module.
-- Will not throw an error if the module was not found, but will throw an error if the
-- loading failed for another reason (eg: syntax error).
-- @param module_name Path of the module to load (ex: kong.plugins.keyauth.api).
-- @return success A boolean indicating wether the module was found.
-- @return module The retrieved module.
function _M.load_module_if_exists(module_name)
    local status, res = pcall(require, module_name)
    if status then
        return true, res
        -- Here we match any character because if a module has a dash '-' in its name, we would need to escape it.
    elseif type(res) == "string" and string_find(res, "module '"..module_name.."' not found", nil, true) then
        return false
    else
        error(res)
    end
end

---Try to generate a random seed using OpenSSL.
-- ffi based, would be more effenticy
-- This function is mainly ispired by https://github.com/bungle/lua-resty-random
-- @return a pseudo-random number for math.randomseed
do
    local bytes_buf_t = ffi_typeof "uint8_t[?]"
    local n_bytes = 4
    function _M.get_random_seed()
        local buf = ffi_new(bytes_buf_t, n_bytes)

        if C.RAND_bytes(buf, n_bytes) == 0 then
            ngx.log(ngx.ERR, "could not get random bytes, using ngx.time() + ngx.worker.pid() instead")
            return ngx.time() + ngx.worker.pid()
        end

        local a, b, c, d = ffi_str(buf, n_bytes):byte(1, 4)
        return a * 0x1000000 + b * 0x10000 + c * 0x100 + d
    end
end

return _M
