# nvim-gh-dashboard Copilot Instructions

## Validation

This is a Neovim Lua plugin. CI runs the following commands:

```sh
# Check formatting (does not modify files)
stylua --check lua tests plugin

# Lint; `.luacheckrc` declares the global `vim`
luacheck lua tests plugin

# Run the complete Plenary Busted suite
PLENARY_PATH=/path/to/plenary.nvim \
  nvim --headless --noplugin -u tests/minimal_init.lua \
  -c "PlenaryBustedDirectory tests/nvim-gh-dashboard { minimal_init = 'tests/minimal_init.lua' }"

# Run one spec file
PLENARY_PATH=/path/to/plenary.nvim \
  nvim --headless --noplugin -u tests/minimal_init.lua \
  -c "PlenaryBustedFile tests/nvim-gh-dashboard/github-service_spec.lua"
```

`tests/minimal_init.lua` prepends the repository and Plenary to `runtimepath`.
It obtains Plenary from `PLENARY_PATH`, `.tests/plenary.nvim`, or common
lazy.nvim/packer locations, so set `PLENARY_PATH` when none of those exist.

## Architecture

- `plugin/nvim-gh-dashboard.lua` registers `:GHDashboard [username] [year]`;
  it passes command arguments to
  `require("nvim-gh-dashboard").open_dashboard()`, so the dashboard can be
  opened even when Neovim was started with file arguments.
- `lua/nvim-gh-dashboard/init.lua` validates and defaults configuration,
  applies colors, then delegates to `dashboard-view.open_dashboard()`.
- `dashboard-view.lua` owns the scratch, read-only dashboard buffer and
  coordinates the UI lifecycle. It renders a centered header and loading
  spinner immediately; after `github-service.fetch_dashboard_data()` resolves,
  it builds graph models, writes the final buffer contents, applies
  highlights, and enables cursor tracking.
- `github-service.lua` fetches GitHub's contribution-tab HTML through
  `plenary.curl`, parses contribution tooltips and activity percentages, and
  caches the last page by `(username, year)`. Its success and failure
  callbacks are scheduled onto Neovim's main event loop, so callers may update
  buffers directly.
- `contribution-metadata.lua` / `activity-metadata.lua` represent raw parsed
  values. `contribution.lua` turns a tooltip into a displayable contribution,
  including the count, GitHub high-tier marker, and intensity highlight group.
  `contributions-graph.lua` and `activity-graph.lua` produce aligned text lines
  plus 0-based highlight spans consumed by `dashboard-view.apply_highlights()`.
- `cursor-tracking.lua` translates a window cursor position into the
  contribution grid and writes the selected tooltip to the final buffer line.
  `spinner.lua` owns the libuv timer; `buffer-helpers.lua` is the required
  route for safely mutating the read-only buffer.

## Repository Conventions

- Avoid magic numbers in Lua. Define a descriptive local constant for every
  non-obvious numeric value (protocol status, API sentinel, index conversion,
  layout dimension, threshold, or unit conversion) and use it at every related
  call site. Leave only self-evident numeric data in tests and user-facing
  examples as literals.
- Keep UI-affecting asynchronous work on the main loop. Wrap Plenary HTTP
  callbacks with `vim.schedule_wrap` before touching Neovim state, and always
  stop/close spinner timers on both success and error paths.
- Dashboard rendering depends on exact positional contracts: graph highlight
  coordinates are 0-based and relative to graph lines; `dashboard-view` adds
  vertical and per-line horizontal centering offsets. If rendered line layout
  changes, update both the associated highlight offsets and cursor-tracking
  calculations.
- Use `buffer_helpers.with_modifiable_buffer()` or `update_line()` for writes
  after `dashboard-view.create_buffer()` has made the buffer read-only. The
  helper restores the original read-only state even when a write fails.
- Contribution text is parsed from GitHub profile HTML rather than a stable
  API. Maintain fixtures in `tests/nvim-gh-dashboard/fixtures.lua` and test
  parser changes with mocked `plenary.curl`; service tests clear
  `package.loaded["plenary.curl"]` so each test can replace it.
- Contribution grid rows are Sunday through Saturday (`weekday_number` 0–6)
  and columns are GitHub week numbers. Preserve this mapping in rendering and
  cursor selection; an inserted leading `false` placeholder aligns partial
  first weeks.
- Colors are defined only through `colors.lua` highlight groups, with
  colorscheme-linked defaults and merged user overrides. Add visual elements
  through this mechanism rather than hard-coded colors.
- Neovim runtime code lives under `lua/nvim-gh-dashboard/`; keep public
  modules and test descriptions hyphenated to match existing
  `require("nvim-gh-dashboard.<module>")` paths.
