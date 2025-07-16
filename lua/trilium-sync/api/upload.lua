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
    assert(bufname:sub(1, util.config.notes_dir:len()) == util.config.notes_dir)
    -- chop off the config folder part of the bufname
    bufname = bufname:sub(util.config.notes_dir:len()+2)
    util.log("Bufname: " .. bufname)
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
                util.request_methods.PUT,
                "/notes/" .. entry.noteId .. "/data",
                vim.fn.json_encode({ content = new_content })
            )
            util.metadata[bufname].raw = new_content
            util.save_metadata()
        end
    end
end


return Upload
