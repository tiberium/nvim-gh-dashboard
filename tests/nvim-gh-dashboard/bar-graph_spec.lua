local ActivityGraph = require("nvim-gh-dashboard.activity-graph")
local AiUsageGraph = require("nvim-gh-dashboard.ai-usage-graph")
local Colors = require("nvim-gh-dashboard.colors")
local Contribution = require("nvim-gh-dashboard.contribution")
local ContributionMetadata = require("nvim-gh-dashboard.contribution-metadata")
local BarGraph = require("nvim-gh-dashboard.bar-graph")

describe("bar-graph", function()
	it("renders and highlights a bar from its state and colors", function()
		local bar = BarGraph.new({
			label = "Usage",
			used = 25,
			total = 100,
			width = 4,
			label_width = 8,
			label_separator = " ",
			value = "25%",
			value_separator = " ",
			chars = { filled = "#", empty = "." },
			colors = {
				label = "Label",
				border = "Border",
				filled = "Fill",
				empty = "Empty",
				value = "Value",
			},
		})

		assert.equals("Usage    [#...] 25%", bar:get_line())
		assert.same({
			{ line = 2, col_start = 0, col_end = 8, hl_group = "Label" },
			{ line = 2, col_start = 9, col_end = 10, hl_group = "Border" },
			{ line = 2, col_start = 10, col_end = 11, hl_group = "Fill" },
			{ line = 2, col_start = 11, col_end = 14, hl_group = "Empty" },
			{ line = 2, col_start = 14, col_end = 15, hl_group = "Border" },
			{ line = 2, col_start = 16, col_end = -1, hl_group = "Value" },
		}, bar:get_highlights(2))
	end)

	it("uses one configured fill color for every bar graph", function()
		local contribution = Contribution.new(ContributionMetadata.new("0", "0", "5 contributions on January 21."))
		local activity_graph = ActivityGraph.new({
			code_review = 0,
			commits = 50,
			pull_requests = 0,
			issues = 0,
		}, 2024, {})
		local ai_usage_graph = AiUsageGraph.new({
			additional_budget_credits = 100,
			additional_credits = 50,
			additional_amount = 0.5,
			included_credits = 100,
			included_credits_used = 50,
			over_pool_credits = 10,
		}, {})

		assert.equals("GHDashboardLevel2", contribution:get_highlight_group())
		assert.equals(BarGraph.FILLED_HIGHLIGHT_GROUP, activity_graph:get_highlights()[3].hl_group)
		assert.equals(BarGraph.FILLED_HIGHLIGHT_GROUP, ai_usage_graph:get_highlights()[4].hl_group)
		assert.is_not_nil(Colors.defaults[BarGraph.FILLED_HIGHLIGHT_GROUP])
	end)
end)
