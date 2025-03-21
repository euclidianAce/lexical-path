local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local string = _tl_compat and _tl_compat.string or string; local lexical_path = require("lexical-path")

local cases = {
   { [[C:\Documents\Newsletters\Summer2018.pdf]], lexical_path.from_components({ "Documents", "Newsletters", "Summer2018.pdf" }, [[C:]], true) },
   { [[\Program Files\Custom Utilities\StringFinder.exe]], lexical_path.from_components({ "Program Files", "Custom Utilities", "StringFinder.exe" }, nil, true) },
   { [[2018\January.xlsx]], lexical_path.from_components({ "2018", "January.xlsx" }, nil, false) },
   { [[..\Publications\TravelBrochure.pdf]], lexical_path.from_components({ "..", "Publications", "TravelBrochure.pdf" }, nil, false) },
   { [[C:\Projects\apilibrary\apilibrary.sln]], lexical_path.from_components({ "Projects", "apilibrary", "apilibrary.sln" }, [[C:]], true) },
   { [[C:Projects\apilibrary\apilibrary.sl]], lexical_path.from_components({ "Projects", "apilibrary", "apilibrary.sl" }, [[C:]], false) },
   { [[\\system07\C$\]], lexical_path.from_components({ "system07", "C$" }, [[\]], true) },
   { [[\\Server2\Share\Test\Foo.txt]], lexical_path.from_components({ "Server2", "Share", "Test", "Foo.txt" }, [[\]], true) },
   { [[\\.\C:\Test\Foo.txt]], lexical_path.from_components({ "C:", "Test", "Foo.txt" }, [[\\.]], true) },
   { [[\\?\C:\Test\Foo.txt]], lexical_path.from_components({ "C:", "Test", "Foo.txt" }, [[\\?]], true) },
   { [[\\.\Volume{b75e2c83-0000-0000-0000-602f00000000}\Test\Foo.txt]], lexical_path.from_components({ "Volume{b75e2c83-0000-0000-0000-602f00000000}", "Test", "Foo.txt" }, [[\\.]], true) },
   { [[\\?\Volume{b75e2c83-0000-0000-0000-602f00000000}\Test\Foo.txt]], lexical_path.from_components({ "Volume{b75e2c83-0000-0000-0000-602f00000000}", "Test", "Foo.txt" }, [[\\?]], true) },
   { [[\\?\C:\]], lexical_path.from_components({ "C:" }, [[\\?]], true) },
   { [[\\.\BootPartition\]], lexical_path.from_components({ "BootPartition" }, [[\\.]], true) },
   { [[\\.\UNC\Server\Share\Test\Foo.txt]], lexical_path.from_components({ "UNC", "Server", "Share", "Test", "Foo.txt" }, [[\\.]], true) },
   { [[\\?\UNC\Server\Share\Test\Foo.txt]], lexical_path.from_components({ "UNC", "Server", "Share", "Test", "Foo.txt" }, [[\\?]], true) },
   { [[\\?\server1\utilities\\filecomparer\]], lexical_path.from_components({ "server1", "utilities", "filecomparer" }, [[\\?]], true) },
   { [[c:\temp\test-file.txt]], lexical_path.from_components({ "temp", "test-file.txt" }, [[C:]], true) },
   { [[\\127.0.0.1\c$\temp\test-file.txt]], lexical_path.from_components({ "127.0.0.1", "c$", "temp", "test-file.txt" }, [[\]], true) },
   { [[\\LOCALHOST\c$\temp\test-file.txt]], lexical_path.from_components({ "LOCALHOST", "c$", "temp", "test-file.txt" }, [[\]], true) },
   { [[\\.\c:\temp\test-file.txt]], lexical_path.from_components({ "c:", "temp", "test-file.txt" }, [[\\.]], true) },
   { [[\\?\c:\temp\test-file.txt]], lexical_path.from_components({ "c:", "temp", "test-file.txt" }, [[\\?]], true) },
   { [[\\.\UNC\LOCALHOST\c$\temp\test-file.txt]], lexical_path.from_components({ "UNC", "LOCALHOST", "c$", "temp", "test-file.txt" }, [[\\.]], true) },
}

local case_output = [[

Input   : %q
Parsed  : %q (%s)
Expected: %q (%s)
]]


local inspect = require("inspect")

describe("Windows paths", function()
   for _, case in ipairs(cases) do
      it("should handle “" .. case[1] .. "”", function()
         local parsed = lexical_path.from_windows(case[1])
         local expected = case[2]
         assert(parsed == expected, case_output:format(
         case[1],
         parsed:to_string("\\"),
         inspect(parsed),
         expected:to_string("\\"),
         inspect(expected)))

      end)

      it("should handle “\\??\\" .. case[1] .. "”", function()
         local parsed = lexical_path.from_windows(case[1])
         local expected = case[2]
         assert(parsed == expected, case_output:format(
         case[1],
         parsed:to_string("\\"),
         inspect(parsed),
         expected:to_string("\\"),
         inspect(expected)))

      end)
   end
end)
