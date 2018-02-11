local jwt = require "resty.jwt"
local json = require "guan.utils.json"
local BasePlugin = require("guan.plugins.base")
local ngx_re_gmatch = ngx.re.gmatch
local string_gsub = string.gsub

local function retrieve_token(request)
    local authorization_header = request.get_headers()['authorization']
    if authorization_header then
        local iterator, iter_err = ngx_re_gmatch(authorization_header, "\\s*(Device|Token)\\s+(.+)")
        if not iterator then
            ngx.log(ngx.WARN, "cannot find token")
            return nil, iter_err
        end
        local m, err = iterator()
        if err then
            return nil, err
        end

        if m and #m > 1 then
            return m[2]
        end
    end
end


local JwtDecodePlugin = BasePlugin:extend()


function JwtDecodePlugin:new()
    JwtDecodePlugin.super.new(self, "jwt-decode-plugin")
end


function JwtDecodePlugin:check_config(config)
    local errors = {}
    local secret = config.secret
    if not secret then
        errors[#errors+1] = "jwt-decode-plugin missing config: secret"
    end
    return #errors == 0, errors[1], errors
end

function JwtDecodePlugin:run(option)
    JwtDecodePlugin.super.run(self)
    if not option.secret then
        ngx.log(ngx.WARN, "can not find jwt secret")
    end

    local access_token, err = retrieve_token(ngx.req)

    if err then
        ngx.exit(ngx.HTTP_UNAUTHORIZED)
    end

    local jwt_obj = jwt:verify(option.secret or '', access_token)

    ngx.log(ngx.ERR, "jwt_obj.payload ", json.encode(jwt_obj.payload))
    if not jwt_obj.verified then
        ngx.log(ngx.ERR, "jwt token not verified: ", json.encode(jwt_obj))
        ngx.exit(ngx.HTTP_UNAUTHORIZED)
    end
    ngx.log(ngx.ERR, "verified")

    if jwt_obj.header.exp < ngx.now() then
        ngx.log(ngx.ERR, "jwt token expired: ", json.encode(jwt_obj))
        ngx.exit(ngx.HTTP_UNAUTHORIZED)
    end

    for k, v in pairs(jwt_obj.payload) do
        local x_header = "x-" .. string_gsub(k, '_', '-')
        ngx.log(ngx.DEBUG, "kv: " .. k .. v)

        ngx.req.set_header(x_header, v)
    end

end


return JwtDecodePlugin
