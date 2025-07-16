local util = require("trilium-sync.util")
local auth = require("trilium-sync.auth")
local curl = require("trilium-sync.api.curl")
local Api = { download=require("trilium-sync.api.download"), upload=require("trilium-sync.api.upload") }

local config = util.config


--- call this before any other methods to ensure we have proper authentication
function Api.init_session()
    util.load_metadata()
    if auth.session.verified then return end
    auth.load_session()
    -- verify current session works (does not check CSRF)
    local res = curl(util.request_methods.GET, "/tree")

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



function Api.sync()
    -- make sure session is initialized
    Api.init_session()

    -- cleanup the sync (check for renames/deletions)
    sync_cleanup()

    -- fetch the notes to sync files
    Api.download.all_notes()
end


return Api
