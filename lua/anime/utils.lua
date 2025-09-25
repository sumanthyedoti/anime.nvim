local M = {}

function M.break_words_and_chars(text)
	local i = 1
	local results = {}
	while i <= #text do
		local char = text:sub(i, i)

		if char:match("[%s%w_]") then
			-- Found start of a word, capture the whole word
			local word_start = i
			-- preceding spaces
			while i <= #text and text:sub(i, i):match("[%s]") do
				i = i + 1
			end
			-- word characters
			while i <= #text and text:sub(i, i):match("[%w_]") do
				i = i + 1
			end
			-- trailing spaces
			while i <= #text and text:sub(i, i):match("[%s]") do
				i = i + 1
			end
			local word = text:sub(word_start, i - 1)
			table.insert(results, word)
		else
			-- Any non-word character (including spaces and special chars)
			local char_start = i
			i = i + 1
			-- trailing spaces
			while i <= #text and text:sub(i, i):match("[%s]") do
				i = i + 1
			end
			local trailing_spaces = text:sub(char_start + 1, i - 1)
			table.insert(results, char .. trailing_spaces)
		end
	end

	return results
end

return M
