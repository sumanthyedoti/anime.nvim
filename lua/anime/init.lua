local M = {}
local vim_utils = require("anime.vim_utils")
local CONSTANTS = require("anime.constants")

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

function M.record_code()
	local mode = vim.fn.mode()

	if mode:match("^[vV]") then -- Check if we're in visual mode
		vim.cmd("normal! ") -- Exit visual mode first to update marks
	end

	local lines = vim_utils.get_visual_selection()

	if #lines > 0 then
		state.recorded_lines = lines
		state.recorded_text = table.concat(lines, CONSTANTS.newline_char)
		state.is_recording = false

		print(string.format("Recorded %d line(s) of code", #lines))

		vim.notify("Code recorded successfully!\nUse :PlayCode to animate playback", vim.log.levels.INFO)
	else
		vim.notify("No text selected", vim.log.levels.WARN)
	end
end

local autoindent = vim.o.autoindent

local function before_play()
	state.is_playing = true
	local cmp = require("cmp") -- Disable auto-completion suggestions
	if cmp then
		cmp.setup.buffer({ enabled = false })
	end
	vim.api.nvim_feedkeys("a", "n", true)
	vim.o.autoindent = false
end

local function after_play()
	state.is_playing = false
	-- Exit insert mode
	vim.api.nvim_feedkeys(t("<ESC>"), "n", true)
	vim.cmd("stopinsert")
	vim.o.autoindent = autoindent
end

function M.play_code(opts)
	opts = opts or {}
	local delay = opts.delay or 50 -- milliseconds between characters

	if not state.recorded_text then
		vim.notify("No code recorded. Use :RecordCode with visual selection first", vim.log.levels.WARN)
		return
	end

	local characters = {}
	print("state.recorded_text", state.recorded_text)
	for char in state.recorded_text:gmatch(".") do
		table.insert(characters, char)
	end

	local char_index = 1

	before_play()

	local function animate()
		if char_index > #characters or not state.is_playing then
			vim.notify("Playback complete!", vim.log.levels.INFO)
			state.is_playing = false
			after_play()
			return
		end

		local char = characters[char_index]
		print("char", char)
		if char == CONSTANTS.newline_char then
			print("newline")
			vim.api.nvim_feedkeys(t("<CR>"), "m", true)
		else
			vim.api.nvim_feedkeys(t(char), "m", true)
		end

		char_index = char_index + 1

		-- vim.api.nvim_feedkeys(t("<ESC>"), "m", true)
		vim.defer_fn(animate, delay)
	end

	animate()
end

function M.stop_playback()
	state.is_playing = false
	vim.notify("Playback stopped", vim.log.levels.INFO)
end

function M.clear_recording()
	state.recorded_text = nil
	state.recorded_lines = {}
	state.is_recording = false
	vim.notify("Recording cleared", vim.log.levels.INFO)
end

vim.api.nvim_create_user_command("AnimeRecord", function()
	M.record_code()
end, { range = true, desc = "Record selected code for animation" })

vim.api.nvim_create_user_command("AnimePlay", function()
	M.play_code({ delay = 200, word_mode = false })
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

return M
