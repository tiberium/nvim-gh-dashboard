local M = {}

local gh = require("gh")
local GitHubContribution = require("github_contrubution")
local dashboardView = require("dashboard-view")

---Function to setup the plugin
function M.setup()
    -- TODO: Parameterize the year
    local year = 2024

    local contributions_metadata = gh.fetch_contributions("tiberium", year)

    if not contributions_metadata then
        print("Failed to fetch contributions.")
        return
    end

    local contributions = {}
    for _, contribution_metadata in ipairs(contributions_metadata) do
        local contribution = GitHubContribution.new(contribution_metadata)

        table.insert(contributions, contribution)
    end

    dashboardView.create_dashboard(contributions, year)
end

return M
