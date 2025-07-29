local M = {}

---Temporarily makes buffer modifiable, executes callback, then restores read-only state
---@param buf_id number
---@param callback function Function to execute while buffer is modifiable
function M.with_modifiable_buffer(buf_id, callback)
    -- Temporarily make buffer modifiable
    vim.bo[buf_id].modifiable = true
    vim.bo[buf_id].readonly = false
    
    -- Execute the callback
    callback()
    
    -- Make buffer read-only again
    vim.bo[buf_id].modifiable = false
    vim.bo[buf_id].readonly = true
end

---Updates a specific line in the buffer
---@param buf_id number
---@param line_idx number 0-based line index
---@param content string Content to set on the line
function M.update_line(buf_id, line_idx, content)
    M.with_modifiable_buffer(buf_id, function()
        vim.api.nvim_buf_set_lines(buf_id, line_idx, line_idx + 1, false, { content })
    end)
end

return M
