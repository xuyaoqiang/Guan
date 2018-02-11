local logger = require("guan.cmd.utils.logger")

local function create_dirs(necessary_dirs)
    if necessary_dirs then
        for _, dir in pairs(necessary_dirs) do
            os.execute("mkdir -p " .. dir .. " > /dev/null")
        end
    end
end

local function remove_ngx_conf(ngx_conf)
    os.remove(ngx_conf)
end

local function ngx_command(args)
    if not args then 
        error("error args to execute nginx command.") 
        os.exit(1)
    end

    local guan_conf, prefix, ngx_conf, ngx_signal = "", "", "", ""
    -- if args.guan_conf ~= nil then guan_conf = "-g \"env GUAN_CONF=" .. args.guan_conf .. ";\"" end
    if args.guan_conf ~= nil then guan_conf = "GUAN_CONF=" .. args.guan_conf .. " " end
    if args.prefix then prefix = "-p " .. args.prefix end
    if args.ngx_conf then ngx_conf = "-c " .. args.ngx_conf end
    if args.ngx_signal then ngx_signal = "-s " .. args.ngx_signal end


    -- local cmd = string.format("nginx %s %s %s %s", guan_conf, prefix, ngx_conf, ngx_signal)
    local cmd = string.format("%snginx %s %s %s", guan_conf, prefix, ngx_conf, ngx_signal)
    logger:info(cmd)
    return os.execute(cmd)
end


local _M = {}

function _M:new(args)
    local instance = {
        guan_conf = args.guan_conf,
        prefix = args.prefix,
        ngx_conf = args.ngx_conf,
        necessary_dirs = args.necessary_dirs
    }

    setmetatable(instance, { __index = self })
    return instance
end

function _M:start()
    logger:info("Start guan command execute.")
    create_dirs(self.necessary_dirs)


    return ngx_command({
        guan_conf = self.guan_conf or nil,
        prefix = self.prefix or nil,
        ngx_conf = self.ngx_conf,
        ngx_signal = nil
    })
end

function _M:stop()
    return ngx_command({
        guan_conf = self.guan_conf or nil,
        prefix = self.prefix or nil,
        ngx_conf = self.ngx_conf,
        ngx_signal = "stop"
    })
end

function _M:reload()
    create_dirs(self.necessary_dirs)
    return ngx_command({
        guan_conf = self.guan_conf or nil,
        prefix = self.prefix or nil,
        ngx_conf = self.ngx_conf,
        ngx_signal = "reload"
    })
end

return _M
