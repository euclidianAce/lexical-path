--- Lexical path management
---
--- An attempt at an abstract Path type that allows for basic things to be made
--- cross platform
---
--- Assumptions:
---  - A single `.` path component has no effect on the path
---    e.g. "foo/./bar" == "foo/bar"
---
---  - A `..` path component is a traversal to the previous component
---    e.g. "foo/../bar" == "bar"
---
---  - Trailing separators have no effect on the path
---    e.g. "foo/bar/" == "foo/bar"
---
---  - Case sensitivity
---    e.g. "FOO/Bar" ~= "foo/bar"
---
---  - Empty components are not allowed/repeated separators are redundant
---    e.g. "foo//bar" == "foo/bar"


--- A path consists of a list of "components" and an optional "root"
--- This library attaches no semantics to the "root" and only uses for
--- comparison. Path parsing functions are documented with the possible roots
--- that they will produce
local record Path
	--- The components of the path
	---
	--- Note that this library will not produce empty components. So if a
	--- Path is constructed elsewhere with one this library could produce
	--- unexpected comparison failures.
	{string}

	--- The "root" of the path. Has different meanings for different
	--- platforms, but the gist is that paths can only be expressed
	--- relative to each other if they share a root or one is rootless
	---
	--- Note, having a root doesn't mean a path is absolute. A root is more
	--- analogous to a Drive on Windows or a mounted device or chroot on Unix
	---
	--- Roots are completely opaque to this library and are only used for
	--- comparing paths. They carry no further semantics.
	---
	--- e.g.
	---    The Windows path "C:foo\bar" is rooted to "C:", but is still a
	---    relative path. Whereas "C:\foo\bar" is rooted to "C:" and is an
	---    absolute path
	root: string

	--- Whether or not this represents an absolute path
	is_absolute: boolean

	--- Produce a new path by appending/prepending a single string component
	--- or the components of another path
	metamethod __concat: function(Path | string, Path | string): Path

	metamethod __eq: function(Path, Path): boolean
end

local path_metatable <const>: metatable<Path> = {
	__index = Path,
	__name = "lexical-path.Path",
	__tostring: function(Path): string = nil,
}

local enum RelativeToError
	"Differing roots"
	"Mixing of absolute and non-absolute path"
end

local lexical_path <const> = {
	Path = Path,
	RelativeToError = RelativeToError,
}

local function parse_components(source: string, component_pattern: string): {string}
	local new: {string} = {}
	for chunk in source:gmatch(component_pattern) do
		if chunk == ".." then
			if #new > 0 and new[#new] ~= ".." then
				table.remove(new)
			else
				table.insert(new, chunk)
			end
		elseif chunk ~= "." then
			table.insert(new, chunk)
		end
	end
	return new
end

function lexical_path.from_components(components: {string}, root?: string, is_absolute?: boolean): Path
	local result <total>: Path = { root = root, is_absolute = is_absolute }
	for i, v in ipairs(components) do result[i] = v end
	return setmetatable(result, path_metatable)
end

--- What `from_windows` uses to determine the root
---
--- Returns the root, whether the path is absolute, and the rest of the path
function lexical_path.chop_windows_root(source: string): string, boolean, string
	local root: string
	local is_absolute = false
	if source:sub(1, 3):match("^[A-Za-z]:\\") then
		root = source:sub(1, 2):upper()
		source = source:sub(4, -1)
		is_absolute = true
	elseif source:sub(1, 2):match("^[A-Za-z]:") then
		root = source:sub(1, 2):upper()
		source = source:sub(3, -1)
	elseif source:sub(1, 4) == [[\\.\]] or source:sub(1, 4) == [[\\?\]] then
		root = source:sub(1, 3)
		source = source:sub(5, -1)
		is_absolute = true
	elseif source:sub(1, 2) == [[\\]] then
		root = [[\]]
		source = source:sub(3, -1)
		is_absolute = true
	elseif source:sub(1, 1) == [[\]] then
		source = source:sub(2, -1)
		is_absolute = true
	end
	return root, is_absolute, source
end

