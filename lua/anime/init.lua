local M = {}

-- Default configuration
local config = {
	playback_delay = 75, -- milliseconds between snapshots
}

-- State management
local state = {
	snapshots = {},
	is_recording = false,
	is_playing = false,
	recording_buffer = nil,
	playback_buffer = nil,
	playback_window = nil,
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

	table.insert(state.snapshots, {
		lines = vim.deepcopy(lines),
		cursor = { cursor[1], cursor[2] },
	})
end

function M.start_recording()
	if state.is_recording then
		vim.notify("Already recording!", vim.log.levels.WARN)
		return
	end

	state.snapshots = {}
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

	vim.api.nvim_buf_set_lines(state.playback_buffer, 0, -1, false, {})

	vim.cmd("LspStop") -- Disable LSP to prevent diagnostics during playback
	if cmp then -- Disable auto-completion suggestions
		cmp.setup.buffer({ enabled = false })
	end
end

local function after_play()
	state.frame_index = 1
	state.is_playing = false

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

function M.clear()
	if state.is_recording then
		M.stop_recording()
	end
	state.frames = {}
	vim.notify("Recording cleared", vim.log.levels.INFO)
end

-- Create commands
vim.api.nvim_create_user_command("AnimeRecordStart", M.start_recording, {
	desc = "Start recording buffer changes",
})

vim.api.nvim_create_user_command("AnimeRecordStop", M.stop_recording, {
	desc = "Stop recording buffer changes",
})

vim.api.nvim_create_user_command("AnimeRecordClear", M.clear, {
	desc = "Clear current recording",
})

vim.api.nvim_create_user_command("AnimePlay", M.play, {
	desc = "Play back recorded changes",
})

vim.api.nvim_create_user_command("AnimePlayStop", M.stop, {
	desc = "Stop playback",
})

return M
