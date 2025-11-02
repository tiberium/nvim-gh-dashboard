local ActivityGraph = {}
ActivityGraph.__index = ActivityGraph

---@class ActivityGraph
---@field contributions Contribution[] flat list of contributions from GitHub
---@field grid Contribution[][] contributions grouped by week day (1 - 7)
---@field year number year of the contributions
---@field height number height of the graph in lines
---@field chars table characters configuration

---@param contributions Contribution[]
---@param year number
---@param chars table Characters configuration
---@return ActivityGraph
function ActivityGraph.new(contributions, year, chars)
    local self = setmetatable({}, ActivityGraph)

    self.contributions = contributions or {}
    self.year = year or tonumber(os.date("%Y"))
    self.chars = chars

    self.grid = {}
    for i = 1, 7 do
        self.grid[i] = vim.tbl_filter(function(contribution)
            return contribution.weekday_number == i - 1
        end, self.contributions)

        if self.grid[i][1].week_number ~= 0 then
            table.insert(self.grid[i], 1, false)
        end
    end

    self.height = 7 -- 7 as there are 7 days in a week

    return self
end

---@return string[]
function ActivityGraph:get_lines()
    local lines = {}

    if not self.contributions or #self.contributions < 1 then
        print("nv-gh-dashboard: Error: No contributions fetched from GitHub")
        return lines
    end

    for i = 1, #self.grid do
        local day_line = ""
        for _, contribution in ipairs(self.grid[i]) do
            if contribution then
                if string.match(contribution.counter, "+$") ~= nil then
                    day_line = day_line .. self.chars.high
                elseif tonumber(contribution.counter) > 0 then
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

return ActivityGraph
