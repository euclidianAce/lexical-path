local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local math = _tl_compat and _tl_compat.math or math; local package = _tl_compat and _tl_compat.package or package; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local type = type




























local Path = {}

































local Pattern = {}




local path_metatable = {
   __index = Path,
   __name = "lexical-path.Path",
   __tostring = nil,
}






local lexical_path = {
   Path = Path,
   Pattern = Pattern,
   ComparisonError = ComparisonError,
}








function lexical_path.component_builder(target)
   local components = target or {}
   return components, function(component)
      if component == ".." then
         if #components > 0 and components[#components] ~= ".." then
            table.remove(components)
         else
            table.insert(components, component)
         end
      elseif component ~= "." and component ~= "" then
         table.insert(components, component)
      end
   end
end

local function parse_components(dest, source, component_pattern)
   local new, add = lexical_path.component_builder(dest)
   for chunk in source:gmatch(component_pattern) do
      add(chunk)
   end
   return new
end




function lexical_path.from_components(components, root, is_absolute)
   local result = { root = root, is_absolute = is_absolute }
   local _, add = lexical_path.component_builder(result)
   for _, v in ipairs(components) do
      add(v)
   end
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
   local result = {
      root = root,
      is_absolute = is_absolute,
   }
   parse_components(result, rest, "[^/\\]+")
   return setmetatable(result, path_metatable)
end






function lexical_path.from_unix(source)
   local result = {
      root = nil,
      is_absolute = source:sub(1, 1) == "/",
   }
   parse_components(result, source, "[^/]+")
   return setmetatable(result, path_metatable)
end


function lexical_path.from_os(source)
   if package.config:sub(1, 1) == "\\" then
      return lexical_path.from_windows(source)
   end
   return lexical_path.from_unix(source)
end


function Path:to_string(separator)
   separator = separator or package.config:sub(1, 1)
   local result = (self.root or "") ..
   (self.is_absolute and separator or "")
   return result .. (#result == 0 and #self == 0 and "." or table.concat(self, separator))
end

path_metatable.__tostring = Path.to_string


function Path:copy()
   local result = { root = self.root, is_absolute = self.is_absolute }
   for i, v in ipairs(self) do result[i] = v end
   return setmetatable(result, path_metatable)
end





function Path:normalized()
   local new = { root = self.root, is_absolute = self.is_absolute }
   local _, add = lexical_path.component_builder(new)
   for _, chunk in ipairs(self) do
      add(chunk)
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



local function root_for_comparison(a, b)
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



function Path:relative_to(other)
   local root, err = root_for_comparison(self, other)
   if err then return nil, err end

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




function Path:is_in(maybe_container)
   local _, err = root_for_comparison(self, maybe_container)
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

local function path_iterator(p, max)
   local index = 0
   return function()
      index = index + 1
      if index > max then return end
      local result = { is_absolute = p.is_absolute, root = p.root }
      for i = 1, index do
         result[i] = p[i]
      end
      return setmetatable(result, path_metatable)
   end
end










function Path:ancestors()
   return path_iterator(self, #self - 1)
end











function Path:lineage()
   return path_iterator(self, #self)
end












function lexical_path.parse_pattern(source)
   local components = {
      is_absolute = (source:sub(1, 1) == "/"),
   }
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


         table.insert(components, "^" .. escaped .. "$")
      end
   end
   return components
end

local function match(path_components, pattern)
   local path_length = #path_components
   local pattern_length = #pattern

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
         local pattern_component = pattern[pattern_index]
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

local function ensure_pattern(pattern_src)
   if type(pattern_src) == "table" then return pattern_src end
   return lexical_path.parse_pattern(pattern_src)
end

function Path:match(pattern_src)
   local pattern = ensure_pattern(pattern_src)
   if self.is_absolute ~= pattern.is_absolute then
      return false
   end
   return match(self, pattern)
end




















function Path:extension(up_to_ndots)
   up_to_ndots = math.max(up_to_ndots or 1, 1)
   local last = self[#self]
   if not last then return end
   for n = up_to_ndots, 1, -1 do
      local patt = "^.-(" .. ("%.[^%.]+"):rep(n) .. ")$"
      local ext = last:match(patt)
      if ext then
         return ext:sub(2, -1), n
      end
   end
   return nil, 0
end




function Path:extension_split(up_to_ndots)
   local ext, count = self:extension(up_to_ndots)
   if not ext then return nil, nil, 0 end

   local result = self:copy()
   result[#result] = result[#result]:sub(1, -2 - #ext)
   return result, ext, count
end

return lexical_path
