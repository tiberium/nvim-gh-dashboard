local ActivityMetadata = {}
ActivityMetadata.__index = ActivityMetadata

---@class ActivityMetadata
---@field code_review number
---@field commits number
---@field pull_requests number
---@field issues number

---@param commits string
---@param code_review string
---@param pull_requests string
---@param issues string
function ActivityMetadata.new(commits, code_review, pull_requests, issues)
    local self = setmetatable({}, ActivityMetadata)

    self.commits = commits
    self.code_review = code_review
    self.pull_requests = pull_requests
    self.issues = issues

    return self
end

return ActivityMetadata
