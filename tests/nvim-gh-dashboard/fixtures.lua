-- Small, self-contained fixtures resembling the relevant fragments of a
-- GitHub user profile page ("...?tab=contributions").
local M = {}

---Builds a fake GitHub contributions page containing the given tool-tips.
---@param entries table[] list of { day = string, week = string, tooltip = string }
---@param opts table|nil { with_activity = boolean, achievements = string[], followers = string, following = string }
---@return string
function M.page(entries, opts)
	opts = opts or {}
	local parts = {}

	table.insert(parts, "<html><body>")

	if opts.with_activity ~= false then
		table.insert(
			parts,
			'<div class="js-activity-overview-graph-container"'
				.. "data-percentages="
				.. '"{&quot;Commits&quot;:70,&quot;Code review&quot;:10,&quot;Pull requests&quot;:15,&quot;Issues&quot;:5}"'
				.. "></div>"
		)
	end

	if opts.followers and opts.following then
		table.insert(
			parts,
			string.format(
				'<a class="Link--secondary" href="/octocat?tab=followers"><span class="text-bold">%s</span> followers</a>',
				opts.followers
			)
		)
		table.insert(
			parts,
			string.format(
				'<a class="Link--secondary" href="/octocat?tab=following"><span class="text-bold">%s</span> following</a>',
				opts.following
			)
		)
	end

	for _, entry in ipairs(entries or {}) do
		table.insert(
			parts,
			string.format(
				'<tool-tip class="sr-only" for="contribution-day-component-%s-%s">%s</tool-tip>',
				entry.day,
				entry.week,
				entry.tooltip
			)
		)
	end

	for _, achievement in ipairs(opts.achievements or {}) do
		table.insert(
			parts,
			string.format(
				'<img data-hovercard-type="achievement" '
					.. 'data-hovercard-url="/users/octocat/achievements/%s/detail?hovercard=1" '
					.. 'alt="Achievement: %s" class="achievement-badge-sidebar">',
				achievement:lower():gsub(" ", "-"),
				achievement
			)
		)
	end

	table.insert(parts, "</body></html>")

	return table.concat(parts, "\n")
end

M.sample_entries = {
	{ day = "0", week = "3", tooltip = "5 contributions on January 21." },
	{ day = "1", week = "3", tooltip = "No contributions on January 22." },
	{ day = "2", week = "3", tooltip = "12+ contributions on January 23." },
}

return M
