RepSheet = RepSheet or {}
local ns = RepSheet

local function trim(text)
	if type(text) ~= "string" then
		return ""
	end
	text = text:gsub("^%s+", "")
	text = text:gsub("%s+$", "")
	return text
end

function ns.Clamp(value, minValue, maxValue)
	if value == nil then
		return minValue
	end
	if value < minValue then
		return minValue
	end
	if value > maxValue then
		return maxValue
	end
	return value
end

function ns.GetPrimarySlashCommand()
	return ns.SLASH_COMMANDS[1] or ""
end

function ns.IsLocalDebugEnabled()
	return type(ns.LOCAL_DEV) == "table" and ns.LOCAL_DEV.ENABLE_DEBUG == true
end

function ns.GetAddonVersion()
	local addonName = ns.SafeString(ns.ADDON_NAME)
	if addonName == "" then
		return ns.TEXT.UNKNOWN
	end

	local metadataKey = ns.SafeString(ns.ADDON_METADATA_VERSION_KEY)
	local version = nil
	if C_AddOns and type(C_AddOns.GetAddOnMetadata) == "function" then
		version = C_AddOns.GetAddOnMetadata(addonName, metadataKey)
	elseif type(GetAddOnMetadata) == "function" then
		version = GetAddOnMetadata(addonName, metadataKey)
	end

	return ns.SafeString(version, ns.TEXT.UNKNOWN)
end

function ns.GetOptionLabel(options, selectedKey, fallbackLabel)
	if type(options) == "table" then
		for index = 1, #options do
			local option = options[index]
			if option.key == selectedKey then
				return option.label
			end
		end
		if options[1] and options[1].label then
			return options[1].label
		end
	end
	return fallbackLabel or ""
end

function ns.SafeNumber(value, fallback)
	local n = tonumber(value)
	if n == nil then
		return fallback or 0
	end
	return n
end

function ns.SafeString(value, fallback)
	if type(value) ~= "string" or value == "" then
		return fallback or ""
	end
	return value
end

function ns.Round(value)
	if type(value) ~= "number" then
		return 0
	end
	if value >= 0 then
		return math.floor(value + 0.5)
	end
	return math.ceil(value - 0.5)
end

function ns.CountTable(tbl)
	if type(tbl) ~= "table" then
		return 0
	end
	local total = 0
	for _ in pairs(tbl) do
		total = total + 1
	end
	return total
end

function ns.NormalizeText(text)
	if type(text) ~= "string" then
		return ""
	end
	text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
	text = text:gsub("|r", "")
	text = text:gsub("|T.-|t", "")
	text = text:gsub("\n", " ")
	text = text:gsub("%s+", " ")
	return trim(text)
end

function ns.NormalizeSearchText(text)
	return string.lower(ns.NormalizeText(text))
end

function ns.SafeTime()
	if time then
		return time()
	end
	return 0
end

function ns.CopyArray(values)
	local out = {}
	for index = 1, #(values or {}) do
		out[index] = values[index]
	end
	return out
end

function ns.PickTableField(data, ...)
	if type(data) ~= "table" then
		return nil
	end
	for index = 1, select("#", ...) do
		local key = select(index, ...)
		if data[key] ~= nil then
			return data[key]
		end
	end
	return nil
end

function ns.FormatDebugNameList(names)
	if type(names) ~= "table" then
		return "-"
	end

	local values = {}
	for index = 1, #names do
		local name = ns.SafeString(names[index])
		if name ~= "" then
			values[#values + 1] = name
		end
	end
	if #values == 0 then
		return "-"
	end

	table.sort(values)
	local limit = math.max(1, ns.SafeNumber(ns.DEBUG_LOG_NAME_LIMIT, 12))
	local display = {}
	for index = 1, math.min(#values, limit) do
		display[#display + 1] = values[index]
	end
	if #values > limit then
		display[#display + 1] = string.format("+%d more", #values - limit)
	end
	return table.concat(display, ", ")
end
