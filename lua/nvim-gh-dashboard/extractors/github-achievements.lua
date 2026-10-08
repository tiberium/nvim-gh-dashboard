local M = {}

local AchievementMetadata = require("nvim-gh-dashboard.models.achievement-metadata")
local AchievementDetails = require("nvim-gh-dashboard.models.achievement-details")

local FIRST_LUA_INDEX = 1
local GITHUB_BASE_URL = "https://github.com"

---@param html string
---@return string
local function plain_text(html)
	return html:gsub("<[^>]->", ""):gsub("&amp;", "&"):gsub("&quot;", '"'):gsub("%s+", " "):match("^%s*(.-)%s*$")
end

---@param html string HTML of GitHub's achievements page
---@return AchievementMetadata[]
function M.extract_achievements(html)
	local achievements = {}
	local seen = {}

	for image_tag in html:gmatch("<img%s+.-%s*/?>") do
		local achievement_type = image_tag:match('data%-hovercard%-type%s*=%s*"achievement"')
			or image_tag:match("data%-hovercard%-type%s*=%s*'achievement'")
		local achievement_name = image_tag:match('alt%s*=%s*"Achievement:%s*(.-)"')
			or image_tag:match("alt%s*=%s*'Achievement:%s*(.-)'")
		local details_path = image_tag:match('data%-hovercard%-url%s*=%s*"([^"]+)"')
			or image_tag:match("data%-hovercard%-url%s*=%s*'([^']+)'")

		if achievement_type and achievement_name and details_path and not seen[achievement_name] then
			seen[achievement_name] = true
			table.insert(achievements, AchievementMetadata.new(achievement_name, GITHUB_BASE_URL .. details_path))
		end
	end

	return achievements
end

---@param html string HTML of a GitHub achievement hovercard
---@return AchievementDetails
function M.extract_details(html)
	local description_html = html:match('<div[^>]-class="mt%-1"[^>]*>%s*(.-)%s*</div>')
	local unlocked_section_start = html:find("achievement-history-unlocked-at", FIRST_LUA_INDEX, true)
	local unlocked_at
	if unlocked_section_start then
		unlocked_at = html:sub(unlocked_section_start):match('<relative%-time%s+[^>]-datetime="([^"]+)"')
	end

	return AchievementDetails.new(description_html and plain_text(description_html) or nil, unlocked_at)
end

return M
