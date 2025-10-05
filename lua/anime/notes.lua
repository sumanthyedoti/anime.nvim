local M = {}

function M.show_note(text)
	-- Split note text into lines for better display
	local lines = vim.split(text, "\n", { plain = true })

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].filetype = "markdown"
	vim.bo[buf].modifiable = false
	vim.bo[buf].bufhidden = "wipe"

	-- Calculate popup size
	local width = 60
	local height = math.min(#lines + 2, 20) -- Max height of 20 lines

	local opts = {
		relative = "cursor", -- "cursor" | "editor"
		row = 1,
		col = 4,
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

	vim.keymap.set("n", "q", M.close_popup_win__closure(win))
	vim.keymap.set("n", "<Esc>", M.close_popup_win__closure(win))

	return win
end

M.render_notes_gutter_signs = function(lines)
	vim.fn.sign_unplace("AnimeNotesGutterGroup")
	for _, line in ipairs(lines) do
		vim.fn.sign_define(
			"AnimeNotesGutter",
			{ text = "🗈", texthl = "DiagnosticSignInfo", numhl = "DiagnosticSignInfo" }
		)
		vim.fn.sign_place(
			0,
			"AnimeNotesGutterGroup",
			"AnimeNotesGutter",
			vim.api.nvim_get_current_buf(),
			{ lnum = line }
		)
	end
end

M.clear_notes_gutter_signs = function()
	vim.fn.sign_unplace("AnimeNotesGutterGroup")
end

function M.close_popup_win__closure(win)
	return function()
		if win and vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end
end

return M
