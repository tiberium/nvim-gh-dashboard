local M = {}

local GithubService = require("github-service")
local Contribution = require("contribution")
local DashboardView = require("dashboard-view")

---Function to setup the plugin
---@param opts table|nil Configuration options
---@field opts.year number|nil Year to fetch contributions for (defaults to current year)
---@field opts.username string|nil GitHub username (defaults to "torvalds")
---@field opts.chars table|nil Characters used in the graph
---@field opts.chars.filled string|nil Character for days with contributions (default: "#")
---@field opts.chars.high string|nil Character for days with 10+ contributions (default: "@")
---@field opts.chars.empty string|nil Character for days with no contributions (default: ".")
function M.setup(opts)
    opts = opts or {}

    -- Set defaults
    local year = opts.year or tonumber(os.date("%Y"))
    local username = opts.username or "torvalds"
    local chars = opts.chars or { filled = "#", high = "@", empty = "." }

    local contributions_metadata = GithubService.fetch_contributions(username, year)

    if not contributions_metadata then
        print("Failed to fetch contributions.")
        return
    end

    local contributions = {}
    for _, contribution_metadata in ipairs(contributions_metadata) do
        local contribution = Contribution.new(contribution_metadata)

        table.insert(contributions, contribution)
    end

    DashboardView.create_dashboard(contributions, year, username, chars)
end

return M
