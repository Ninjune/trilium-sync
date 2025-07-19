local util = require("trilium-sync.util")
local auth = require("trilium-sync.auth")


---Requests the api using the standard request format including authentication.
---
---@param method string One of request_methods
---@param path string The api path for after /api
---@param data string|nil Can only be nil when method is not equal to PUT or POST
---@return string unparsed data
local function curl(method, path, data)
    data = data or ""

    local cmd_base = string.format(
        "curl -s -H 'Cookie: trilium.sid=%s; _csrf=%s' -H 'X-Csrf-Token: %s' -X %s",
        auth.session.sid,
        auth.session.csrf_cookie,
        auth.session.csrf_token,
        method
    )
    local cmd_add = ""

    if method == util.request_methods.POST or method == util.request_methods.PUT then
        cmd_add = " -H 'Content-Type: application/json'"..
        " -d '" .. vim.fn.escape(data, "'") .. "'"
    end

    local cmd = cmd_base .. cmd_add .. " " .. util.config.api_url .. path
    --util.log(cmd)
    local handle = io.popen(cmd)

    if not handle then return "" end

    local result = handle:read("*a")
    handle:close()

    -- ignore GET because it doesn't require CSRF and it may have that text in
    -- the tree
    if method ~= util.request_methods.GET and result:match("Invalid CSRF") then
        auth.reset_session()
        util.log("CSRF Invalid. Resetting session...")
    end

    return result
end

return curl
