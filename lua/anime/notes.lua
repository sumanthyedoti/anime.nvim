local M = {}

function M.show_note(text)
	-- Split annotation text into lines for better display
	local lines = vim.split(text, "\n", { plain = true })

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].filetype = "markdown"
	vim.bo[buf].modifiable = false
	vim.bo[buf].bufhidden = "wipe"

	-- Calculate popup size
	local width = 60
	local height = math.min(#lines + 2, 20) -- Max height of 20 lines
	-- Get editor dimensions
	local ui = vim.api.nvim_list_uis()[1]
	local row = math.floor((ui.height - height) / 2)
	local col = math.floor((ui.width - width) / 2)

	local opts = {
		relative = "cursor",
		row = 1,
		col = 0,
		-- width = 40,
		-- height = 5,
		-- row = row,
		-- col = col,
		width = width,
		height = height,
		style = "minimal",
		-- border = {
		-- 	"╭",
		-- 	"─",
		-- 	"╮",
		-- 	"│",
		-- 	"╯",
		-- 	"─",
		-- 	"╰",
		-- 	"│",
		-- },
		border = {
			"╔",
			"═",
			"╗",
			"║",
			"╝",
			"═",
			"╚",
			"║",
		},
		title = " 🗈Note ",
		title_pos = "left",
	}

	local win = vim.api.nvim_open_win(buf, true, opts)

	vim.wo[win].wrap = true
	vim.wo[win].linebreak = true

	local function close_popup()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end
	vim.keymap.set("n", "q", close_popup)
	vim.keymap.set("n", "<Esc>", close_popup)
end

vim.api.nvim_create_user_command("QuickChat", M.show_note, {})

return M
