local M = {}

local DashboardView = require("nvim-gh-dashboard.dashboard-view")
local Colors = require("nvim-gh-dashboard.colors")

---Function to setup the plugin
---@param opts table|nil Configuration options
---@field opts.year number|nil Year to fetch contributions for (defaults to current year)
---@field opts.username string|nil GitHub username (defaults to "torvalds")
---@field opts.chars table|nil Characters used in the graph
---@field opts.chars.filled string|nil Character for days with contributions (default: "#")
---@field opts.chars.high string|nil Character for days with the highest single-day contribution count (default: "@")
---@field opts.chars.empty string|nil Character for days with no contributions (default: ".")
---@field opts.colors table|nil Highlight group overrides, keyed by highlight group name (see `:h nvim_set_hl`
---for the accepted shape, e.g. `{ fg = "#ff0000" }` or `{ link = "MyGroup" }`). Colors default to groups
---already defined by the active colorscheme; see README.md for the full list of highlight groups.
function M.setup(opts)
	opts = opts or {}

	vim.validate({
		opts = { opts, "table" },
		year = { opts.year, "number", true },
		username = { opts.username, "string", true },
		chars = { opts.chars, "table", true },
		colors = { opts.colors, "table", true },
	})

	-- Set defaults
	local year = opts.year or tonumber(os.date("%Y"))
	local username = opts.username or "torvalds"
	local chars = opts.chars or { filled = "#", high = "@", empty = "." }

	Colors.setup(opts.colors)

	DashboardView.open_dashboard(username, year, chars)
end

return M
