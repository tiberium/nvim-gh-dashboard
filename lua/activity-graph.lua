local ActivityGraph = {}
ActivityGraph.__index = ActivityGraph

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

    self.height = 0

    if self.activities then
        self.height = 4 -- 4 as there are 4 activity directions in GitHub, and we want to render the graph in 4 lines
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
        vim.notify("No activities fetched from GitHub", vim.log.levels.DEBUG)
        return lines
    end

    -- This is the "resolution" of the graph. 5 means that 100% will be represented in 20 characters (100 / 5 = 20), as a
    local resolution = 5

    for _, activityType in ipairs({ "code_review", "commits", "pull_requests", "issues" }) do
        local percentage = self.activities[activityType]
        local bar = self:renderBar(percentage, resolution)
        local line = string.format("%-15s %s %3d%%", activityType, bar, percentage)
        table.insert(lines, line)
    end

    return lines
end

---@return string
function ActivityGraph:renderBar(percentage, resolution)
    local totalChars = 100 / resolution
    local filledChars = math.ceil(percentage / resolution)
    local emptyChars = totalChars - filledChars

    local bar = "[" .. string.rep(self.charFilled, filledChars) .. string.rep(self.charEmpty, emptyChars) .. "]"
    return bar
end

return ActivityGraph
