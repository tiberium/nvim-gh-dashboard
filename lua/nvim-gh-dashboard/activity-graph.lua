local ActivityGraph = {}
ActivityGraph.__index = ActivityGraph

local ACTIVITY_TYPES = { "code_review", "commits", "pull_requests", "issues" }
local ACTIVITY_PERCENTAGE_TOTAL = 100
local PERCENTAGE_PER_BAR_CHARACTER = 5
local ACTIVITY_LABEL_WIDTH = 15
local FIRST_LUA_INDEX = 1
local FIRST_HIGHLIGHT_COLUMN = 0
local CHARACTER_WIDTH = 1
local INTER_COMPONENT_SPACE_WIDTH = 1
local HIGHLIGHT_TO_END_OF_LINE = -1

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

	self.height = FIRST_HIGHLIGHT_COLUMN

	if self.activities then
		self.height = #ACTIVITY_TYPES
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

	for _, activityType in ipairs(ACTIVITY_TYPES) do
		local percentage = self.activities[activityType]
		local bar = self:renderBar(percentage, PERCENTAGE_PER_BAR_CHARACTER)
		local line = string.format("%-15s %s %3d%%", activityType, bar, percentage)
		table.insert(lines, line)
	end

	return lines
end

---@return string
function ActivityGraph:renderBar(percentage, resolution)
	local totalChars = ACTIVITY_PERCENTAGE_TOTAL / resolution
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

	local totalChars = ACTIVITY_PERCENTAGE_TOTAL / PERCENTAGE_PER_BAR_CHARACTER

	for line_idx, activityType in ipairs(ACTIVITY_TYPES) do
		local percentage = self.activities[activityType]
		local filledChars = math.ceil(percentage / PERCENTAGE_PER_BAR_CHARACTER)
		local emptyChars = totalChars - filledChars

		local line = line_idx - FIRST_LUA_INDEX
		local col = FIRST_HIGHLIGHT_COLUMN

		table.insert(
			highlights,
			{ line = line, col_start = col, col_end = ACTIVITY_LABEL_WIDTH, hl_group = "GHDashboardActivityLabel" }
		)
		col = ACTIVITY_LABEL_WIDTH + INTER_COMPONENT_SPACE_WIDTH

		-- opening bracket
		table.insert(
			highlights,
			{ line = line, col_start = col, col_end = col + CHARACTER_WIDTH, hl_group = "GHDashboardActivityBorder" }
		)
		col = col + CHARACTER_WIDTH

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
			{ line = line, col_start = col, col_end = col + CHARACTER_WIDTH, hl_group = "GHDashboardActivityBorder" }
		)
		col = col + CHARACTER_WIDTH + INTER_COMPONENT_SPACE_WIDTH

		table.insert(highlights, {
			line = line,
			col_start = col,
			col_end = HIGHLIGHT_TO_END_OF_LINE,
			hl_group = "GHDashboardActivityPercent",
		})
	end

	return highlights
end

return ActivityGraph
