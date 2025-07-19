local util = require("trilium-sync.util")
local curl = require("trilium-sync.api.curl")
local Download = {
    _branch_count = 0,
    _max_branch_count = 0
}

--- 
---@param noteId NoteId
---@return string
local function get_note_content(noteId)
    -- api/notes/(noteID)/blob
    local data = curl(util.request_methods.GET, "/notes/" ..noteId.. "/blob")
    local content = vim.json.decode(data).content
    content = content or ""
    if content == vim.NIL then content = "" end

    return content
end


--- puts a note into local files: both tree_dir (if it's there) and notes_dir
--- @param root Node
--- @param path string|nil the relative file path of this node
local function save_tree(root, path)
    path = path or ""

    local content = get_note_content(root.noteId)
    assert(content ~= nil and content ~= vim.NIL)

    content = util.html_to_markdown(content)

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
    local notes_path = util.config.notes_dir.."/"..root.noteId..".md"

    Download._branch_count = Download._branch_count + 1
    vim.notify("[trilium-sync] "..Download._branch_count.."/"..Download._max_branch_count, vim.log.levels.INFO)
    vim.cmd("redraw")

    -- create the real note
    util.save_file_async(notes_path, content, function ()
        util.metadata.trackedNoteIDs[root.noteId] = true;

        -- create the link in tree (this is allowed to error)
        vim.uv.fs_symlink(notes_path, tree_abs_path)
    end)
end


---generates the children for a given noteid
---@param triliumData table
---@return Node[]
local function gen_children_tree(triliumData)
    -- Step 1: Create noteId to note map
    local notesMap = {}
    for _, note in ipairs(triliumData.notes) do
        notesMap[note.noteId] = {
            title = note.title:gsub("[/\\:*?\"<>|]", "_"),
            noteId = note.noteId
        }
    end

    -- Step 2: Build parent-child relationships
    local childrenMap = {}
    for _, branch in ipairs(triliumData.branches) do
        if branch.parentNoteId ~= "none" then
            if not childrenMap[branch.parentNoteId] then
                childrenMap[branch.parentNoteId] = {}
            end
            table.insert(childrenMap[branch.parentNoteId], {
                noteId = branch.noteId,
                position = branch.notePosition
            })
        end
    end

    -- Step 3: Recursive function to build the tree
    local function buildTree(parentNoteId)
        local result = {}
        local index = 1

        if not childrenMap[parentNoteId] then return result end

        for _, child in ipairs(childrenMap[parentNoteId]) do
            local childNote = notesMap[child.noteId]
            if not childNote then goto continue end
            Download._max_branch_count = Download._max_branch_count + 1

            local node = {
                title = childNote.title,
                noteId = child.noteId
            }

            -- Recursively build children
            local grandchildren = buildTree(child.noteId)
            if next(grandchildren) ~= nil then
                node.children = grandchildren
            end

            result[index] = node
            index = index + 1

            ::continue::
        end

        return result
    end

    return buildTree("root")
end


--- saves all of the notes to the data folder
function Download.all_notes()
    vim.fn.mkdir(util.config.notes_dir, "p")
    vim.fn.mkdir(util.config.tree_dir, "p")
    local data = curl(util.request_methods.GET, "/tree?subTreeNoteId=root")
    local tree_data = vim.json.decode(data)
    local root = gen_children_tree(tree_data)
    --io.popen("echo "..vim.fn.escape(util.debug_dump_table(root), '"').." > /tmp/data.txt")

    for _, node in ipairs(root) do
        save_tree(node)
    end

    Download._max_branch_count = 0
    Download._branch_count = 0
    util.save_metadata()
end

--- TODO impl
function Download.note_by_id()

end


return Download
