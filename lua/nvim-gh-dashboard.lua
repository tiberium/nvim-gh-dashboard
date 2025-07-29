local M = {}

local GithubService = require("github-service")
local Contribution = require("contribution")
local DashboardView = require("dashboard-view")

---Function to setup the plugin
function M.setup()
    -- TODO: Parameterize the year
    local year = 2024

    local contributions_metadata = GithubService.fetch_contributions("tiberium", year)

    if not contributions_metadata then
        print("Failed to fetch contributions.")
        return
    end

    local contributions = {}
    for _, contribution_metadata in ipairs(contributions_metadata) do
        local contribution = Contribution.new(contribution_metadata)

        table.insert(contributions, contribution)
    end

    DashboardView.create_dashboard(contributions, year)
end

return M
