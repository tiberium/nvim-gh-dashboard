local M = {}

local gh = require("gh")

function M.setup()
    local contributions = gh.fetch_contributions("tiberium")

    -- local file = io.open("contributions.txt", "a")
    -- if file then
    --     for _, contribution in ipairs(contributions) do
    --         file:write(contribution .. "\n")
    --     end
    --     file:close()
    -- else
    --     print("Error opening file for writing.")
    -- end

    M.dashboard()
end

function M.dashboard()
    vim.cmd("enew")
    vim.bo.buftype = "nofile"
    vim.bo.bufhidden = "wipe"
    vim.bo.swapfile = false

    local lines = gh.fetch_contributions("tiberium")

    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
    vim.bo.modifiable = false
    vim.bo.readonly = true
end

return M
