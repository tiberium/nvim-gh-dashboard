local Graph = {}
Graph.__index = Graph

---@class Graph
---@field contributions GitHubContribution[] flat list of contributions from GitHub
---@field grid GitHubContribution[][] contributions grouped by week day (0 - 6)
---@field year number year of the contributions
---@field height number height of the graph in lines

---@param contributions GitHubContribution[]
---@param year number
---@return Graph
function Graph.new(contributions, year)
    local self = setmetatable({}, Graph)

    self.contributions = contributions or {}
    self.year = year or tonumber(os.date("%Y"))

    self.graph = {}
    for i = 0, 6 do
        self.graph[i] = vim.tbl_filter(function(contribution)
            return contribution.weekday_number == i
        end, self.contributions)

        if self.graph[i][1].week_number ~= 0 then
            table.insert(self.graph[i], 1, false)
        end
    end

    self.height = 13

    return self
end

---@return string[]
function Graph:get_lines()
    local lines = {}

    if not self.contributions or #self.contributions < 1 then
        print("nv-gh-dashboard: Error: No contributions fetched from GitHub")
        return lines
    end

    -- Add a simple line
    table.insert(lines, "┌──────────────────────────────────────────────────────────────┐")
    table.insert(lines, "│                      GitHub Contributions                    │")
    table.insert(lines, "└──────────────────────────────────────────────────────────────┘")
    table.insert(lines, "")
    table.insert(lines, "Year: " .. self.year)
    table.insert(lines, "")

    for i = 0, #self.graph do
        local day_line = ""
        for _, contribution in ipairs(self.graph[i]) do
            if contribution then
                if string.match(contribution.counter, "+$") ~= nil then
                    day_line = day_line .. "A"
                elseif tonumber(contribution.counter) > 0 then
                    day_line = day_line .. "X"
                else
                    day_line = day_line .. " "
                end
            else
                day_line = day_line .. " "
            end
        end
        table.insert(lines, day_line)
    end

    return lines
end

return Graph
