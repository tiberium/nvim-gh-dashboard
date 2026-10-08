local ContributionsGraph = {}
ContributionsGraph.__index = ContributionsGraph

local DAYS_PER_WEEK = 7
local FIRST_LUA_INDEX = 1
local GITHUB_ZERO_BASED_INDEX = 0
local NO_CONTRIBUTIONS = 0

---@class ContributionsGraph
---@field contributions Contribution[] flat list of contributions from GitHub
---@field grid Contribution[][] contributions grouped by week day (1 - 7)
---@field year number year of the contributions
---@field height number height of the graph in lines
---@field chars table characters configuration

---@param contributions Contribution[]
---@param year number
---@param chars table Characters configuration
---@return ContributionsGraph
function ContributionsGraph.new(contributions, year, chars)
	local self = setmetatable({}, ContributionsGraph)

	self.contributions = contributions or {}
	self.year = year or tonumber(os.date("%Y"))
	self.chars = chars

	self.grid = {}
	for i = FIRST_LUA_INDEX, DAYS_PER_WEEK do
		self.grid[i] = vim.tbl_filter(function(contribution)
			return contribution.weekday_number == i - FIRST_LUA_INDEX
		end, self.contributions)

		if self.grid[i][FIRST_LUA_INDEX] and self.grid[i][FIRST_LUA_INDEX].week_number ~= GITHUB_ZERO_BASED_INDEX then
			table.insert(self.grid[i], FIRST_LUA_INDEX, false)
		end
	end

	self.height = DAYS_PER_WEEK

	return self
end

---@return string[]
function ContributionsGraph:get_lines()
	local lines = {}

	if not self.contributions or #self.contributions < FIRST_LUA_INDEX then
		vim.notify("No contributions fetched from GitHub", vim.log.levels.ERROR)
		return lines
	end

	for i = 1, #self.grid do
		local day_line = ""
		for _, contribution in ipairs(self.grid[i]) do
			if contribution then
				if string.match(contribution.counter, "+$") ~= nil then
					day_line = day_line .. self.chars.high
				elseif tonumber(contribution.counter) > NO_CONTRIBUTIONS then
					day_line = day_line .. self.chars.filled
				else
					day_line = day_line .. self.chars.empty
				end
			else
				day_line = day_line .. " "
			end
		end
		table.insert(lines, day_line)
	end

	return lines
end

---Returns per-character highlight spans for the rendered graph lines, so that
---each day can be colored according to its contribution intensity (see
---`Contribution:get_highlight_group`).
---@return table[] highlights list of `{ line = number, col = number, hl_group = string }`
---(0-based `line`/`col`, matching the lines returned by `get_lines`)
function ContributionsGraph:get_highlights()
	local highlights = {}

	for i = 1, #self.grid do
		for col, contribution in ipairs(self.grid[i]) do
			if contribution then
				table.insert(highlights, {
					line = i - FIRST_LUA_INDEX,
					col = col - FIRST_LUA_INDEX,
					hl_group = contribution:get_highlight_group(),
				})
			end
		end
	end

	return highlights
end

return ContributionsGraph
