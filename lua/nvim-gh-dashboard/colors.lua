local M = {}

---Default highlight group definitions.
---
---Each entry is a table compatible with `vim.api.nvim_set_hl`'s `{val}` argument.
---Colors are not hard-coded; instead every group is `link`-ed to a highlight
---group that is virtually guaranteed to already be defined by whatever
---colorscheme is loaded (built-in groups such as `String`, `Title`,
---`DiagnosticWarn`, ...). This means the dashboard automatically adapts its
---colors to the user's current colorscheme/palette.
---@type table<string, table>
M.defaults = {
	-- Header
	GHDashboardHeaderBorder = { link = "FloatBorder" },
	GHDashboardHeaderTitle = { link = "Title" },
	GHDashboardHeaderLabel = { link = "Comment" },
	GHDashboardHeaderValue = { link = "Identifier" },

	-- Contributions graph: intensity scale, from "no contributions" to the
	-- highest tier (100+ contributions in a single day), mirroring the
	-- multiple shades of green used on github.com.
	GHDashboardEmpty = { link = "Comment" },
	GHDashboardLevel1 = { link = "DiagnosticHint" },
	GHDashboardLevel2 = { link = "DiagnosticInfo" },
	GHDashboardLevel3 = { link = "DiagnosticOk" },
	GHDashboardLevel4 = { link = "String" },
	-- 100+ contributions in a single day: intentionally distinct from the
	-- green scale above so it stands out at a glance.
	GHDashboardHigh = { link = "DiagnosticWarn", bold = true },

	-- Activity graph (percentage bars)
	GHDashboardActivityLabel = { link = "Identifier" },
	GHDashboardActivityBorder = { link = "NonText" },
	GHDashboardActivityBarFilled = { link = "Function" },
	GHDashboardActivityBarEmpty = { link = "Comment" },
	GHDashboardActivityPercent = { link = "Number" },
}

---Sets up (defines) all the highlight groups used by the dashboard, applying
---any user-provided overrides on top of the defaults.
---@param colors table|nil user overrides, keyed by highlight group name. Each
---value is merged into (and overrides) the corresponding default definition,
---using the same shape accepted by `vim.api.nvim_set_hl` (e.g. `{ fg = "#ff0000" }`,
---`{ link = "MyGroup" }`, `{ bold = true }`, ...).
function M.setup(colors)
	colors = colors or {}

	for name, default_definition in pairs(M.defaults) do
		local override = colors[name]
		local definition = default_definition

		if override then
			definition = vim.tbl_deep_extend("force", {}, default_definition, override)
			-- Overriding with explicit colors should not keep a stale `link`
			-- around, otherwise the link would take precedence over fg/bg.
			if override.link == nil and (override.fg or override.bg or override.ctermfg or override.ctermbg) then
				definition.link = nil
			end
		end

		vim.api.nvim_set_hl(0, name, definition)
	end
end

return M
