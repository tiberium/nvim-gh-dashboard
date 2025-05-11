local M = {}

local ContributionMetadata = {}
ContributionMetadata.__index = ContributionMetadata

---@class ContributionMetadata
---@field day string
---@field week string
---@field contribution_tooltip string

---@param day string
---@param week string
---@param contribution_tooltip string
function ContributionMetadata.new(day, week, contribution_tooltip)
    local self = setmetatable({}, ContributionMetadata)
    self.day = day
    self.week = week
    self.contribution_tooltip = contribution_tooltip
    return self
end

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

    -- -- Write response to a file for debugging
    -- local file = io.open("response.html", "w")
    -- if not file then
    --     error("Could not open file for writing")
    -- end
    -- file:write(response.body)
    -- file:close()

    local contributions_matcher =
    '<tool%-tip.-for="contribution%-day%-component%-(%d+)%-([%d]+)".->(.-contribution[s]? on.-)</tool%-tip>'
    local contributions = response.body:gmatch(contributions_matcher)

    local contributions_list = {}
    for day, week, contribution in contributions do
        table.insert(contributions_list, ContributionMetadata.new(day, week, contribution))
    end
    return contributions_list
end

return M
