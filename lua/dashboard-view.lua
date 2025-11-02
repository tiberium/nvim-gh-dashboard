local M = {}

local Graph = require("graph")
local buffer_helpers = require("buffer-helpers")

---Creates header lines for the dashboard
---@param year number
---@param username string
---@return string[]
function M.create_header(year, username)
    local header_lines = {}

    table.insert(header_lines, "┌──────────────────────────────────────────────────────────────┐")
    table.insert(header_lines, "│                      GitHub Contributions                    │")
    table.insert(header_lines, "└──────────────────────────────────────────────────────────────┘")
    table.insert(header_lines, "")
    table.insert(header_lines, "User: " .. username)
    table.insert(header_lines, "Year: " .. year)
    table.insert(header_lines, "")

    return header_lines
end

---Creates the dashboard buffer and fills it with data
---@param contributions Contribution[]
---@param year number
---@param username string
---@param chars table Characters configuration
function M.create_dashboard(contributions, year, username, chars)
    vim.cmd("enew")
    vim.bo.buftype = "nofile"
    vim.bo.bufhidden = "wipe"
    vim.bo.swapfile = false

    -- local win_id = vim.api.nvim_get_current_win()
    local buf_id = vim.api.nvim_get_current_buf()
    -- TODO Needed later
    -- local width = vim.api.nvim_win_get_width(win_id)

    -- Create header and graph separately
    local contributions_graph = Graph.new(contributions, year, chars)

    local graph_lines = contributions_graph:get_lines()
    local header_lines = M.create_header(year, username)

    -- Combine header and graph
    local dashboard_lines = {}
    for _, line in ipairs(header_lines) do
        table.insert(dashboard_lines, line)
    end
    for _, line in ipairs(graph_lines) do
        table.insert(dashboard_lines, line)
    end

    -- Add empty lines for cursor position info
    table.insert(dashboard_lines, "")
    table.insert(dashboard_lines, "")

    vim.api.nvim_buf_set_lines(0, 0, -1, false, dashboard_lines)
    vim.bo.modifiable = false
    vim.bo.readonly = true

    -- Set up cursor position tracking (need to adjust height calculation)
    local total_height = #header_lines + contributions_graph.height
    M.setup_cursor_tracking(buf_id, contributions_graph, total_height)
end

---Sets up cursor position tracking for the dashboard buffer
---@param buf_id number
---@param contributions_graph Graph
---@param total_height number
function M.setup_cursor_tracking(buf_id, contributions_graph, total_height)
    -- Create autocommand group for this buffer
    local group = vim.api.nvim_create_augroup("GHDashboardCursor", { clear = false })

    -- Set up cursor moved autocommand
    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
        group = group,
        buffer = buf_id,
        callback = function()
            M.update_contribution_details(buf_id, contributions_graph, total_height)
        end,
    })
end

---Converts global cursor position to graph-local coordinates
---@param contributions_graph Graph
---@param header_height number
---@return number|nil line Graph-local line (1-7), nil if outside graph
---@return number col Graph-local column
function M.get_graph_cursor_position(contributions_graph, header_height)
    local cursor = vim.api.nvim_win_get_cursor(0)
    local line_global = cursor[1]
    local col_global = cursor[2] + 1 -- Convert to 1-based indexing

    -- Convert global cursor position to local buffer position
    local line = line_global - header_height
    local col = col_global

    -- Check that cursor is in the graph
    if (line < 1 or line > 7) then
        return nil, col
    end

    return line, col
end

---Updates the cursor position display in the buffer
---@param buf_id number
---@param contributions_graph Graph
---@param total_height number
function M.update_contribution_details(buf_id, contributions_graph, total_height)
    local line, col = M.get_graph_cursor_position(
        contributions_graph,
        total_height - contributions_graph.height
    )

    local tooltip = ""
    if line then
        local selected_contribution = contributions_graph.grid[line][col]
        if (selected_contribution) then
            tooltip = selected_contribution.tooltip
        end
    end

    local position_line_idx = total_height + 1
    buffer_helpers.update_line(buf_id, position_line_idx, tooltip)
end

return M
