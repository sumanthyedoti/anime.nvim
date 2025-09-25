local M = {}

-- State management
local state = {
	recorded_text = nil,
	recorded_lines = {},
	buffer = nil,
	window = nil,
	is_recording = false,
	is_playing = false,
}

-- Helper function to get visual selection
local function get_visual_selection()
	-- Get the visual selection marks
	local start_pos = vim.fn.getpos("'<")
	local end_pos = vim.fn.getpos("'>")

	local start_line = start_pos[2]
	local start_col = start_pos[3]
	local end_line = end_pos[2]
	local end_col = end_pos[3]

	-- Get the selected lines
	local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)

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

-- Function to record code from visual selection
function M.record_code()
	local mode = vim.fn.mode()

	-- Check if we're in visual mode
	if mode:match("^[vV]") then
		-- Exit visual mode first to update marks
		vim.cmd("normal! ")
	end

	-- Get the visual selection
	local lines = get_visual_selection()

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

	local lines_to_write = { "" }
	local current_line = 1
	local current_col = 1

	-- Prepare text chunks (words or characters)
	local chunks = {}
	if word_mode then
		-- Split by words while preserving spaces and newlines
		for line_num, line in ipairs(state.recorded_lines) do
			-- Add words from this line
			for word in line:gmatch("%S+") do
				table.insert(chunks, word)
			end
			-- Add newline after each line except the last
			if line_num < #state.recorded_lines then
				table.insert(chunks, "\n")
			end
		end
	else
		-- Split into individual characters
		for char in state.recorded_text:gmatch(".") do
			table.insert(chunks, char)
		end
	end

	local chunk_index = 1

	local function animate()
		if chunk_index > #chunks or not state.is_playing then
			vim.notify("Playback complete!", vim.log.levels.INFO)
			state.is_playing = false
			return
		end

		local chunk = chunks[chunk_index]

		if chunk == "\n" then
			-- Handle newline
			table.insert(lines_to_write, "")
			current_line = current_line + 1
			current_col = 1
		else
			-- Add chunk to current line
			if word_mode and lines_to_write[current_line] ~= "" then
				-- Add space before word (except at line start)
				lines_to_write[current_line] = lines_to_write[current_line] .. " " .. chunk
			else
				lines_to_write[current_line] = lines_to_write[current_line] .. chunk
			end
		end

		-- Update buffer
		vim.api.nvim_buf_set_lines(state.buffer, 0, -1, false, lines_to_write)

		-- Move cursor to end of text for visual feedback
		vim.api.nvim_win_set_cursor(state.window, { current_line, string.len(lines_to_write[current_line]) })

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
	M.play_code({ delay = 50, word_mode = false })
end, { desc = "Play back recorded code with animation" })

vim.api.nvim_create_user_command("AnimePlayWords", function()
	M.play_code({ delay = 150, word_mode = true })
end, { desc = "Play back recorded code word by word" })

vim.api.nvim_create_user_command("AnimeStop", function()
	M.stop_playback()
end, { desc = "Stop code playback animation" })

vim.api.nvim_create_user_command("AnimeClearRecording", function()
	M.clear_recording()
end, { desc = "Clear recorded code" })

-- Return the module
return M
