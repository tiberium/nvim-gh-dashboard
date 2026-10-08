local ProfileDetails = {}
ProfileDetails.__index = ProfileDetails

---@class ProfileDetails
---@field followers string
---@field following string

---@param followers string
---@param following string
---@return ProfileDetails
function ProfileDetails.new(followers, following)
	return setmetatable({
		followers = followers,
		following = following,
	}, ProfileDetails)
end

return ProfileDetails
