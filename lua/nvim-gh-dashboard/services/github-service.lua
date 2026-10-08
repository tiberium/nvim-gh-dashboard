local M = {}

local GithubClient = require("nvim-gh-dashboard.clients.github-client")
local GithubProfile = require("nvim-gh-dashboard.extractors.github-profile")
local GithubAchievements = require("nvim-gh-dashboard.extractors.github-achievements")
local GithubAiUsage = require("nvim-gh-dashboard.extractors.github-ai-usage")

---@class DashboardData
---@field contributions ContributionMetadata[]
---@field activity ActivityMetadata|nil
---@field profile_details ProfileDetails|nil
---@field repositories RepositoryMetadata[]

---@param contributions_html string
---@param profile_html string
---@return DashboardData
local function dashboard_data(contributions_html, profile_html)
	return {
		contributions = GithubProfile.extract_contributions(contributions_html),
		activity = GithubProfile.extract_activity(contributions_html),
		profile_details = GithubProfile.extract_profile_details(profile_html),
		repositories = GithubProfile.extract_repositories(profile_html),
	}
end

---@param details_url string
---@param on_success fun(details: { description: string|nil, unlocked_at: string|nil })
---@param on_error fun(message: string)
function M.fetch_achievement_details(details_url, on_success, on_error)
	GithubClient.fetch_achievement_details_page(details_url, function(html)
		on_success(GithubAchievements.extract_details(html))
	end, on_error)
end

---@param username string
---@param on_success fun(achievements: AchievementMetadata[])
---@param on_error fun(message: string)
function M.fetch_achievements(username, on_success, on_error)
	GithubClient.fetch_achievements_page(username, function(html)
		vim.schedule(function()
			on_success(GithubAchievements.extract_achievements(html))
		end)
	end, on_error)
end

---@param username string
---@param year number|nil
---@param use_cache boolean|nil
---@param on_success fun(data: DashboardData)
---@param on_error fun(message: string)
function M.fetch_dashboard_data(username, year, use_cache, on_success, on_error)
	GithubClient.fetch_dashboard_pages(username, year, use_cache, function(contributions_html, profile_html)
		on_success(dashboard_data(contributions_html, profile_html))
	end, on_error)
end

---@param year number
---@param month number
---@param on_loading fun()
---@param on_success fun(usage: AiUsageData)
---@param on_error fun()
function M.fetch_ai_usage(year, month, on_loading, on_success, on_error)
	GithubClient.fetch_ai_usage(year, month, on_loading, function(quota_response, usage_response)
		local usage = GithubAiUsage.extract_usage(quota_response, usage_response)
		if usage then
			on_success(usage)
		else
			on_error()
		end
	end, on_error)
end

return M
