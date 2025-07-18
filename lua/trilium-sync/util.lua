local util = {}


util.config = {
    debug_messages = true,
    api_url = "https://notes.ninjune.dev/api",
    notes_dir = vim.fn.stdpath("data") .. "/trilium-sync/notes",
    tree_dir = vim.fn.stdpath("data") .. "/trilium-sync/tree",
    meta_file = vim.fn.stdpath("data") .. "/trilium-sync/.metadata.json",
    session_file = vim.fn.stdpath("data") .. "/trilium-sync/.session.json",

    -- these need spacing on both sides of arguments
    pandoc_markdown_to_html_additional_arguments = " ",
    pandoc_html_to_markdown_additional_arguments = " ",

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

---@enum
util.request_methods = {
    GET="GET",
    PUT="PUT",
    DELETE="DELETE",
    POST="POST",
}

---@type TriliumMetadata
util.metadata = {
    trackedNoteIDs = {},
}


---saves a file asynchronously.
---if callback is nil, blocks thread til execution finished
---@param path string
---@param content string
---@param callback fun()|nil
---@return string|nil
function util.save_file_async(path, content, callback)
    vim.uv.fs_open(path, "w", tonumber("664", 8), function(err, fd)
        assert(not err, err)
        vim.uv.fs_write(fd, content, nil, function(err, _)
            assert(not err, err)
            vim.uv.fs_close(fd)
            if callback then callback() end
        end)
    end)
end


---reads a file asynchronously (blocks thread til execution finished). 
---returns nil on data if does not exist.
---@param path string
---@param callback fun(data: string|nil)
---@return string|nil
function util.read_file_async(path, callback)
    vim.uv.fs_stat(path, function(err, stat)
        if not stat then return callback(nil) end
        assert(not err, err)
        vim.uv.fs_open(path, "r", 438, function(err, fd)
            assert(not err, err)
            vim.uv.fs_read(fd, stat.size, 0, function(err, data)
                assert(not err, err)
                vim.uv.fs_close(fd, function(err)
                    assert(not err, err)
                    return callback(data)
                end)
            end)
        end)
    end)
end


function util.load_metadata()
    util.read_file_async(util.config.meta_file, function (data)
        if not data or data == "" then return end
        data = vim.json.decode(data)
        if data ~= nil and data.trackedNoteIDs ~= nil then
            util.metadata = data
        end
    end)
end


function util.save_metadata()
    util.save_file_async(util.config.meta_file, vim.json.encode(util.metadata))
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
        return vim.json.encode(o)
    else
        return tostring(o)
    end
end


return util
