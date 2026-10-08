local M = {}

local ContributionMetadata = require("nvim-gh-dashboard.models.contribution-metadata")
local ActivityMetadata = require("nvim-gh-dashboard.models.activity-metadata")
local ProfileDetails = require("nvim-gh-dashboard.models.profile-details")
local RepositoryMetadata = require("nvim-gh-dashboard.models.repository-metadata")

local FIRST_LUA_INDEX = 1
local POPULAR_REPOSITORIES_HEADING = "Popular repositories"
local OPEN_ORDERED_LIST_TAG = "<ol"
local CLOSE_ORDERED_LIST_TAG = "</ol>"
local REPOSITORY_LIST_ITEM_PATTERN = "<li[^>]*>(.-)</li>"
local LEGACY_REPOSITORY_LIST_ITEM_PATTERN = '<li[^>]-itemprop%s*=%s*["\']owns["][^>]*>(.-)</li>'
local REPOSITORY_NAME_PATTERN = '<span%s+[^>]-class="repo"[^>]*>(.-)</span>'
local DEFAULT_STAR_COUNT = "0"

---@param html string
---@return string
local function plain_text(html)
	return html:gsub("<[^>]->", ""):gsub("&amp;", "&"):gsub("&quot;", '"'):gsub("%s+", " "):match("^%s*(.-)%s*$")
end

---@param html string HTML of GitHub's contribution tab
---@return ContributionMetadata[]
function M.extract_contributions(html)
	local matcher =
		'<tool%-tip.-for="contribution%-day%-component%-(%d+)%-([%d]+)".->(.-contribution[s]? on.-)</tool%-tip>'
	local contributions = {}

	for day, week, tooltip in html:gmatch(matcher) do
		table.insert(contributions, ContributionMetadata.new(day, week, tooltip))
	end

	return contributions
end

---@param html string HTML of GitHub's contribution tab
---@return ActivityMetadata|nil
function M.extract_activity(html)
	local matcher = '<div[^>]-class="js%-activity%-overview%-graph%-container"[^>]-data%-percentages="([^"]+)"'
	local percentages = html:match(matcher)

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

---@param html string HTML of GitHub's profile page
---@return ProfileDetails|nil
function M.extract_profile_details(html)
	local followers, following

	for attributes, content in html:gmatch("<a%s+([^>]-)>(.-)</a>") do
		local tab = attributes:match('[?&]tab=([^"&]+)')
		if tab == "followers" or tab == "following" then
			local count = plain_text(content):match("^([%d%.,]+[kKmM]?)%s+")
			if tab == "followers" then
				followers = count
			else
				following = count
			end
		end
	end

	if not followers or not following then
		return nil
	end

	return ProfileDetails.new(followers, following)
end

---@param html string HTML of GitHub's profile page
---@return RepositoryMetadata[]
function M.extract_repositories(html)
	local repositories = {}
	local popular_repositories_start = html:find(POPULAR_REPOSITORIES_HEADING, FIRST_LUA_INDEX, true)
	local repository_list
	local list_item_pattern = LEGACY_REPOSITORY_LIST_ITEM_PATTERN

	if popular_repositories_start then
		local list_start = html:find(OPEN_ORDERED_LIST_TAG, popular_repositories_start, true)
		local list_end = list_start and html:find(CLOSE_ORDERED_LIST_TAG, list_start, true)
		if list_start and list_end then
			repository_list = html:sub(list_start, list_end - FIRST_LUA_INDEX)
			list_item_pattern = REPOSITORY_LIST_ITEM_PATTERN
		end
	end

	for repository_html in (repository_list or html):gmatch(list_item_pattern) do
		local name, stars, language
		local name_html = repository_html:match(REPOSITORY_NAME_PATTERN)
		if name_html then
			name = plain_text(name_html)
		end

		for attributes, content in repository_html:gmatch("<a%s+([^>]-)>(.-)</a>") do
			local itemprop = attributes:match("itemprop%s*=%s*[\"']([^\"']+)[\"']")
			local href = attributes:match("href%s*=%s*[\"']([^\"']+)[\"']")
			if not name and itemprop and itemprop:find("codeRepository", FIRST_LUA_INDEX, true) then
				name = plain_text(content)
			elseif href and href:match("/stargazers$") then
				stars = plain_text(content)
			end
		end

		local language_html =
			repository_html:match("<[^>]-itemprop%s*=%s*[\"']programmingLanguage[\"'][^>]*>(.-)</[^>]+>")
		if language_html then
			language = plain_text(language_html)
		end

		if name then
			table.insert(repositories, RepositoryMetadata.new(name, stars or DEFAULT_STAR_COUNT, language))
		end
	end

	return repositories
end

return M
