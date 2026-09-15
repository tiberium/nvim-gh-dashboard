local AiUsageGraph = {}
AiUsageGraph.__index = AiUsageGraph

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
	self.height = 4

	return self
end

---@param used number
---@param total number
---@return string
function AiUsageGraph:render_bar(used, total)
	local width = 20
	local filled = total > 0 and math.min(width, math.ceil((used / total) * width)) or 0
	return "[" .. string.rep(self.char_filled, filled) .. string.rep(self.char_empty, width - filled) .. "]"
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
			usage.additional_budget_credits / 100
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
		{ line = 0, col_start = 0, col_end = -1, hl_group = "GHDashboardAiUsageTitle" },
	}

	for line = 1, 3 do
		table.insert(highlights, {
			line = line,
			col_start = 0,
			col_end = 20,
			hl_group = "GHDashboardAiUsageLabel",
		})
		table.insert(highlights, {
			line = line,
			col_start = 20,
			col_end = 22,
			hl_group = "GHDashboardAiUsageBorder",
		})
		table.insert(highlights, {
			line = line,
			col_start = 22,
			col_end = 42,
			hl_group = "GHDashboardAiUsageBar",
		})
		table.insert(highlights, {
			line = line,
			col_start = 42,
			col_end = -1,
			hl_group = "GHDashboardAiUsageValue",
		})
	end

	return highlights
end

return AiUsageGraph
