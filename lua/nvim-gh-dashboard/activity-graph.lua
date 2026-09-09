local ActivityGraph = {}
ActivityGraph.__index = ActivityGraph

---@class ActivityGraph
---@field activities ActivityMetadata single object with all the activities metadata
---@field year number year of the activities
---@field height number height of the graph in lines
---@field chars table characters configuration

---@param activities ActivityMetadata|nil
---@param year number year of the activities
---@param chars table Characters configuration
---@return ActivityGraph
function ActivityGraph.new(activities, year, chars)
	local self = setmetatable({}, ActivityGraph)

	self.activities = activities

	self.height = 0

	if self.activities then
		self.height = 4 -- 4 as there are 4 activity directions in GitHub, and we want to render the graph in 4 lines
	end

	self.year = year or tonumber(os.date("%Y"))
	self.chars = chars

	self.charFilled = self.chars.filled or "#"
	self.charEmpty = self.chars.empty or "."

	return self
end

---@return string[]
function ActivityGraph:get_lines()
	local lines = {}

	if not self.activities then
		return lines
	end

	-- This is the "resolution" of the graph. 5 means that 100% will be represented in 20 characters (100 / 5 = 20), as a
	local resolution = 5

	for _, activityType in ipairs({ "code_review", "commits", "pull_requests", "issues" }) do
		local percentage = self.activities[activityType]
		local bar = self:renderBar(percentage, resolution)
		local line = string.format("%-15s %s %3d%%", activityType, bar, percentage)
		table.insert(lines, line)
	end

	return lines
end

---@return string
function ActivityGraph:renderBar(percentage, resolution)
	local totalChars = 100 / resolution
	local filledChars = math.ceil(percentage / resolution)
	local emptyChars = totalChars - filledChars

	local bar = "[" .. string.rep(self.charFilled, filledChars) .. string.rep(self.charEmpty, emptyChars) .. "]"
	return bar
end

---Returns per-character highlight spans for the rendered graph lines,
---distinguishing the activity label, the bar's border/brackets, its filled
---and empty portions, and the trailing percentage, so each element can use a
---different color.
---@return table[] highlights list of `{ line, col_start, col_end, hl_group }`
---(0-based, end-exclusive, matching the lines returned by `get_lines`)
function ActivityGraph:get_highlights()
	local highlights = {}

	if not self.activities then
		return highlights
	end

	local resolution = 5
	local totalChars = 100 / resolution
	local label_width = 15

	for line_idx, activityType in ipairs({ "code_review", "commits", "pull_requests", "issues" }) do
		local percentage = self.activities[activityType]
		local filledChars = math.ceil(percentage / resolution)
		local emptyChars = totalChars - filledChars

		local line = line_idx - 1
		local col = 0

		table.insert(
			highlights,
			{ line = line, col_start = col, col_end = label_width, hl_group = "GHDashboardActivityLabel" }
		)
		col = label_width + 1 -- skip the space between label and bar

		-- opening bracket
		table.insert(
			highlights,
			{ line = line, col_start = col, col_end = col + 1, hl_group = "GHDashboardActivityBorder" }
		)
		col = col + 1

		table.insert(
			highlights,
			{ line = line, col_start = col, col_end = col + filledChars, hl_group = "GHDashboardActivityBarFilled" }
		)
		col = col + filledChars

		table.insert(
			highlights,
			{ line = line, col_start = col, col_end = col + emptyChars, hl_group = "GHDashboardActivityBarEmpty" }
		)
		col = col + emptyChars

		-- closing bracket
		table.insert(
			highlights,
			{ line = line, col_start = col, col_end = col + 1, hl_group = "GHDashboardActivityBorder" }
		)
		col = col + 1 + 1 -- skip the space between bar and percentage

		table.insert(
			highlights,
			{ line = line, col_start = col, col_end = -1, hl_group = "GHDashboardActivityPercent" }
		)
	end

	return highlights
end

return ActivityGraph
