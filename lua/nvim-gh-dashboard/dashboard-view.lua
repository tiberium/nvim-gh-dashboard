local M = {}

local ContributionsGraph = require("nvim-gh-dashboard.contributions-graph")
local ActivityGraph = require("nvim-gh-dashboard.activity-graph")
local AiUsageGraph = require("nvim-gh-dashboard.ai-usage-graph")
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

local CURRENT_WINDOW_ID = 0
local BUFFER_START_LINE = 0
local END_OF_BUFFER = -1
local HIGHLIGHT_TO_END_OF_LINE = -1
local FIRST_LUA_INDEX = 1
local NEXT_LINE_OFFSET = 1
local CENTER_DIVISOR = 2
local AI_MENU_SHORTCUT_COLUMN_START = 1
local AI_MENU_SHORTCUT_COLUMN_END = 2
local AI_MENU_LABEL_COLUMN_START = 4
local AI_PANEL_SEPARATOR_OFFSET_FROM_BOTTOM = 1
local CURSOR_COLUMN_INDEX = 2
local vertical_offset = 5
local ai_usage_height = 4
local bottom_empty_lines = 2
local top_empty_lines = 2

-- Centering helpers shared by `render_dashboard` (header + graphs) and
-- `open_dashboard` (header-only, while the spinner is showing), so that the
-- dashboard is centered on screen right away instead of appearing in the
-- top-left corner for a moment while data is being fetched.

---@param win_width number
---@param width number
---@return number
local function pad_for_width(win_width, width)
	return math.max(BUFFER_START_LINE, math.floor((win_width - width) / CENTER_DIVISOR))
end

---Computes the horizontal padding needed to center a single line, using
---display width (not byte length) since lines may contain multi-byte UTF-8
---box-drawing characters. Blank lines get no padding: prepending spaces to
---an otherwise empty line only adds invisible trailing whitespace (which
---some 'listchars' configurations render as visible characters), with no
---centering benefit since there is no visible content to center.
---@param win_width number
---@param line string
---@return number
local function pad_for_line(win_width, line)
	if line == "" then
		return BUFFER_START_LINE
	end
	return pad_for_width(win_width, vim.fn.strdisplaywidth(line))
end

---@param lines string[]
---@return number
local function max_width(lines)
	local width = BUFFER_START_LINE
	for _, line in ipairs(lines) do
		width = math.max(width, vim.fn.strdisplaywidth(line))
	end
	return width
end

---@param win_height number
---@param content_height number
---@return number
local function vertical_pad_for(win_height, content_height)
	return math.max(BUFFER_START_LINE, math.floor((win_height - content_height) / CENTER_DIVISOR) - vertical_offset)
end

---@param win_width number
---@return string
local function separator_for_width(win_width)
	return string.rep("─", win_width)
end

---@param lines string[]
---@param panel_line_idx number 0-based separator line index
---@param win_width number
local function append_ai_panel(lines, panel_line_idx, win_width)
	while #lines < panel_line_idx do
		table.insert(lines, "")
	end
	table.insert(lines, separator_for_width(win_width))
	for _ = FIRST_LUA_INDEX, ai_usage_height + bottom_empty_lines do
		table.insert(lines, "")
	end
end

---Prepends the given per-line paddings to each line (skipping blanks, see
---`pad_for_line`).
---@param lines string[]
---@param pads number[]
---@return string[]
local function apply_horizontal_padding(lines, pads)
	local padded = {}
	for i, line in ipairs(lines) do
		if line == "" then
			table.insert(padded, "")
		else
			table.insert(padded, string.rep(" ", pads[i] or BUFFER_START_LINE) .. line)
		end
	end
	return padded
end

