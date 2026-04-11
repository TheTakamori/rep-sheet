AltRepTracker = AltRepTracker or {}
local ns = AltRepTracker

ns.DB_SCHEMA_VERSION = 2
ns.ADDON_NAME = "AltRepTracker"
ns.ADDON_METADATA_VERSION_KEY = "Version"
ns.ALL_EXPANSIONS_KEY = "all"
ns.SCAN_DELAY_SECONDS = 0.8
ns.DEBUG_LOG_MAX_LINES = 400
ns.FACTION_HEADER_EXPAND_LIMIT = 500
ns.EXTRA_MAJOR_FACTION_IDS = { 2600 }

ns.FACTION_ICON = "Interface\\Icons\\Achievement_Reputation_01"
ns.FACTION_ICON_MAJOR = "Interface\\Icons\\inv_misc_book_09"
ns.FACTION_ICON_FRIENDSHIP = "Interface\\Icons\\inv_misc_toy_07"
ns.FACTION_ICON_NEIGHBORHOOD = "Interface\\Icons\\inv_10_misc_homerepairkit_color1"
ns.FALLBACK_CLASS_COLOR = { 1, 0.82, 0 }
ns.MAX_STANDARD_STANDING_ID = 8
ns.SORT_WEIGHTS = {
	MAXED = 1,
	ENTRY_PARAGON = 0.1,
	NORMALIZED_MAJOR = 0.25,
	NORMALIZED_FRIENDSHIP = 0.1,
	NORMALIZED_PARAGON = 0.2,
}

ns.FILTER_STATUS = {
	ALL = "all",
	FAVORITES = "favorites",
	MAXED = "maxed",
}

ns.FILTER_STATUS_OPTIONS = {
	{ key = ns.FILTER_STATUS.ALL, label = "All Factions" },
	{ key = ns.FILTER_STATUS.FAVORITES, label = "Favorites Only" },
	{ key = ns.FILTER_STATUS.MAXED, label = "Any Alt Maxed" },
}

ns.SORT_KEY = {
	BEST_PROGRESS = "bestProgress",
	CLOSEST_TO_NEXT = "closestToNext",
	NAME = "name",
	EXPANSION = "expansion",
}

ns.SORT_OPTIONS = {
	{ key = ns.SORT_KEY.BEST_PROGRESS, label = "Best Alt Progress" },
	{ key = ns.SORT_KEY.CLOSEST_TO_NEXT, label = "Closest to Next Rank" },
	{ key = ns.SORT_KEY.NAME, label = "Faction Name" },
	{ key = ns.SORT_KEY.EXPANSION, label = "Expansion" },
}

ns.REP_TYPE = {
	STANDARD = "standard",
	MAJOR = "major",
	FRIENDSHIP = "friendship",
	NEIGHBORHOOD = "neighborhood",
	OTHER = "other",
}

ns.EVENT = {
	ADDON_LOADED = "ADDON_LOADED",
	PLAYER_LOGIN = "PLAYER_LOGIN",
	PLAYER_ENTERING_WORLD = "PLAYER_ENTERING_WORLD",
	UPDATE_FACTION = "UPDATE_FACTION",
	CHAT_MSG_COMBAT_FACTION_CHANGE = "CHAT_MSG_COMBAT_FACTION_CHANGE",
	MAJOR_FACTION_RENOWN_LEVEL_CHANGED = "MAJOR_FACTION_RENOWN_LEVEL_CHANGED",
	QUEST_TURNED_IN = "QUEST_TURNED_IN",
}

ns.SCAN_REASON = {
	UNKNOWN = "Unknown",
	DELAYED = "Delayed scan",
	MANUAL_REFRESH = "Manual refresh",
	SLASH_COMMAND = "Slash command",
	PLAYER_LOGIN = ns.EVENT.PLAYER_LOGIN,
	PLAYER_ENTERING_WORLD = ns.EVENT.PLAYER_ENTERING_WORLD,
	UPDATE_FACTION = ns.EVENT.UPDATE_FACTION,
	CHAT_MSG_COMBAT_FACTION_CHANGE = ns.EVENT.CHAT_MSG_COMBAT_FACTION_CHANGE,
	MAJOR_FACTION_RENOWN_LEVEL_CHANGED = ns.EVENT.MAJOR_FACTION_RENOWN_LEVEL_CHANGED,
	QUEST_TURNED_IN = ns.EVENT.QUEST_TURNED_IN,
}

ns.SLASH_COMMANDS = { "/altrep", "/altreptracker" }
ns.SLASH_SUBCOMMAND = {
	SCAN = "scan",
	DEBUG = "debug",
}

