---@alias noteId string
---@alias parentNoteId string
---@alias parent {
---   noteId: noteId,
---   title: string,
---   parent: parent|nil,
---}
---@alias tree_tables { 
---    leaf_note_ids: noteId[],
---    parent_lookup_table: {noteId: parentNoteId},
---    title_lookup_table: {noteId: string},
---}

local util = require("trilium-sync.util")
local curl = require("trilium-sync.api.curl")
local Download = {}


--- 
---@param noteId noteId
---@return string
local function get_note_content(noteId)
    -- api/notes/(noteID)/blob
    local data = curl(util.request_methods.GET, "/notes/" ..noteId.. "/blob")
    local content = vim.fn.json_decode(data).content
    content = content or ""
    if content == vim.NIL then content = "" end

    return content
end


--- puts a note into local file
---@param title string ensure this does not have slashes before this method if you don't want it in a folder
---@param noteId noteId
---@param parent parent|nil
---@param is_leaf boolean|nil assumed leaf by default
local function save_note(title, noteId, parent, is_leaf)
    is_leaf = is_leaf or true
    local content = get_note_content(noteId)
    if content == vim.NIL or (content == "" and title:find("_dircontent")) then return end

    content = util.html_to_markdown(content)
    local relative_file_path = ""

    while parent ~= nil do
        -- ensure the title when saving the note and in the file path are equal
        parent.title = parent.title:gsub("[/\\:*?\"<>|]", "_")
        relative_file_path = parent.title.."/"..relative_file_path

        save_note(
            parent.title .. "/" .. "_dircontent",
            parent.noteId,
            parent.parent,
            false
        )
        parent = parent.parent
    end

    local abs_file_path = util.config.notes_dir .. "/" .. relative_file_path
    vim.fn.mkdir(abs_file_path, "p")

    abs_file_path = abs_file_path .. title .. ".md"
    relative_file_path = relative_file_path .. title .. ".md"
    local f = io.open(abs_file_path, "w")

    if f then
        f:write(content or "")
        f:close()
        util.metadata[relative_file_path] = { noteId = noteId }
        util.save_metadata()
    else
        util.log("Failed to write note: " .. abs_file_path)
    end
end


---generates some needed tables for downloading notes
---
---@param tree table
---@return tree_tables
local function gen_tree_tables(tree)
    --@type boolean[]
    local parent_note_ids = {}
    local parent_lookup_table = {}
    local title_lookup_table = {}

    for _, branch in ipairs(tree.branches) do
        parent_note_ids[branch.parentNoteId] = true
        parent_lookup_table[branch.noteId] = branch.parentNoteId
    end

    local leaf_note_ids = {}
    for _, note in ipairs(tree.notes) do
        if not parent_note_ids[note.noteId] and note.mime == "text/html" then
            table.insert(leaf_note_ids, note.noteId)
        end
        title_lookup_table[note.noteId] = note.title
    end

    return {
        leaf_note_ids=leaf_note_ids,
        parent_lookup_table=parent_lookup_table,
        title_lookup_table=title_lookup_table
    }
end


---generates the parents for a given noteid
---@param noteId noteId note id to generate parents for
---@param tables tree_tables
---@return parent|nil
local function gen_parent(noteId, tables)
    -- base case
    local parentId = tables.parent_lookup_table[noteId]
    assert(parentId ~= nil and parentId ~= "none")
    if parentId == "root" then
        return nil
    end

    ---@type parent
    local parent = {}
    parent.noteId = parentId
    parent.title = tables.title_lookup_table[parentId]
    parent.parent = gen_parent(parentId, tables)


    return parent
end


--- saves all of the notes to the data folder
function Download.all_notes()
    vim.fn.mkdir(util.config.notes_dir, "p")
    local data = curl(util.request_methods.GET, "/tree?subTreeNoteId=root")
    local tree = vim.fn.json_decode(data)

    -- create notes
    local tables = gen_tree_tables(tree)

    for _, note in ipairs(tables.leaf_note_ids) do
        local title = tables.title_lookup_table[note]
        title = title:gsub("[/\\:*?\"<>|]", "_")
        save_note(title, note, gen_parent(note, tables))
    end
    util.log("Notes downloaded to " .. util.config.notes_dir)
end

--- TODO impl
function Download.note_by_id()

end


return Download
