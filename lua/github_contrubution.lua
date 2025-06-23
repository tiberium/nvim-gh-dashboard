local GitHubContribution = {}
GitHubContribution.__index = GitHubContribution

---@class GitHubContribution
---@field counter string -- format: <number>[+]
---@field month string -- format: <month> (e.g. "January", "February", ...)
---@field day string -- format: <day> (e.g. "1", "2", ..., "31")
---@field tooltip string -- format: `<couter | No> contribution|s on <month> <day>.`
---@field weekday_number number -- 0 - 6 (0 = Sunday, 1 = Monday, ..., 6 = Saturday) as GitHub codes
---@field week_number number -- week number of the year (0 - 52)

---@param metadata ContributionMetadata
---@return GitHubContribution | nil
function GitHubContribution.new(metadata --[[@as ContributionMetadata]])
    local self = setmetatable({}, GitHubContribution)
    if metadata == nil then
        return nil
    end

    self.tooltip = metadata.tooltip

    self.weekday_number = tonumber(metadata.day)
    self.week_number = tonumber(metadata.week)

    -- unpack contribution
    local pattern = "(%d+[%+]?) contribution[s]? on (%a+) (%w+)%."
    local contribution_raw_fixed = self.tooltip:gsub("^No%s", "0 ")
    local counter, month, day = contribution_raw_fixed:match(pattern)

    -- validate unpacked values
    if not counter or not month or not day then
        print("Invalid contribution format: " .. metadata.tooltip)
        return nil
    end

    self.counter = counter
    self.month = month
    self.day = day

    return self
end

return GitHubContribution
