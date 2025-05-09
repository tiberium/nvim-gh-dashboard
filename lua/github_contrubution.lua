local GitHubContribution = {}
GitHubContribution.__index = GitHubContribution

---@class GitHubContribution
---@field month string
---@field day string
---@field counter string

---@param contribution_raw string format: `<couter | No> contribution|s on <month> <day>.`
---@return GitHubContribution | nil
function GitHubContribution.new(contribution_raw)
    local self = setmetatable({}, GitHubContribution)
    if contribution_raw == nil then
        return nil
    end

    -- unpack contribution
    local pattern = "(%d+[%+]?) contribution[s]? on (%a+) (%w+)%."
    local contribution_raw_fixed = contribution_raw:gsub("^No%s", "0 ")
    local counter, month, day = contribution_raw_fixed:match(pattern)

    -- validate unpacked values
    if not counter or not month or not day then
        print("Invalid contribution format: " .. contribution_raw)
        return nil
    end

    self.counter = tonumber(counter)
    self.month = month
    self.day = day

    return self
end

return GitHubContribution
