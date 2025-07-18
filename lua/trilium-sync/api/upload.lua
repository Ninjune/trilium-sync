local util = require("trilium-sync.util")
local curl = require("trilium-sync.api.curl")
local Upload = {}


--- uploads the current buffer if it is in metadata and there are changes.
function Upload.push_current_buffer()
    local data = {
        curbufId = 0,
        startLine = 0,
        endLine = -1,
        strictIndex = false,
    }
    local bufname = vim.api.nvim_buf_get_name(data.curbufId)
    if not bufname:sub(1, util.config.notes_dir:len()) == util.config.notes_dir then return end
    -- chop off the config folder part of the bufname and .md
    local noteId = bufname:sub(util.config.notes_dir:len()+2, bufname:len()-3)

    if not util.metadata.trackedNoteIDs[noteId] then return end

    local lines = vim.api.nvim_buf_get_lines(
        data.curbufId,
        data.startLine,
        data.endLine,
        data.strictIndex
    )

    local new_content = table.concat(lines, "\n")
    new_content = util.markdown_to_html(new_content)
    util.log("Syncing note: " .. noteId)
    curl(
        util.request_methods.PUT,
        "/notes/" .. noteId .. "/data",
        vim.json.encode({ content = new_content })
    )
    util.save_metadata()
end


return Upload
