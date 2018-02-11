local ngx_handle = require("bin.utils.ngx_handle")
local args_util = require("bin.utils.args_util")
local logger = require("bin.utils.logger")


local _M = {}


_M.help = [[
Usage: guan stop [OPTIONS]

Stop Guan with configurations(prefix/guan_conf/ngx_conf).

Options:
 -p,--prefix  (optional string) override prefix directory
 -o,--guan_conf (optional string) guan configuration file
 -c,--ngx_conf (optional string) nginx configuration file
 -h,--help (optional string) show help tips

Examples:
 guan stop  #use `/usr/local/guan` as workspace with `/usr/local/guan/conf/guan.conf` & `/usr/local/guan/conf/nginx.conf`
 guan stop --prefix=/opt/guan  #use the `prefix` as workspace with ${prefix}/conf/guan.conf & ${prefix}/conf/nginx.conf
 guan stop --guan_conf=/opt/guan/conf/guan.conf --prefix=/opt/guan --ngx_conf=/opt/guan/conf/nginx.conf
 guan stop -h  #just show help tips
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
        local handler = ngx_handle:new(args)

        local result = handler:stop()
        if result == 0 then
            logger:success("Guan stoped.")
        end
    end, function(e)
        logger:error("Could not stop Guan, error: %s", e)
        err = e
    end)

    if err then
        error(err)
    end
end


return _M
