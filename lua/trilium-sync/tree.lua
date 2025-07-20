local M = {
    _max_branch_count = 0,
    _branch_count = 0
}


--- Search the tree recursively for a noteId
---@param tree table The tree structure to search
---@param noteId string The noteId to find
---@param path table? current running path
---@return Node? node
---@return string[]? path
M.find_node_with_path = function (tree, noteId, path)
    path = path or {}

    for idx, node in pairs(tree) do
        table.insert(path, node.title)

        if node.noteId == noteId then
            return node, path
        end

        if node.children then
            local found, full_path = M.find_node_with_path(node.children, noteId, path)
            if found then
                return found, full_path
            end
        end

        table.remove(path)
    end

    return nil, nil
end

M.insert_child_node = function(parent_tree, new_node)
    parent_tree.children = parent_tree.children or {}
    table.insert(parent_tree.children, new_node)
    return true
end


---generates the tree using the downloaded data
---@param triliumData table
---@return Node[]
M.gen_children_tree = function (triliumData)
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
            M._max_branch_count = M._max_branch_count + 1

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


return M
