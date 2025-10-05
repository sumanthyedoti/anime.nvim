local M = {}

local saved_maps = {}

local function save_users_keymaps()
	local keys_to_override = { " ar", " ae", " aa", " as", " an", " ap", " ak", "ao" }
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
	vim.keymap.set("n", "<leader>ar", ":AnimeRecord<CR>", { desc = "Start Anime record" })
	vim.keymap.set("n", "<leader>ae", ":AnimeRecordStop<CR>", { desc = "Stop Anime record" })
	vim.keymap.set("n", "<leader>aa", ":AnimePlay<CR>", { desc = "Start Anime play" })
	vim.keymap.set("n", "<leader>as", ":AnimePlayStop<CR>", { desc = "Stop Anime play" })
	vim.keymap.set("n", "<leader>am", ":AnimeNoteAdd<CR>", { desc = "Add note" })
	vim.keymap.set("n", "<leader>an", ":AnimeNoteNext<CR>", { desc = "Show next note" })
	vim.keymap.set("n", "<leader>ap", ":AnimeNotePrev<CR>", { desc = "Show prev note" })
	vim.keymap.set("n", "<leader>ak", ":AnimeKeymapsSet<CR>", { desc = "Set Anime keymaps" })
	vim.keymap.set("n", "<leader>ao", ":AnimeKeymapsRestore<CR>", { desc = "Restore normal keymaps" })
end

function M.restore_keymaps()
	vim.notify("Restoring keymaps", vim.log.levels.INFO)
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
