local redis = require("guan.lib.redis_util")
local utils = require("guan.utils.utils")
local json = require "guan.utils.json"
local BasePlugin = require("guan.plugins.base")

local ngx_log = ngx.log
local pairs = pairs
local tostring = tostring
local fmt = string.format
local ngx_timer_at = ngx.timer.at

local EXPIRATIONS = {
    Second = 1,
    Minute = 60,
    Hour = 3600,
    Day = 86400
}


local RATELIMIT_LIMIT = "X-RateLimit-Limit"
local RATELIMIT_REMAINING = "X-RateLimit-Remaining"


local function connect_redis(conf)
    local red = redis:new(conf)

    local count, err = red:get_reused_times()
    if not err then
        ngx_log(ngx.ERR, "redis reused times: " .. count)
    end
    return red
end

    
local function get_local_key(limit_key, name, time_key)
    return fmt("ratelimit:%s:%s:%s", limit_key, name, time_key)
end


local function incr_usage_by_redis(redis_client, limits, limit_key, current_timetable, value)
    local keys = {}
    local expirations = {}
    local idx = 0

    for name, _ in pairs(limits) do
        local time_key = current_timetable[name]
        local cache_key = get_local_key(limit_key, name, time_key)
        ngx_log(ngx.ERR, "cache_key: " .. cache_key)
        local exists, err = redis_client:exists(cache_key)
        if err then
            ngx_log(ngx.ERR, "failed to query Redis: ", err)
            return nil, err
        end
        idx = idx + 1
        keys[idx] = cache_key

        if not exists or exists == 0 then
            expirations[idx] = EXPIRATIONS[name]
        end
    end

    redis_client:init_pipeline()
    for i = 1, idx do
        ngx_log(ngx.ERR, "incr by key: " .. keys[i])
        redis_client:incrby(keys[i], value)
        if expirations[i] then
            redis_client:expire(keys[i], expirations[i])
        end
    end

    local _, err = redis_client:commit_pipeline()
    if err then
        ngx_log(ngx.ERR, "failed to commit pipeline in Redis: ", err)
        return nil, err
    end
    return true
end


local function get_usage_by_redis(client, limit_key, current_timetable, limits)
    -- local client = connect_redis(redis_conf)
    local usage = {}
    local stop
    ngx_log(ngx.ERR, json.encode(limits))
    for name, limit in pairs(limits) do
        local time_key = current_timetable[name]
        local cache_key = get_local_key(limit_key, name, time_key)
        local current_usage, err = client:get(cache_key)
        ngx_log(ngx.ERR, "time_key ", time_key)
        ngx_log(ngx.ERR, "cache_key ", cache_key)
        ngx_log(ngx.ERR, "usage ", current_usage)
        if err then
            return nil, nil, err
        end

        if current_usage == ngx.null then
            current_usage = nil
        end
        
        if not current_usage then
            current_usage = 0
        end
        
        -- get remaning
        local remaining = limit - current_usage

        usage[name] = {
            limit = limit,
            remaining = remaining
        }
        if remaining <= 0 then
            stop = name
        end
    end
    
    return usage, stop
end

local RateLimitingPlugin = BasePlugin:extend()


function RateLimitingPlugin:new()
    RateLimitingPlugin.super.new(self, "rate-limiting-plugin")
end


function RateLimitingPlugin:check_conf(conf)
    local errors = {}
end



function RateLimitingPlugin:run(conf)
    RateLimitingPlugin.super.run(self)
    
    local limits = {
        Second = conf.second,
        Minute = conf.minute,
        Hour = conf.hour,
        Day = conf.day
    }

    local redis_conf = {
       host = conf.redis_host,
       port = conf.redis_port,
       timeout = conf.redis_timeout,
       db_index= conf.redis_database
    }
    local redis_client = connect_redis(redis_conf)
    local current_timetable = utils.current_timetable()

    local fault_tolerant = conf.fault_tolerant
    local limit_header_field = conf.limit_header_field
    local limit_key
    if limit_header_field then
        limit_key = ngx.req.get_headers()[limit_header_field]
    end

    if not limit_key then
        limit_key = ngx.var.remote_addr
    end
    ngx_log(ngx.ERR, "limit_key: " .. limit_key) 
    local usage, stop, err = get_usage_by_redis(redis_client, limit_key, current_timetable, limits)
    if err then
        if fault_tolerant then
            ngx_log(ngx.ERR, "failed to get usage", tostring(err))
        else
            ngx.exit(429)
            return true 
        end
    end

    if usage then
        for k, v in pairs(usage) do
            ngx.header[RATELIMIT_LIMIT .. '-' .. k] = v.limit
            ngx.header[RATELIMIT_REMAINING .. '-' .. k] = math.max(0, (stop == nil or stop == k) and v.remaining - 1 or v.remaining)
        end

        if stop then
            ngx.exit(429)
            return true 
        end
    end
    
    local incr = function(permature, client, limit_conf, key, timetable, value)
        if permature then
            return
        end
        incr_usage_by_redis(client, limit_conf, key, timetable, value)
    end

    local ok, err = ngx_timer_at(0, incr , redis_client, limits, limit_key, current_timetable, 1)
    if not ok then
        ngx_log(ngx.ERR, "failed to create timer: ", err)
    end
    
end

return RateLimitingPlugin
