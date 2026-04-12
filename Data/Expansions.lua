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
ns.ExpansionDataByKey = byKey
ns.ExpansionOrderByKey = orderByKey
