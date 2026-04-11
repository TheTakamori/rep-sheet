RepSheet = RepSheet or {}
local ns = RepSheet
local filtersApi = ns.FactionFilters

local function bucketMatchesFilters(bucket, expansionKey, searchText, statusKey)
	if expansionKey ~= ns.ALL_EXPANSIONS_KEY and bucket.expansionKey ~= expansionKey then
		return false
	end

	if searchText ~= "" and string.find(bucket.searchText or "", searchText, 1, true) == nil then
		return false
	end

	if statusKey == ns.FILTER_STATUS.FAVORITES then
		return ns.IsFavoriteFaction(bucket.factionKey)
	end
	if statusKey == ns.FILTER_STATUS.MAXED then
		return bucket.maxedCount > 0
	end

	return true
end

function filtersApi.CompareBucketsCore(sortKey, a, b)
	if sortKey == ns.SORT_KEY.EXPANSION then
		local expA = ns.ExpansionSortValue(a.expansionKey)
		local expB = ns.ExpansionSortValue(b.expansionKey)
		if expA ~= expB then
			return expA < expB
		end
	elseif sortKey == ns.SORT_KEY.BEST_PROGRESS then
		if a.bestOverallFraction ~= b.bestOverallFraction then
			return a.bestOverallFraction > b.bestOverallFraction
		end
		if a.maxedCount ~= b.maxedCount then
			return a.maxedCount > b.maxedCount
		end
	elseif sortKey == ns.SORT_KEY.CLOSEST_TO_NEXT then
		if a.closestRemaining ~= b.closestRemaining then
			return a.closestRemaining < b.closestRemaining
		end
		if a.bestOverallFraction ~= b.bestOverallFraction then
			return a.bestOverallFraction > b.bestOverallFraction
		end
	end

	local nameA = ns.NormalizeSearchText(a.name)
	local nameB = ns.NormalizeSearchText(b.name)
	if nameA ~= nameB then
		return nameA < nameB
	end
	return tostring(a.factionKey) < tostring(b.factionKey)
end

local function compareBuckets(sortKey, byFactionKey, a, b)
	local groupA = (a.parentFactionKey and byFactionKey[a.parentFactionKey]) or a
	local groupB = (b.parentFactionKey and byFactionKey[b.parentFactionKey]) or b
	if groupA ~= groupB then
		return filtersApi.CompareBucketsCore(sortKey, groupA, groupB)
	end

	local isChildA = groupA ~= a
	local isChildB = groupB ~= b
	if isChildA ~= isChildB then
		return not isChildA
	end

	return filtersApi.CompareBucketsCore(ns.SORT_KEY.NAME, a, b)
end

function ns.GetFilteredFactionResults()
	local index = ns.BuildFactionIndex()
	local filters = ns.GetFilters()
	local runtime = ns.RuntimeEnsure()
	local expansionKey = filters.expansionKey or ns.ALL_EXPANSIONS_KEY
	local searchText = ns.NormalizeSearchText(filters.searchText)
	local sortKey = filters.sortKey or ns.SORT_KEY.BEST_PROGRESS
	local statusKey = filters.statusKey or ns.FILTER_STATUS.ALL
	local signature = table.concat({
		expansionKey,
		searchText,
		sortKey,
		statusKey,
		tostring(index.totalCharacters),
	}, "\31")

	if runtime.filteredSignature == signature and runtime.filteredResults then
		return runtime.filteredResults, runtime.filteredTotalCharacters or 0
	end

	local filtered = {}
	for bucketIndex = 1, #index.all do
		local bucket = index.all[bucketIndex]
		if bucketMatchesFilters(bucket, expansionKey, searchText, statusKey) then
			filtered[#filtered + 1] = bucket
		end
	end

	table.sort(filtered, function(a, b)
		return compareBuckets(sortKey, index.byKey, a, b)
	end)

	runtime.filteredSignature = signature
	runtime.filteredResults = filtered
	runtime.filteredTotalCharacters = index.totalCharacters
	return filtered, index.totalCharacters
end
