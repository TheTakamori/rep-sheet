AltRepTracker = AltRepTracker or {}
local ns = AltRepTracker

local buffer = {}
local listeners = {}

local function nowText()
	if date then
		return date("%H:%M:%S")
	end
	return "00:00:00"
end

local function stringifyValue(value)
	if value == nil then
		return "-"
	end
	if type(value) == "boolean" then
		return value and "yes" or "no"
	end
	if type(value) == "number" then
		if value == math.floor(value) then
			return tostring(value)
		end
		return string.format("%.3f", value)
	end
	return tostring(value)
end

local function notifyListeners(line)
	for key, callback in pairs(listeners) do
		if type(callback) == "function" then
			callback(line, buffer)
		else
			listeners[key] = nil
		end
	end
end

function ns.DebugLog(message)
	local line = string.format("%s %s", nowText(), tostring(message))
	buffer[#buffer + 1] = line
	if #buffer > ns.DEBUG_LOG_MAX_LINES then
		table.remove(buffer, 1)
	end
	notifyListeners(line)
end

function ns.GetDebugLogLines()
	return buffer
end

function ns.GetDebugLogText()
	return table.concat(buffer, "\n")
end

function ns.GetLastDebugLine()
	return buffer[#buffer]
end

function ns.DebugValueText(value)
	return stringifyValue(value)
end

function ns.DebugTableKeys(tbl, limit)
	if type(tbl) ~= "table" then
		return "-"
	end

	local keys = {}
	for key in pairs(tbl) do
		keys[#keys + 1] = tostring(key)
	end
	table.sort(keys)

	if limit and limit > 0 and #keys > limit then
		local extra = #keys - limit
		while #keys > limit do
			table.remove(keys)
		end
		keys[#keys + 1] = string.format("+%d more", extra)
	end

	return table.concat(keys, ",")
end

function ns.ShouldTraceReputationRow(row, special)
	if type(row) == "table" then
		if row.isAccountWide == true then
			return true
		end
		if ns.SafeNumber(row.majorFactionID, 0) > 0 or ns.SafeNumber(row.renownFactionID, 0) > 0 then
			return true
		end
	end

	if type(special) == "table" then
		if special.isAccountWide == true then
			return true
		end
		if special.repType == ns.REP_TYPE.MAJOR or special.hasParagon == true then
			return true
		end
		if ns.SafeNumber(special.majorFactionID, 0) > 0 then
			return true
		end
	end

	return false
end

function ns.ClearDebugLog()
	wipe(buffer)
	notifyListeners("")
end

function ns.RegisterDebugListener(key, callback)
	if key == nil then
		return
	end
	listeners[key] = callback
end

function ns.UnregisterDebugListener(key)
	listeners[key] = nil
end
