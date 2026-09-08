if vim.g.loaded_nvim_gh_dashboard then
    return
end
vim.g.loaded_nvim_gh_dashboard = true

---Creates the :GHDashboard user command.
---Usage:
---  :GHDashboard                    -- uses configured/default username and current year
---  :GHDashboard octocat            -- shows octocat's contributions for the current year
---  :GHDashboard octocat 2023       -- shows octocat's contributions for 2023
vim.api.nvim_create_user_command("GHDashboard", function(cmd_opts)
    local args = cmd_opts.fargs
    local setup_opts = {}

    if args[1] then
        setup_opts.username = args[1]
    end

    if args[2] then
        local year = tonumber(args[2])
        if not year then
            vim.notify("nvim-gh-dashboard: 'year' argument must be a number", vim.log.levels.ERROR)
            return
        end
        setup_opts.year = year
    end

    require("nvim-gh-dashboard").setup(setup_opts)
end, {
    nargs = "*",
    desc = "Open the GitHub contributions dashboard",
})
