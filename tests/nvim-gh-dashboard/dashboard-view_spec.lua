local GithubService = require("nvim-gh-dashboard.github-service")
local DashboardView = require("nvim-gh-dashboard.dashboard-view")
local ContributionMetadata = require("nvim-gh-dashboard.contribution-metadata")
local CursorTracking = require("nvim-gh-dashboard.cursor-tracking")

describe("dashboard-view", function()
	local default_chars = { filled = "#", high = "@", empty = "." }

	describe("create_header", function()
		it("includes the centered menu, username, and year", function()
			local lines = DashboardView.create_header(2024, "octocat", 80)

			local joined = table.concat(lines, "\n")
			assert.matches("%[C%] Contributions", joined)
			assert.matches("%[A%] AI", joined)
			assert.equals(string.rep("─", 80), lines[2])
			assert.matches("User: octocat", joined)
			assert.matches("Year: 2024", joined)
		end)
	end)

	describe("create_buffer", function()
		it("hides listchars in the dashboard window", function()
			vim.wo.list = true

			local buf_id = DashboardView.create_buffer()

			assert.is_false(vim.wo.list)

			vim.api.nvim_buf_delete(buf_id, { force = true })
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

		it("does not overwrite content after being stopped", function()
			local buf_id = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, { "Achievements loaded" })

			local timer = DashboardView.start_spinner(buf_id, 0, "Loading achievements...")
			DashboardView.stop_spinner(timer)

			vim.wait(100)

			local line = vim.api.nvim_buf_get_lines(buf_id, 0, 1, false)[1]
			assert.equals("Achievements loaded", line)

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
		it("loads achievements above the AI usage separator asynchronously", function()
			local Contribution = require("nvim-gh-dashboard.contribution")
			local original_fetch_achievements = GithubService.fetch_achievements
			local requested_username
			GithubService.fetch_achievements = function(username, on_success, _)
				requested_username = username
				vim.schedule(function()
					on_success({ "Pull Shark", "YOLO" })
				end)
			end
			local metadata = ContributionMetadata.new("0", "0", "5 contributions on January 21.")
			local contributions = { Contribution.new(metadata) }
			local buf_id = vim.api.nvim_create_buf(false, true)

			DashboardView.render_dashboard(buf_id, contributions, nil, 2024, "octocat", default_chars)

			local loaded = vim.wait(300, function()
				return table
					.concat(vim.api.nvim_buf_get_lines(buf_id, 0, -1, false), "\n")
					:find("Pull Shark, YOLO", 1, true) ~= nil
			end)
			assert.is_true(loaded)
			assert.equals("octocat", requested_username)
			local lines = vim.api.nvim_buf_get_lines(buf_id, 0, -1, false)
			local separator = string.rep("─", vim.api.nvim_win_get_width(0))
			local separator_idx
			for i, line in ipairs(lines) do
				if line == separator then
					separator_idx = i
				end
			end
			assert.is_not_nil(separator_idx)
			assert.matches("Pull Shark, YOLO", lines[separator_idx - 1])

			GithubService.fetch_achievements = original_fetch_achievements
			vim.api.nvim_buf_delete(buf_id, { force = true })
		end)

		it("loads the authenticated AI usage panel after pressing Enter on the AI menu", function()
			local Contribution = require("nvim-gh-dashboard.contribution")
			vim.api.nvim_win_set_height(0, 40)
			local buf_id = vim.api.nvim_create_buf(false, true)
			local original_fetch_ai_usage = GithubService.fetch_ai_usage
			local fetch_ai_usage_calls = 0
			GithubService.fetch_ai_usage = function(_, _, on_loading, on_success, _)
				fetch_ai_usage_calls = fetch_ai_usage_calls + 1
				vim.schedule(function()
					on_loading()
					on_success({
						additional_budget_credits = 5000,
						additional_credits = 300,
						additional_amount = 3,
						included_credits = 1500,
						included_credits_used = 1500,
						over_pool_credits = 300,
					})
				end)
			end

			local contributions = {}
			for day = 0, 6 do
				local metadata = ContributionMetadata.new(tostring(day), "0", "5 contributions on January 21.")
				table.insert(contributions, Contribution.new(metadata))
			end

			DashboardView.render_dashboard(buf_id, contributions, nil, 2024, "octocat", default_chars)

			local lines = vim.api.nvim_buf_get_lines(buf_id, 0, -1, false)
			local joined = table.concat(lines, "\n")
			assert.matches("User: octocat", joined)
			assert.matches("%[A%] AI", joined)
			assert.matches("%[C%] Contributions", joined)
			assert.same({ "", "" }, { lines[1], lines[2] })
			assert.equals(0, fetch_ai_usage_calls)
			assert.is_nil(joined:find("AI Usage", 1, true))
			local separator = string.rep("─", vim.api.nvim_win_get_width(0))
			local separator_idx
			for i = #lines, 1, -1 do
				if lines[i] == separator then
					separator_idx = i
					break
				end
			end
			assert.is_not_nil(separator_idx)
			assert.same({ "", "" }, { lines[#lines - 1], lines[#lines] })

			local ai_menu_line
			for i, line in ipairs(lines) do
				if line:match("^%s*%[C%] Contributions%s+%[A%] AI%s*$") then
					ai_menu_line = i
					break
				end
			end
			assert.is_not_nil(ai_menu_line)
			local ai_button_col = lines[ai_menu_line]:find("[A]", 1, true) - 1
			vim.api.nvim_buf_call(buf_id, function()
				vim.api.nvim_win_set_cursor(0, { ai_menu_line, ai_button_col + #"[A]" + 1 })
				vim.api.nvim_feedkeys(vim.keycode("<CR>"), "x", false)
			end)
			assert.equals(0, fetch_ai_usage_calls)

			vim.api.nvim_buf_call(buf_id, function()
				vim.api.nvim_win_set_cursor(0, { ai_menu_line, ai_button_col })
				vim.api.nvim_feedkeys(vim.keycode("<CR>"), "x", false)
			end)

			vim.wait(300, function()
				local panel = table.concat(vim.api.nvim_buf_get_lines(buf_id, 0, -1, false), "\n")
				return fetch_ai_usage_calls == 1 and panel:find("AI Usage", 1, true) ~= nil
			end)
			lines = vim.api.nvim_buf_get_lines(buf_id, 0, -1, false)
			joined = table.concat(lines, "\n")
			assert.equals(1, fetch_ai_usage_calls)
			assert.matches("AI Usage", joined)
			assert.matches("Additional budget", joined)
			assert.matches("Included AI credits", joined)
			assert.matches("Over%-pool AI credits", joined)
			local ai_title = lines[separator_idx + 1]:gsub("^%s+", "")
			assert.equals("AI Usage", ai_title)
			assert.is_true(#lines > 0)

			GithubService.fetch_ai_usage = original_fetch_ai_usage
			vim.api.nvim_buf_delete(buf_id, { force = true })
		end)

		it("focuses the contributions graph with C or Enter on the Contributions menu button", function()
			local Contribution = require("nvim-gh-dashboard.contribution")
			local buf_id = vim.api.nvim_create_buf(false, true)
			local contributions = {}
			for day = 0, 6 do
				local metadata = ContributionMetadata.new(tostring(day), "0", "5 contributions on January 21.")
				table.insert(contributions, Contribution.new(metadata))
			end

			DashboardView.render_dashboard(buf_id, contributions, nil, 2024, "octocat", default_chars)

			local lines = vim.api.nvim_buf_get_lines(buf_id, 0, -1, false)
			local menu_line
			local graph_line
			for i, line in ipairs(lines) do
				if line:match("^%s*%[C%] Contributions%s+%[A%] AI%s*$") then
					menu_line = i
				elseif not graph_line and line:match("^%s*#%s*$") then
					graph_line = i
				end
			end
			assert.is_not_nil(menu_line)
			assert.is_not_nil(graph_line)

			local contributions_button_col = lines[menu_line]:find("[C]", 1, true) - 1
			local graph_col = lines[graph_line]:find("#", 1, true) - 1
			vim.api.nvim_set_current_buf(buf_id)

			vim.api.nvim_win_set_cursor(0, { menu_line, contributions_button_col })
			vim.api.nvim_feedkeys("C", "mx", false)
			assert.same({ graph_line, graph_col }, vim.api.nvim_win_get_cursor(0))

			vim.api.nvim_win_set_cursor(0, { menu_line, contributions_button_col })
			vim.api.nvim_feedkeys(vim.keycode("<CR>"), "x", false)
			assert.same({ graph_line, graph_col }, vim.api.nvim_win_get_cursor(0))

			vim.api.nvim_buf_delete(buf_id, { force = true })
		end)
	end)

	describe("cursor tracking", function()
		it("centers contribution details in the dashboard window", function()
			local buf_id = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_set_current_buf(buf_id)
			vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, vim.fn["repeat"]({ "" }, 20))

			local tooltip = "5 contributions on January 21."
			local contributions_graph = {
				height = 7,
				grid = {
					{
						{ tooltip = tooltip },
					},
				},
			}
			local activity_graph = { height = 0 }
			local total_height = 14
			vim.api.nvim_win_set_cursor(0, { 8, 0 })

			CursorTracking.update_contribution_details(buf_id, contributions_graph, activity_graph, total_height, 0)

			local expected_pad = math.floor((vim.api.nvim_win_get_width(0) - vim.fn.strdisplaywidth(tooltip)) / 2)
			local detail_line = vim.api.nvim_buf_get_lines(buf_id, total_height + 2, total_height + 3, false)[1]
			assert.equals(string.rep(" ", expected_pad) .. tooltip, detail_line)

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
					on_success({ contributions = metadata_list, activity = nil, user_page = "" })
				end)
			end

			local buf_id = DashboardView.open_dashboard("octocat", 2024, default_chars)

			-- Immediately after opening, the buffer must already exist and show
			-- a loading indicator rather than being blocked until data arrives.
			assert.is_true(vim.api.nvim_buf_is_valid(buf_id))
			local initial_lines = vim.api.nvim_buf_get_lines(buf_id, 0, -1, false)
			assert.matches("User: octocat", table.concat(initial_lines, "\n"))
			local initial_menu_line
			local initial_user_line
			for i, line in ipairs(initial_lines) do
				if line:match("^%s*%[C%] Contributions%s+%[A%] AI%s*$") then
					initial_menu_line = i
				elseif line:match("^%s*User: octocat%s*$") then
					initial_user_line = i
				end
			end
			assert.is_not_nil(initial_menu_line)
			assert.same(
				{ initial_menu_line, initial_lines[initial_menu_line]:find("[C]", 1, true) - 1 },
				vim.api.nvim_win_get_cursor(0)
			)
			assert.is_not_nil(initial_user_line)

			local dashboard_rendered = vim.wait(300, function()
				local lines = vim.api.nvim_buf_get_lines(buf_id, 0, -1, false)
				for _, line in ipairs(lines) do
					if line:match("^%s*" .. default_chars.filled .. "%s*$") then
						return true
					end
				end
				return false
			end)
			assert.is_true(dashboard_rendered)

			local rendered_lines = vim.api.nvim_buf_get_lines(buf_id, 0, -1, false)
			local rendered_user_line
			for i, line in ipairs(rendered_lines) do
				if line:match("^%s*User: octocat%s*$") then
					rendered_user_line = i
					break
				end
			end
			assert.equals(initial_user_line, rendered_user_line)
			assert.same(
				{ initial_menu_line, initial_lines[initial_menu_line]:find("[C]", 1, true) - 1 },
				vim.api.nvim_win_get_cursor(0)
			)

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
