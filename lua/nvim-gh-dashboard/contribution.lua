local Contribution = {}
Contribution.__index = Contribution

---@class Contribution
---@field counter string -- format: <number>[+]
---@field month string -- format: <month> (e.g. "January", "February", ...)
---@field day string -- format: <day> (e.g. "1", "2", ..., "31")
---@field tooltip string -- format: `<couter | No> contribution|s on <month> <day>.`
---@field weekday_number number -- 0 - 6 (0 = Sunday, 1 = Monday, ..., 6 = Saturday), as coded by GitHub.
---@field week_number number -- week number of the year (0 - 52)
---@field count number -- numeric contribution count for the day (the `+` suffix, if any, is stripped)
---@field is_high boolean -- true when GitHub flagged this as the highest tier (`counter` ends with `+`, i.e. 100+)

---Highlight group thresholds for the contribution intensity scale, mirroring
---the multiple shades used on github.com. Days flagged by GitHub as the
---highest tier (`is_high`) always use `GHDashboardHigh`, regardless of count.
---@type table[]
Contribution.level_thresholds = {
	{ max = 0, group = "GHDashboardEmpty" },
	{ max = 3, group = "GHDashboardLevel1" },
	{ max = 6, group = "GHDashboardLevel2" },
	{ max = 9, group = "GHDashboardLevel3" },
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
	local contribution_raw_fixed = self.tooltip:gsub("^No%s", "0 ")
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
	self.count = tonumber((counter:gsub("%+$", ""))) or 0

	return self
end

---Returns the highlight group that best represents this day's contribution
---intensity, mirroring the multiple shades of green used on github.com. Days
---flagged by GitHub as the highest tier (100+ contributions) are always
---rendered with `GHDashboardHigh`, regardless of the exact count.
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
