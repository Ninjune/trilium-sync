local M = {}
local api = require("trilium-sync.api")
local util = require("trilium-sync.util")
local augroup = vim.api.nvim_create_augroup("trilium-sync", { clear = true })


local function main()
    api.init_session()
    util.log("Session initialized.")

    vim.api.nvim_create_user_command("TriliumSync", function()
        util.log("Syncing...")
        api.sync()
    end, {})
end



function M.setup()
    vim.api.nvim_create_autocmd("VimEnter", {
        group = augroup,
        desc = "Load trilium-sync.",
        once = true,
        callback = main,
    })

    vim.api.nvim_create_autocmd("BufWritePost", {
        group = augroup,
        pattern = "*.md",
        callback = api.upload.push_current_buffer,
    })

    vim.api.nvim_create_autocmd("BufNewFile", {
        group = "augroup",
        pattern = "*.md",
        callback = function ()
            local file_path = vim.fn.expand("<afile>:p")
            if not file_path:sub(1, util.config.tree_dir:len()) == util.config.tree_dir then return end
        end
    })
end


return M
