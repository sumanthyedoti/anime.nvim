local M = {}
local utils = require("anime.utils")
local vim_utils = require("anime.vim_utils")
local notes = require("anime.notes")
local keymapping = require("anime.keymapping")

local config = {
	playback_delay = 200,
}

local state = {
	frames = {},
	is_recording = false,
	is_playing = false,
	recording_buffer = nil,
	playback_buffer = nil,
	playback_window = nil,
	notes = {},
	popup_win = nil,
	popup_buf = nil,
	last_lines = nil,
	last_cursor = nil,
}

local function calculate_delta(old_lines, new_lines, cursor)
	local old_count = #old_lines
	local new_count = #new_lines

	local delta = {
		line_changes = {},
		line_count = new_count,
		cursor = { cursor[1], cursor[2] },
	}

	-- Flag if lines were added or removed
	local line_diff = new_count - old_count
	if line_diff ~= 0 then
		delta.line_count_changed = true
	end

	-- Find changed lines
	local max_lines = math.max(old_count, new_count)
	for i = 1, max_lines do
		if old_lines[i] ~= new_lines[i] then
			delta.line_changes[i] = new_lines[i] or false
		end
	end

	return delta
end

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

	if #state.frames == 0 then -- First frame: store everything
		local initial_changes = {}
		for i, line in ipairs(lines) do
			initial_changes[i] = line
		end

		table.insert(state.frames, {
			line_changes = initial_changes,
			line_count = #lines,
			cursor = { cursor[1], cursor[2] },
		})
		state.last_lines = vim.deepcopy(lines)
		return
	end

	local delta = calculate_delta(state.last_lines, lines, cursor)

	-- Only store if there are actual changes
	if next(delta.line_changes) ~= nil then
		table.insert(state.frames, delta)
		state.last_lines = vim.deepcopy(lines)
	end
end

function M.start_recording()
	if state.is_recording then
		vim.notify("Already recording!", vim.log.levels.WARN)
		return
	end

	state.frames = {}
	state.last_lines = nil
	state.recording_buffer = vim.api.nvim_get_current_buf()
	state.is_recording = true

	capture_frame()

	local group = vim.api.nvim_create_augroup("AnimeRecording", { clear = true })

	vim.api.nvim_create_autocmd({ "TextChangedI", "TextChanged" }, {
		group = group,
		buffer = state.recording_buffer,
		callback = capture_frame,
	})

	vim.notify("Recording started! Use :AnimeRecordStop when done", vim.log.levels.INFO)
end

function M.stop_recording()
	if not state.is_recording then
		vim.notify("Not currently recording", vim.log.levels.WARN)
		return
	end

	capture_frame()
	state.is_recording = false
	vim.api.nvim_del_augroup_by_name("AnimeRecording")

	vim.notify(string.format("Recording stopped!"), vim.log.levels.INFO)
end

local cmp = require("cmp")

local function before_play()
	print(vim.inspect(state.frames))
	state.is_playing = true
	state.playback_buffer = vim.api.nvim_get_current_buf()
	state.playback_window = vim.api.nvim_get_current_win()
	vim.api.nvim_buf_set_lines(state.playback_buffer, 0, -1, false, {})
	vim.cmd("LspStop") -- Disable LSP to prevent diagnostics during playback
	if cmp then -- Disable auto-completion suggestions
		cmp.setup.buffer({ enabled = false })
	end
	notes.clear_notes_gutter_signs()
	keymapping.set_keymaps()
end

local function after_play()
	state.frame_index = 1
	state.is_playing = false
	vim.cmd("LspStart") -- Re-enable LSP
	if cmp then -- Re-enable auto-completion suggestions
		cmp.setup.buffer({ enabled = true })
	end
	if next(state.notes) ~= nil then
		notes.render_notes_gutter_signs(vim.tbl_keys(state.notes))
	end
	vim.notify("Playback complete!", vim.log.levels.INFO)
end

local function apply_delta(current_lines, delta)
	local new_lines = vim.deepcopy(current_lines)

	for line_num, content in pairs(delta.line_changes) do -- Apply line changes
		if content == false then -- Line was deleted
			new_lines[line_num] = nil
		else -- Line was changed or added
			new_lines[line_num] = content
		end
	end

	-- Handle line count changes (compact table to remove nils)
	if delta.line_count_changed then
		local compacted = {}
		for i = 1, delta.line_count do
			compacted[i] = new_lines[i] or ""
		end
		return compacted
	end

	return new_lines
end

function M.play()
	if #state.frames == 0 then
		vim.notify("No recording found. Use :AnimeRecordStart first", vim.log.levels.WARN)
		return
	end

	before_play()

	local frame_index = 1
	local current_buffer_state = {}

	local function animate()
		if frame_index > #state.frames or not state.is_playing then
			after_play()
			return
		end

		local frame = state.frames[frame_index]
		local cursor_pos = nil
		local delta = frame
		current_buffer_state = apply_delta(current_buffer_state, delta)

		-- Check if it's a multi line change
		local current_line_count = vim.api.nvim_buf_line_count(state.playback_buffer)
		local target_line_count = delta.line_count

		if math.abs(current_line_count - target_line_count) > 1 or delta.line_count_changed then
			-- Multi line change -- replace entire buffer
			vim.api.nvim_buf_set_lines(state.playback_buffer, 0, -1, false, current_buffer_state)
		else
			-- Single line change - update only changed lines
			for line_num, content in pairs(delta.line_changes) do
				if content == false then
					if line_num <= vim.api.nvim_buf_line_count(state.playback_buffer) then -- Delete line
						vim.api.nvim_buf_set_lines(state.playback_buffer, line_num - 1, line_num, false, {})
					end
				else -- Update existing line
					vim.api.nvim_buf_set_lines(state.playback_buffer, line_num - 1, line_num, false, { content })
				end
			end
		end

		cursor_pos = delta.cursor

		if cursor_pos then -- Set cursor position
			local cursor_line = math.min(cursor_pos[1], vim.api.nvim_buf_line_count(state.playback_buffer))
			local lines = vim.api.nvim_buf_get_lines(state.playback_buffer, cursor_line - 1, cursor_line, false)
			local line = lines[1] or ""
			local cursor_col = math.min(cursor_pos[2], #line)
			pcall(vim.api.nvim_win_set_cursor, state.playback_window, { cursor_line, cursor_col })
		end

		frame_index = frame_index + 1
		vim.defer_fn(animate, config.playback_delay)
	end

	animate()
end

function M.stop()
	state.is_playing = false
	keymapping.restore_keymaps()
	vim.notify("Playback stopped", vim.log.levels.INFO)
end

function M.clear_recording()
	if state.is_recording then
		M.stop_recording()
	end
	state.frames = {}
	state.notes = {}
	M.clear_caption_marks()
	vim.notify("Recording cleared", vim.log.levels.INFO)
end

local function save_note(line, text)
	state.notes[line] = text
	if next(state.notes) ~= nil then
		notes.render_notes_gutter_signs(vim.tbl_keys(state.notes))
	end
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
		notes.clear_notes_gutter_signs()
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
