local M = {}

local DashboardView = require("nvim-gh-dashboard.dashboard-view")
local Colors = require("nvim-gh-dashboard.colors")

---@param opts table|nil Configuration options
---@return number year
---@return string username
---@return table chars
local function dashboard_options(opts)
	opts = opts or {}

	vim.validate({
		opts = { opts, "table" },
		year = { opts.year, "number", true },
		username = { opts.username, "string", true },
		chars = { opts.chars, "table", true },
		colors = { opts.colors, "table", true },
	})

	local year = opts.year or tonumber(os.date("%Y"))
	local username = opts.username or "torvalds"
	local chars = opts.chars or { filled = "#", high = "@", empty = "." }

	return year, username, chars
end

---Opens the dashboard using the provided configuration.
---@param opts table|nil Configuration options
function M.open_dashboard(opts)
	local year, username, chars = dashboard_options(opts)
	Colors.setup(opts and opts.colors)
	DashboardView.open_dashboard(username, year, chars)
end

---Configures and opens the dashboard unless Neovim was started with a file.
---@param opts table|nil Configuration options
function M.setup(opts)
	local year, username, chars = dashboard_options(opts)
	Colors.setup(opts and opts.colors)

	if vim.fn.argc() == 0 then
		DashboardView.open_dashboard(username, year, chars)
	end
end

return M
