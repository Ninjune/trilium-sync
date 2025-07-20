local tree = require("trilium-sync.tree")
local curl = require("trilium-sync.api.curl")
local util = require("trilium-sync.util")
local Download = require("trilium-sync.api.download")
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
            "/notes/"..parentId.."/children?target=into",
            vim.json.encode(payload)
        )
    )
    assert(data and data ~= vim.NIL)

    -- update the title
    local title_update_data = curl(
        "PUT",
        "/notes/"..data.note.noteId.."/title",
        vim.json.encode({title=title})
    )
    assert(title_update_data)

    -- todo: autocommands
    -- todo: finish this, remember folder creation
    util.metadata[data.note.noteId] = {
        tracked=true,
        date_modified=data.note.utcDateModified
    }

    local parent_node, parent_path = tree.find_node_with_path(util.metadata.tree, parentId)
    assert(parent_node and parent_path)
    table.insert(parent_path, title)

    ---@type Node
    local new_node = {
        noteId=data.note.noteId,
        title=title,
    }

    tree.insert_child_node(parent_node, new_node)

    local tree_abs_path = table.concat(parent_path, "/")

    Download.save_note(data.note.noteId, "", tree_abs_path)

    return data
end


return M
