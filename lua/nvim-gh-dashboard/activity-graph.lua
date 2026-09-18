local ActivityGraph = {}
ActivityGraph.__index = ActivityGraph

local BarGraph = require("nvim-gh-dashboard.bar-graph")

local ACTIVITY_TYPES = { "code_review", "commits", "pull_requests", "issues" }
local ACTIVITY_PERCENTAGE_TOTAL = 100
local PERCENTAGE_PER_BAR_CHARACTER = 5
local ACTIVITY_LABEL_WIDTH = 15
local FIRST_LUA_INDEX = 1
local FIRST_HIGHLIGHT_COLUMN = 0
local ACTIVITY_BAR_WIDTH = ACTIVITY_PERCENTAGE_TOTAL / PERCENTAGE_PER_BAR_CHARACTER
local ACTIVITY_LABEL_SEPARATOR = " "
local ACTIVITY_VALUE_SEPARATOR = " "
local ACTIVITY_BAR_COLORS = {
	label = "GHDashboardActivityLabel",
	border = "GHDashboardActivityBorder",
	filled = BarGraph.FILLED_HIGHLIGHT_GROUP,
	empty = "GHDashboardActivityBarEmpty",
	value = "GHDashboardActivityPercent",
}

---@class ActivityGraph
---@field activities ActivityMetadata single object with all the activities metadata
---@field year number year of the activities
---@field height number height of the graph in lines
---@field chars table characters configuration
---@field bars BarGraph[] rendered activity bars

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

	self.bars = {}
	if self.activities then
		for _, activity_type in ipairs(ACTIVITY_TYPES) do
			local percentage = self.activities[activity_type]
			table.insert(
				self.bars,
				BarGraph.new({
					label = activity_type,
					used = percentage,
					total = ACTIVITY_PERCENTAGE_TOTAL,
					width = ACTIVITY_BAR_WIDTH,
					label_width = ACTIVITY_LABEL_WIDTH,
					label_separator = ACTIVITY_LABEL_SEPARATOR,
					value = string.format("%3d%%", percentage),
					value_separator = ACTIVITY_VALUE_SEPARATOR,
					chars = self.chars,
					colors = ACTIVITY_BAR_COLORS,
				})
			)
		end
	end

	return self
end

---@return string[]
function ActivityGraph:get_lines()
	local lines = {}

	if not self.activities then
		return lines
	end

	for _, bar in ipairs(self.bars) do
		table.insert(lines, bar:get_line())
	end

	return lines
end

---Returns highlights for the activity bars.
---@return table[] highlights list of `{ line, col_start, col_end, hl_group }`
---(0-based, end-exclusive, matching the lines returned by `get_lines`)
function ActivityGraph:get_highlights()
	local highlights = {}

	if not self.activities then
		return highlights
	end

	for line_idx, bar in ipairs(self.bars) do
		vim.list_extend(highlights, bar:get_highlights(line_idx - FIRST_LUA_INDEX))
	end

	return highlights
end

return ActivityGraph
