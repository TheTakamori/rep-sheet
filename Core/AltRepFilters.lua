RepSheet = RepSheet or {}
local ns = RepSheet
local altRepApi = ns.AltRepFilters or {}
ns.AltRepFilters = altRepApi

local function entrySortName(entry)
	local name = ns.SafeString(entry.sortName)
	if name == "" then
		name = ns.NormalizeSearchText(entry.name)
	end
	return name
end

function altRepApi.CompareEntriesByName(a, b)
	local nameA = entrySortName(a)
	local nameB = entrySortName(b)
	if nameA ~= nameB then
		return nameA < nameB
	end
	return tostring(a.factionKey) < tostring(b.factionKey)
end

function altRepApi.CompareEntriesByLevelDesc(a, b)
	local fracA = ns.SafeNumber(a.overallFraction, 0)
	local fracB = ns.SafeNumber(b.overallFraction, 0)
	if fracA ~= fracB then
		return fracA > fracB
	end
	local maxedA = a.isMaxed and 1 or 0
	local maxedB = b.isMaxed and 1 or 0
	if maxedA ~= maxedB then
		return maxedA > maxedB
	end
	return altRepApi.CompareEntriesByName(a, b)
end

function altRepApi.CompareEntries(sortKey, a, b)
	if sortKey == ns.ALT_REP_SORT_KEY.LEVEL_DESC then
		return altRepApi.CompareEntriesByLevelDesc(a, b)
	end
	return altRepApi.CompareEntriesByName(a, b)
end

local function entryMatchesExpansion(entry, expansionKey)
	if expansionKey == ns.ALL_EXPANSIONS_KEY then
		return true
	end
	return ns.SafeString(entry.expansionKey) == expansionKey
end

function ns.GetFilteredAltReputationEntries(characterKey)
	characterKey = ns.SafeString(characterKey)
	local entries = ns.GetAltReputationEntries(characterKey)
	local filters = ns.GetAltRepFilters()
	local runtime = ns.RuntimeEnsure()

	local expansionKey = ns.SafeString(filters.expansionKey, ns.ALL_EXPANSIONS_KEY)
	local sortKey = filters.sortKey or ns.ALT_REP_SORT_KEY.NAME

	local signature = ns.JoinSignature({
		characterKey,
		expansionKey,
		sortKey,
		#entries,
	})

	if runtime.altRepResultsSignature == signature and runtime.altRepResults then
		return runtime.altRepResults, runtime.altRepResultsTotal or 0
	end

	local filtered = {}
	for index = 1, #entries do
		local entry = entries[index]
		if entryMatchesExpansion(entry, expansionKey) then
			filtered[#filtered + 1] = entry
		end
	end

	table.sort(filtered, function(a, b)
		return altRepApi.CompareEntries(sortKey, a, b)
	end)

	runtime.altRepResultsSignature = signature
	runtime.altRepResults = filtered
	runtime.altRepResultsTotal = #entries
	return filtered, #entries
end
