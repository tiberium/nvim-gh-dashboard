local M = {}

local gh = require("gh")
local Graph = require("graph")
local GitHubContribution = require("github_contrubution")

---Function to setup the plugin
function M.setup()
    -- TODO: Parameterize the year
    local year = 2024

    local contributions_metadata = gh.fetch_contributions("tiberium", year)

    if not contributions_metadata then
        print("Failed to fetch contributions.")
        return
    end

    local contributions = {}
    for _, contribution_metadata in ipairs(contributions_metadata) do
        local contribution = GitHubContribution.new(contribution_metadata)

        table.insert(contributions, contribution)
    end

    M.dashboard(contributions, year)
end

---Fuction creating the dashboard buffer and filling it with data
---@param contributions GitHubContribution[]
---@param year number
function M.dashboard(contributions, year)
    vim.cmd("enew")
    vim.bo.buftype = "nofile"
    vim.bo.bufhidden = "wipe"
    vim.bo.swapfile = false

    local win_id = vim.api.nvim_get_current_win()
    local width = vim.api.nvim_win_get_width(win_id)

    local contributions_graph = Graph.new(contributions, width, year)
    local graph_lines = contributions_graph:get_lines()

    vim.api.nvim_buf_set_lines(0, 0, -1, false, graph_lines)
    vim.bo.modifiable = false
    vim.bo.readonly = true
end

return M
