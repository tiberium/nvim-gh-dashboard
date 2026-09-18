local Contribution = {}
Contribution.__index = Contribution

local NO_CONTRIBUTIONS_MAXIMUM = 0
local LEVEL_ONE_CONTRIBUTIONS_MAXIMUM = 3
local LEVEL_TWO_CONTRIBUTIONS_MAXIMUM = 6
local LEVEL_THREE_CONTRIBUTIONS_MAXIMUM = 9

---@class Contribution
---@field counter string -- format: <number>[+]
---@field month string -- format: <month> (e.g. "January", "February", ...)
---@field day string -- format: <day> (e.g. "1", "2", ..., "31")
---@field tooltip string -- format: `<couter | No> contribution|s on <month> <day>.`
---@field weekday_number number -- 0 - 6 (0 = Sunday, 1 = Monday, ..., 6 = Saturday), as coded by GitHub.
---@field week_number number -- week number of the year (0 - 52)
---@field count number -- numeric contribution count for the day (the `+` suffix, if any, is stripped)
---@field is_high boolean -- true when GitHub flagged this as the highest tier (`counter` ends with `+`, i.e. 100+)

---@type table[]
Contribution.level_thresholds = {
	{ max = NO_CONTRIBUTIONS_MAXIMUM, group = "GHDashboardEmpty" },
	{ max = LEVEL_ONE_CONTRIBUTIONS_MAXIMUM, group = "GHDashboardLevel1" },
	{ max = LEVEL_TWO_CONTRIBUTIONS_MAXIMUM, group = "GHDashboardLevel2" },
	{ max = LEVEL_THREE_CONTRIBUTIONS_MAXIMUM, group = "GHDashboardLevel3" },
	{ max = math.huge, group = "GHDashboardLevel4" },
}

---@param metadata ContributionMetadata
---@return Contribution | nil
function Contribution.new(
	metadata --[[@as ContributionMetadata]]
)
	local self = setmetatable({}, Contribution)
	if metadata == nil then
		return nil
	end

	self.tooltip = metadata.tooltip

	self.weekday_number = tonumber(metadata.day)
	self.week_number = tonumber(metadata.week)

	-- unpack contribution
	local pattern = "(%d+[%+]?) contribution[s]? on (%a+) (%w+)%."
	local contribution_raw_fixed = self.tooltip:gsub("^No%s", tostring(NO_CONTRIBUTIONS_MAXIMUM) .. " ")
	local counter, month, day = contribution_raw_fixed:match(pattern)

	-- validate unpacked values
	if not counter or not month or not day then
		vim.notify("Failed to parse contribution metadata: " .. metadata.tooltip, vim.log.levels.ERROR)
		return nil
	end

	self.counter = counter
	self.month = month
	self.day = day

	self.is_high = counter:match("%+$") ~= nil
	self.count = tonumber((counter:gsub("%+$", ""))) or NO_CONTRIBUTIONS_MAXIMUM

	return self
end

---Returns the highlight group for this day's contribution intensity.
---@return string
function Contribution:get_highlight_group()
	if self.is_high then
		return "GHDashboardHigh"
	end

	for _, threshold in ipairs(Contribution.level_thresholds) do
		if self.count <= threshold.max then
			return threshold.group
		end
	end

	return "GHDashboardLevel4"
end

return Contribution
