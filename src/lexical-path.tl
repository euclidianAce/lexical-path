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
---
---
--- This library is released under CC0 1.0


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

local record Pattern
	{string}
	is_absolute: boolean
end

local path_metatable <const>: metatable<Path> = {
	__index = Path,
	__name = "lexical-path.Path",
	__tostring: function(Path): string = nil,
}

local enum ComparisonError
	"Differing roots"
	"Mixing of absolute and non-absolute path"
end

local enum Normalization
	"normal"
	"non-normal"
end

local lexical_path <const> = {
	Path = Path,
	Pattern = Pattern,
	ComparisonError = ComparisonError,
	Normalization = Normalization,
}

--- Returns an array and a function that will modify the returned array
---
--- If `target` is provided, it is returned and the returned function will modify it
---
--- The returned function will attempt to normalize components as it is given them.
---  - When it is given "." or "", it ignores it and returns "non-normal"
---  - When it is given ".." and the array is non-empty, it removes the last component and returns "non-normal", (otherwise it appends ".." and returns "normal")
---  - otherwise it appends the component and return strue
function lexical_path.component_builder(target?: {string}): {string}, function(component: string): Normalization
	local components <const> = target or {}
	return components, function(component: string): Normalization
		if component == ".." then
			if #components > 0 and components[#components] ~= ".." then
				table.remove(components)
				return "non-normal"
			end
			table.insert(components, component)
			return "normal"
		end
		if component ~= "." and component ~= "" then
			table.insert(components, component)
			return "normal"
		end
		return "non-normal"
	end
end

local function parse_components(dest: {string}, source: string, component_pattern: string): {string}, Normalization
	local new <const>, add <const> = lexical_path.component_builder(dest)
	local normal: Normalization = "normal"
	for chunk in source:gmatch(component_pattern) do
		if add(chunk) == "non-normal" then
			normal = "non-normal"
		end
	end
	return new, normal
end

--- Bring your own parser
---
--- The given components array will be copied and normalized
---
--- Returns the constructed path, whether the given components we already
--- normalized, and if they weren't, the index of the first non-normal
--- component
function lexical_path.from_components(components: {string}, root?: string, is_absolute?: boolean): Path, Normalization, integer
	local result <total>: Path = { root = root, is_absolute = is_absolute }
	local _, add <const> = lexical_path.component_builder(result)
	local non_normal_index: integer = nil
	local normal: Normalization = "normal"
	for i, v in ipairs(components) do
		if add(v) == "non-normal" and not non_normal_index then
			normal = "non-normal"
			non_normal_index = i
		end
	end
	return setmetatable(result, path_metatable), normal, non_normal_index
end

