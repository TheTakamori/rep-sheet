AltRepTracker = AltRepTracker or {}
local ns = AltRepTracker

-- Fallback parent links for faction groups whose direct children are not
-- exposed reliably by the current Blizzard scan APIs.
ns.FACTION_PARENT_HINTS_BY_ID = {
	[2601] = 2600, -- The Weaver -> The Severed Threads
	[2605] = 2600, -- The General -> The Severed Threads
	[2607] = 2600, -- The Vizier -> The Severed Threads
	[2671] = 2653, -- Venture Company -> The Cartels of Undermine
	[2673] = 2653, -- Bilgewater Cartel -> The Cartels of Undermine
	[2675] = 2653, -- Blackwater Cartel -> The Cartels of Undermine
	[2677] = 2653, -- Steamwheedle Cartel -> The Cartels of Undermine
}

-- Some rows still inherit an incorrect section header from the standard
-- reputation list even though they are top-level factions in the UI.
ns.FACTION_FORCE_ROOT_IDS = {
	[2640] = true, -- Brann Bronzebeard
}
