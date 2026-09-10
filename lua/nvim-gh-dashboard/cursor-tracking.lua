local M = {}

local buffer_helpers = require("nvim-gh-dashboard.buffer-helpers")

---Sets up cursor position tracking for the dashboard buffer
---@param buf_id number
---@param contributions_graph ContributionsGraph
---@param activity_graph ActivityGraph
---@param total_height number
---@param horizontal_pad number|nil defaults to 0
function M.setup(buf_id, contributions_graph, activity_graph, total_height, horizontal_pad)
	-- Create autocommand group for this buffer
	local group = vim.api.nvim_create_augroup("GHDashboardCursor", { clear = false })

	-- Set up cursor moved autocommand
	vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
		group = group,
		buffer = buf_id,
		callback = function()
			M.update_contribution_details(buf_id, contributions_graph, activity_graph, total_height, horizontal_pad)
		end,
	})
end

---Converts global cursor position to graph-local coordinates
---@param header_height number
---@param horizontal_pad number|nil defaults to 0
---@return number|nil line ContributionsGraph-local line (1-7), nil if outside graph
---@return number col ContriutionsGraph-local column
function M.get_graph_cursor_position(header_height, horizontal_pad)
	horizontal_pad = horizontal_pad or 0

	local cursor = vim.api.nvim_win_get_cursor(0)
	local line_global = cursor[1]
	local col_global = cursor[2] + 1 -- Convert to 1-based indexing

	-- Convert global cursor position to local buffer position
	local line = line_global - header_height
	local col = col_global - horizontal_pad

	-- Check that cursor is in the graph
	if line < 1 or line > 7 then
		return nil, col
	end

	return line, col
end

---Updates the cursor position display in the buffer
---@param buf_id number
---@param contributions_graph ContributionsGraph
---@param activity_graph ActivityGraph
---@param total_height number
---@param horizontal_pad number|nil defaults to 0
function M.update_contribution_details(buf_id, contributions_graph, activity_graph, total_height, horizontal_pad)
	local line, col =
		M.get_graph_cursor_position(total_height - contributions_graph.height - activity_graph.height, horizontal_pad)

	local tooltip = ""
	if line then
		local selected_contribution = contributions_graph.grid[line][col]
		if selected_contribution then
			tooltip = selected_contribution.tooltip
		end
	end

	local tooltip_pad = math.max(0, math.floor((vim.api.nvim_win_get_width(0) - vim.fn.strdisplaywidth(tooltip)) / 2))
	local position_line_idx = total_height + 2
	buffer_helpers.update_line(buf_id, position_line_idx, string.rep(" ", tooltip_pad) .. tooltip)
end

return M
