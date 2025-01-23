local type _ = require("busted")
local lexical_path <const> = require "lexical-path"
local unix <const> = lexical_path.from_unix
local luassert <const> = require("luassert")

describe("match", function()
	local function assert_match(p: lexical_path.Path, pattern: string)
		local res <const> = p:match(pattern)
		luassert.is_true(res, "“" .. tostring(p) .. "” should have matched “" .. pattern .. "” but it didn't")
	end
	local function assert_not_match(p: lexical_path.Path, pattern: string)
		local res <const> = p:match(pattern)
		luassert.is_false(res, "“" .. tostring(p) .. "” should _NOT_ have matched “" .. pattern .. "” but it did")
	end

	it("should match literals with no globs", function()
		local p <const> = unix "foo/bar/baz"
		assert_not_match(p, "foo/bar")
		assert_match(p, "foo/bar/baz")
		assert_not_match(p, "foo/bar/bazz")
	end)
	it("should treat globs “*” as matching non path separators", function()
		local p <const> = unix "foo/bar/baz"
		assert_match(p, "*/bar/baz")
		assert_match(p, "foo/*/baz")
		assert_match(p, "*/*/baz")
		assert_match(p, "f*/b*/b*z")
		assert_match(p, "*/*/*")
		assert_not_match(p, "*")
		assert_not_match(p, "foo/*")
		assert_not_match(p, "*/*")
		assert_not_match(p, "*/*/bazzz")
		assert_not_match(unix "build/cyan/commands/blah.tl", "build/cyan/*")
	end)
	it("should treat double globs as matching any number of directories", function()
		local p <const> = unix "foo/bar/baz/bat"
		assert_match(p, "**/bat")
		assert_match(p, "foo/bar/**/bat")
		assert_match(p, "foo/bar/baz/**/bat")
		assert_not_match(p, "foo/**/foo")
		assert_not_match(p, "**/baz/foo")
	end)
	it("should be able to mix globs and double globs", function()
		local p <const> = unix "foo/bar/baz/bat"
		assert_match(p, "foo/b*/**/bat")
		assert_match(p, "*/**/*/bat")
		assert_match(p, "*/**/bat")
		assert_match(p, "**/bat")
		assert_match(p, "**/*")
		assert_not_match(p, "**/bar/bat")
		assert_not_match(p, "foo/*/**/baz")
	end)
end)
