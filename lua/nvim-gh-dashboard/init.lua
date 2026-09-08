local M = {}

local DashboardView = require("nvim-gh-dashboard.dashboard-view")

---Function to setup the plugin
---@param opts table|nil Configuration options
---@field opts.year number|nil Year to fetch contributions for (defaults to current year)
---@field opts.username string|nil GitHub username (defaults to "torvalds")
---@field opts.chars table|nil Characters used in the graph
---@field opts.chars.filled string|nil Character for days with contributions (default: "#")
---@field opts.chars.high string|nil Character for days with the highest single-day contribution count (default: "@")
---@field opts.chars.empty string|nil Character for days with no contributions (default: ".")
function M.setup(opts)
	opts = opts or {}

	-- Set defaults
	local year = opts.year or tonumber(os.date("%Y"))
	local username = opts.username or "torvalds"
	local chars = opts.chars or { filled = "#", high = "@", empty = "." }

	DashboardView.open_dashboard(username, year, chars)
end

return M
