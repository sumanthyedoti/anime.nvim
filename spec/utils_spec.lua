local utils = require("anime.utils")
local eq = assert.are.same

describe("utils", function()
	it("should break words with preceding spaces", function()
		local text = "This is a test sentence."
		local words_and_chars = utils.break_words_and_chars(text)
		eq(words_and_chars, { "This ", "is ", "a ", "test ", "sentence", "." })
	end)

	it("should break special characters", function()
		local text = "This is a %^* &"
		local words_and_chars = utils.break_words_and_chars(text)
		eq(words_and_chars, { "This ", "is ", "a ", "%", "^", "* ", "&" })
	end)

	it("preceding and trailing spaces should be captured with a word", function()
		local text = "     word     "
		local words_and_chars = utils.break_words_and_chars(text)
		eq(words_and_chars, { "     word     " })
	end)

	it("trailing spaces should be captured with a special char", function()
		local text = "     &     "
		local words_and_chars = utils.break_words_and_chars(text)
		eq(words_and_chars, { "     ", "&     " })
	end)

	it("non-breaking special characters should be captured separately", function()
		local text = "function()   ~/project/nvim"
		local words_and_chars = utils.break_words_and_chars(text)
		eq(words_and_chars, { "function", "(", ")   ", "~", "/", "project", "/", "nvim" })
	end)
end)

describe("trim_lines", function()
	it("should trim leading and trailing spaces from each line", function()
		local lines = {
			"   line one   ",
			"line two    ",
			"   line three",
			"line four",
			"     ",
			"",
		}
		local trimmed = utils.trim_lines(lines)
		eq(trimmed, { "line one", "line two", "line three", "line four", "", "" })
	end)
end)
