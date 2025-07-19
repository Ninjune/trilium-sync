local curl = require("trilium-sync.api.curl")
local util = require("trilium-sync.util")
local M = {}


function M.create_branch(parentId, title)
    local payload = {
        content="",
        isProtected=false,
        type="text"
    }
    local data = vim.json.decode(
        curl(
            "POST",
            "/api/notes/"..parentId.."/children?target=into",
            vim.json.encode(payload)
        )
    )

    -- todo: setup metadata for date created for each note
    -- todo: 
    util.metadata

    return data.noteId
end


return M
