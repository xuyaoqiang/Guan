local ngx_handle = require("bin.utils.ngx_handle")
local start_cmd = require("bin.cmds.start")
local stop_cmd = require("bin.cmds.stop")
local logger = require("bin.utils.logger")


local _M = {}


_M.help = [[
Usage: guan restart [OPTIONS]

Restart Guan with configurations(prefix/guan_conf/ngx_conf).

Options:
 -p,--prefix  (optional string) override prefix directory
 -o,--guan_conf (optional string) guan configuration file
 -c,--ngx_conf (optional string) nginx configuration file
 -h,--help (optional string) show help tips

Examples:
 guan restart  #use `/usr/local/guan` as workspace with `/usr/local/guan/conf/guan.conf` & `/usr/local/guan/conf/nginx.conf`
 guan restart --prefix=/opt/guan  #use the `prefix` as workspace with ${prefix}/conf/guan.conf & ${prefix}/conf/nginx.conf
 guan restart --guan_conf=/opt/guan/conf/guan.conf --prefix=/opt/guan --ngx_conf=/opt/guan/conf/nginx.conf
 guan restart -h  #just show help tips
]]

function _M.execute(origin_args)
    logger:info("Stop guan...")
    pcall(stop_cmd.execute, origin_args)

    logger:info("Start guan...")
    start_cmd.execute(origin_args)
end


return _M
