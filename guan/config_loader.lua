local json = require("guan.utils.json")
local IO = require("guan.utils.io")
local _M = {}

function _M.load(config_path)
    config_path = config_path or "/etc/guan/guan.conf"
    local config_contents = IO.read_file(config_path)
    if not config_contents then
        ngx.log(ngx.ERR, "Config file not found!: ", config_path)
        os.exit(1)
    end
    local config = json.decode(config_contents)
    return config, config_path
end

return _M
