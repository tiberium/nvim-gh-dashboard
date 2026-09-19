local M = {}

local DashboardView = require("nvim-gh-dashboard.dashboard-view")
local Colors = require("nvim-gh-dashboard.colors")

local NO_FILE_ARGUMENTS = 0
local MAXIMUM_ACHIEVEMENT_CHARACTERS = 10
local DEFAULT_ACHIEVEMENT_CHARS = { "%", "&", "*", "(", "[", "?", "!", "+", "=", "~" }

---@param configured_chars string|nil Comma-separated achievement symbols
---@return string[]
local function achievement_chars(configured_chars)
	if configured_chars == nil then
		return DEFAULT_ACHIEVEMENT_CHARS
	end

	local chars = vim.split(configured_chars, ",", { plain = true, trimempty = true })
	if #chars == 0 or #chars > MAXIMUM_ACHIEVEMENT_CHARACTERS then
		error("achievement_chars must contain between 1 and 10 comma-separated ASCII characters.")
	end

	for _, char in ipairs(chars) do
		local byte = #char == 1 and string.byte(char)
		if not byte or byte < string.byte("!") or byte > string.byte("~") then
			error("achievement_chars must contain only single printable ASCII characters.")
		end
	end

	return chars
end

---@param opts table|nil Configuration options
---@return number year
---@return string username
---@return table chars
---@return string[] achievement_chars
local function dashboard_options(opts)
	opts = opts or {}

	vim.validate({
		opts = { opts, "table" },
		year = { opts.year, "number", true },
		username = { opts.username, "string", true },
		chars = { opts.chars, "table", true },
		achievement_chars = { opts.achievement_chars, "string", true },
		colors = { opts.colors, "table", true },
	})

	local year = opts.year or tonumber(os.date("%Y"))
	local username = opts.username or "torvalds"
	local chars = opts.chars or { filled = "#", high = "@", empty = "." }

	return year, username, chars, achievement_chars(opts.achievement_chars)
end

---Opens the dashboard using the provided configuration.
---@param opts table|nil Configuration options
function M.open_dashboard(opts)
	local year, username, chars, achievement_symbols = dashboard_options(opts)
	Colors.setup(opts and opts.colors)
	DashboardView.open_dashboard(username, year, chars, achievement_symbols)
end

---Configures and opens the dashboard unless Neovim was started with a file.
---@param opts table|nil Configuration options
function M.setup(opts)
	local year, username, chars, achievement_symbols = dashboard_options(opts)
	Colors.setup(opts and opts.colors)

	if vim.fn.argc() == NO_FILE_ARGUMENTS then
		DashboardView.open_dashboard(username, year, chars, achievement_symbols)
	end
end

return M
