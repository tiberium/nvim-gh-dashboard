local M = {}

local gh = require("gh")

function M.setup()
    local contributions = gh.fetch_years("tiberium")
    print(contributions)
end

return M
