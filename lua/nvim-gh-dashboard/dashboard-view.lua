local M = {}

local ContributionsGraph = require("nvim-gh-dashboard.contributions-graph")
local ActivityGraph = require("nvim-gh-dashboard.activity-graph")
local Contribution = require("nvim-gh-dashboard.contribution")
local GithubService = require("nvim-gh-dashboard.github-service")
local buffer_helpers = require("nvim-gh-dashboard.buffer-helpers")
local Spinner = require("nvim-gh-dashboard.spinner")
local CursorTracking = require("nvim-gh-dashboard.cursor-tracking")

-- Re-exported for backward compatibility.
M.spinner_frames = Spinner.spinner_frames
M.spinner_interval_ms = Spinner.spinner_interval_ms

---Namespace used for all the highlights (colors) applied by this plugin.
M.namespace = vim.api.nvim_create_namespace("nvim-gh-dashboard")

---Creates header lines for the dashboard
---@param year number
---@param username string
---@return string[]
function M.create_header(year, username)
	local header_lines = {}

	table.insert(
		header_lines,
		"┌──────────────────────────────────────────────────────────────┐"
	)
	table.insert(header_lines, "│                      GitHub Contributions                    │")
	table.insert(
		header_lines,
		"└──────────────────────────────────────────────────────────────┘"
	)
	table.insert(header_lines, "")
	table.insert(header_lines, "User: " .. username)
	table.insert(header_lines, "Year: " .. year)
	table.insert(header_lines, "")

	return header_lines
end

---Computes the highlight spans for the header lines produced by
---`M.create_header`, coloring the border, title, and labels/values
---differently.
---@param header_lines string[]
---@return table[] highlights list of `{ line, col_start, col_end, hl_group }`
---(0-based, end-exclusive)
function M.get_header_highlights(header_lines)
	local highlights = {}
	local border_char = "│"
	local border_len = #border_char

	for line_idx, line in ipairs(header_lines) do
		local line0 = line_idx - 1

		if line:match("^[┌└]") then
			table.insert(
				highlights,
				{ line = line0, col_start = 0, col_end = -1, hl_group = "GHDashboardHeaderBorder" }
			)
		elseif vim.startswith(line, border_char) then
			table.insert(
				highlights,
				{ line = line0, col_start = 0, col_end = border_len, hl_group = "GHDashboardHeaderBorder" }
			)
			table.insert(highlights, {
				line = line0,
				col_start = border_len,
				col_end = #line - border_len,
				hl_group = "GHDashboardHeaderTitle",
			})
			table.insert(
				highlights,
				{ line = line0, col_start = #line - border_len, col_end = -1, hl_group = "GHDashboardHeaderBorder" }
			)
		elseif line:match("^%a+:%s") then
			local _, label_end = line:find("^%a+:%s")
			table.insert(
				highlights,
				{ line = line0, col_start = 0, col_end = label_end, hl_group = "GHDashboardHeaderLabel" }
			)
			table.insert(
				highlights,
				{ line = line0, col_start = label_end, col_end = -1, hl_group = "GHDashboardHeaderValue" }
			)
		end
	end

	return highlights
end

---Applies a list of `{ line, col_start, col_end, hl_group }` or
---`{ line, col, hl_group }` highlight spans to the given buffer, offsetting
---every `line` by `line_offset`. `col_end = -1` (or omitted `col_end` combined
---with `col`) highlights to the end of the line.
---@param buf_id number
---@param highlights table[]
---@param line_offset number|nil defaults to 0
---@param col_offset number|nil defaults to 0
function M.apply_highlights(buf_id, highlights, line_offset, col_offset)
	if not vim.api.nvim_buf_is_valid(buf_id) then
		return
	end

	line_offset = line_offset or 0
	col_offset = col_offset or 0

	for _, highlight in ipairs(highlights) do
		local col_start = (highlight.col_start or highlight.col) + col_offset
		local col_end = highlight.col_end or (col_start + 1)
		if col_end ~= -1 then
			col_end = col_end + col_offset
		end

		vim.api.nvim_buf_add_highlight(
			buf_id,
			M.namespace,
			highlight.hl_group,
			highlight.line + line_offset,
			col_start,
			col_end
		)
	end
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
	return Spinner.start(buf_id, line_idx, message)
end

---Stops and closes a spinner timer created by `M.start_spinner`
---@param timer uv.uv_timer_t|nil
function M.stop_spinner(timer)
	Spinner.stop(timer)
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

	-- Center the dashboard within the current window, both horizontally and
	-- vertically, by padding it with leading spaces/blank lines.
	-- Use display width (not byte length) since border lines contain
	-- multi-byte UTF-8 box-drawing characters.
	local content_width = 0
	for _, line in ipairs(dashboard_lines) do
		content_width = math.max(content_width, vim.fn.strdisplaywidth(line))
	end

	local win_width = vim.api.nvim_win_get_width(0)
	local win_height = vim.api.nvim_win_get_height(0)
	local horizontal_pad = math.max(0, math.floor((win_width - content_width) / 2))
	local vertical_pad = math.max(0, math.floor((win_height - #dashboard_lines) / 2))

	local centered_lines = {}
	for _ = 1, vertical_pad do
		table.insert(centered_lines, "")
	end
	for _, line in ipairs(dashboard_lines) do
		table.insert(centered_lines, string.rep(" ", horizontal_pad) .. line)
	end

	buffer_helpers.with_modifiable_buffer(buf_id, function()
		vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, centered_lines)
	end)

	vim.api.nvim_buf_clear_namespace(buf_id, M.namespace, 0, -1)
	M.apply_highlights(buf_id, M.get_header_highlights(header_lines), vertical_pad, horizontal_pad)
	M.apply_highlights(
		buf_id,
		contributions_graph:get_highlights(),
		vertical_pad + #header_lines,
		horizontal_pad
	)
	M.apply_highlights(
		buf_id,
		activity_graph:get_highlights(),
		vertical_pad + #header_lines + contributions_graph.height + 1,
		horizontal_pad
	)

	-- Set up cursor position tracking (need to adjust height calculation)
	local total_height = vertical_pad + #header_lines + contributions_graph.height + activity_graph.height
	M.setup_cursor_tracking(buf_id, contributions_graph, activity_graph, total_height, horizontal_pad)
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
	M.apply_highlights(buf_id, M.get_header_highlights(header_lines))

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
---@param horizontal_pad number|nil defaults to 0
function M.setup_cursor_tracking(buf_id, contributions_graph, activity_graph, total_height, horizontal_pad)
	CursorTracking.setup(buf_id, contributions_graph, activity_graph, total_height, horizontal_pad)
end

---Converts global cursor position to graph-local coordinates
---@param header_height number
---@param horizontal_pad number|nil defaults to 0
---@return number|nil line ContributionsGraph-local line (1-7), nil if outside graph
---@return number col ContriutionsGraph-local column
function M.get_graph_cursor_position(header_height, horizontal_pad)
	return CursorTracking.get_graph_cursor_position(header_height, horizontal_pad)
end

---Updates the cursor position display in the buffer
---@param buf_id number
---@param contributions_graph ContributionsGraph
---@param activity_graph ActivityGraph
---@param total_height number
---@param horizontal_pad number|nil defaults to 0
function M.update_contribution_details(buf_id, contributions_graph, activity_graph, total_height, horizontal_pad)
	CursorTracking.update_contribution_details(buf_id, contributions_graph, activity_graph, total_height, horizontal_pad)
end

return M
