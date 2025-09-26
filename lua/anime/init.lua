local M = {}
local vim_utils = require("anime.vim_utils")

-- State management
local state = {
	recorded_text = nil,
	recorded_lines = {},
	buffer = nil,
	window = nil,
	is_recording = false,
	is_playing = false,
}

local function t(str)
	return vim.api.nvim_replace_termcodes(str, true, false, true)
end

-- Function to record code from visual selection
function M.record_code()
	local mode = vim.fn.mode()

	-- Check if we're in visual mode
	if mode:match("^[vV]") then
		-- Exit visual mode first to update marks
		vim.cmd("normal! ")
	end

	-- Get the visual selection
	local lines = vim_utils.get_visual_selection()

	if #lines > 0 then
		state.recorded_lines = lines
		state.recorded_text = table.concat(lines, "\n")
		state.is_recording = false

		print(string.format("Recorded %d line(s) of code", #lines))

		-- Optionally show what was recorded
		vim.notify("Code recorded successfully!\nUse :PlayCode to animate playback", vim.log.levels.INFO)
	else
		vim.notify("No text selected", vim.log.levels.WARN)
	end
end

-- Function to play back recorded code with animation
function M.play_code(opts)
	opts = opts or {}
	local delay = opts.delay or 50 -- milliseconds between characters
	local word_mode = opts.word_mode or false -- if true, animate word by word

	if not state.recorded_text then
		vim.notify("No code recorded. Use :RecordCode with visual selection first", vim.log.levels.WARN)
		return
	end

	-- Create a new buffer for playback
	-- state.buffer = vim.api.nvim_create_buf(false, true)
	state.buffer = vim.api.nvim_get_current_buf()

	-- vim.cmd("split") -- Open buffer in a new window (split)
	state.window = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(state.window, state.buffer)

	-- Start animation
	state.is_playing = true

	-- Prepare text chunks (words or characters)
	local chunks = {}
	-- Split into individual characters
	for char in state.recorded_text:gmatch(".") do
		table.insert(chunks, char)
	end

	local chunk_index = 1

	vim.api.nvim_feedkeys(t("a"), "m", true)
	local function animate()
		if chunk_index > #chunks or not state.is_playing then
			vim.notify("Playback complete!", vim.log.levels.INFO)
			state.is_playing = false
			return
		end

		local chunk = chunks[chunk_index]
		vim.bo[state.buffer].autoindent = false
		if chunk == "\n" then
			vim.api.nvim_feedkeys(t("<CR>"), "m", true)
		else
			vim.api.nvim_feedkeys(t(chunk), "m", true)
		end

		chunk_index = chunk_index + 1

		-- Schedule next chunk
		vim.defer_fn(animate, delay)
	end

	-- Start animation
	animate()
end

-- Function to stop playback
function M.stop_playback()
	state.is_playing = false
	vim.notify("Playback stopped", vim.log.levels.INFO)
end

-- Function to clear recorded code
function M.clear_recording()
	state.recorded_text = nil
	state.recorded_lines = {}
	state.is_recording = false
	vim.notify("Recording cleared", vim.log.levels.INFO)
end

-- Create commands immediately when the module is loaded
vim.api.nvim_create_user_command("AnimeRecord", function()
	M.record_code()
end, { range = true, desc = "Record selected code for animation" })

vim.api.nvim_create_user_command("AnimePlay", function()
	M.play_code({ delay = 500, word_mode = false })
end, { desc = "Play back recorded code with animation" })

vim.api.nvim_create_user_command("AnimePlayWords", function()
	M.play_code({ delay = 500, word_mode = true })
end, { desc = "Play back recorded code word by word" })

vim.api.nvim_create_user_command("AnimeStop", function()
	M.stop_playback()
end, { desc = "Stop code playback animation" })

vim.api.nvim_create_user_command("AnimeClearRecording", function()
	M.clear_recording()
end, { desc = "Clear recorded code" })

-- Return the module
return M
