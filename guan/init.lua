local ipairs = ipairs
local pairs = pairs
local pcall = pcall
local require = require
require("guan.lib.globalpatches")()

local config_loader = require("guan.config_loader")
local utils = require("guan.utils.utils")
local json = require("guan.utils.json")
local stat = require("guan.stat")

local plugin_handlers = {}
local plugin_configs = {}
local location_plugins = {}

local function load_enable_plugins(config)
    ngx.log(ngx.INFO, "Discovering enabled plugins")
    local plugins = config.plugins
    local locations = config.locations

    for k, _ in pairs(plugins) do
        local enabled, plugin_handler = utils.load_module_if_exists(k)
        if not enabled then
            ngx.log(ngx.WARN, "plugin " .. k .. " not installed!")
        else
            ngx.log(ngx.DEBUG, "Enable plugin: " .. k)
            plugin_handlers[k] = plugin_handler
        end
    end

    -- check location config
    for k, v in pairs(locations) do
        for _, stage_plugins in pairs(v) do
            for _, stage_plugin in ipairs(stage_plugins) do
                if not plugin_handlers[stage_plugin] then
                    ngx.log(ngx.WARN, "plugin '" .. stage_plugin .. "' in location  '" .. k .. "' not installed!")
                end
            end
        end
    end

    return plugin_handlers
end


-- #####################Guan################
local Guan = {}

-- 执行过程
-- 加载配置
-- 加载配置
--
function Guan.init(options)
    options = options or  {}
    local config
    local status, err = pcall(function()
        local conf_file_path = options.config
        config = config_loader.load(conf_file_path)
        if not config then
            ngx.log(ngx.ERR, "load config error!")
        end
        plugin_handlers = load_enable_plugins(config)
        plugin_configs = config.plugins
        location_plugins = config.locations
        ngx.update_time()
    end)

    if not status or err then
        ngx.log(ngx.ERR, "Startup error: " .. err)
        os.exit(1)
    end

    Guan.data = {
        config = config
    }

    return config
end


function Guan.init_worker()
    math.randomseed()

    -- enable stat 
    stat.init()
end


function Guan.redirect(location)
    local plugins = location_plugins[location].redirect_plugins
    if plugins then
        for _, v in ipairs(plugins) do
            local plugin = plugin_handlers[v]
            local plugin_config = plugin_configs[v] or {}
            if not plugin then
                ngx.log(ngx.WARN, "plugin " .. v .. " or plugin config")
            else
                plugin:run(plugin_config)
            end
        end
    end
end


function Guan.rewrite(location)
    local plugins = location_plugins[location].rewrite_plugins
    if plugins then
        for _, v in ipairs(plugins) do
            local plugin = plugin_handlers[v]
            local plugin_config = plugin_configs[v] or {}
            if not plugin then
                ngx.log(ngx.WARN, "plugin " .. v .. " or plugin config")
            else
                plugin:run(plugin_config)
            end
        end
    end
end


function Guan.access(location)

    local plugins = location_plugins[location].access_plugins
    if plugins then
        for _, v in ipairs(plugins) do
            local plugin = plugin_handlers[v]
            local plugin_config = plugin_configs[v]
            ngx.log(ngx.WARN, v .. " config: " .. json.encode(plugin_config))
            if not plugin then
                ngx.log(ngx.WARN, "plugin " .. v .. " or plugin config")
            else
                plugin:run(plugin_config)
            end
        end
    end
end

function Guan.header_filter(location)
    local plugins = location_plugins[location].header_plugins
    if plugins then
        for _, v in ipairs(plugins) do
            local plugin = plugin_handlers[v]
            local plugin_config = plugin_configs[v] or {}
            if not plugin then
                ngx.log(ngx.WARN, "plugin " .. v .. " or plugin config")
            else
                plugin:run(plugin_config)
            end
        end
    end
end

function Guan.body_filter(location)
    local plugins = location_plugins[location].body_plugins
    if plugins then
        for _, v in ipairs(plugins) do
            local plugin = plugin_handlers[v]
            local plugin_config = plugin_configs[v] or {}
            if not plugin then
                ngx.log(ngx.WARN, "plugin " .. v .. " or plugin config")
            else
                plugin:run(plugin_config)
            end
        end
    end
end

function Guan.log(location)
    stat.log()

    local plugins = location_plugins[location].log_plugins
    if plugins then
        for _, v in ipairs(plugins) do
            local plugin = plugin_handlers[v]
            local plugin_config = plugin_configs[v] or {}
            if not plugin then
                ngx.log(ngx.WARN, "plugin " .. v .. " or plugin config")
            else
                plugin:run(plugin_config)
            end
        end
    end
end

function Guan.stat_api()
    gw_status = stat.stat()
    
    ngx.header.content_type = "application/json"
    ngx.say(json.encode(gw_status))
end


return Guan
