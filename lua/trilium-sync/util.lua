local util = {}


util.config = {
    debug_messages = true,
    api_url = "https://notes.ninjune.dev/api",
    notes_dir = vim.fn.stdpath("data") .. "/trilium-sync/notes",
    tree_dir = vim.fn.stdpath("data") .. "/trilium-sync/tree",
    meta_file = vim.fn.stdpath("data") .. "/trilium-sync/.metadata.json",
    session_file = vim.fn.stdpath("data") .. "/trilium-sync/.session.json",

    -- these need spacing on both sides of arguments
    pandoc_markdown_to_html_additional_arguments = nil,
    pandoc_html_to_markdown_additional_arguments = nil,

    ---function that runs before pandoc converts document
    ---(ran on download)
    ---
    ---@param html string
    ---@return string
    pandoc_html_to_markdown_preprocess = function (html)
        return html
    end,

    ---function that runs after pandoc converts document
    ---(ran on download)
    ---
    ---@param markdown string
    ---@return string
    pandoc_html_to_markdown_postprocess = function (markdown)
        markdown = markdown:gsub("\\\n", "\n")
        return markdown
    end,

    ---function that runs before pandoc converts document
    ---(ran on upload)
    ---
    ---@param markdown string
    ---@return string
    pandoc_markdown_to_html_preprocess = function (markdown)
        return markdown
    end,

    ---function that runs after pandoc converts document
    ---(ran on upload)
    ---@param html string
    ---@return string
    pandoc_markdown_to_html_postprocess = function (html)
        return html
    end,
}

util.request_methods = {
    GET="GET",
    PUT="PUT",
    DELETE="DELETE",
    POST="POST",
}

util.metadata = {}


function util.load_metadata()
    local f = io.open(util.config.meta_file, "r")

    if f then
        local data = f:read("*a")
        util.metadata = vim.fn.json_decode(data) or {}
        f:close()
    end
end


function util.save_metadata()
    local f = io.open(util.config.meta_file, "w")
    if f then
        f:write(vim.fn.json_encode(util.metadata))
        f:close()
    end
end

---logs a message to :messages
---@param data string
---@param level vim.log.levels|nil
function util.log(data, level)
    if not util.config.debug_messages then return end
    level = level or vim.log.levels.DEBUG
    vim.notify(data, level)
end


--- changes a html file to markdown format using pandoc
---
--- @param html string
--- @return string
function util.html_to_markdown(html)
    local tmp_in = os.tmpname()
    local tmp_out = os.tmpname()

    html = util.config.pandoc_html_to_markdown_preprocess(html)

    -- Write HTML to tmp_in
    local f = io.open(tmp_in, "w")
    if not f then return "" end
    f:write(html)
    f:close()

    -- Run pandoc to convert
    local cmd = string.format("pandoc -f html -t markdown -o %s %s", tmp_out, tmp_in)
    os.execute(cmd)

    -- Read Markdown from tmp_out
    local out = io.open(tmp_out, "r")
    if not out then return "" end
    local markdown = out:read("*a")
    out:close()

    -- Clean up
    os.remove(tmp_in)
    os.remove(tmp_out)

    markdown = util.config.pandoc_html_to_markdown_postprocess(markdown)

    return markdown
end


function util.markdown_to_html(md)
    local tmp_in = os.tmpname()
    local tmp_out = os.tmpname()

    md = util.config.pandoc_markdown_to_html_preprocess(md)

    -- Write Markdown to tmp_in
    local f = io.open(tmp_in, "w")
    if not f then return "" end
    f:write(md)
    f:close()

    -- Run pandoc to convert
    local cmd = string.format(
        "pandoc%s-f markdown+hard_line_breaks -t html -o %s %s",
        util.config.pandoc_additional_arguments or " ",
        tmp_out,
        tmp_in
    )
    os.execute(cmd)

    -- Read HTML from tmp_out
    local out = io.open(tmp_out, "r")
    if not out then return "" end
    local html = out:read("*a")
    out:close()

    -- Clean up
    os.remove(tmp_in)
    os.remove(tmp_out)

    html = util.config.pandoc_markdown_to_html_postprocess(html)

    return html
end


---dumps a table to a json string
---@param o table
---@return string
function util.debug_dump_table(o)
    if type(o) == 'table' then
        return vim.fn.json_encode(o)
    else
        return tostring(o)
    end
end


return util
