local Graph = {}
Graph.__index = Graph


---@enum days
local DAYS = {
    "monday",
    "tuesday",
    "wednesday",
    "thursday",
    "friday",
    "saturday",
    "sunday"
}


---@class Graph
---@field contributions GitHubContribution[] flat list of contributions from GitHub
---@field width number width of the graph or number of weeks to display
---@field grid table<days, GitHubContribution[]> grid of contributions
---@field year number year of the contributions

---@param contributions GitHubContribution[]
---@param width number
---@param year number
---@return Graph
function Graph.new(contributions, width, year)
    local self = setmetatable({}, Graph)

    self.contributions = contributions or {}
    self.width = width or 0
    self.year = year or tonumber(os.date("%Y"))

    self.grid = {}

    -- local number_of_weeks = math.ceil(#self.contributions / #DAYS)

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
    table.insert(lines, "Year: " .. self.year)

    return lines
end

return Graph