---Creates header lines for the dashboard
---@param year number
---@param username string
---@param win_width number
---@return string[]
function M.create_header(year, username, win_width)
	local header_lines = {}

	table.insert(header_lines, "[A] AI")
	table.insert(header_lines, separator_for_width(win_width))
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
		local line0 = line_idx - FIRST_LUA_INDEX

		if line == "[A] AI" then
			table.insert(highlights, {
				line = line0,
				col_start = AI_MENU_SHORTCUT_COLUMN_START,
				col_end = AI_MENU_SHORTCUT_COLUMN_END,
				hl_group = "GHDashboardMenuShortcut",
			})
			table.insert(highlights, {
				line = line0,
				col_start = AI_MENU_LABEL_COLUMN_START,
				col_end = HIGHLIGHT_TO_END_OF_LINE,
				hl_group = "GHDashboardMenuLabel",
			})
		elseif line:match("^─+$") or line:match("^[┌└]") then
			table.insert(highlights, {
				line = line0,
				col_start = BUFFER_START_LINE,
				col_end = HIGHLIGHT_TO_END_OF_LINE,
				hl_group = "GHDashboardHeaderBorder",
			})
		elseif vim.startswith(line, border_char) then
			table.insert(highlights, {
				line = line0,
				col_start = BUFFER_START_LINE,
				col_end = border_len,
				hl_group = "GHDashboardHeaderBorder",
			})
			table.insert(highlights, {
				line = line0,
				col_start = border_len,
				col_end = #line - border_len,
				hl_group = "GHDashboardHeaderTitle",
			})
			table.insert(highlights, {
				line = line0,
				col_start = #line - border_len,
				col_end = HIGHLIGHT_TO_END_OF_LINE,
				hl_group = "GHDashboardHeaderBorder",
			})
		elseif line:match("^%a+:%s") then
			local _, label_end = line:find("^%a+:%s")
			table.insert(highlights, {
				line = line0,
				col_start = BUFFER_START_LINE,
				col_end = label_end,
				hl_group = "GHDashboardHeaderLabel",
			})
			table.insert(highlights, {
				line = line0,
				col_start = label_end,
				col_end = HIGHLIGHT_TO_END_OF_LINE,
				hl_group = "GHDashboardHeaderValue",
			})
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
---@param col_offset number|number[]|nil defaults to 0. Either a single offset
---applied to every highlight, or an array indexed by `highlight.line + 1`
---(each source line can be padded independently when centering per-line).
function M.apply_highlights(buf_id, highlights, line_offset, col_offset)
	if not vim.api.nvim_buf_is_valid(buf_id) then
		return
	end

	line_offset = line_offset or BUFFER_START_LINE
	col_offset = col_offset or BUFFER_START_LINE

	for _, highlight in ipairs(highlights) do
		local pad = type(col_offset) == "table" and (col_offset[highlight.line + FIRST_LUA_INDEX] or BUFFER_START_LINE)
			or col_offset
		local col_start = (highlight.col_start or highlight.col) + pad
		local col_end = highlight.col_end or (col_start + NEXT_LINE_OFFSET)
		if col_end ~= HIGHLIGHT_TO_END_OF_LINE then
			col_end = col_end + pad
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

	-- Disable gutters (number/sign/fold columns). These are window-local and
	-- independent from the user's global config; if left enabled they eat
	-- into the window's left edge while `nvim_win_get_width` still reports
	-- the *full* window width, so horizontal-centering math would treat
	-- gutter columns as usable text space and shift the centered content a
	-- few columns to the right of where it visually should be.
	vim.wo.number = false
	vim.wo.relativenumber = false
	vim.wo.signcolumn = "no"
	vim.wo.foldcolumn = "0"
	vim.wo.list = false

	vim.bo.modifiable = false
	vim.bo.readonly = true

	return buf_id
end

---Starts an animated Braille spinner on the given line of the buffer.
---@param buf_id number
---@param line_idx number 0-based line index to animate
---@param message string|nil Message to show next to the spinner
---@param col_offset number|nil Leading spaces to prepend to each frame, defaults to 0
---@return uv.uv_timer_t timer Timer handle; call `M.stop_spinner(timer)` to stop it
function M.start_spinner(buf_id, line_idx, message, col_offset)
	return Spinner.start(buf_id, line_idx, message, col_offset)
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
		vim.api.nvim_buf_set_lines(buf_id, BUFFER_START_LINE, END_OF_BUFFER, false, {
			"Failed to load GitHub dashboard:",
			"",
			message,
		})
	end)
end

