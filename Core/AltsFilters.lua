RepSheet = RepSheet or {}
local ns = RepSheet
local altsApi = ns.AltsFilters or {}
ns.AltsFilters = altsApi

local function recordHasProfession(record, professionName)
	for index = 1, #(record.professionList or {}) do
		if record.professionList[index] == professionName then
			return true
		end
	end
	return false
end

local function recordMatchesFilters(record, searchText, factionGroup, classFile, raceFile, professionName)
	if searchText ~= "" then
		local nameMatch = string.find(record.searchText or "", searchText, 1, true)
		local realmMatch = string.find(record.realmSearchText or "", searchText, 1, true)
		if not nameMatch and not realmMatch then
			return false
		end
	end

	if factionGroup ~= ns.ALT_FACTION_FILTER.ALL and record.factionName ~= factionGroup then
		return false
	end

	if classFile ~= ns.ALL_ALT_FILTER_KEY and record.classFile ~= classFile then
		return false
	end

	if raceFile ~= ns.ALL_ALT_FILTER_KEY and record.raceFile ~= raceFile then
		return false
	end

	if professionName ~= ns.ALL_ALT_FILTER_KEY and not recordHasProfession(record, professionName) then
		return false
	end

	return true
end

function altsApi.CompareRecordsCore(sortKey, a, b)
	if sortKey == ns.ALT_SORT_KEY.LEVEL_DESC then
		local levelA = ns.SafeNumber(a.level, 0)
		local levelB = ns.SafeNumber(b.level, 0)
		if levelA ~= levelB then
			return levelA > levelB
		end
	elseif sortKey == ns.ALT_SORT_KEY.CLASS then
		if a.sortClass ~= b.sortClass then
			return a.sortClass < b.sortClass
		end
	elseif sortKey == ns.ALT_SORT_KEY.LAST_SCAN_DESC then
		local scanA = ns.SafeNumber(a.lastScanAt, 0)
		local scanB = ns.SafeNumber(b.lastScanAt, 0)
		if scanA ~= scanB then
			return scanA > scanB
		end
	end

	if a.sortName ~= b.sortName then
		return a.sortName < b.sortName
	end
	return tostring(a.characterKey) < tostring(b.characterKey)
end

function ns.GetFilteredAltResults()
	local index = ns.BuildAltsIndex()
	local altFilters = ns.GetAltFilters()
	local runtime = ns.RuntimeEnsure()

	local searchText = ns.NormalizeSearchText(altFilters.searchText)
	local factionGroup = altFilters.factionGroup or ns.ALT_FACTION_FILTER.ALL
	local classFile = altFilters.classFile or ns.ALL_ALT_FILTER_KEY
	local raceFile = altFilters.raceFile or ns.ALL_ALT_FILTER_KEY
	local professionName = altFilters.professionName or ns.ALL_ALT_FILTER_KEY
	local sortKey = altFilters.sortKey or ns.ALT_SORT_KEY.NAME

	local signature = ns.JoinSignature({
		searchText,
		factionGroup,
		classFile,
		raceFile,
		professionName,
		sortKey,
		index.totalAlts,
	})

	if runtime.altResultsSignature == signature and runtime.altResults then
		return runtime.altResults, runtime.altResultsTotal or 0
	end

	local filtered = {}
	for recordIndex = 1, #index.all do
		local record = index.all[recordIndex]
		if recordMatchesFilters(record, searchText, factionGroup, classFile, raceFile, professionName) then
			filtered[#filtered + 1] = record
		end
	end

	table.sort(filtered, function(a, b)
		return altsApi.CompareRecordsCore(sortKey, a, b)
	end)

	runtime.altResultsSignature = signature
	runtime.altResults = filtered
	runtime.altResultsTotal = index.totalAlts
	return filtered, index.totalAlts
end
