local AiUsageGraph = {}
AiUsageGraph.__index = AiUsageGraph

local AI_USAGE_GRAPH_HEIGHT = 4
local AI_USAGE_BAR_WIDTH = 20
local AI_USAGE_LABEL_WIDTH = 20
local AI_USAGE_VALUE_LINE_COUNT = AI_USAGE_GRAPH_HEIGHT - 1
local CREDITS_PER_DOLLAR = 100
local FIRST_LUA_INDEX = 1
local FIRST_HIGHLIGHT_COLUMN = 0
local BRACKET_WIDTH = 1
local HIGHLIGHT_TO_END_OF_LINE = -1

---@class AiUsageData
---@field additional_budget_credits number
---@field additional_credits number
---@field additional_amount number
---@field included_credits number
---@field included_credits_used number
---@field over_pool_credits number

---@param usage AiUsageData
---@param chars table Characters configuration
---@return AiUsageGraph
function AiUsageGraph.new(usage, chars)
	local self = setmetatable({}, AiUsageGraph)

	self.usage = usage
	self.chars = chars
	self.char_filled = chars.filled or "#"
	self.char_empty = chars.empty or "."
	self.height = AI_USAGE_GRAPH_HEIGHT

	return self
end

---@param used number
---@param total number
---@return string
function AiUsageGraph:render_bar(used, total)
	local filled = total > FIRST_HIGHLIGHT_COLUMN
			and math.min(AI_USAGE_BAR_WIDTH, math.ceil((used / total) * AI_USAGE_BAR_WIDTH))
		or FIRST_HIGHLIGHT_COLUMN
	return "["
		.. string.rep(self.char_filled, filled)
		.. string.rep(self.char_empty, AI_USAGE_BAR_WIDTH - filled)
		.. "]"
end

---@return string[]
function AiUsageGraph:get_lines()
	local usage = self.usage

	return {
		"AI Usage",
		string.format(
			"%-20s%s $%.2f / $%.2f",
			"Additional budget",
			self:render_bar(usage.additional_credits, usage.additional_budget_credits),
			usage.additional_amount,
			usage.additional_budget_credits / CREDITS_PER_DOLLAR
		),
		string.format(
			"%-20s%s %d / %d",
			"Included AI credits",
			self:render_bar(usage.included_credits_used, usage.included_credits),
			usage.included_credits_used,
			usage.included_credits
		),
		string.format(
			"%-20s%s %.2f",
			"Over-pool AI credits",
			self:render_bar(usage.over_pool_credits, usage.additional_budget_credits),
			usage.over_pool_credits
		),
	}
end

---@return table[]
function AiUsageGraph.get_highlights()
	local highlights = {
		{
			line = FIRST_HIGHLIGHT_COLUMN,
			col_start = FIRST_HIGHLIGHT_COLUMN,
			col_end = HIGHLIGHT_TO_END_OF_LINE,
			hl_group = "GHDashboardAiUsageTitle",
		},
	}

	for line = FIRST_LUA_INDEX, AI_USAGE_VALUE_LINE_COUNT do
		table.insert(highlights, {
			line = line,
			col_start = FIRST_HIGHLIGHT_COLUMN,
			col_end = AI_USAGE_LABEL_WIDTH,
			hl_group = "GHDashboardAiUsageLabel",
		})
		table.insert(highlights, {
			line = line,
			col_start = AI_USAGE_LABEL_WIDTH,
			col_end = AI_USAGE_LABEL_WIDTH + (BRACKET_WIDTH * 2),
			hl_group = "GHDashboardAiUsageBorder",
		})
		table.insert(highlights, {
			line = line,
			col_start = AI_USAGE_LABEL_WIDTH + (BRACKET_WIDTH * 2),
			col_end = AI_USAGE_LABEL_WIDTH + (BRACKET_WIDTH * 2) + AI_USAGE_BAR_WIDTH,
			hl_group = "GHDashboardAiUsageBar",
		})
		table.insert(highlights, {
			line = line,
			col_start = AI_USAGE_LABEL_WIDTH + (BRACKET_WIDTH * 2) + AI_USAGE_BAR_WIDTH,
			col_end = HIGHLIGHT_TO_END_OF_LINE,
			hl_group = "GHDashboardAiUsageValue",
		})
	end

	return highlights
end

return AiUsageGraph
