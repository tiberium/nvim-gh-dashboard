local BarGraph = {}
BarGraph.__index = BarGraph

BarGraph.FILLED_HIGHLIGHT_GROUP = "GHDashboardBarGraphFill"

local NO_VALUE = 0
local FIRST_HIGHLIGHT_COLUMN = 0
local BRACKET_WIDTH = 1
local HIGHLIGHT_TO_END_OF_LINE = -1
local DEFAULT_FILLED_CHARACTER = "#"
local DEFAULT_EMPTY_CHARACTER = "."

---@class BarGraphColors
---@field label string
---@field border string
---@field filled string
---@field empty string|nil
---@field value string

---@class BarGraph
---@field label string
---@field used number
---@field total number
---@field width number
---@field label_width number
---@field label_separator string
---@field value string
---@field value_separator string
---@field chars table
---@field colors BarGraphColors
---@field filled_width number
---@field empty_width number

---@param options table
---@return BarGraph
function BarGraph.new(options)
	local self = setmetatable({}, BarGraph)

	self.label = options.label
	self.used = options.used
	self.total = options.total
	self.width = options.width
	self.label_width = options.label_width
	self.label_separator = options.label_separator or ""
	self.value = options.value
	self.value_separator = options.value_separator or ""
	self.chars = {
		filled = options.chars.filled or DEFAULT_FILLED_CHARACTER,
		empty = options.chars.empty or DEFAULT_EMPTY_CHARACTER,
	}
	self.colors = options.colors
	self.filled_width = self.total > NO_VALUE
			and math.max(NO_VALUE, math.min(self.width, math.ceil((self.used / self.total) * self.width)))
		or NO_VALUE
	self.empty_width = self.width - self.filled_width

	return self
end

---@return string
function BarGraph:get_line()
	local bar = "["
		.. string.rep(self.chars.filled, self.filled_width)
		.. string.rep(self.chars.empty, self.empty_width)
		.. "]"
	return string.format(
		"%-" .. self.label_width .. "s%s%s%s",
		self.label,
		self.label_separator,
		bar,
		self.value_separator
	) .. self.value
end

---@param line number 0-based line number
---@return table[]
function BarGraph:get_highlights(line)
	local highlights = {
		{
			line = line,
			col_start = FIRST_HIGHLIGHT_COLUMN,
			col_end = self.label_width,
			hl_group = self.colors.label,
		},
	}
	local bar_start = self.label_width + #self.label_separator

	table.insert(highlights, {
		line = line,
		col_start = bar_start,
		col_end = bar_start + BRACKET_WIDTH,
		hl_group = self.colors.border,
	})

	local filled_start = bar_start + BRACKET_WIDTH
	table.insert(highlights, {
		line = line,
		col_start = filled_start,
		col_end = filled_start + self.filled_width,
		hl_group = self.colors.filled,
	})

	if self.colors.empty then
		local empty_start = filled_start + self.filled_width
		table.insert(highlights, {
			line = line,
			col_start = empty_start,
			col_end = empty_start + self.empty_width,
			hl_group = self.colors.empty,
		})
	end

	local closing_bracket = filled_start + self.width
	table.insert(highlights, {
		line = line,
		col_start = closing_bracket,
		col_end = closing_bracket + BRACKET_WIDTH,
		hl_group = self.colors.border,
	})
	table.insert(highlights, {
		line = line,
		col_start = closing_bracket + BRACKET_WIDTH + #self.value_separator,
		col_end = HIGHLIGHT_TO_END_OF_LINE,
		hl_group = self.colors.value,
	})

	return highlights
end

return BarGraph
