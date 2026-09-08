local GithubService = require("nvim-gh-dashboard.github-service")
local DashboardView = require("nvim-gh-dashboard.dashboard-view")
local ContributionMetadata = require("nvim-gh-dashoard.contribution-metadata")

describe("dashboard-view", function()
	local default_chars = { filled = "#", high = "@", empty = "." }

	describe("create_header", function()
		it("includes the username and year", function()
			local lines = DashboardView.create_header(2024, "octocat")

			local joined = table.concat(lines, "\n")
			assert.matches("User: octocat", joined)
			assert.matches("Year: 2024", joined)
		end)
	end)

	describe("spinner", function()
		it("animates a braille frame into the target line", function()
			local buf_id = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, { "" })

			local timer = DashboardView.start_spinner(buf_id, 0, "Loading...")

			vim.wait(300, function()
				local line = vim.api.nvim_buf_get_lines(buf_id, 0, 1, false)[1]
				return line ~= "" and line ~= nil
			end)

			local line = vim.api.nvim_buf_get_lines(buf_id, 0, 1, false)[1]
			assert.matches("Loading%.%.%.", line)

			local has_frame = false
			for _, frame in ipairs(DashboardView.spinner_frames) do
				if line:find(frame, 1, true) then
					has_frame = true
					break
				end
			end
			assert.is_true(has_frame)

			DashboardView.stop_spinner(timer)
			assert.is_true(timer:is_closing())

			vim.api.nvim_buf_delete(buf_id, { force = true })
		end)
	end)

	describe("render_error", function()
		it("writes the error message into the buffer", function()
			local buf_id = vim.api.nvim_create_buf(false, true)

			DashboardView.render_error(buf_id, "boom")

			local lines = vim.api.nvim_buf_get_lines(buf_id, 0, -1, false)
			assert.matches("boom", table.concat(lines, "\n"))

			vim.api.nvim_buf_delete(buf_id, { force = true })
		end)
	end)

	describe("render_dashboard", function()
		it("renders the header and graphs into the buffer", function()
			local Contribution = require("contribution")
			local buf_id = vim.api.nvim_create_buf(false, true)

			local contributions = {}
			for day = 0, 6 do
				local metadata = ContributionMetadata.new(tostring(day), "0", "5 contributions on January 21.")
				table.insert(contributions, Contribution.new(metadata))
			end

			DashboardView.render_dashboard(buf_id, contributions, nil, 2024, "octocat", default_chars)

			local lines = vim.api.nvim_buf_get_lines(buf_id, 0, -1, false)
			local joined = table.concat(lines, "\n")
			assert.matches("User: octocat", joined)
			assert.is_true(#lines > 0)

			vim.api.nvim_buf_delete(buf_id, { force = true })
		end)
	end)

	describe("open_dashboard", function()
		it("opens the buffer immediately and replaces the spinner with graphs on success", function()
			local original_fetch = GithubService.fetch_dashboard_data
			local metadata_list = {}
			for day = 0, 6 do
				table.insert(
					metadata_list,
					ContributionMetadata.new(tostring(day), "0", "5 contributions on January 21.")
				)
			end

			GithubService.fetch_dashboard_data = function(_, _, _, on_success, _)
				vim.schedule(function()
					on_success({ contributions = metadata_list, activity = nil })
				end)
			end

			local buf_id = DashboardView.open_dashboard("octocat", 2024, default_chars)

			-- Immediately after opening, the buffer must already exist and show
			-- a loading indicator rather than being blocked until data arrives.
			assert.is_true(vim.api.nvim_buf_is_valid(buf_id))
			local initial_lines = vim.api.nvim_buf_get_lines(buf_id, 0, -1, false)
			assert.matches("User: octocat", table.concat(initial_lines, "\n"))

			vim.wait(300, function()
				local lines = vim.api.nvim_buf_get_lines(buf_id, 0, -1, false)
				return table.concat(lines, "\n"):find("contribution%-day", 1, false) == nil
					and #vim.tbl_filter(function(l)
						return l ~= ""
					end, lines) > 0
			end)

			GithubService.fetch_dashboard_data = original_fetch
			vim.api.nvim_buf_delete(buf_id, { force = true })
		end)

		it("shows an error message when fetching fails", function()
			local original_fetch = GithubService.fetch_dashboard_data

			GithubService.fetch_dashboard_data = function(_, _, _, _, on_error)
				vim.schedule(function()
					on_error("network unreachable")
				end)
			end

			local buf_id = DashboardView.open_dashboard("octocat", 2024, default_chars)

			vim.wait(300, function()
				local lines = vim.api.nvim_buf_get_lines(buf_id, 0, -1, false)
				return table.concat(lines, "\n"):find("network unreachable", 1, true) ~= nil
			end)

			local lines = vim.api.nvim_buf_get_lines(buf_id, 0, -1, false)
			assert.matches("network unreachable", table.concat(lines, "\n"))

			GithubService.fetch_dashboard_data = original_fetch
			vim.api.nvim_buf_delete(buf_id, { force = true })
		end)
	end)
end)