---Loads the personal Copilot usage panel into its reserved dashboard section.
---@param buf_id number
---@param chars table Characters configuration
---@param panel_line_idx number 0-based separator line index
function M.load_ai_usage(buf_id, chars, panel_line_idx)
	local billing_period = os.date("*t")
	local spinner_line_idx
	local spinner_timer
	GithubService.fetch_ai_usage(billing_period.year, billing_period.month, function()
		if not vim.api.nvim_buf_is_valid(buf_id) then
			return
		end

		spinner_line_idx = panel_line_idx + NEXT_LINE_OFFSET
		local spinner_message = "Loading AI usage..."
		local spinner_pad = pad_for_width(
			vim.api.nvim_win_get_width(CURRENT_WINDOW_ID),
			vim.fn.strdisplaywidth(Spinner.spinner_frames[FIRST_LUA_INDEX] .. " " .. spinner_message)
		)
		buffer_helpers.with_modifiable_buffer(buf_id, function()
			vim.api.nvim_buf_set_lines(
				buf_id,
				spinner_line_idx,
				spinner_line_idx + ai_usage_height,
				false,
				vim.fn["repeat"]({ "" }, ai_usage_height)
			)
		end)
		spinner_timer = M.start_spinner(buf_id, spinner_line_idx, spinner_message, spinner_pad)
	end, function(usage)
		M.stop_spinner(spinner_timer)
		if not vim.api.nvim_buf_is_valid(buf_id) then
			return
		end

		local ai_usage_graph = AiUsageGraph.new(usage, chars)
		local ai_usage_lines = ai_usage_graph:get_lines()
		local ai_usage_pad = pad_for_width(vim.api.nvim_win_get_width(CURRENT_WINDOW_ID), max_width(ai_usage_lines))
		local ai_usage_pads = {}
		for i = FIRST_LUA_INDEX, #ai_usage_lines do
			ai_usage_pads[i] = ai_usage_pad
		end

		buffer_helpers.with_modifiable_buffer(buf_id, function()
			vim.api.nvim_buf_set_lines(
				buf_id,
				spinner_line_idx,
				spinner_line_idx + ai_usage_height,
				false,
				apply_horizontal_padding(ai_usage_lines, ai_usage_pads)
			)
		end)
		M.apply_highlights(buf_id, ai_usage_graph:get_highlights(), spinner_line_idx, ai_usage_pads)
	end, function()
		M.stop_spinner(spinner_timer)
		if not vim.api.nvim_buf_is_valid(buf_id) or not spinner_line_idx then
			return
		end

		local message = "Unable to load AI usage."
		local message_pad = pad_for_line(vim.api.nvim_win_get_width(CURRENT_WINDOW_ID), message)
		buffer_helpers.with_modifiable_buffer(buf_id, function()
			vim.api.nvim_buf_set_lines(
				buf_id,
				spinner_line_idx,
				spinner_line_idx + ai_usage_height,
				false,
				{ string.rep(" ", message_pad) .. message, "", "", "" }
			)
		end)
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

	local activity_graph = ActivityGraph.new(activities, year, chars)
	local activity_graph_lines = activity_graph:get_lines()
	local win_width = vim.api.nvim_win_get_width(CURRENT_WINDOW_ID)
	local win_height = vim.api.nvim_win_get_height(CURRENT_WINDOW_ID)
	local ai_panel_line_idx = math.max(
		BUFFER_START_LINE,
		win_height - ai_usage_height - bottom_empty_lines - AI_PANEL_SEPARATOR_OFFSET_FROM_BOTTOM
	)
	local header_lines = M.create_header(year, username, win_width)

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
	table.insert(dashboard_lines, "")

	-- Center everything horizontally relative to the full window width, and
	-- the whole block vertically. Header lines (title/frame, "User: ...",
	-- "Year: ...") vary a lot in width, so each is centered independently -
	-- otherwise shorter lines like "User: ..."/"Year: ..." end up merely
	-- left-aligned to the frame's left edge instead of centered on screen.
	-- The two graphs are centered as a block (same padding for every row)
	-- so their internal grid/bar columns stay aligned with each other.
	local header_pads = {}
	for i, line in ipairs(header_lines) do
		header_pads[i] = pad_for_line(win_width, line)
	end

	local contributions_pad = pad_for_width(win_width, max_width(contributions_graph_lines))
	local contributions_pads = {}
	for i = FIRST_LUA_INDEX, #contributions_graph_lines do
		contributions_pads[i] = contributions_pad
	end

	local activity_pad = pad_for_width(win_width, max_width(activity_graph_lines))
	local activity_pads = {}
	for i = FIRST_LUA_INDEX, #activity_graph_lines do
		activity_pads[i] = activity_pad
	end

	local dashboard_pads = {}
	for i = FIRST_LUA_INDEX, #header_lines do
		dashboard_pads[i] = header_pads[i]
	end
	for i = FIRST_LUA_INDEX, #contributions_graph_lines do
		dashboard_pads[#header_lines + i] = contributions_pads[i]
	end
	dashboard_pads[#header_lines + #contributions_graph_lines + NEXT_LINE_OFFSET] = BUFFER_START_LINE
	for i = FIRST_LUA_INDEX, #activity_graph_lines do
		dashboard_pads[#header_lines + #contributions_graph_lines + NEXT_LINE_OFFSET + i] = activity_pads[i]
	end
	dashboard_pads[#dashboard_lines] = BUFFER_START_LINE

	local vertical_pad = top_empty_lines + vertical_pad_for(ai_panel_line_idx, #dashboard_lines)

	local centered_lines = {}
	for _ = FIRST_LUA_INDEX, vertical_pad do
		table.insert(centered_lines, "")
	end
	for _, line in ipairs(apply_horizontal_padding(dashboard_lines, dashboard_pads)) do
		table.insert(centered_lines, line)
	end
	ai_panel_line_idx = math.max(ai_panel_line_idx, #centered_lines)
	append_ai_panel(centered_lines, ai_panel_line_idx, win_width)

	buffer_helpers.with_modifiable_buffer(buf_id, function()
		vim.api.nvim_buf_set_lines(buf_id, BUFFER_START_LINE, END_OF_BUFFER, false, centered_lines)
	end)

	vim.api.nvim_buf_clear_namespace(buf_id, M.namespace, BUFFER_START_LINE, END_OF_BUFFER)
	M.apply_highlights(buf_id, M.get_header_highlights(header_lines), vertical_pad, header_pads)
	M.apply_highlights(buf_id, contributions_graph:get_highlights(), vertical_pad + #header_lines, contributions_pads)
	M.apply_highlights(
		buf_id,
		activity_graph:get_highlights(),
		vertical_pad + #header_lines + contributions_graph.height + NEXT_LINE_OFFSET,
		activity_pads
	)
	M.apply_highlights(buf_id, {
		{
			line = BUFFER_START_LINE,
			col_start = BUFFER_START_LINE,
			col_end = HIGHLIGHT_TO_END_OF_LINE,
			hl_group = "GHDashboardSeparator",
		},
	}, ai_panel_line_idx)

	-- Set up cursor position tracking (need to adjust height calculation)
	local total_height = vertical_pad + #header_lines + contributions_graph.height + activity_graph.height
	M.setup_cursor_tracking(buf_id, contributions_graph, activity_graph, total_height, contributions_pad)

	local ai_usage_requested = false
	local function request_ai_usage()
		if ai_usage_requested then
			return
		end
		ai_usage_requested = true
		M.load_ai_usage(buf_id, chars, ai_panel_line_idx)
	end

	vim.keymap.set("n", "A", request_ai_usage, {
		buffer = buf_id,
		desc = "Load GitHub Copilot AI usage",
		nowait = true,
	})
	vim.keymap.set("n", "<CR>", function()
		local current_line = vim.api.nvim_get_current_line()
		local button_start = current_line:find("[A]", FIRST_LUA_INDEX, true)
		local cursor_col = vim.api.nvim_win_get_cursor(CURRENT_WINDOW_ID)[CURSOR_COLUMN_INDEX]
		if
			button_start
			and cursor_col >= button_start - FIRST_LUA_INDEX
			and cursor_col < button_start - FIRST_LUA_INDEX + #"[A]"
		then
			request_ai_usage()
			return ""
		end

		return "<CR>"
	end, {
		buffer = buf_id,
		expr = true,
		desc = "Load GitHub Copilot AI usage",
		nowait = true,
	})
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

	-- Center the header on screen immediately, the same way `render_dashboard`
	-- centers the final content, so the dashboard doesn't briefly appear in
	-- the top-left corner while data is still being fetched.
	local win_width = vim.api.nvim_win_get_width(CURRENT_WINDOW_ID)
	local win_height = vim.api.nvim_win_get_height(CURRENT_WINDOW_ID)
	local ai_panel_line_idx = math.max(
		BUFFER_START_LINE,
		win_height - ai_usage_height - bottom_empty_lines - AI_PANEL_SEPARATOR_OFFSET_FROM_BOTTOM
	)
	local header_lines = M.create_header(year, username, win_width)

	local header_pads = {}
	for i, line in ipairs(header_lines) do
		header_pads[i] = pad_for_line(win_width, line)
	end

	local vertical_pad = top_empty_lines + vertical_pad_for(ai_panel_line_idx, #header_lines)

	local centered_lines = {}
	for _ = FIRST_LUA_INDEX, vertical_pad do
		table.insert(centered_lines, "")
	end
	for _, line in ipairs(apply_horizontal_padding(header_lines, header_pads)) do
		table.insert(centered_lines, line)
	end
	append_ai_panel(centered_lines, ai_panel_line_idx, win_width)

	buffer_helpers.with_modifiable_buffer(buf_id, function()
		vim.api.nvim_buf_set_lines(buf_id, BUFFER_START_LINE, END_OF_BUFFER, false, centered_lines)
	end)
	M.apply_highlights(buf_id, M.get_header_highlights(header_lines), vertical_pad, header_pads)
	M.apply_highlights(buf_id, {
		{
			line = BUFFER_START_LINE,
			col_start = BUFFER_START_LINE,
			col_end = HIGHLIGHT_TO_END_OF_LINE,
			hl_group = "GHDashboardSeparator",
		},
	}, ai_panel_line_idx)

	-- The header already ends with a blank line; use it to host the spinner
	local spinner_line_idx = vertical_pad + #header_lines - NEXT_LINE_OFFSET
	local spinner_message = "Loading GitHub dashboard..."
	local spinner_col_offset = pad_for_width(
		win_width,
		vim.fn.strdisplaywidth(Spinner.spinner_frames[FIRST_LUA_INDEX] .. " " .. spinner_message)
	)
	local timer = M.start_spinner(buf_id, spinner_line_idx, spinner_message, spinner_col_offset)

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
	CursorTracking.update_contribution_details(
		buf_id,
		contributions_graph,
		activity_graph,
		total_height,
		horizontal_pad
	)
end

return M
