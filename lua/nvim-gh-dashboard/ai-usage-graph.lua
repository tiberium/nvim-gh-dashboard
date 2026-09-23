local AiUsageGraph = {}
AiUsageGraph.__index = AiUsageGraph

local BarGraph = require("nvim-gh-dashboard.bar-graph")

local AI_USAGE_GRAPH_HEIGHT = 4
local AI_USAGE_BAR_WIDTH = 20
local AI_USAGE_LABEL_WIDTH = 20
local CREDITS_PER_DOLLAR = 100
local FIRST_HIGHLIGHT_COLUMN = 0
local HIGHLIGHT_TO_END_OF_LINE = -1
local AI_USAGE_VALUE_SEPARATOR = " "
local AI_USAGE_BAR_COLORS = {
	label = "GHDashboardAiUsageLabel",
	border = "GHDashboardAiUsageBorder",
	filled = BarGraph.FILLED_HIGHLIGHT_GROUP,
	value = "GHDashboardAiUsageValue",
}

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
	self.height = AI_USAGE_GRAPH_HEIGHT
	self.bars = {
		BarGraph.new({
			label = "Additional budget",
			used = usage.additional_credits,
			total = usage.additional_budget_credits,
			width = AI_USAGE_BAR_WIDTH,
			label_width = AI_USAGE_LABEL_WIDTH,
			value = string.format(
				"$%.2f / $%.2f",
				usage.additional_amount,
				usage.additional_budget_credits / CREDITS_PER_DOLLAR
			),
			value_separator = AI_USAGE_VALUE_SEPARATOR,
			chars = self.chars,
			colors = AI_USAGE_BAR_COLORS,
		}),
		BarGraph.new({
			label = "Included AI credits",
			used = usage.included_credits_used,
			total = usage.included_credits,
			width = AI_USAGE_BAR_WIDTH,
			label_width = AI_USAGE_LABEL_WIDTH,
			value = string.format("%d / %d", usage.included_credits_used, usage.included_credits),
			value_separator = AI_USAGE_VALUE_SEPARATOR,
			chars = self.chars,
			colors = AI_USAGE_BAR_COLORS,
		}),
		BarGraph.new({
			label = "Over-pool AI credits",
			used = usage.over_pool_credits,
			total = usage.additional_budget_credits,
			width = AI_USAGE_BAR_WIDTH,
			label_width = AI_USAGE_LABEL_WIDTH,
			value = string.format("%.2f", usage.over_pool_credits),
			value_separator = AI_USAGE_VALUE_SEPARATOR,
			chars = self.chars,
			colors = AI_USAGE_BAR_COLORS,
		}),
	}

	return self
end

---@return string[]
function AiUsageGraph:get_lines()
	local lines = { "AI Usage" }
	for _, bar in ipairs(self.bars) do
		table.insert(lines, bar:get_line())
	end
	return lines
end

---@return table[]
function AiUsageGraph:get_highlights()
	local highlights = {
		{
			line = FIRST_HIGHLIGHT_COLUMN,
			col_start = FIRST_HIGHLIGHT_COLUMN,
			col_end = HIGHLIGHT_TO_END_OF_LINE,
			hl_group = "GHDashboardAiUsageTitle",
		},
	}

	for line, bar in ipairs(self.bars) do
		vim.list_extend(highlights, bar:get_highlights(line))
	end

	return highlights
end

return AiUsageGraph
