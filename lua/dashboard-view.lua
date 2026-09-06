local M = {}

local ContributionsGraph = require("contributions-graph")
local ActivityGraph = require("activity-graph")
local Contribution = require("contribution")
local GithubService = require("github-service")
local buffer_helpers = require("buffer-helpers")

-- vim.uv is the new name (Neovim >= 0.10), vim.loop is kept for older versions
local uv = vim.uv or vim.loop

M.spinner_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
M.spinner_interval_ms = 80

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

---Creates a scratch, read-only buffer meant to be used as the dashboard buffer
---@return number buf_id
function M.create_buffer()
    vim.cmd("enew")
    vim.bo.buftype = "nofile"
    vim.bo.bufhidden = "wipe"
    vim.bo.swapfile = false

    local buf_id = vim.api.nvim_get_current_buf()

    vim.bo.modifiable = false
    vim.bo.readonly = true

    return buf_id
end

---Starts an animated Braille spinner on the given line of the buffer.
---@param buf_id number
---@param line_idx number 0-based line index to animate
---@param message string|nil Message to show next to the spinner
---@return uv.uv_timer_t timer Timer handle; call `M.stop_spinner(timer)` to stop it
function M.start_spinner(buf_id, line_idx, message)
    local frame_idx = 1
    local timer = uv.new_timer()

    timer:start(0, M.spinner_interval_ms, vim.schedule_wrap(function()
        if not vim.api.nvim_buf_is_valid(buf_id) then
            M.stop_spinner(timer)
            return
        end

        local frame = M.spinner_frames[frame_idx]
        buffer_helpers.update_line(buf_id, line_idx, frame .. " " .. (message or "Loading..."))

        frame_idx = (frame_idx % #M.spinner_frames) + 1
    end))

    return timer
end

---Stops and closes a spinner timer created by `M.start_spinner`
---@param timer uv.uv_timer_t|nil
function M.stop_spinner(timer)
    if timer and not timer:is_closing() then
        timer:stop()
        timer:close()
    end
end

---Renders an error message into the dashboard buffer, replacing the spinner
---@param buf_id number
---@param message string
function M.render_error(buf_id, message)
    if not vim.api.nvim_buf_is_valid(buf_id) then
        return
    end

    buffer_helpers.with_modifiable_buffer(buf_id, function()
        vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, {
            "Failed to load GitHub dashboard:",
            "",
            message,
        })
    end)
end

---Renders the header and graphs into an already-created dashboard buffer
---@param buf_id number
---@param contributions Contribution[]
---@param activities ActivityMetadata|nil
---@param year number
---@param username string
---@param chars table Characters configuration
function M.render_dashboard(buf_id, contributions, activities, year, username, chars)
    if not vim.api.nvim_buf_is_valid(buf_id) then
        return
    end

    -- Create header and graph separately
    local contributions_graph = ContributionsGraph.new(contributions, year, chars)

    local contributions_graph_lines = contributions_graph:get_lines()
    local header_lines = M.create_header(year, username)

    local activity_graph = ActivityGraph.new(activities, year, chars)
    local activity_graph_lines = activity_graph:get_lines()

    -- Combine header and graphs
    local dashboard_lines = {}
    for _, line in ipairs(header_lines) do
        table.insert(dashboard_lines, line)
    end
    for _, line in ipairs(contributions_graph_lines) do
        table.insert(dashboard_lines, line)
    end
    table.insert(dashboard_lines, "")
    for _, line in ipairs(activity_graph_lines) do
        table.insert(dashboard_lines, line)
    end

    -- Add empty lines for cursor position info
    table.insert(dashboard_lines, "")

    buffer_helpers.with_modifiable_buffer(buf_id, function()
        vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, dashboard_lines)
    end)

    -- Set up cursor position tracking (need to adjust height calculation)
    local total_height = #header_lines + contributions_graph.height + activity_graph.height
    M.setup_cursor_tracking(buf_id, contributions_graph, activity_graph, total_height)
end

---Opens the dashboard buffer immediately, showing an animated spinner while the
---GitHub data is being fetched asynchronously, then replaces it with the
---rendered graphs on success or an error message on failure.
---@param username string GitHub username
---@param year number Year to fetch contributions for
---@param chars table Characters configuration
---@return number buf_id
function M.open_dashboard(username, year, chars)
    local buf_id = M.create_buffer()

    local header_lines = M.create_header(year, username)
    buffer_helpers.with_modifiable_buffer(buf_id, function()
        vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, header_lines)
    end)

    -- The header already ends with a blank line; use it to host the spinner
    local spinner_line_idx = #header_lines - 1
    local timer = M.start_spinner(buf_id, spinner_line_idx, "Loading GitHub dashboard...")

    GithubService.fetch_dashboard_data(username, year, true, function(data)
        M.stop_spinner(timer)

        local contributions = {}
        for _, contribution_metadata in ipairs(data.contributions) do
            local contribution = Contribution.new(contribution_metadata)
            if contribution then
                table.insert(contributions, contribution)
            end
        end

        M.render_dashboard(buf_id, contributions, data.activity, year, username, chars)
    end, function(message)
        M.stop_spinner(timer)
        M.render_error(buf_id, message)
    end)

    return buf_id
end

---Sets up cursor position tracking for the dashboard buffer
---@param buf_id number
---@param contributions_graph ContributionsGraph
---@param activity_graph ActivityGraph
---@param total_height number
function M.setup_cursor_tracking(buf_id, contributions_graph, activity_graph, total_height)
    -- Create autocommand group for this buffer
    local group = vim.api.nvim_create_augroup("GHDashboardCursor", { clear = false })

    -- Set up cursor moved autocommand
    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
        group = group,
        buffer = buf_id,
        callback = function()
            M.update_contribution_details(buf_id, contributions_graph, activity_graph, total_height)
        end,
    })
end

---Converts global cursor position to graph-local coordinates
---@param header_height number
---@return number|nil line ContributionsGraph-local line (1-7), nil if outside graph
---@return number col ContriutionsGraph-local column
function M.get_graph_cursor_position(header_height)
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
---@param contributions_graph ContributionsGraph
---@param activity_graph ActivityGraph
---@param total_height number
function M.update_contribution_details(buf_id, contributions_graph, activity_graph, total_height)
    local line, col = M.get_graph_cursor_position(
        total_height - contributions_graph.height - activity_graph.height
    )

    local tooltip = ""
    if line then
        local selected_contribution = contributions_graph.grid[line][col]
        if (selected_contribution) then
            tooltip = selected_contribution.tooltip
        end
    end

    local position_line_idx = total_height + 2
    buffer_helpers.update_line(buf_id, position_line_idx, tooltip)
end

return M