--- What `from_windows` uses to determine the root
---
--- Returns the root, whether the path is absolute, and the rest of the path
---
--- The root is determined by taking the following steps:
---  - if the path starts with `\??\`, it is removed
---  - if the path then starts with a letter followed by a volume separator (aka a
---    colon) `[a-zA-Z]:`, it is rooted to that drive letter, and the drive
---    letter and separator are removed.
---    Then if the path immediately starts with a `\`, it is considered absolute and the `\` is removed
---    otherwise it is relative (but still rooted)
---    Additionally, drive letters are parsed as either upper or lower case, but upper case is always returned as the root by this function
---  - otherwise if the path then starts with a `\\.\` or `\\?\` the first 4
---    characters are removed, the path is aboslute, and rooted to `\\.` or `\\?`
---    repectively
---  - otherwise if the path then starts with `\\`, it is removed, the path is absolute, and rooted to `\`
---  - otherwise if the path then starts with `\`, it is removed, the path is absolute, but not rooted
---  - otherwise the path is relative and not rooted
function lexical_path.chop_windows_root(source: string): string, boolean, string
	local root: string
	local is_absolute = false

	if source:sub(1, 4) == [[\??\]] then
		source = source:sub(5, -1)
	end

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
---   - A drive letter followed by a colon (Note: Drive letters will be converted to upper case. This doesn't count as normalization)
---   - \, representing a UNC path, always absolute
---   - \\?, representing an absolute DOS device path (without normalization), always absolute
---   - \\., representing an absolute DOS device path, always absolute
---
--- NT Object path prefixes (i.e. `\??\` are stripped)
---
--- UNC paths that contain drive letters followed by `$` are not converted to anything else
---
--- e.g. `\\system07\C$\` on windows would resolve to the root directory of `C:` on the host `system07`,
--- but to this library, this is just an absolute path, rooted at `\`, with components `{ "system07", "C$" }`
---
--- See
--- https://learn.microsoft.com/en-us/dotnet/standard/io/file-path-formats
--- for more information on windows file path formats
---
--- Returns the path and whether or not it was already normalized
function lexical_path.from_windows(source: string): Path, Normalization
	local root <const>, is_absolute <const>, rest <const> = lexical_path.chop_windows_root(source)
	local result <total>: Path = {
		root = root,
		is_absolute = is_absolute,
	}
	local _, norm <const> = parse_components(result, rest, "[^/\\]+")
	return setmetatable(result, path_metatable), norm
end

--- Parse a string as a Unix path
---
--- Component Separator: "/"
--- Possible Roots:
---   - nil
---
--- Returns the path and whether or not it was already normalized
function lexical_path.from_unix(source: string): Path, Normalization
	local result <total>: Path = {
		root = nil,
		is_absolute = source:sub(1, 1) == "/"
	}
	local _, norm <const> = parse_components(result, source, "[^/]+")
	return setmetatable(result, path_metatable), norm
end

--- Parse a string as a path for the current OS
function lexical_path.from_os(source: string): Path, Normalization
	if package.config:sub(1, 1) == "\\" then
		return lexical_path.from_windows(source)
	end
	return lexical_path.from_unix(source)
end

--- Render a path to a string using the given path separator or defaulting to the native one
function Path:to_string(separator?: string): string
	separator = separator or package.config:sub(1, 1)
	local result <const> = (self.root or "")
		.. (self.is_absolute and separator or "")
	return result .. (#result == 0 and #self == 0 and "." or table.concat(self, separator))
end

path_metatable.__tostring = Path.to_string

--- Create a copy of a path
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
	local _, add <const> = lexical_path.component_builder(new)
	for _, chunk in ipairs(self) do
		add(chunk)
	end
	return setmetatable(new, path_metatable)
end

local non_normal_components <const>: {string:boolean} = {
	[".."] = true,
	["."] = true,
	[""] = true,
}

--- if the path is considered normalized, returns true
--- otherwise returns false and the index of the first component that is non-normal
function Path:is_normalized(): boolean, integer
	for i, component in ipairs(self) do
		if non_normal_components[component] then
			return false, i
		end
	end
	return true
end

path_metatable.__eq = function(a: Path, b: Path): boolean
	if rawequal(a, b) then return true end
	if rawequal(a, nil) then return false end
	if rawequal(b, nil) then return false end
	if not rawequal(getmetatable(a), path_metatable) then return false end
	if not rawequal(getmetatable(b), path_metatable) then return false end

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

--- Note, returned root may be nil
--- check if the error is non nil
local function root_for_comparison(a: Path, b: Path): string, ComparisonError
	if a.root ~= b.root then
		if not a.root then
			return b.root
		elseif not b.root then
			return a.root
		else
			return nil, "Differing roots"
		end
	end
	if a.is_absolute ~= b.is_absolute then
		return nil, "Mixing of absolute and non-absolute path"
	end
	return a.root
end

--- Will return nil when paths have different non-nil roots or they are not the
--- same absolute-ness
function Path:relative_to(other: Path): Path, ComparisonError
	local root <const>, err <const> = root_for_comparison(self, other)
	if err then return nil, err end

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
	local ret <total>: Path = { root = root, is_absolute = false }
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

--- Returns whether the path (`self`) is contained within the given path (`maybe_container`)
---
--- Note that a path is not considered to contain itself
function Path:is_in(maybe_container: Path): boolean, ComparisonError
	local _, err <const> = root_for_comparison(self, maybe_container)
	if err then return nil, err end

	if #maybe_container == 0 then return true end
	if #self <= #maybe_container then return false end

	for i = 1, #maybe_container do
		if self[i] ~= maybe_container[i] then
			return false
		end
	end

	return true
end

local function path_iterator(p: Path, max: integer): function(): Path
	local index = 0
	return function(): Path
		index = index + 1
		if index > max then return end
		local result <total>: Path = { is_absolute = p.is_absolute, root = p.root }
		for i = 1, index do
			result[i] = p[i]
		end
		return setmetatable(result, path_metatable)
	end
end

--- Iterate over the leading directories in a path, excluding the path itself
---
--- e.g.
---    `lexical_path.from_unix "foo/bar/baz/qux":ancestors()` will yield:
---    "foo"
---    "foo/bar"
---    "foo/bar/baz"
---
--- See also `Path:lineage()`
function Path:ancestors(): function(): Path
	return path_iterator(self, #self - 1)
end

--- Iterate over the leading directories in a path, including the path itself
---
--- e.g.
---    `lexical_path.from_unix "foo/bar/baz/qux":lineage()` will yield:
---    "foo"
---    "foo/bar"
---    "foo/bar/baz"
---    "foo/bar/baz/qux"
---
--- See also `Path:ancestors()`
function Path:lineage(): function(): Path
	return path_iterator(self, #self)
end

--- Check if a path matches against a shell style glob pattern
---
--- For patterns:
---    - `/` is always the path separator
---    - a pattern starting with `/` is an absolute path
---    - `*` represents any number of non-path-separator characters (i.e. matches within a component)
---    - `**` on its own represents any number of path components
---    - Same assumptions about paths as stated at the top of this module
---
--- Returns the components of the pattern (normalized) as patterns for
--- string.match, and whether the matching path should be absolute
function lexical_path.parse_pattern(source: string): Pattern
	local components <total>: Pattern = {
		is_absolute = (source:sub(1, 1) == "/")
	}
	for chunk in source:gmatch "[^/]+" do
		if chunk == ".." then
			if #components > 0 and components[#components] ~= ".." then
				table.remove(components)
			else
				table.insert(components, chunk)
			end
		elseif chunk == "**" then
			if components[#components] ~= "**" then
				table.insert(components, "**")
			end
		elseif chunk ~= "." then
			local escaped <const> = chunk:gsub(
				"[%^%$%(%)%%%.%[%]%*%+%-%?]",
				function(c: string): string
					if c == "*" then
						return ".*"
					end
					return "%" .. c
				end
			)

			table.insert(components, "^" .. escaped .. "$")
		end
	end
	return components
end

function Path:remove_leading(leading: Path): Path, ComparisonError
	if leading.is_absolute ~= self.is_absolute then
		return nil, "Mixing of absolute and non-absolute path"
	end
	local result <const> = self:copy()
	result.is_absolute = false
	local index = 1
	for _, chunk in ipairs(leading) do
		if result[index] ~= chunk then
			break
		end
		index = index + 1
	end
	if index < #leading then
		return result
	end
	for _ = 1, index - 1 do
		table.remove(result, 1)
	end
	return result
end

local function match(path_components: {string}, pattern: Pattern): boolean
	local path_length <const> = #path_components
	local pattern_length <const> = #pattern

	local pattern_index = 1
	local path_index = 1

	local double_glob_stack <const> = {}
	local function push_state()
		table.insert(double_glob_stack, { pattern_index, path_index })
	end
	local function pop_state(): boolean
		local t <const> = table.remove(double_glob_stack)
		if not t then return false end
		pattern_index = t[1]
		path_index = t[2] + 1
		return true
	end

	local function completed_match(): boolean
		return pattern_index > pattern_length and path_index > path_length
	end

	repeat
		while pattern_index <= pattern_length and path_index <= path_length do
			local pattern_component <const> = pattern[pattern_index]
			local path_component <const> = path_components[path_index]

			if pattern_component == "**" then
				push_state()
				pattern_index = pattern_index + 1
			elseif path_component:match(pattern_component) then
				pattern_index = pattern_index + 1
				path_index = path_index + 1
			elseif not pop_state() then
				return false
			end
		end
	until completed_match() or not pop_state()

	return completed_match()
end

local function ensure_pattern(pattern_src: string | Pattern): Pattern
	if pattern_src is Pattern then return pattern_src end
	return lexical_path.parse_pattern(pattern_src)
end

function Path:match(pattern_src: string | Pattern): boolean
	local pattern <const> = ensure_pattern(pattern_src)
	if self.is_absolute ~= pattern.is_absolute then
		return false
	end
	return match(self, pattern)
end

--- Get the extension of a path
---
--- Essentially takes the last component and splits it on the last '.' character
---
--- The `up_to_ndots` parameter defaults to 1 and determines the maximum number
--- of '.' characters allowed in the extension.
---
--- Returns the extension and how many '.' characters were matched
---
--- Examples:
---
---    from_os "foo.d.tl":extension() -> "tl", 1
---    from_os "foo.d.tl":extension(1) -> "tl", 1
---    from_os "foo.d.tl":extension(2) -> "d.tl", 2
---    from_os "foo.d.tl":extension(3) -> "d.tl", 2
---
---    from_os "a.":extension() -> nil, 0
---
--- See also `Path:extension_split`
function Path:extension(up_to_ndots?: integer): string, integer
	up_to_ndots = math.max(up_to_ndots or 1, 1)
	local last <const> = self[#self]
	if not last then return end
	for n = up_to_ndots, 1, -1 do
		local patt <const> = "^.-(" .. ("%.[^%.]+"):rep(n) .. ")$"
		local ext <const> = last:match(patt)
		if ext then
			return ext:sub(2, -1), n
		end
	end
	return nil, 0
end

--- Get the extension of a path and a copy of the path with the extension stripped
---
--- See `Path:extension` for details
function Path:extension_split(up_to_ndots?: integer): Path, string, integer
	local ext <const>, count <const> = self:extension(up_to_ndots)
	if not ext then return nil, nil, 0 end

	local result <const> = self:copy()
	result[#result] = result[#result]:sub(1, -2 - #ext)
	return result, ext, count
end

return lexical_path
