local vim_utils = require("anime.vim_utils")

local saved_maps = {}
local M = {}

local function save_users_keymaps()
	local keys_to_override = { " an", " ap" }
	local existing_keymaps = vim.api.nvim_get_keymap("n") -- keymaps for normal mode
	for _, map in ipairs(existing_keymaps) do
		for _, key in ipairs(keys_to_override) do
			if map.lhs == key then
				saved_maps[key] = map
			end
		end
	end
end

function M.set_keymaps()
	save_users_keymaps()
	vim.keymap.set("n", "<leader>an", ":AnimeNoteNext<CR>", { desc = "Show next note" })
	vim.keymap.set("n", "<leader>ap", ":AnimeNotePrev<CR>", { desc = "Show prev note" })
end

function M.restore_keymaps()
	print("restoring keymaps", table.concat(vim.tbl_keys(saved_maps), ", "))
	for _, key in ipairs(vim.tbl_keys(saved_maps)) do
		local keymap = saved_maps[key]
		vim.keymap.set("n", key, keymap.rhs or keymap.callback, {
			noremap = keymap.noremap == 1,
			silent = keymap.silent == 1,
			desc = keymap.desc,
		})
	end
	saved_maps = {}
end

return M
