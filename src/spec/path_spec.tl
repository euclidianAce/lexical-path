local type _ = require("busted")
local lexical_path <const> = require "lexical-path"
local unix <const> = lexical_path.from_unix
local luassert <const> = require("luassert")

describe("lexical-path", function()
	describe("remove_leading", function()
		it("should remove the leading components of the path", function()
			local p = unix "foo/bar/baz"
			local leading = unix "foo/bar"
			local result, err = p:remove_leading(leading)
			luassert.is_not_nil(result, err)
			luassert.equal(result, unix "baz", "Expected foo/bar/baz with foo/bar removed to be baz")
		end)

		it("should error when mixing abolute and non-absolute paths", function()
			local p = unix "/foo"
			local leading = unix "foo"
			local result, err = p:remove_leading(leading)
			luassert.is_nil(result, "Expected result to be nil")
			luassert.truthy(err, "Expected err to be truthy")
			luassert.equal(err, "Mixing of absolute and non-absolute path", "Error message was incorrect")
		end)
	end)
end)
