local ngx_re = require("ngx.re")
local core = require("apisix.core")
local http = require "resty.http"
local tostring = tostring

local schema = {
    type = "object",
    properties = {
      list = {
       type = "array",
        minItems = 1,
        items = {
            type = "object",
            properties = {
                type = {
                    type = "string",
                    default = "header",
                    enum = {"header", "body"},
                    description = "name localtion",
                },
                keyword = {
                    type = "string",
                    minLength = 1,
                    maxLength = 1024,
                    description = "keyword name",
                },
                content = {
                    type = "string",
                    default = "",
                    minLength = 1,
                    maxLength = 1024,
                    description = "keyword content",
                },
                url = {
                    type = "string",
                    description = "forward url",
                },
            },
        },
        anyOf = {
            {required = {"type","keyword","url"}},
        },
      }
    }
}


local plugin_name = "hc-redirect"


local _M = {
    version = 0.1,
    priority = 100,
    name = plugin_name,
    schema = schema,
}


function _M.check_schema(conf)
    local ok, err = core.schema.check(schema, conf)
    if not ok then
        return false, err
    end
    return true
end


function _M.rewrite(conf, ctx)
    core.log.error("hc-redircet...")
    local req_headers = core.request.headers(ctx)
    local req_body = core.request.get_body()

    -- core.log.error("req1: ",core.json.delay_encode(core.request.get_body()))
    -- core.log.error("req2: ",core.json.delay_encode(core.request.headers(ctx)))

    for k, c in pairs(conf.list) do
        local content
        if c.type == "header" then
            content = req_headers[c.keyword]
        elseif c.type == "body" then
            if req_headers["content-type"] == "application/json" then
                local keywords = ngx_re.split(c.keyword, "\\.")
                local json_body = core.json.delay_encode(req_body)
                local data, err = core.json.decode(req_body)
                if keywords == nil then
                   content = data[c.keyword]
                else
                    for i, kw in ipairs(keywords) do
                        data = data[kw]
                        if type(data) ~= 'table' then
                            break
                        end
                    end
                    content = data
                end 
            end
        end
        if c.content == content then
            local httpc = http.new()
            local res, err = httpc:request_uri(c.url, {
                method = ngx.var.request_method,
                -- path = ngx.var.request_uri,
                headers = core.request.headers(ctx),
                body = core.request.get_body()
            })
            if not res then
                core.log.error("failed to request: ", err)
                return 500, "internal error"
            end
            return res.status, res.body
        end
    end
    core.log.error("not found...")
    return 404
end


return _M
