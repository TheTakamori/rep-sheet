RepSheet = RepSheet or {}
local ns = RepSheet

local list = {
	{ key = ns.ALL_EXPANSIONS_KEY, name = "All expansions", gameExp = nil },
	{ key = "classic", name = "Classic / Vanilla", gameExp = LE_EXPANSION_CLASSIC },
	{ key = "bc", name = "The Burning Crusade", gameExp = LE_EXPANSION_BURNING_CRUSADE },
	{ key = "wrath", name = "Wrath of the Lich King", gameExp = LE_EXPANSION_WRATH_OF_THE_LICH_KING },
	{ key = "cata", name = "Cataclysm", gameExp = LE_EXPANSION_CATACLYSM },
	{ key = "mop", name = "Mists of Pandaria", gameExp = LE_EXPANSION_MISTS_OF_PANDARIA },
	{ key = "wod", name = "Warlords of Draenor", gameExp = LE_EXPANSION_WARLORDS_OF_DRAENOR },
	{ key = "legion", name = "Legion", gameExp = LE_EXPANSION_LEGION },
	{ key = "bfa", name = "Battle for Azeroth", gameExp = LE_EXPANSION_BATTLE_FOR_AZEROTH },
	{ key = "sl", name = "Shadowlands", gameExp = LE_EXPANSION_SHADOWLANDS },
	{ key = "df", name = "Dragonflight", gameExp = LE_EXPANSION_DRAGONFLIGHT },
	{ key = "tww", name = "The War Within", gameExp = LE_EXPANSION_WAR_WITHIN },
	{ key = "midnight", name = "Midnight", gameExp = rawget(_G, "LE_EXPANSION_MIDNIGHT") },
}

ns.Expansions = list

local byKey = {}
local orderByKey = {}
for index = 1, #list do
	local entry = list[index]
	byKey[entry.key] = entry
	orderByKey[entry.key] = index
end

function ns.GetExpansionByKey(key)
	return byKey[key] or byKey.all
end

function ns.ExpansionLabelForKey(key)
	return ns.GetExpansionByKey(key).name
end

function ns.ExpansionSortValue(key)
	return orderByKey[key] or math.huge
end

function ns.ExpansionKeyFromGameExp(gameExp)
	if gameExp == nil then
		return nil
	end
	for i = 1, #list do
		local entry = list[i]
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
