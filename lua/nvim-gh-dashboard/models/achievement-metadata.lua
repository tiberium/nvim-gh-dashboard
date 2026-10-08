local AchievementMetadata = {}
AchievementMetadata.__index = AchievementMetadata

---@param name string
---@param details_url string
---@return AchievementMetadata
function AchievementMetadata.new(name, details_url)
	return setmetatable({
		name = name,
		details_url = details_url,
	}, AchievementMetadata)
end

return AchievementMetadata
