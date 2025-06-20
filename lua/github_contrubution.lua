local GitHubContribution = {}
GitHubContribution.__index = GitHubContribution

---@class GitHubContribution
---@field counter string -- format: <number>[+]
---@field month string -- format: <month> (e.g. "January", "February", ...)
---@field day string -- format: <day> (e.g. "1", "2", ..., "31")
---@field raw string format: `<couter | No> contribution|s on <month> <day>.`
---@field weekday_number number 0 - 6 (0 = Sunday, 1 = Monday, ..., 6 = Saturday) as GitHub codes
---@field week_number number week number of the year (0 - 52)

---@param contribution_metadata ContributionMetadata
---@return GitHubContribution | nil
function GitHubContribution.new(contribution_metadata --[[@as ContributionMetadata]])
    local self = setmetatable({}, GitHubContribution)
    if contribution_metadata == nil then
        return nil
    end

    self.raw = contribution_metadata.contribution_tooltip

    self.weekday_number = tonumber(contribution_metadata.day)
    self.week_number = tonumber(contribution_metadata.week)

    -- unpack contribution
    local pattern = "(%d+[%+]?) contribution[s]? on (%a+) (%w+)%."
    local contribution_raw_fixed = self.raw:gsub("^No%s", "0 ")
    local counter, month, day = contribution_raw_fixed:match(pattern)

    -- validate unpacked values
    if not counter or not month or not day then
        print("Invalid contribution format: " .. contribution_metadata)
        return nil
    end

    self.counter = counter
    self.month = month
    self.day = day

    return self
end

return GitHubContribution
