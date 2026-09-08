-- Minimal init used to run the plenary busted test suite.
--
-- Usage:
--   PLENARY_PATH=/path/to/plenary.nvim \
--     nvim --headless --noplugin -u tests/minimal_init.lua \
--     -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"

local repo_root = vim.fn.fnamemodify(vim.fn.getcwd(), ":p")

-- Make `require("github-service")`, `require("dashboard-view")`, etc. resolve.
vim.opt.rtp:prepend(repo_root)

-- Make `require("tests.fixtures")` resolve to tests/fixtures.lua at the repo root.
package.path = repo_root .. "/?.lua;" .. repo_root .. "/?/init.lua;" .. package.path

-- plenary.nvim is required both as a runtime dependency (plenary.curl) and as
-- the test harness (plenary.busted). Look it up via PLENARY_PATH, falling back
-- to a handful of common install locations used by plugin managers.
local candidates = {
	os.getenv("PLENARY_PATH"),
	repo_root .. "/.tests/plenary.nvim",
	vim.fn.stdpath("data") .. "/lazy/plenary.nvim",
	vim.fn.stdpath("data") .. "/site/pack/packer/start/plenary.nvim",
}

for _, path in ipairs(candidates) do
	if path and vim.fn.isdirectory(path) == 1 then
		vim.opt.rtp:append(path)
		break
	end
end

vim.cmd("runtime plugin/plenary.vim")
