local M = {}

local ContributionMetadata = {}
ContributionMetadata.__index = ContributionMetadata

---@class ContributionMetadata
---@field day string
---@field week string
---@field tooltip string

---@param day string -- 0-6 (0 = Sunday, 1 = Monday, ..., 6 = Saturday) as GitHub codes; row number
---@param week string -- week number of the year (0 - 52); column number
---@param contribution_tooltip string -- format: `<couter | No> contribution|s on <month> <day>.`
function ContributionMetadata.new(day, week, contribution_tooltip)
    local self = setmetatable({}, ContributionMetadata)
    self.day = day
    self.week = week
    self.tooltip = contribution_tooltip
    return self
end

M.ContributionMetadata = ContributionMetadata

---@param username string GitHub username
---@param year number|nil Year to fetch contributions for
---@return ContributionMetadata[]|nil
function M.fetch_contributions(username, year)
    local curl = require("plenary.curl")

    local url = string.format("https://github.com/%s?tab=contributions", username)

    if year then
        -- Yes, GitHub uses be default the last month of the year to select the year...
        url = url .. "&from=" .. year .. "-12-01"
    end

    local response = curl.get(url, {
        headers = {
            ["x-requested-with"] = "XMLHttpRequest",
        }
    })
    if response.status ~= 200 then
        return nil
    end

    local contributions_matcher =
    '<tool%-tip.-for="contribution%-day%-component%-(%d+)%-([%d]+)".->(.-contribution[s]? on.-)</tool%-tip>'
    local contributions = response.body:gmatch(contributions_matcher)

    local contributions_list = {}
    for day, week, tooltip in contributions do
        table.insert(contributions_list, ContributionMetadata.new(day, week, tooltip))
    end
    return contributions_list
end

return M
