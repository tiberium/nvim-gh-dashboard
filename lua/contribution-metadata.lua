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

return ContributionMetadata
