
local Object = require("guan.lib.classic")
local BasePlugin = Object:extend()


function BasePlugin:new(name)
    self._name = name
end


function BasePlugin:get_name()
    return self._name
end


function BasePlugin:run()
    ngx.log(ngx.DEBUG, "executing plugin \"", self._name)
end


function BasePlugin:check_config(config)
    ngx.log(ngx.DEBUG, "check config: plugin \"", self._name)
end

return BasePlugin
