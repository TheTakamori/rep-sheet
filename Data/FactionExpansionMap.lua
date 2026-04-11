AltRepTracker = AltRepTracker or {}
local ns = AltRepTracker

local overridesByID = {
	[2507] = "df", -- Dragonscale Expedition
	[2503] = "df", -- Maruuk Centaur
	[2510] = "df", -- Valdrakken Accord
	[2511] = "df", -- Iskaara Tuskarr
	[2564] = "df", -- Loamm Niffen
	[2574] = "df", -- Dream Wardens
	[2590] = "tww", -- Council of Dornogal
	[2594] = "tww", -- The Assembly of the Deeps
	[2570] = "tww", -- Hallowfall Arathi
	[2600] = "tww", -- The Severed Threads
}

local overridesByName = {
	[ns.NormalizeSearchText("Dragonscale Expedition")] = "df",
	[ns.NormalizeSearchText("Maruuk Centaur")] = "df",
	[ns.NormalizeSearchText("Valdrakken Accord")] = "df",
	[ns.NormalizeSearchText("Iskaara Tuskarr")] = "df",
	[ns.NormalizeSearchText("Loamm Niffen")] = "df",
	[ns.NormalizeSearchText("Dream Wardens")] = "df",
	[ns.NormalizeSearchText("Wrathion")] = "df",
	[ns.NormalizeSearchText("Sabellian")] = "df",
	[ns.NormalizeSearchText("Cobalt Assembly")] = "df",
	[ns.NormalizeSearchText("Council of Dornogal")] = "tww",
	[ns.NormalizeSearchText("The Assembly of the Deeps")] = "tww",
	[ns.NormalizeSearchText("Hallowfall Arathi")] = "tww",
	[ns.NormalizeSearchText("The Severed Threads")] = "tww",
	[ns.NormalizeSearchText("The Cartels of Undermine")] = "tww",
	[ns.NormalizeSearchText("Brann Bronzebeard")] = "tww",
	[ns.NormalizeSearchText("Neighborhood Initiative")] = "midnight",
}

function ns.ResolveFactionExpansionOverride(factionID, factionName)
	if factionID and overridesByID[factionID] then
		return overridesByID[factionID]
	end
	local normalizedName = ns.NormalizeSearchText(factionName)
	if normalizedName ~= "" and overridesByName[normalizedName] then
		return overridesByName[normalizedName]
	end
	return nil
end
