RepSheet = RepSheet or {}
local ns = RepSheet

local function profSlotName(profession)
	if type(profession) ~= "table" then
		return ""
	end
	return ns.SafeString(profession.name)
end

local function buildProfessionList(professions)
	local list = {}
	if type(professions) ~= "table" then
		return list
	end
	local first = profSlotName(professions.primary1)
	if first ~= "" then
		list[#list + 1] = first
	end
	local second = profSlotName(professions.primary2)
	if second ~= "" then
		list[#list + 1] = second
	end
	return list
end

local function buildMetaText(record)
	local parts = {}
	if record.level > 0 then
		parts[#parts + 1] = string.format(
			ns.FORMAT.ALT_DETAIL_LEVEL_RACE_CLASS,
			record.level,
			record.raceName,
			record.className
		)
	end
	if record.factionName ~= "" then
		parts[#parts + 1] = string.format(ns.FORMAT.ALT_FACTION_GROUP, record.factionName)
	end
	return table.concat(parts, ns.SEPARATOR.META_PARTS)
end

local function buildProfessionText(record)
	if #record.professionList == 0 then
		return ns.TEXT.NO_PROFESSIONS
	end
	return table.concat(record.professionList, ns.SEPARATOR.PROFESSION_LIST)
end

local function buildAltRecord(character, reputationCount)
	local record = {
		characterKey = ns.SafeString(character.characterKey),
		name = ns.SafeString(character.name, ns.TEXT.UNKNOWN),
		realm = ns.SafeString(character.realm),
		level = ns.SafeNumber(character.level, 0),
		className = ns.SafeString(character.className),
		classFile = ns.SafeString(character.classFile),
		raceName = ns.SafeString(character.raceName),
		raceFile = ns.SafeString(character.raceFile),
		factionName = ns.SafeString(character.factionName),
		professions = type(character.professions) == "table" and character.professions or nil,
		professionList = buildProfessionList(character.professions),
		reputationCount = ns.SafeNumber(reputationCount, 0),
		lastScanAt = ns.SafeNumber(character.lastScanAt, 0),
	}
	record.searchText = ns.NormalizeSearchText(record.name)
	record.realmSearchText = ns.NormalizeSearchText(record.realm)
	record.sortName = ns.NormalizeSearchText(record.name)
	record.sortClass = ns.NormalizeSearchText(record.className)
	record.metaText = buildMetaText(record)
	record.professionText = buildProfessionText(record)
	return record
end

local function appendUniqueOption(target, key, label)
	key = ns.SafeString(key)
	if key == "" or target.seen[key] then
		return
	end
	target.seen[key] = true
	target.list[#target.list + 1] = { key = key, label = label or key }
end

local function newOptionAccumulator(allLabel)
	return {
		seen = {},
		list = { { key = ns.ALL_ALT_FILTER_KEY, label = allLabel } },
	}
end

local function sortOptions(accumulator)
	table.sort(accumulator.list, function(a, b)
		if a.key == ns.ALL_ALT_FILTER_KEY then
			return true
		end
		if b.key == ns.ALL_ALT_FILTER_KEY then
			return false
		end
		return ns.NormalizeSearchText(a.label) < ns.NormalizeSearchText(b.label)
	end)
	return accumulator.list
end

function ns.BuildAltsIndex()
	local runtime = ns.RuntimeEnsure()
	if not runtime.altsIndexDirty and runtime.altsIndex then
		return runtime.altsIndex
	end

	local characters = ns.GetSortedCharacters()
	local all = {}
	local byKey = {}

	local classes = newOptionAccumulator(ns.TEXT.ALTS_FILTER_ALL_CLASSES)
	local races = newOptionAccumulator(ns.TEXT.ALTS_FILTER_ALL_RACES)
	local professions = newOptionAccumulator(ns.TEXT.ALTS_FILTER_ALL_PROFESSIONS)

	for index = 1, #characters do
		local character = characters[index]
		local reputationCount = ns.CountTable(character.reputations)
		local record = buildAltRecord(character, reputationCount)
		all[#all + 1] = record
		byKey[record.characterKey] = record

		if record.classFile ~= "" then
			appendUniqueOption(classes, record.classFile, record.className ~= "" and record.className or record.classFile)
		end
		if record.raceFile ~= "" then
			appendUniqueOption(races, record.raceFile, record.raceName ~= "" and record.raceName or record.raceFile)
		end
		for profIndex = 1, #record.professionList do
			local name = record.professionList[profIndex]
			appendUniqueOption(professions, name, name)
		end
	end

	runtime.altsIndex = {
		all = all,
		byKey = byKey,
		totalAlts = #all,
		options = {
			classes = sortOptions(classes),
			races = sortOptions(races),
			professions = sortOptions(professions),
		},
	}
	runtime.altsIndexDirty = false
	ns.InvalidateAltResults()
	return runtime.altsIndex
end

function ns.GetAltRecordByKey(characterKey)
	if ns.SafeString(characterKey) == "" then
		return nil
	end
	return ns.BuildAltsIndex().byKey[characterKey]
end

function ns.GetAltFilterOptions()
	return ns.BuildAltsIndex().options
end

local function compareReputationEntries(a, b)
	local nameA = ns.SafeString(a.sortName)
	if nameA == "" then
		nameA = ns.NormalizeSearchText(a.name)
	end
	local nameB = ns.SafeString(b.sortName)
	if nameB == "" then
		nameB = ns.NormalizeSearchText(b.name)
	end
	if nameA ~= nameB then
		return nameA < nameB
	end
	return tostring(a.factionKey) < tostring(b.factionKey)
end

function ns.GetAltReputationEntries(characterKey)
	characterKey = ns.SafeString(characterKey)
	if characterKey == "" then
		return {}
	end

	local runtime = ns.RuntimeEnsure()
	runtime.altRepEntriesByCharacter = type(runtime.altRepEntriesByCharacter) == "table"
		and runtime.altRepEntriesByCharacter
		or {}
	if runtime.altRepEntriesByCharacter[characterKey] then
		return runtime.altRepEntriesByCharacter[characterKey]
	end

	local index = ns.BuildFactionIndex()
	local entries = {}
	for bucketIndex = 1, #index.all do
		local bucket = index.all[bucketIndex]
		local entry = bucket.byCharacterKey and bucket.byCharacterKey[characterKey] or nil
		if entry then
			entries[#entries + 1] = entry
		end
	end

	table.sort(entries, compareReputationEntries)
	runtime.altRepEntriesByCharacter[characterKey] = entries
	return entries
end
