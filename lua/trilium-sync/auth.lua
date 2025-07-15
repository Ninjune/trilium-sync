local util = require("trilium-sync.util")
local auth = {}

auth.session = {
    sid = "",
    csrf_cookie = "",
    csrf_token = "",
    verified = false,
}


-- TODO: DRY
function auth.load_session()
    local f = io.open(util.config.session_file, "r")

    if f then
        local data = f:read("*a")
        auth.session = vim.fn.json_decode(data) or {}
        f:close()
    end
end


function auth.save_session()
    local f = io.open(util.config.session_file, "w")
    if f then
        f:write(vim.fn.json_encode(auth.session))
        f:close()
    end
end


--- asks the user for their password
--- @return string
local function prompt_password()
    return vim.fn.inputsecret("[trilium-sync] Enter your Trilium password: ")
end


--- Perform login and return session + csrf tokens
--- @param password string
--- @return table|nil
local function get_session(password)
    -- Step 1: Login
    local login_cmd = string.format(
        "curl -i -s -X POST -d \"password=%s\" %s",
        password, util.config.api_url:gsub("/api", "") .. "/login"
    )
    local login_out = io.popen(login_cmd):read("*a")

    local sid = login_out:match("Set%-Cookie:%s*trilium%.sid=([^;]+);")
    if not sid then return nil end

    -- Step 2: Get CSRF
    local csrf_cmd = string.format(
        "curl -i -s -H \"Cookie: trilium.sid=%s\" %s",
        sid, util.config.api_url:gsub("/api", "")
    )

    local csrf_out = io.popen(csrf_cmd):read("*a")

    -- Step 3: Split the CSRF
    local csrf_raw = csrf_out:match("Set%-Cookie: _csrf=([%w]+%%[%w%-_]+);")
    if not csrf_raw then return nil end

    local csrf_token = csrf_raw:match("([^%%]+)")

    return {
        sid = sid,
        csrf_cookie = csrf_raw,
        csrf_token = csrf_token
    }
end


function auth.reset_session()
    auth.session = get_session(prompt_password())
    auth.save_session()
end


return auth
