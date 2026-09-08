local M = {}

local buffer_helpers = require("nvim-gh-dashboard.buffer-helpers")

-- vim.uv is the new name (Neovim >= 0.10), vim.loop is kept for older versions
local uv = vim.uv or vim.loop

M.spinner_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
M.spinner_interval_ms = 80

---Starts an animated Braille spinner on the given line of the buffer.
---@param buf_id number
---@param line_idx number 0-based line index to animate
---@param message string|nil Message to show next to the spinner
---@return uv.uv_timer_t timer Timer handle; call `M.stop(timer)` to stop it
function M.start(buf_id, line_idx, message)
	local frame_idx = 1
	local timer = uv.new_timer()

	timer:start(
		0,
		M.spinner_interval_ms,
		vim.schedule_wrap(function()
			if not vim.api.nvim_buf_is_valid(buf_id) then
				M.stop(timer)
				return
			end

			local frame = M.spinner_frames[frame_idx]
			buffer_helpers.update_line(buf_id, line_idx, frame .. " " .. (message or "Loading..."))

			frame_idx = (frame_idx % #M.spinner_frames) + 1
		end)
	)

	return timer
end

---Stops and closes a spinner timer created by `M.start`
---@param timer uv.uv_timer_t|nil
function M.stop(timer)
	if timer and not timer:is_closing() then
		timer:stop()
		timer:close()
	end
end

return M
