local M = {}

local gh = require("gh")
local Graph = require("graph")
local GitHubContribution = require("github_contrubution")

---Function to setup the plugin
function M.setup()
    -- TODO: Parameterize the year
    local year = 2024

    local contributions_metadata = gh.fetch_contributions("tiberium", year)

    if not contributions_metadata then
        print("Failed to fetch contributions.")
        return
    end

    local contributions = {}
    for _, contribution_metadata in ipairs(contributions_metadata) do
        local contribution = GitHubContribution.new(contribution_metadata)

        table.insert(contributions, contribution)
    end

    M.dashboard(contributions, year)
end

---Fuction creating the dashboard buffer and filling it with data
---@param contributions GitHubContribution[]
---@param year number
function M.dashboard(contributions, year)
    vim.cmd("enew")
    vim.bo.buftype = "nofile"
    vim.bo.bufhidden = "wipe"
    vim.bo.swapfile = false

    -- local win_id = vim.api.nvim_get_current_win()
    local buf_id = vim.api.nvim_get_current_buf()
    -- TODO Needed later
    -- local width = vim.api.nvim_win_get_width(win_id)

    local contributions_graph = Graph.new(contributions, year)
    local graph_lines = contributions_graph:get_lines()

    -- Add empty lines for cursor position info
    table.insert(graph_lines, "")
    table.insert(graph_lines, "")

    vim.api.nvim_buf_set_lines(0, 0, -1, false, graph_lines)
    vim.bo.modifiable = false
    vim.bo.readonly = true

    -- Set up cursor position tracking
    M.setup_cursor_tracking(buf_id, contributions_graph)
end

---Sets up cursor position tracking for the dashboard buffer
---@param buf_id number
---@param contributions_graph Graph
function M.setup_cursor_tracking(buf_id, contributions_graph)
    -- Create autocommand group for this buffer
    local group = vim.api.nvim_create_augroup("GHDashboardCursor", { clear = false })

    -- Set up cursor moved autocommand
    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
        group = group,
        buffer = buf_id,
        callback = function()
            M.display_contribution_details(buf_id, contributions_graph)
        end,
    })
end

---Updates the cursor position display in the buffer
---@param buf_id number
---@param contributions_graph Graph
function M.display_contribution_details(buf_id, contributions_graph)
    local cursor = vim.api.nvim_win_get_cursor(0)
    local line_global = cursor[1]
    local col_global = cursor[2] + 1 -- Convert to 1-based indexing

    -- Convert global cursor position to local buffer position
    local line = line_global - (contributions_graph.height - 7)
    local col = col_global

    -- check that cursor is in the graph
    if (line < 1 or line > 7) then
        return
    end

    local position_text = string.format("Position: Line %d, Column %d", line, col)

    -- Calculate the line number where position info should be displayed
    -- It's at contributions_graph.height + 1 (one empty line + position line)
    local position_line_idx = contributions_graph.height + 1

    -- Temporarily make buffer modifiable to update position
    vim.bo[buf_id].modifiable = true
    vim.bo[buf_id].readonly = false

    -- Update the position line
    vim.api.nvim_buf_set_lines(buf_id, position_line_idx, position_line_idx + 1, false, { position_text })

    -- Make buffer read-only again
    vim.bo[buf_id].modifiable = false
    vim.bo[buf_id].readonly = true
end

return M
