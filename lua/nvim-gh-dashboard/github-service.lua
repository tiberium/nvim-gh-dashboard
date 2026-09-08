local M = {}

local ContributionMetadata = require("contribution-metadata")
local ActivityMetadata = require("activity-metadata")

---@class DashboardData
---@field contributions ContributionMetadata[]
---@field activity ActivityMetadata|nil

-- Cache for the main GitHub user page content (request.body)
local cached_gh_main_page = {
	username = nil,
	year = nil,
	html = nil,
}

---@param username string GitHub username
---@param year number|nil Year to fetch contributions for
---@return string url
local function build_url(username, year)
	local url = string.format("https://github.com/%s?tab=contributions", username)

	if year then
		-- Yes, GitHub uses be default the last month of the year to select the year...
		url = url .. "&from=" .. year .. "-12-01"
	end

	return url
end

---@param user_page string HTML of the GitHub user page
---@return ContributionMetadata[]
local function parse_contributions(user_page)
	local contributions_matcher =
		'<tool%-tip.-for="contribution%-day%-component%-(%d+)%-([%d]+)".->(.-contribution[s]? on.-)</tool%-tip>'
	local contributions = user_page:gmatch(contributions_matcher)

	local contributions_list = {}
	for day, week, tooltip in contributions do
		table.insert(contributions_list, ContributionMetadata.new(day, week, tooltip))
	end
	return contributions_list
end

---@param user_page string HTML of the GitHub user page
---@return ActivityMetadata|nil
local function parse_activity(user_page)
	local div_matcher = '<div[^>]-class="js%-activity%-overview%-graph%-container"[^>]-data%-percentages="([^"]+)"'
	local percentages = user_page:match(div_matcher)

	if not percentages then
		return nil
	end

	local commits = percentages:match("&quot;Commits&quot;:(%d+)")
	local code_review = percentages:match("&quot;Code review&quot;:(%d+)")
	local pull_requests = percentages:match("&quot;Pull requests&quot;:(%d+)")
	local issues = percentages:match("&quot;Issues&quot;:(%d+)")

	if not commits or not code_review or not pull_requests or not issues then
		return nil
	end

	return ActivityMetadata.new(commits, code_review, pull_requests, issues)
end

---@param user_page string HTML of the GitHub user page
---@return DashboardData
local function parse_dashboard_data(user_page)
	return {
		contributions = parse_contributions(user_page),
		activity = parse_activity(user_page),
	}
end

M.parse_contributions = parse_contributions
M.parse_activity = parse_activity
M.parse_dashboard_data = parse_dashboard_data

---Fetches the GitHub user page once, asynchronously, and parses both contributions
---and activity out of the same response. `on_success`/`on_error` are always invoked
---on the main event loop (via `vim.schedule_wrap`), so it is safe to touch buffers,
---windows or other UI state from them.
---@param username string GitHub username
---@param year number|nil Year to fetch contributions for
---@param use_cache boolean|nil Whether to use cached page content
---@param on_success fun(data: DashboardData) Called with the parsed dashboard data
---@param on_error fun(message: string) Called with an error message on failure
function M.fetch_dashboard_data(username, year, use_cache, on_success, on_error)
	local caching = use_cache or false

	if
		caching
		and cached_gh_main_page.html ~= nil
		and cached_gh_main_page.username == username
		and cached_gh_main_page.year == year
	then
		on_success(parse_dashboard_data(cached_gh_main_page.html))
		return
	end

	local curl = require("plenary.curl")
	local url = build_url(username, year)

	curl.get(url, {
		headers = {
			["x-requested-with"] = "XMLHttpRequest",
		},
		callback = vim.schedule_wrap(function(response)
			if response.status ~= 200 then
				on_error(string.format("Failed to fetch GitHub page (status %s).", tostring(response.status)))
				return
			end

			cached_gh_main_page = {
				username = username,
				year = year,
				html = response.body,
			}

			on_success(parse_dashboard_data(response.body))
		end),
		on_error = vim.schedule_wrap(function(err)
			on_error("Failed to fetch GitHub page: " .. (err and err.message or "unknown error"))
		end),
	})
end

return M