ns.TEXT = {
	UNKNOWN = "Unknown",
	NEVER = "Never",
	UNKNOWN_FACTION = "Unknown Faction",
	REPUTATION = "Reputation",
	RENOWN = "Renown",
	RENOWN_XP = "Renown XP",
	FRIENDSHIP = "Friendship",
	NEIGHBORHOOD = "Neighborhood",
	PARAGON = "Paragon",
	PARAGON_SUFFIX = " + Paragon",
	NO_DATA = "No Data",
	FAVORITE = "Favorite",
	UNFAVORITE = "Unfavorite",
	DETAILS = "Details",
	DEBUG = "Debug",
	BACK = "Back",
	CANCEL = "Cancel",
	CLEAR_LOG = "Clear Log",
	CLEAR_ALL_DATA = "Clear All Data",
	SCAN_AND_LOG = "Scan & Log",
	FORGET_ALT = "Forget Alt",
	FORGET = "Forget",
	FORGET_ALT_TITLE = "Forget Alt",
	FORGET_ALT_SELECT = "Select an Alt...",
	FORGET_ALT_INFO = "Remove the selected alt's saved Alt Rep Tracker data. This does not delete the WoW character. The data will return if that character logs in and scans again.",
	FORGET_ALT_SCAN_BUSY = "Wait for the current scan to finish before forgetting an alt.",
	FORGET_ALT_CURRENT = "You cannot forget the character you are currently logged into.",
	FORGET_ALT_NOT_FOUND = "That alt is no longer stored. Refresh and try again.",
	FORGET_ALT_FAILED = "Unable to forget that alt right now.",
	WARBAND = "Warband",
	SEARCH = "Search",
	SCAN_THIS_ALT = "Scan This Alt",
	EXPANSION = "Expansion",
	SORT = "Sort",
	FILTER = "Filter",
	MAIN_TITLE = "Alt Rep Tracker",
	MAIN_SUBTITLE = "Which alt has the reputation you need?",
	MAIN_INFO = "Search factions by name, narrow the list with dropdowns, and compare every known alt on the right. Warband reputations show once; progress is the same for every character on your account.",
	NO_FACTION_SELECTED = "No Faction Selected",
	CHOOSE_FACTION_HINT = "Choose a faction from the list on the left.",
	DETAIL_EMPTY_HINT = "Select a faction on the left to see every known alt here.",
	DEBUG_TITLE = "Debug Log",
	DEBUG_INFO = "The log below is a selectable edit box. Click it, then press Ctrl-C to copy. Use Clear Log and Scan & Log to capture a fresh trace. Clear All Data wipes every saved character snapshot so you can test from a clean state.",
	DEBUG_EMPTY_HINT = "No debug lines yet. Use Scan & Log to capture a fresh trace.",
	CLEAR_ALL_DATA_CONFIRM = "Delete all saved Alt Rep Tracker reputation data for every character?",
	KNOWN_CHARACTER_NOTE = "Known characters only. Each alt must log in once with the addon installed.",
	PARAGON_REWARD_READY = "Paragon Reward Ready",
	PROGRESS_BAR_TOOLTIP_TITLE = "Progress Bar Legend",
	PROGRESS_BAR_TOOLTIP_OVERALL = "Blue: Overall progress toward finishing the reputation.",
	PROGRESS_BAR_TOOLTIP_BAND = "Orange: Progress within the current rank or renown level.",
	PROGRESS_BAR_TOOLTIP_MAXED = "Gold: The reputation is fully maxed.",
	PROGRESS_BAR_TOOLTIP_PARAGON = "Purple: Paragon progress after the reputation is maxed.",
}

ns.FORMAT = {
	COUNT_EMPTY = "No factions match the current search and dropdown filters.  Characters: %d",
	COUNT_RESULTS = "Factions: %d  Characters: %d",
	STATUS_FOOTER = "Last Snapshot: %s  Source: %s  Tip: each alt must log in once to appear here.",
	VERSION_FOOTER = "Version: %s",
	CHARACTER_COUNT = "%d Character%s",
	BEST_CHARACTER = "Best: %s",
	PROGRESS_SUMMARY = "%s  Maxed %d",
	DETAIL_LAST_SCAN = "Last Scan: %s",
	DETAIL_SUBTITLE = "%s  %s",
	DETAIL_SUMMARY = "Best Alt: %s  Maxed: %d/%d",
	DETAIL_SUMMARY_WARBAND = "Warband Reputation. Last Snapshot: %s.",
	STANDARD_SCAN_CAPTURED = "Standard scan captured %d faction rows.",
	SAVED_REPUTATIONS = "Saved %d reputations for %s.",
}

ns.LOG = {
	ADDON_LOADED = "Alt Rep Tracker loaded. Use %s to open the browser.",
	MAIN_FRAME_CREATED = "Main frame created. Use %s to open it.",
	SCAN_FAILED = "Scan Failed: %s",
}

ns.DEFAULT_MAIN_FRAME_POSITION = {
	point = "CENTER",
	relativePoint = "CENTER",
	x = 0,
	y = 20,
}

ns.STANDING_LABELS = {
	[1] = "Hated",
	[2] = "Hostile",
	[3] = "Unfriendly",
	[4] = "Neutral",
	[5] = "Friendly",
	[6] = "Honored",
	[7] = "Revered",
	[8] = "Exalted",
}

ns.EXPANSION_HEADER_ALIASES = {
	["all expansions"] = "all",
	["classic"] = "classic",
	["classic / vanilla"] = "classic",
	["vanilla"] = "classic",
	["the burning crusade"] = "bc",
	["burning crusade"] = "bc",
	["wrath of the lich king"] = "wrath",
	["cataclysm"] = "cata",
	["mists of pandaria"] = "mop",
	["warlords of draenor"] = "wod",
	["legion"] = "legion",
	["battle for azeroth"] = "bfa",
	["shadowlands"] = "sl",
	["dragonflight"] = "df",
	["the war within"] = "tww",
	["midnight"] = "midnight",
}
