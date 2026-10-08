local M = {}

local HTTP_OK_STATUS = 200
local DECEMBER = 12
local FIRST_DAY_OF_MONTH = 1
local SUCCESS_EXIT_CODE = 0
local JOB_START_FAILURE_MAX_ID = 0
local EXECUTABLE_RESULT = 1
local GITHUB_BASE_URL = "https://github.com"
local HOVERCARD_REQUEST_HEADERS = {
	Accept = "text/html",
	["X-Requested-With"] = "XMLHttpRequest",
	["User-Agent"] = "Mozilla/5.0",
}

local cached_dashboard_pages = {
	username = nil,
	year = nil,
	contributions_html = nil,
	profile_html = nil,
}

---@param username string
---@param year number|nil
---@return string
local function contributions_url(username, year)
	local url = string.format("%s/%s?tab=contributions", GITHUB_BASE_URL, username)
	if year then
		url = url .. "&from=" .. year .. string.format("-%02d-%02d", DECEMBER, FIRST_DAY_OF_MONTH)
	end
	return url
end

---@param username string
---@return string
local function profile_url(username)
	return string.format("%s/%s", GITHUB_BASE_URL, username)
end

---@param username string
---@return string
local function achievements_url(username)
	return string.format("%s/%s?tab=achievements", GITHUB_BASE_URL, username)
end

---@param err table|nil
---@return string
local function error_message(err)
	return err and err.message or "unknown error"
end

---@param url string
---@param options table
---@param failure_prefix string
---@param on_success fun(body: string)
---@param on_error fun(message: string)
local function fetch_html(url, options, failure_prefix, on_success, on_error)
	local curl = require("plenary.curl")
	curl.get(url, {
		headers = options.headers,
		callback = vim.schedule_wrap(function(response)
			if response.status ~= HTTP_OK_STATUS then
				on_error(string.format("%s (status %s).", failure_prefix, tostring(response.status)))
				return
			end
			on_success(response.body)
		end),
		on_error = vim.schedule_wrap(function(err)
			on_error(failure_prefix .. ": " .. error_message(err))
		end),
	})
end

---@param username string
---@param year number|nil
---@param use_cache boolean|nil
---@param on_success fun(contributions_html: string, profile_html: string)
---@param on_error fun(message: string)
function M.fetch_dashboard_pages(username, year, use_cache, on_success, on_error)
	if
		use_cache
		and cached_dashboard_pages.username == username
		and cached_dashboard_pages.year == year
		and cached_dashboard_pages.contributions_html
		and cached_dashboard_pages.profile_html
	then
		on_success(cached_dashboard_pages.contributions_html, cached_dashboard_pages.profile_html)
		return
	end

	local contributions_html
	local profile_html
	local completed = false

	local function fail(message)
		if completed then
			return
		end
		completed = true
		on_error(message)
	end

	local function finish()
		if completed or not contributions_html or not profile_html then
			return
		end
		completed = true
		cached_dashboard_pages = {
			username = username,
			year = year,
			contributions_html = contributions_html,
			profile_html = profile_html,
		}
		on_success(contributions_html, profile_html)
	end

	fetch_html(
		contributions_url(username, year),
		{ headers = { ["x-requested-with"] = "XMLHttpRequest" } },
		"Failed to fetch GitHub contributions",
		function(body)
			contributions_html = body
			finish()
		end,
		fail
	)
	fetch_html(profile_url(username), {}, "Failed to fetch GitHub profile", function(body)
		profile_html = body
		finish()
	end, fail)
end

---@param username string
---@param on_success fun(html: string)
---@param on_error fun(message: string)
function M.fetch_achievements_page(username, on_success, on_error)
	fetch_html(achievements_url(username), {}, "Failed to fetch GitHub achievements", on_success, on_error)
end

---@param details_url string
---@param on_success fun(html: string)
---@param on_error fun(message: string)
function M.fetch_achievement_details_page(details_url, on_success, on_error)
	fetch_html(
		details_url,
		{ headers = HOVERCARD_REQUEST_HEADERS },
		"Failed to fetch achievement details",
		on_success,
		on_error
	)
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

---@param year number
---@param month number
---@param on_loading fun()
---@param on_success fun(quota_response: table, usage_response: table)
---@param on_error fun()
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
				on_success(quota_response, usage_response)
			end, on_error)
		end, on_error)
	end, function() end)
end

return M
