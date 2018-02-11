local ngx_handle = require("guan.cmd.utils.ngx_handle")
local args_util = require("guan.cmd.utils.args_util")
local logger = require("guan.cmd.utils.logger")

local function new_handler(args)
    args.necessary_dirs ={ -- runtime nginx conf/pid/logs dir
        tmp = args.prefix .. '/tmp',
        logs = args.prefix .. '/logs'
    }

    return ngx_handle:new(args)
end


local _M = {}


_M.help = [[
Usage: guan start [OPTIONS]

Start Guan with configurations(prefix/guan_conf/ngx_conf).

Options:
 -p,--prefix  (optional string) override prefix directory
 -o,--guan_conf (optional string) guan configuration file
 -c,--ngx_conf (optional string) nginx configuration file
 -h,--help (optional string) show help tips

Examples:
 guan start  #use `/usr/local/guan` as workspace with `/usr/local/guan/conf/guan.conf` & `/usr/local/guan/conf/nginx.conf`
 guan start --prefix=/opt/guan  #use the `prefix` as workspace with ${prefix}/conf/guan.conf & ${prefix}/conf/nginx.conf
 guan start --guan_conf=/opt/guan/conf/guan.conf --prefix=/opt/guan --ngx_conf=/opt/guan/conf/nginx.conf
 guan start -h  #just show help tips
]]

function _M.execute(origin_args)

    -- format and parse args
    local args = {
        guan_conf = origin_args.guan_conf,
        prefix = origin_args.prefix,
        ngx_conf = origin_args.ngx_conf
    }
    for i, v in pairs(origin_args) do
        if i == "o" and not args.guan_conf then args.guan_conf = v end
        if i == "p" and not args.prefix then args.prefix = v end
        if i == "c" and not args.ngx_conf then args.ngx_conf = v end
    end

    -- use default args if not exist
    -- if not args.prefix then args.prefix = command_util.pwd() end
    if not args.prefix then args.prefix = "/usr/local/guan" end
    if not args.guan_conf then args.guan_conf = args.prefix .. "/conf/guan.conf" end
    if not args.ngx_conf then args.ngx_conf = args.prefix .. "/conf/nginx.conf" end

    if args then
        logger:info("args:")
        for i, v in pairs(args) do
            logger:info("\t%s:%s", i, v)
        end
        logger:info("args end.")
    end

    local err
    xpcall(function()
        local handler = new_handler(args)

        local result = handler:start()
        if result == 0 then
            logger:success("Guan started.")
        end
    end, function(e)
        logger:error("Could not start Guan, stopping it")
        pcall(function() handler:stop() end)
        err = e
        logger:warn("Stopped Guan")
    end)

    if err then
        error(err)
    end
end


return _M
