---@diagnostic disable: undefined-global
local coverage = {}

local function normalize_path(source)
	if type(source) ~= "string" or source == "" then
		return nil
	end
	if source:sub(1, 1) == "@" then
		return source:sub(2)
	end
	return nil
end

local function trim(text)
	return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function shell_quote(text)
	return "'" .. tostring(text):gsub("'", "'\\''") .. "'"
end

local function count_coverable_lines(path)
	local handle = io.popen("luac -l -p " .. shell_quote(path) .. " 2>/dev/null")
	if handle then
		local output = handle:read("*a")
		handle:close()
		local coverable = {}
		for line in output:gmatch("[^\r\n]+") do
			local line_number = line:match("^%s*%d+%s+%[(%d+)%]")
			line_number = tonumber(line_number)
			if line_number and line_number > 0 then
				coverable[line_number] = true
			end
		end
		if next(coverable) then
			return coverable
		end
	end

	local file = io.open(path, "r")
	if not file then
		return {}
	end

	local coverable = {}
	local line_number = 0
	for line in file:lines() do
		line_number = line_number + 1
		local stripped = trim(line)
		if stripped ~= "" and not stripped:match("^%-%-") then
			coverable[line_number] = true
		end
	end

	file:close()
	return coverable
end

local function sorted_pairs_by_coverage(rows)
	table.sort(rows, function(a, b)
		if a.percent ~= b.percent then
			return a.percent < b.percent
		end
		return a.relative_path < b.relative_path
	end)
	return rows
end

function coverage.new(root, relative_paths)
	local self = {
		root = root,
		files = {},
	}

	for index = 1, #(relative_paths or {}) do
		local relative_path = relative_paths[index]
		local absolute_path = root .. "/" .. relative_path
		self.files[absolute_path] = {
			relative_path = relative_path,
			coverable = count_coverable_lines(absolute_path),
			executed = {},
		}
	end

	self._hook = function(_, line)
		local info = debug.getinfo(2, "S")
		local path = normalize_path(info and info.source)
		local file = path and self.files[path] or nil
		if file and file.coverable[line] then
			file.executed[line] = true
		end
	end

	return setmetatable(self, { __index = coverage })
end

function coverage:before_test()
	debug.sethook(self._hook, "l")
end

function coverage:after_test()
	debug.sethook()
end

function coverage:report()
	local total_coverable = 0
	local total_executed = 0
	local rows = {}

	for _, file in pairs(self.files) do
		local file_coverable = 0
		local file_executed = 0
		for line in pairs(file.coverable) do
			file_coverable = file_coverable + 1
			if file.executed[line] then
				file_executed = file_executed + 1
			end
		end

		total_coverable = total_coverable + file_coverable
		total_executed = total_executed + file_executed
		rows[#rows + 1] = {
			relative_path = file.relative_path,
			executed = file_executed,
			coverable = file_coverable,
			percent = file_coverable > 0 and (file_executed / file_coverable * 100) or 100,
		}
	end

	local total_percent = total_coverable > 0 and (total_executed / total_coverable * 100) or 100
	print(string.format(
		"Coverage (approx): %.1f%% (%d/%d coverable lines)",
		total_percent,
		total_executed,
		total_coverable
	))

	rows = sorted_pairs_by_coverage(rows)
	for index = 1, math.min(#rows, 8) do
		local row = rows[index]
		if row.percent < 100 then
			print(string.format(
				"coverage %5.1f%% %4d/%-4d %s",
				row.percent,
				row.executed,
				row.coverable,
				row.relative_path
			))
		end
	end
end

return coverage