--- Parse a string as a Windows path
---
--- Component Separator: "\\" or "/"
--- Possible Roots:
---   - nil
---   - A drive letter followed by a colon (Note: Drive letters will be normalized to upper case)
---   - "", representing the current drive
---   - \, representing a UNC path, always absolute
---   - \\?, representing an absolute DOS device path (without normalization), always absolute
---   - \\., representing an absolute DOS device path, always absolute
---
--- See
--- https://learn.microsoft.com/en-us/dotnet/standard/io/file-path-formats
--- for more information on windows file path formats
function lexical_path.from_windows(source: string): Path
	local root <const>, is_absolute <const>, rest <const> = lexical_path.chop_windows_root(source)
	return lexical_path.from_components(parse_components(rest, "[^/\\]+"), root, is_absolute)
end

--- Parse a string as a Unix path
---
--- Component Separator: "/"
--- Possible Roots:
---   - nil
function lexical_path.from_unix(source: string): Path
	return lexical_path.from_components(parse_components(source, "[^/]+"), nil, source:sub(1, 1) == "/")
end

--- Parse a string as a path for the current OS
function lexical_path.from_os(source: string): Path
	if package.config:sub(1, 1) == "\\" then
		return lexical_path.from_windows(source)
	end
	return lexical_path.from_unix(source)
end

function Path:to_string(separator?: string): string
	separator = separator or package.config:sub(1, 1)
	return (self.root or "") .. (self.is_absolute and separator or "") .. table.concat(self, separator)
end

path_metatable.__tostring = Path.to_string

function Path:copy(): Path
	local result <total>: Path = { root = self.root, is_absolute = self.is_absolute }
	for i, v in ipairs(self) do result[i] = v end
	return setmetatable(result, path_metatable)
end

--- Produce a new path with redundant traversals removed
---
--- e.g.
---    "foo/./bar/../baz" would be normalized to "foo/baz"
function Path:normalized(): Path
	local new <total>: Path = { root = self.root, is_absolute = self.is_absolute }
	for _, chunk in ipairs(self) do
		if chunk == ".." then
			if #new > 0 and new[#new] ~= ".." then
				table.remove(new)
			else
				table.insert(new, chunk)
			end
		elseif chunk ~= "." and #chunk > 0 then
			table.insert(new, chunk)
		end
	end
	return setmetatable(new, path_metatable)
end

path_metatable.__eq = function(a: Path, b: Path): boolean
	if rawequal(a, b) then return true end
	if a == nil then return false end
	if b == nil then return false end
	if getmetatable(a) ~= path_metatable then return false end
	if getmetatable(b) ~= path_metatable then return false end

	if a.root ~= b.root or a.is_absolute ~= b.is_absolute or #a ~= #b then
		return false
	end
	for i = 1, #a do
		if a[i] ~= b[i] then
			return false
		end
	end
	return true
end

path_metatable.__concat = function(a: Path | string, b: Path | string): Path
	local a_components: {string}
	local b_components: {string}
	local root: string
	local is_absolute = false
	if a is Path then
		a_components = a
		is_absolute = a.is_absolute
		root = a.root
	else
		assert(a is string)
		a_components = { a }
	end
	if b is Path then
		if b.is_absolute then error("Attempt to concatenate an absolute path") end

		b_components = b
		if root then
			if b.root and root ~= b.root then
				error("Attempt to concatenate paths with different roots")
			end
		else
			root = b.root
		end
	else
		assert(b is string)
		b_components = { b }
	end

	local result <total>: Path = {
		root = root,
		is_absolute = is_absolute,
	}
	for i, v in ipairs(a_components) do result[i] = v end
	local offset <const> = #a_components
	for i, v in ipairs(b_components) do result[offset + i] = v end
	return setmetatable(result, path_metatable)
end

--- Will return nil when paths have different non-nil roots or they are not the
--- same absolute-ness
function Path:relative_to(other: Path): Path, RelativeToError
	local root = self.root
	if self.root ~= other.root then
		if not self.root then
			root = other.root
		elseif not other.root then
			root = self.root
		else
			return nil, "Differing roots"
		end
	end
	if self.is_absolute ~= other.is_absolute then
		return nil, "Mixing of absolute and non-absolute path"
	end

	local a_len <const> = #self
	local b_len <const> = #other
	local mismatch = false
	local idx = 0
	for i = 1, math.min(a_len, b_len) do
		if self[i] ~= other[i] then
			mismatch = true
			break
		end
		idx = i
	end
	if b_len > a_len then
		mismatch = true
	end
	local ret: Path = { root = root }
	if mismatch then
		for _ = 1, b_len - idx do
			table.insert(ret, "..")
		end
	end
	for i = idx + 1, a_len do
		table.insert(ret, self[i])
	end
	return setmetatable(ret, path_metatable)
end

return lexical_path
