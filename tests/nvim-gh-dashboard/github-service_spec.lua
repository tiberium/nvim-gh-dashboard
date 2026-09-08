local fixtures = require("tests.nvim-gh-dashboard.fixtures")

describe("github-service", function()
	local GithubService

	before_each(function()
		package.loaded["github-service"] = nil
		package.loaded["plenary.curl"] = nil
		GithubService = require("nvim-gh-dashboard.github-service")
	end)

	describe("parse_contributions", function()
		it("extracts every contribution tool-tip", function()
			local html = fixtures.page(fixtures.sample_entries)

			local contributions = GithubService.parse_contributions(html)

			assert.equals(3, #contributions)
			assert.equals("0", contributions[1].day)
			assert.equals("3", contributions[1].week)
			assert.equals("5 contributions on January 21.", contributions[1].tooltip)
			assert.equals("No contributions on January 22.", contributions[2].tooltip)
			assert.equals("12+ contributions on January 23.", contributions[3].tooltip)
		end)

		it("returns an empty list when there are no tool-tips", function()
			local html = fixtures.page({})

			local contributions = GithubService.parse_contributions(html)

			assert.same({}, contributions)
		end)
	end)

	describe("parse_activity", function()
		it("extracts the activity percentages", function()
			local html = fixtures.page(fixtures.sample_entries, { with_activity = true })

			local activity = GithubService.parse_activity(html)

			assert.is_not_nil(activity)
			assert.equals("70", activity.commits)
			assert.equals("10", activity.code_review)
			assert.equals("15", activity.pull_requests)
			assert.equals("5", activity.issues)
		end)

		it("returns nil when the activity container is missing", function()
			local html = fixtures.page(fixtures.sample_entries, { with_activity = false })

			local activity = GithubService.parse_activity(html)

			assert.is_nil(activity)
		end)
	end)

	describe("parse_dashboard_data", function()
		it("combines contributions and activity from a single page", function()
			local html = fixtures.page(fixtures.sample_entries)

			local data = GithubService.parse_dashboard_data(html)

			assert.equals(3, #data.contributions)
			assert.is_not_nil(data.activity)
			assert.equals("70", data.activity.commits)
		end)
	end)

	describe("fetch_dashboard_data", function()
		it("uses the cached page and does not hit the network again", function()
			local html = fixtures.page(fixtures.sample_entries)
			local get_calls = 0

			package.loaded["plenary.curl"] = {
				get = function(_, opts)
					get_calls = get_calls + 1
					opts.callback({ status = 200, body = html })
				end,
			}

			local first_result, second_result

			GithubService.fetch_dashboard_data("octocat", 2024, true, function(data)
				first_result = data
			end, function(message)
				error("unexpected error: " .. message)
			end)

			vim.wait(200, function()
				return first_result ~= nil
			end)
			assert.is_not_nil(first_result)

			GithubService.fetch_dashboard_data("octocat", 2024, true, function(data)
				second_result = data
			end, function(message)
				error("unexpected error: " .. message)
			end)

			assert.is_not_nil(second_result)
			assert.equals(1, get_calls)
		end)

		it("fetches once and resolves both contributions and activity on success", function()
			local html = fixtures.page(fixtures.sample_entries)
			local requested_url

			package.loaded["plenary.curl"] = {
				get = function(url, opts)
					requested_url = url
					opts.callback({ status = 200, body = html })
				end,
			}

			local result
			GithubService.fetch_dashboard_data("octocat", 2024, false, function(data)
				result = data
			end, function(message)
				error("unexpected error: " .. message)
			end)

			vim.wait(200, function()
				return result ~= nil
			end)

			assert.is_not_nil(result)
			assert.equals(3, #result.contributions)
			assert.is_not_nil(result.activity)
			assert.matches("octocat", requested_url)
			assert.matches("2024%-12%-01", requested_url)
		end)

		it("calls on_error when the response status is not 200", function()
			package.loaded["plenary.curl"] = {
				get = function(_, opts)
					opts.callback({ status = 404, body = "" })
				end,
			}

			local error_message
			GithubService.fetch_dashboard_data("octocat", nil, false, function()
				error("unexpected success")
			end, function(message)
				error_message = message
			end)

			vim.wait(200, function()
				return error_message ~= nil
			end)

			assert.is_not_nil(error_message)
			assert.matches("404", error_message)
		end)

		it("calls on_error when the curl job fails", function()
			package.loaded["plenary.curl"] = {
				get = function(_, opts)
					opts.on_error({ message = "connection refused" })
				end,
			}

			local error_message
			GithubService.fetch_dashboard_data("octocat", nil, false, function()
				error("unexpected success")
			end, function(message)
				error_message = message
			end)

			vim.wait(200, function()
				return error_message ~= nil
			end)

			assert.is_not_nil(error_message)
			assert.matches("connection refused", error_message)
		end)
	end)
end)
