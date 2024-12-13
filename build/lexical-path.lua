local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local math = _tl_compat and _tl_compat.math or math; local package = _tl_compat and _tl_compat.package or package; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local type = type




























local Path = {}

































local path_metatable = {
   __index = Path,
   __name = "lexical-path.Path",
   __tostring = nil,
}






local lexical_path = {
   Path = Path,
   RelativeToError = RelativeToError,
}

local function parse_components(source, component_pattern)
   local new = {}
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

function lexical_path.from_components(components, root, is_absolute)
   local result = { root = root, is_absolute = is_absolute }
   for i, v in ipairs(components) do result[i] = v end
   return setmetatable(result, path_metatable)
end




function lexical_path.chop_windows_root(source)
   local root
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














function lexical_path.from_windows(source)
   local root, is_absolute, rest = lexical_path.chop_windows_root(source)
   return lexical_path.from_components(parse_components(rest, "[^/\\]+"), root, is_absolute)
end






function lexical_path.from_unix(source)
   return lexical_path.from_components(parse_components(source, "[^/]+"), nil, source:sub(1, 1) == "/")
end


function lexical_path.from_os(source)
   if package.config:sub(1, 1) == "\\" then
      return lexical_path.from_windows(source)
   end
   return lexical_path.from_unix(source)
end

function Path:to_string(separator)
   separator = separator or package.config:sub(1, 1)
   return (self.root or "") ..
   (self.is_absolute and separator or "") ..
   (#self == 0 and "." or table.concat(self, separator))
end

path_metatable.__tostring = Path.to_string

function Path:copy()
   local result = { root = self.root, is_absolute = self.is_absolute }
   for i, v in ipairs(self) do result[i] = v end
   return setmetatable(result, path_metatable)
end





function Path:normalized()
   local new = { root = self.root, is_absolute = self.is_absolute }
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

path_metatable.__eq = function(a, b)
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

path_metatable.__concat = function(a, b)
   local a_components
   local b_components
   local root
   local is_absolute = false
   if type(a) == "table" then
      a_components = a
      is_absolute = a.is_absolute
      root = a.root
   else
      assert(type(a) == "string")
      a_components = { a }
   end
   if type(b) == "table" then
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
      assert(type(b) == "string")
      b_components = { b }
   end

   local result = {
      root = root,
      is_absolute = is_absolute,
   }
   for i, v in ipairs(a_components) do result[i] = v end
   local offset = #a_components
   for i, v in ipairs(b_components) do result[offset + i] = v end
   return setmetatable(result, path_metatable)
end



function Path:relative_to(other)
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

   local a_len = #self
   local b_len = #other
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
   local ret = { root = root, is_absolute = false }
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












local function parse_pattern(source)
   local components = {}
   for chunk in source:gmatch("[^/]+") do
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
         local escaped = chunk:gsub(
         "[%^%$%(%)%%%.%[%]%*%+%-%?]",
         function(c)
            if c == "*" then
               return ".*"
            end
            return "%" .. c
         end)


         table.insert(components, escaped)
      end
   end
   return components, source:sub(1, 1) == "/"
end

local function match(path_components, pattern_components)
   local path_length = #path_components
   local pattern_length = #pattern_components

   local pattern_index = 1
   local path_index = 1

   local double_glob_stack = {}
   local function push_state()
      table.insert(double_glob_stack, { pattern_index, path_index })
   end
   local function pop_state()
      local t = table.remove(double_glob_stack)
      if not t then return false end
      pattern_index = t[1]
      path_index = t[2] + 1
      return true
   end

   local function completed_match()
      return pattern_index > pattern_length and path_index > path_length
   end

   repeat
      while pattern_index <= pattern_length and path_index <= path_length do
         local pattern_component = pattern_components[pattern_index]
         local path_component = path_components[path_index]

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

function Path:match(pattern_src)
   local pattern, absolute = parse_pattern(pattern_src)
   if self.is_absolute ~= absolute then
      return false
   end
   return match(self, pattern)
end

return lexical_path
