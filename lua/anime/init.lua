local M = {}
local utils = require("anime.utils")
local vim_utils = require("anime.vim_utils")
local notes = require("anime.notes")
local keymapping = require("anime.keymapping")

local config = {
	playback_delay = 75, -- milliseconds between frames
}

local state = {
	frames = {},
	frame_index = 1,
	is_recording = false,
	is_playing = false,
	recording_buffer = nil,
	playback_buffer = nil,
	playback_window = nil,

	notes = {},
	notes_line_numbers = {},
	notes_current_index = nil,
	notes_current_window = nil,
}

function M.setup(opts)
	config = vim.tbl_deep_extend("force", config, opts or {})
end

local function capture_frame()
	if not state.is_recording then
		return
	end

	local lines = vim.api.nvim_buf_get_lines(state.recording_buffer, 0, -1, false)
	local ok, cursor = pcall(vim.api.nvim_win_get_cursor, 0)

	if not ok or not cursor then
		return
	end

	table.insert(state.frames, {
		lines = vim.deepcopy(lines),
		cursor = { cursor[1], cursor[2] },
	})
end

function M.start_recording()
	if state.is_recording then
		vim.notify("Already recording!", vim.log.levels.WARN)
		return
	end

	state.frames = {}
	state.recording_buffer = vim.api.nvim_get_current_buf()
	state.is_recording = true

	capture_frame()

	local group = vim.api.nvim_create_augroup("AnimeRecording", { clear = true })

	vim.api.nvim_create_autocmd({ "TextChangedI", "TextChanged" }, {
		group = group,
		buffer = state.recording_buffer,
		callback = capture_frame,
	})

	vim.api.nvim_create_autocmd("CursorMovedI", {
		group = group,
		buffer = state.recording_buffer,
		callback = capture_frame,
	})

	vim.notify("Recording started! Use :AnimeStopRecord when done", vim.log.levels.INFO)
end

