if vim.g.loaded_nvim_gh_dashboard then
	return
end
vim.g.loaded_nvim_gh_dashboard = true

local USERNAME_ARGUMENT_INDEX = 1
local YEAR_ARGUMENT_INDEX = 2

---Creates the :GHDashboard user command.
---Usage:
---  :GHDashboard                    -- uses configured/default username and current year
---  :GHDashboard octocat            -- shows octocat's contributions for the current year
---  :GHDashboard octocat 2023       -- shows octocat's contributions for 2023
vim.api.nvim_create_user_command("GHDashboard", function(cmd_opts)
	local args = cmd_opts.fargs
	local setup_opts = {}

	if args[USERNAME_ARGUMENT_INDEX] then
		setup_opts.username = args[USERNAME_ARGUMENT_INDEX]
	end

	if args[YEAR_ARGUMENT_INDEX] then
		local year = tonumber(args[YEAR_ARGUMENT_INDEX])
		if not year then
			vim.notify("nvim-gh-dashboard: 'year' argument must be a number", vim.log.levels.ERROR)
			return
		end
		setup_opts.year = year
	end

	require("nvim-gh-dashboard").open_dashboard(setup_opts)
end, {
	nargs = "*",
	desc = "Open the GitHub contributions dashboard",
})
