# Color customization

`nvim-gh-dashboard` defines its colors through Neovim highlight groups. By
default, the groups link to built-in groups, so the dashboard uses the active
colorscheme without requiring explicit color values.

Override any group through `colors` in `setup()`. Definitions use the same
shape as `vim.api.nvim_set_hl()`:

```lua
require("nvim-gh-dashboard").setup({
  colors = {
    GHDashboardHigh = { fg = "#ff9e64", bold = true },
    GHDashboardBarGraphFill = { link = "DiagnosticOk" },
  },
})
```

An explicit foreground or background color replaces the default link.

## Highlight groups

| Highlight group | Default link | Used for |
|---|---|---|
| `GHDashboardHeaderBorder` | `FloatBorder` | Header box border |
| `GHDashboardHeaderBorderActive` | `GHDashboardHigh` | Header box border while showing contribution or achievement details |
| `GHDashboardHeaderTitle` | `Title` | Header title |
| `GHDashboardHeaderLabel` | `Comment` | `User:` and `Year:` labels |
| `GHDashboardHeaderValue` | `Identifier` | Username and year values |
| `GHDashboardAchievementsTitle` | `DiagnosticInfo` (bold) | Achievements heading |
| `GHDashboardAchievementsBorder` | `NonText` | Achievements border |
| `GHDashboardAchievementsEmpty` | `Comment` | Empty achievements state |
| `GHDashboardAchievementsError` | `DiagnosticError` | Achievements error state |
| `GHDashboardAchievementSymbol1` | `String` (bold) | Achievement badge |
| `GHDashboardAchievementSymbol2` | `Function` (bold) | Achievement badge |
| `GHDashboardAchievementSymbol3` | `DiagnosticHint` (bold) | Achievement badge |
| `GHDashboardAchievementSymbol4` | `DiagnosticInfo` (bold) | Achievement badge |
| `GHDashboardAchievementSymbol5` | `DiagnosticOk` (bold) | Achievement badge |
| `GHDashboardAchievementSymbol6` | `DiagnosticWarn` (bold) | Achievement badge |
| `GHDashboardAchievementSymbol7` | `Number` (bold) | Achievement badge |
| `GHDashboardAchievementSymbol8` | `Constant` (bold) | Achievement badge |
| `GHDashboardAchievementSymbol9` | `Special` (bold) | Achievement badge |
| `GHDashboardAchievementSymbol10` | `Type` (bold) | Achievement badge |
| `GHDashboardMenuShortcut` | `Function` (bold) | Menu shortcut |
| `GHDashboardMenuLabel` | `String` | Menu label |
| `GHDashboardSeparator` | `NonText` | Section separator |
| `GHDashboardEmpty` | `Comment` | Days with no contributions |
| `GHDashboardLevel1` | `DiagnosticHint` | Days with 1-3 contributions |
| `GHDashboardLevel2` | `DiagnosticInfo` | Days with 4-6 contributions |
| `GHDashboardLevel3` | `DiagnosticOk` | Days with 7-9 contributions |
| `GHDashboardLevel4` | `String` | Days with 10-99 contributions |
| `GHDashboardHigh` | `DiagnosticWarn` (bold) | Days with 100+ contributions |
| `GHDashboardBarGraphFill` | `Function` | Filled activity and AI Usage bars |
| `GHDashboardActivityLabel` | `Identifier` | Activity type label |
| `GHDashboardActivityBorder` | `NonText` | Activity bar brackets |
| `GHDashboardActivityBarEmpty` | `Comment` | Empty activity bar segment |
| `GHDashboardActivityPercent` | `Number` | Activity percentage |
| `GHDashboardAiUsageTitle` | `Title` | AI Usage heading |
| `GHDashboardAiUsageLabel` | `Identifier` | AI Usage labels |
| `GHDashboardAiUsageBorder` | `NonText` | AI Usage bar brackets |
| `GHDashboardAiUsageValue` | `Number` | AI Usage values |
