local utils = require("anime.utils")
local M = {}

function M.get_visual_selection()
	local start_pos = vim.fn.getpos("'<")
	local end_pos = vim.fn.getpos("'>")

	local start_line = start_pos[2]
	local start_col = start_pos[3]
	local end_line = end_pos[2]
	local end_col = end_pos[3]

	local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
	lines = utils.trim_lines(lines)

	-- Handle single line selection
	if #lines == 1 then
		lines[1] = string.sub(lines[1], start_col, end_col)
	else
		-- Handle multi-line selection
		if #lines > 0 then
			-- Trim first line from start_col
			lines[1] = string.sub(lines[1], start_col)
			-- Trim last line up to end_col
			if #lines > 1 then
				lines[#lines] = string.sub(lines[#lines], 1, end_col)
			end
		end
	end

	return lines
end

function M.char_at_cursor()
	local _, col = unpack(vim.api.nvim_win_get_cursor(0))
	local line = vim.api.nvim_get_current_line()
	return line:sub(col + 1, col + 1)
end

return M
