local ck = require "resty.cookie"
local BasePlugin = require("guan.plugins.base")

local CookieRewritePlugin = BasePlugin:extend()


function CookieRewritePlugin:new()
    CookieRewritePlugin.super.new(self, "cookie-decode-plugin")
end


function CookieRewritePlugin:check_config(config)
    local errors = {}
    local field = config.field
    if not field then
        errors[#errors+1] = "cookie-decode-plugin missing config: field"
    end
    return #errors == 0, errors[1], errors
end

function CookieRewritePlugin:run(option)
    CookieRewritePlugin.super.run(self)
    local cookie, err = ck:new()
    if not cookie then
        ngx.log(ngx.WARN, err)
        return
    end

    local token, err = cookie:get(option.field)
    if not token then
        ngx.log(ngx.WARN, err)
        return
    end
    
    ngx.req.set_header('authorization', 'Token ' .. token)
end


return CookieRewritePlugin
