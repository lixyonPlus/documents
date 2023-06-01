--
-- Licensed to the Apache Software Foundation (ASF) under one or more
-- contributor license agreements.  See the NOTICE file distributed with
-- this work for additional information regarding copyright ownership.
-- The ASF licenses this file to You under the Apache License, Version 2.0
-- (the "License"); you may not use this file except in compliance with
-- the License.  You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
local ipairs    = ipairs
local core      = require("apisix.core")
local lrucache  = core.lrucache.new({
    ttl = 300, count = 512
})


local schema = {
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
            key = {
                type = "string",
                minLength = 1,
                maxLength = 1024,
                description = "key name",
            },
            value = {
                type = "string",
                minLength = 1,
                maxLength = 1024,
                description = "key name equals value",
            },
            url = {
                type = "string",
                description = "forward url",
            },
        },
    },
    anyOf = {
        {required = {"type","key","value","url"}},
    },
}


local plugin_name = "ip-redirect"


local _M = {
    version = 0.1,
    priority = 3000,
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


function _M.restrict(conf, ctx)
    local value
    if conf.type == "header" then
        value = core.request.header(ctx, conf.key)
    else
        local body, err = core.request.get_body()
        if not body then
            if err then
                core.log.error("failed to get body: ", err)
            end
            req_body, err = core.json.decode(body)
        end
    end

    if conf.blacklist then
        local matcher = lrucache(conf.blacklist, nil,
                                 core.ip.create_ip_matcher, conf.blacklist)
        if matcher then
            block = matcher:match(remote_addr)
        end
    end

    if conf.whitelist then
        local matcher = lrucache(conf.whitelist, nil,
                                 core.ip.create_ip_matcher, conf.whitelist)
        if matcher then
            block = not matcher:match(remote_addr)
        end
    end

    if block then
        return 403, { message = conf.message }
    end
end


return _M
