local util = require("trilium-sync.util")
local auth = require("trilium-sync.auth")
local api = {}

local config = util.config

local request_methods = {
    GET="GET",
    PUT="PUT",
    DELETE="DELETE",
    POST="POST",
}

---Requests the api using the standard request format including authentication.
---
---@param method string One of request_methods
---@param path string The api path for after /api
---@param data string|nil Can only be nil when method is not equal to PUT or POST
---@return string
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

    if method == request_methods.POST or method == request_methods.PUT then
        cmd_add = " -H 'Content-Type: application/json'"..
        " -d '" .. vim.fn.escape(data, "'") .. "'"
    end

    local cmd = cmd_base .. cmd_add .. " " .. config.api_url .. path
    util.log(cmd)
    local handle = io.popen(cmd)

    if not handle then return "" end

    local result = handle:read("*a")
    handle:close()

    -- ignore GET because it doesn't require CSRF and it may have that text in
    -- the tree
    if method ~= request_methods.GET and result:match("Invalid CSRF") then
        auth.reset_session()
        util.log("CSRF Invalid. Resetting session...")
    end

    return result
end


--- puts a note into local file
---@param title string
---@param content string
local function save_note(title, content, noteId)
    title = title:gsub("[/\\:*?\"<>|]", "_")
    content = util.html_to_markdown(content)

    local filename = config.notes_dir .. "/" .. title .. ".md"
    local f = io.open(filename, "w")

    if f then
        f:write(content or "")
        f:close()
        util.metadata[filename] = { noteId = noteId, raw = content }
        util.save_metadata()
    else
        util.log("Failed to write note: " .. title)
    end
end


--- request the note api with a blob
--- @param noteId string
--- @return string
local function get_note_content(noteId)
    -- api/notes/(noteID)/blob
    local data = curl(request_methods.GET, "/notes/" ..noteId.. "/blob")
    local content = util.json_decode(data).content

    return content
end


--- saves all of the notes to the data folder
local function fetch_notes()
    vim.fn.mkdir(config.notes_dir, "p")
    local data = curl(request_methods.GET, "/tree")
    local notes = util.json_decode(data)["notes"]
    for _, note in ipairs(notes) do
        if note.mime == "text/html" then
            local content = get_note_content(note.noteId)
            save_note(note.title, content, note.noteId)
        end
    end
    util.log("Notes downloaded to " .. config.notes_dir)
end


--- call this before any other methods to ensure we have proper authentication
function api.init_session()
    util.load_metadata()
    if auth.session.verified then return end
    auth.load_session()
    -- verify current session works (does not check CSRF)
    local res = curl(request_methods.GET, "/tree")

    if res:match("Logged") or res == "" then
        auth.reset_session()
    end

    auth.session.verified = true
    -- reset if invalid
end


local function sync_cleanup()
    util.load_metadata()

    local existing_files = {}
    for file in vim.fs.dir(config.notes_dir) do
        existing_files[file] = true
        local filepath = config.notes_dir.."/"..file
        local note_not_in_metadata = not util.metadata[filepath] and file:match(".md$")
        if note_not_in_metadata then -- creation
            util.log("Detected creation: "..filepath)
            --util.metadata[filepath] = util.json_encode({ noteId="", raw="" })
        end
    end

    for filename, data in pairs(util.metadata) do
        local note_not_in_files = not existing_files[vim.fs.basename(filename)]
        if note_not_in_files then -- deletion
            util.log("Detected deletion: " .. filename)
            -- DELETE note
            --curl_delete("/notes/" .. data.noteId)
            util.metadata[filename] = nil
        end
    end

    util.save_metadata()
end



function api.sync()
    -- make sure session is initialized
    api.init_session()

    -- cleanup the sync (check for renames/deletions)
    sync_cleanup()

    -- fetch the notes to sync files
    fetch_notes()
end


function api.push_if_tracked()
    local data = {
        curbufId = 0,
        startLine = 0,
        endLine = -1,
        strictIndex = false,
    }
    local bufname = vim.api.nvim_buf_get_name(data.curbufId)
    local entry = util.metadata[bufname]

    if entry then
        local lines = vim.api.nvim_buf_get_lines(
            data.curbufId,
            data.startLine,
            data.endLine,
            data.strictIndex
        )

        local new_content = table.concat(lines, "\n")
        new_content = util.markdown_to_html(new_content)
        if new_content ~= entry.raw then
            util.log("Syncing note: " .. bufname)
            curl(
                request_methods.PUT,
                "/notes/" .. entry.noteId .. "/data",
                vim.fn.json_encode({ content = new_content })
            )
            util.metadata[bufname].raw = new_content
            util.save_metadata()
        end
    end
end


return api
