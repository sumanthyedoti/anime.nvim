local utils = require("anime.utils")
---@diagnostic disable-next-line: undefined-field
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

describe("index_of", function()
	it("should handle empty arrays", function()
		local array = {}
		local index = utils.index_of(array, "apple")
		eq(index, nil)
	end)
	it("should return the index of existing value in an array", function()
		local array = { "apple", "banana", "cherry" }
		local index = utils.index_of(array, "banana")
		eq(index, 2)
	end)
	it("should return the index of existing number in an array", function()
		local array = { 1, 2, 3 }
		local index = utils.index_of(array, 2)
		eq(index, 2)
	end)
	it("should return nil if the value is not found", function()
		local array = { "apple", "banana", "cherry" }
		local index = utils.index_of(array, "date")
		eq(index, nil)
	end)
end)

describe("smaller_value", function()
	it("should return first value if value is at fist index", function()
		local array = { 1, 2, 3, 5 }
		local index = utils.smaller_value(array, 1)
		eq(index, 1)
	end)
	it("should return previous value if values are same", function()
		local array = { 1, 2, 3, 5 }
		local index = utils.smaller_value(array, 5)
		eq(index, 3)
	end)
	it("should return previous value if values are same", function()
		local array = { 1, 2, 3, 5, 7 }
		local index = utils.smaller_value(array, 5)
		eq(index, 3)
	end)
	it("should return previous value if elemnent is bigger", function()
		local array = { 1, 2, 3, 5, 7 }
		local index = utils.smaller_value(array, 4)
		eq(index, 3)
	end)
	it("should return nil if value is out of range", function()
		local array = { 1, 2, 3, 5 }
		local index = utils.smaller_value(array, 0)
		eq(index, nil)
	end)
	it("should return nil if value is out of range", function()
		local array = { 1, 2, 3, 5 }
		local index = utils.smaller_value(array, 6)
		eq(index, nil)
	end)
end)

describe("bigger_value", function()
	it("should return last value if value is at last index are same", function()
		local array = { 1, 2, 3, 5 }
		local index = utils.bigger_value(array, 5)
		eq(index, 5)
	end)
	it("should return next value if value are same", function()
		local array = { 1, 2, 3, 5 }
		local index = utils.bigger_value(array, 1)
		eq(index, 2)
	end)
	it("should return next value if values are same", function()
		local array = { 1, 2, 3, 5, 7 }
		local index = utils.bigger_value(array, 5)
		eq(index, 7)
	end)
	it("should return next value if elemnent is bigger", function()
		local array = { 1, 2, 3, 5, 7 }
		local index = utils.bigger_value(array, 4)
		eq(index, 5)
	end)
	it("should return nil if value is out of range", function()
		local array = { 1, 2, 3, 5 }
		local index = utils.bigger_value(array, 0)
		eq(index, nil)
	end)
	it("should return nil if value is out of range", function()
		local array = { 1, 2, 3, 5 }
		local index = utils.bigger_value(array, 6)
		eq(index, nil)
	end)
end)
