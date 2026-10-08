local AchievementDetails = {}
AchievementDetails.__index = AchievementDetails

---@class AchievementDetails
---@field description string|nil
---@field unlocked_at string|nil

---@param description string|nil
---@param unlocked_at string|nil
---@return AchievementDetails
function AchievementDetails.new(description, unlocked_at)
	return setmetatable({
		description = description,
		unlocked_at = unlocked_at,
	}, AchievementDetails)
end

return AchievementDetails
