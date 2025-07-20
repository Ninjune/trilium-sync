local tree = require("trilium-sync.tree")
local util = require("trilium-sync.util")
local curl = require("trilium-sync.api.curl")
local Download = {}

--- 
---@param noteId NoteId
---@return {
---blobId: string,
---content: string,
---contentLength: integer,
---dateModified: string,
---utcDateModified: string,
---}
local function get_note_data(noteId)
    -- api/notes/(noteID)/blob
    local data = curl(util.request_methods.GET, "/notes/" ..noteId.. "/blob")
    data = vim.json.decode(data)

    return data
end


Download.save_note = function (noteId, content, tree_abs_path)
    local notes_path = util.config.notes_dir.."/"..noteId..".md"

    -- create the real note
    util.save_file_async(notes_path, content, function ()
        -- create the link in tree (this is allowed to error)
        vim.uv.fs_symlink(notes_path, tree_abs_path)
    end)
end


--- puts a note into local files: both tree_dir (if it's there) and notes_dir
--- @param root Node
--- @param path string|nil the relative file path of this node
local function save_tree(root, path)
    path = path or ""

    local note_data = get_note_data(root.noteId)
    assert(note_data ~= nil and note_data ~= vim.NIL)

    note_data.content = util.html_to_markdown(note_data.content)

    if root.children ~= nil then
        for _, child in ipairs(root.children) do
            save_tree(child, path..root.title.."/")
        end
        path = path..root.title.."/"
    end

    local tree_abs_path = util.config.tree_dir .. "/" .. path
    vim.fn.mkdir(tree_abs_path, "p")

    tree_abs_path = tree_abs_path .. root.title .. ".md"
    path = path .. root.title .. ".md"

    tree._branch_count = tree._branch_count + 1
    vim.notify("[trilium-sync] "..tree._branch_count.."/"..tree._max_branch_count, vim.log.levels.INFO)
    vim.cmd("redraw")

    util.metadata.trackedNoteIDs[root.noteId] = {
        tracked=true,
        date_modified=note_data.utcDateModified
    };

    Download.save_note(root.noteId, note_data.content, tree_abs_path)
end



--- saves all of the notes to the data folder
function Download.all_notes()
    vim.fn.mkdir(util.config.notes_dir, "p")
    vim.fn.mkdir(util.config.tree_dir, "p")
    -- prime the tree (expand all subfolders)
    curl(util.request_methods.PUT, "/branches/none_root/expanded-subtree/1")

    local data = curl(util.request_methods.GET, "/tree?subTreeNoteId=root")
    local tree_data = vim.json.decode(data)
    local root = tree.gen_children_tree(tree_data)
    --io.popen("echo "..vim.fn.escape(util.debug_dump_table(root), '"').." > /tmp/data.txt")

    for _, node in ipairs(root) do
        save_tree(node)
    end

    Download._max_branch_count = 0
    tree._branch_count = 0
    util.metadata.tree = tree_data
    util.save_metadata()
end


--- TODO impl
function Download.note_by_id()

end


return Download
