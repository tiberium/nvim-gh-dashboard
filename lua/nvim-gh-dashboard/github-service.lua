local M = {}

local ContributionMetadata = require("nvim-gh-dashboard.contribution-metadata")
local ActivityMetadata = require("nvim-gh-dashboard.activity-metadata")

local HTTP_OK_STATUS = 200
local DECEMBER = 12
local FIRST_DAY_OF_MONTH = 1
local SUCCESS_EXIT_CODE = 0
local JOB_START_FAILURE_MAX_ID = 0
local EXECUTABLE_RESULT = 1
local ZERO_CREDITS = 0

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
		url = url .. "&from=" .. year .. string.format("-%02d-%02d", DECEMBER, FIRST_DAY_OF_MONTH)
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
			if response.status ~= HTTP_OK_STATUS then
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

---@param quota_response table
---@param usage_response table
---@return AiUsageData|nil
function M.parse_ai_usage(quota_response, usage_response)
	local quota = quota_response.quota_snapshots and quota_response.quota_snapshots.premium_interactions
	if not quota then
		return nil
	end

	local additional_credits = ZERO_CREDITS
	local additional_amount = ZERO_CREDITS
	for _, item in ipairs(usage_response.usageItems or {}) do
		additional_credits = additional_credits + (item.netQuantity or ZERO_CREDITS)
		additional_amount = additional_amount + (item.netAmount or ZERO_CREDITS)
	end

	local included_credits = quota.entitlement or ZERO_CREDITS
	return {
		additional_budget_credits = quota.overage_entitlement or ZERO_CREDITS,
		additional_credits = additional_credits,
		additional_amount = additional_amount,
		included_credits = included_credits,
		included_credits_used = math.min(quota.credits_used or ZERO_CREDITS, included_credits),
		over_pool_credits = math.max(ZERO_CREDITS, (quota.credits_used or ZERO_CREDITS) - included_credits),
	}
end

---@param args string[]
---@param on_success fun(response: table)
---@param on_error fun()
local function fetch_gh_json(args, on_success, on_error)
	local output = {}
	local job_id = vim.fn.jobstart(args, {
		on_stdout = function(_, data)
			vim.list_extend(output, data)
		end,
		on_exit = vim.schedule_wrap(function(_, code)
			if code ~= SUCCESS_EXIT_CODE then
				on_error()
				return
			end

			local ok, response = pcall(vim.fn.json_decode, table.concat(output, "\n"))
			if ok then
				on_success(response)
			else
				on_error()
			end
		end),
	})

	if job_id <= JOB_START_FAILURE_MAX_ID then
		on_error()
	end
end

---@param args string[]
---@param on_success fun()
---@param on_error fun()
local function run_gh_command(args, on_success, on_error)
	local job_id = vim.fn.jobstart(args, {
		on_exit = vim.schedule_wrap(function(_, code)
			if code == SUCCESS_EXIT_CODE then
				on_success()
			else
				on_error()
			end
		end),
	})

	if job_id <= JOB_START_FAILURE_MAX_ID then
		on_error()
	end
end

---Fetches personal Copilot usage through the authenticated GitHub CLI. An
---unauthenticated or unavailable CLI simply results in no panel data.
---@param year number
---@param month number
---@param on_loading fun() Called after GitHub CLI authentication succeeds
---@param on_success fun(usage: AiUsageData)
---@param on_error fun() Called after authentication when a usage request fails
function M.fetch_ai_usage(year, month, on_loading, on_success, on_error)
	if vim.fn.executable("gh") ~= EXECUTABLE_RESULT then
		return
	end

	run_gh_command({ "gh", "auth", "status", "--hostname", "github.com" }, function()
		on_loading()
		fetch_gh_json({ "gh", "api", "copilot_internal/user" }, function(quota_response)
			local login = quota_response.login
			if not login then
				on_error()
				return
			end

			fetch_gh_json({
				"gh",
				"api",
				string.format("users/%s/settings/billing/ai_credit/usage?year=%d&month=%d", login, year, month),
			}, function(usage_response)
				local usage = M.parse_ai_usage(quota_response, usage_response)
				if usage then
					on_success(usage)
				else
					on_error()
				end
			end, on_error)
		end, on_error)
	end, function() end)
end

return M
