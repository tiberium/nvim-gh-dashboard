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

-- Possibly we can commend that out
M.ContributionMetadata = ContributionMetadata


local ActivityMetadata = {}
ActivityMetadata.__index = ActivityMetadata

---@class ActivityMetadata
---@field code_review number
---@field commits number
---@field pull_requests number
---@field issues number

---@param commits string
---@param code_review string
---@param pull_requests string
---@param issues string
function ActivityMetadata.new(commits, code_review, pull_requests, issues)
    local self = setmetatable({}, ActivityMetadata)

    self.commits = commits
    self.code_review = code_review
    self.pull_requests = pull_requests
    self.issues = issues

    return self
end

M.ActivityMetadata = ActivityMetadata

-- Cache for the main GitHub user page content (request.body)
local cached_gh_main_page = {
    username = nil,
    year = nil,
    html = nil
}

---@param username string GitHub username
---@param year number|nil Year to fetch contributions for
---@param use_cache boolean|nil Whether to use cached page content
---@return string|nil
local function main_gh_user_page(username, year, use_cache)
    local caching = use_cache or false

    if caching and cached_gh_main_page.html ~= nil and cached_gh_main_page.username == username and cached_gh_main_page.year == year then
        return cached_gh_main_page.html
    end

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

    return response.body
end

---@param username string GitHub username
---@param year number|nil Year to fetch contributions for
---@param use_cache boolean Flag indicating if the user's main gh page should be refetched
---@return ContributionMetadata[]|nil
function M.fetch_contributions(username, year, use_cache)
    local user_page = main_gh_user_page(username, year, use_cache)

    if not user_page then
        vim.notify("Failed to fetch user page for contributions.", vim.log.levels.ERROR)
        return nil
    end

    local contributions_matcher =
    '<tool%-tip.-for="contribution%-day%-component%-(%d+)%-([%d]+)".->(.-contribution[s]? on.-)</tool%-tip>'
    local contributions = user_page:gmatch(contributions_matcher)

    local contributions_list = {}
    for day, week, tooltip in contributions do
        table.insert(contributions_list, ContributionMetadata.new(day, week, tooltip))
    end
    return contributions_list
end

---@param username string GitHub username
---@param year number|nil Year to fetch contributions for
---@param use_cache boolean Flag indicating if the user's main gh page should be refetched
---@return ActivityMetadata|nil
function M.fetch_activity(username, year, use_cache)
    local user_page = main_gh_user_page(username, year, use_cache)

    if not user_page then
        vim.notify("Failed to fetch user page for activity.", vim.log.levels.ERROR)
        return nil
    end

    local div_matcher = '<div[^>]-class="js%-activity%-overview%-graph%-container"[^>]-data%-percentages="([^"]+)"'
    local percentages = user_page:match(div_matcher)

    if not percentages then
        return nil
    end

    local commits = percentages:match('&quot;Commits&quot;:(%d+)')
    local code_review = percentages:match('&quot;Code review&quot;:(%d+)')
    local pull_requests = percentages:match('&quot;Pull requests&quot;:(%d+)')
    local issues = percentages:match('&quot;Issues&quot;:(%d+)')

    if not commits or not code_review or not pull_requests or not issues then
        vim.notify("Failed to fetch activity data...", vim.log.levels.ERROR)
        return nil
    end

    return ActivityMetadata.new(commits, code_review, pull_requests, issues)
end

return M
