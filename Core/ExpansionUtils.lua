RepSheet = RepSheet or {}
local ns = RepSheet

function ns.GetExpansionByKey(key)
	local byKey = ns.ExpansionDataByKey or {}
	return byKey[key] or byKey[ns.ALL_EXPANSIONS_KEY]
end

function ns.ExpansionLabelForKey(key)
	local entry = ns.GetExpansionByKey(key)
	return entry and entry.name or ns.TEXT.UNKNOWN
end

function ns.ExpansionSortValue(key)
	return (ns.ExpansionOrderByKey or {})[key] or math.huge
end

function ns.ExpansionKeyFromGameExp(gameExp)
	if gameExp == nil then
		return nil
	end
	for index = 1, #(ns.Expansions or {}) do
		local entry = ns.Expansions[index]
		if entry.gameExp ~= nil and entry.gameExp == gameExp then
			return entry.key
		end
	end
	return nil
end

function ns.ResolveExpansionKeyFromHeader(headerName)
	headerName = ns.NormalizeSearchText(headerName)
	if headerName == "" then
		return nil
	end
	return ns.EXPANSION_HEADER_ALIASES[headerName]
end

function ns.ResolveExpansionKeyFromHeaders(headerPath)
	if type(headerPath) ~= "table" then
		return nil
	end
	for index = #headerPath, 1, -1 do
		local key = ns.ResolveExpansionKeyFromHeader(headerPath[index])
		if key and key ~= ns.ALL_EXPANSIONS_KEY then
			return key
		end
	end
	return nil
end