function M.stop_recording()
	if not state.is_recording then
		vim.notify("Not currently recording", vim.log.levels.WARN)
		return
	end

	capture_frame()
	state.is_recording = false
	vim.api.nvim_del_augroup_by_name("AnimeRecording")

	vim.notify(string.format("Recording stopped! Captured %d frames", #state.frames), vim.log.levels.INFO)
end

local cmp = require("cmp")

local function before_play()
	state.is_playing = true
	state.playback_buffer = vim.api.nvim_get_current_buf()
	state.playback_window = vim.api.nvim_get_current_win()
	notes.clear_notes_gutter_signs()
	vim.api.nvim_buf_set_lines(state.playback_buffer, 0, -1, false, {})
	vim.cmd("LspStop") -- Disable LSP to prevent diagnostics during playback
	if cmp then -- Disable auto-completion suggestions
		cmp.setup.buffer({ enabled = false })
	end
end

local function after_play()
	state.frame_index = 1
	state.is_playing = false
	notes.render_notes_gutter_signs(vim.tbl_keys(state.notes))
	vim.cmd("LspStart") -- Re-enable LSP
	if cmp then -- Re-enable auto-completion suggestions
		cmp.setup.buffer({ enabled = true })
	end
end

function M.play()
	if #state.frames == 0 then
		vim.notify("No recording found. Use :AnimeStartRecord first", vim.log.levels.WARN)
		return
	end

	before_play()
	local function animate()
		if state.frame_index > #state.frames or not state.is_playing then
			after_play()
			vim.notify("Playback complete!", vim.log.levels.INFO)
			return
		end
		local frame = state.frames[state.frame_index]

		vim.api.nvim_buf_set_lines(state.playback_buffer, 0, -1, false, frame.lines)

		local line_count = vim.api.nvim_buf_line_count(state.playback_buffer)
		local cursor_line = math.min(frame.cursor[1], line_count)
		local line = vim.api.nvim_buf_get_lines(state.playback_buffer, cursor_line - 1, cursor_line, false)[1]
		local cursor_col = math.min(frame.cursor[2], #line)

		pcall(vim.api.nvim_win_set_cursor, state.playback_window, { cursor_line, cursor_col })

		state.frame_index = state.frame_index + 1

		vim.defer_fn(animate, config.playback_delay)
	end

	animate()
end

function M.stop()
	state.is_playing = false
	vim.notify("Playback stopped", vim.log.levels.INFO)
end

function M.clear_recording()
	if state.is_recording then
		M.stop_recording()
	end
	state.frames = {}
	vim.notify("Recording cleared", vim.log.levels.INFO)
end

local function save_note(line, text)
	state.notes[line] = text
	local noted_lines = vim.tbl_keys(state.notes)
	notes.render_notes_gutter_signs(noted_lines)
end

local function update_note_lines()
	state.note_lines = vim.tbl_keys(state.notes)
	table.sort(state.note_lines)
end

function M.add_note()
	local line = vim.fn.line(".")
	local buf = vim.api.nvim_create_buf(false, true)
	local width = math.floor(vim.o.columns * 0.4)
	local height = math.floor(vim.o.lines * 0.3)

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "cursor",
		width = width,
		height = height,
		row = 1,
		col = 4,
		border = "rounded",
		title = " 🗈Add Note ",
	})

	vim.bo[buf].filetype = "markdown"

	vim.keymap.set("n", "q", notes.close_popup_win__closure(win))
	vim.keymap.set("n", "<Esc>", notes.close_popup_win__closure(win))

	vim.keymap.set("n", "<CR>", function()
		local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		vim.api.nvim_win_close(win, true)
		save_note(line, table.concat(lines, "\n"))

		update_note_lines()
	end, { buffer = buf })
end

function M.list_notes()
	if vim.tbl_isempty(state.notes) then
		vim.notify("No notes found", vim.log.levels.INFO)
		return
	end

	local lines = { "Notes:" }
	for line_num, text in pairs(state.notes) do
		table.insert(lines, string.format("  Line %d: %s", line_num, text:sub(1, 50)))
	end

	vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end

function M.show_note()
	local current_line_num = vim.api.nvim_win_get_cursor(0)[1]
	local current_line_note = state.notes[current_line_num]

	if not current_line_note then
		vim.notify("No note on this line", vim.log.levels.WARN)
		return
	end

	notes.show_note(current_line_note)
end

function M.remove_note()
	local line = vim.api.nvim_win_get_cursor(0)[1]

	if state.notes[line] then
		state.notes[line] = nil
		notes.render_notes_gutter_signs(vim.tbl_keys(state.notes))
		update_note_lines()
	else
		vim.notify("No note on this line", vim.log.levels.WARN)
	end
end

function M.go_to_next_note()
	if vim.tbl_isempty(state.notes) then
		return
	end

	notes.close_popup_win__closure(state.notes_current_window)()
	state.notes_current_window = nil

	local current_line_num = vim_utils.get_current_line_number()
	local next_note_line_num = utils.bigger_value(state.note_lines, current_line_num)
	local next_note = state.notes[next_note_line_num]
	vim.api.nvim_win_set_cursor(0, { next_note_line_num, 0 })
	state.notes_current_window = notes.show_note(next_note)
end

function M.go_to_prev_note()
	if vim.tbl_isempty(state.notes) then
		return
	end

	notes.close_popup_win__closure(state.notes_current_window)()
	state.notes_current_window = nil

	local current_line_num = vim_utils.get_current_line_number()
	local prev_note_line_num = utils.smaller_value(state.note_lines, current_line_num)
	local prev_note = state.notes[prev_note_line_num]
	vim.api.nvim_win_set_cursor(0, { prev_note_line_num, 0 })
	state.notes_current_window = notes.show_note(prev_note)
end

vim.api.nvim_create_user_command("AnimeRecord", M.start_recording, {
	desc = "Start recording buffer changes",
})

vim.api.nvim_create_user_command("AnimeRecordStop", M.stop_recording, {
	desc = "Stop recording buffer changes",
})

vim.api.nvim_create_user_command("AnimeRecordClear", M.clear_recording, {
	desc = "Clear current recording",
})

vim.api.nvim_create_user_command("AnimePlay", M.play, {
	desc = "Play back recorded changes",
})

vim.api.nvim_create_user_command("AnimePlayStop", M.stop, {
	desc = "Stop playback",
})

vim.api.nvim_create_user_command("AnimeNoteAdd", M.add_note, {
	desc = "Add Node",
})

vim.api.nvim_create_user_command("AnimeNoteShow", M.show_note, {
	desc = "Show Note",
})

vim.api.nvim_create_user_command("AnimeNoteRemove", M.remove_note, {
	desc = "Remove Note",
})

vim.api.nvim_create_user_command("AnimeNotesList", M.list_notes, {
	desc = "List Notes",
})

vim.api.nvim_create_user_command("AnimeNoteNext", M.go_to_next_note, {
	desc = "Show next note",
})

vim.api.nvim_create_user_command("AnimeNotePrev", M.go_to_prev_note, {
	desc = "Show next note",
})

vim.api.nvim_create_user_command("AnimeKeymapsSet", keymapping.set_keymaps, {
	desc = "Set Anime keymaps",
})

vim.api.nvim_create_user_command("AnimeKeymapsRestore", keymapping.restore_keymaps, {
	desc = "Resore Anime keymaps",
})

return M
