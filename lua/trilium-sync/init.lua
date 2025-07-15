local M = {}
local api = require("trilium-sync.api")
local util = require("trilium-sync.util")
local auth = require("trilium-sync.auth")
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
        callback = api.push_if_tracked,
    })
end


return M
