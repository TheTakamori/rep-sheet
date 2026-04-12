RepSheet = RepSheet or {}
local ns = RepSheet

local function buildVisibleRow(bucket, hasChildren, isCollapsed)
	local row = {}
	for key, value in pairs(bucket or {}) do
		row[key] = value
	end
	row.treeHasChildren = hasChildren == true
	row.treeCollapsed = isCollapsed == true
	return row
end

function ns.GetFactionParentChain(factionKey)
	local index = ns.BuildFactionIndex()
	local bucket = index.byKey[factionKey]
	if not bucket then
		return {}
	end

	local chain = {}
	local cursor = bucket
	local seen = {}
	while cursor and cursor.parentFactionKey do
		local parentKey = tostring(cursor.parentFactionKey)
		if seen[parentKey] then
			break
		end
		seen[parentKey] = true
		local parentBucket = index.byKey[parentKey]
		if parentBucket then
			table.insert(chain, 1, parentBucket)
			cursor = parentBucket
		else
			break
		end
	end
	return chain
end

function ns.IsFactionDescendantOf(factionKey, ancestorFactionKey)
	local index = ns.BuildFactionIndex()
	local bucket = index.byKey[factionKey]
	local targetKey = tostring(ancestorFactionKey or "")
	if not bucket or targetKey == "" then
		return false
	end

	local cursor = bucket
	local seen = {}
	while cursor and cursor.parentFactionKey do
		local parentKey = tostring(cursor.parentFactionKey)
		if seen[parentKey] then
			break
		end
		if parentKey == targetKey then
			return true
		end
		seen[parentKey] = true
		cursor = index.byKey[parentKey]
	end
	return false
end

function ns.GetVisibleFactionRows()
	local runtime = ns.RuntimeEnsure()
	if runtime.visibleRows and runtime.visibleRowsDirty ~= true then
		return runtime.visibleRows
	end

	local index = ns.BuildFactionIndex()
	local filters = ns.GetFilters()
	local matchedBuckets = ns.GetFilteredFactionResults()
	local visibleByKey = {}

	for bucketIndex = 1, #matchedBuckets do
		local bucket = matchedBuckets[bucketIndex]
		local cursor = bucket
		while cursor do
			if visibleByKey[cursor.factionKey] then
				break
			end
			visibleByKey[cursor.factionKey] = true
			if not cursor.parentFactionKey then
				break
			end
			cursor = index.byKey[cursor.parentFactionKey]
		end
	end

	-- Keep search results expanded while typing, but still allow manual
	-- collapsing when the user is only filtering by expansion or status.
	local revealSearchMatches = ns.NormalizeSearchText(filters.searchText) ~= ""

	local function collectVisibleChildren(bucket)
		local children = {}
		for childIndex = 1, #(bucket.childFactionKeys or {}) do
			local childKey = bucket.childFactionKeys[childIndex]
			local childBucket = index.byKey[childKey]
			if childBucket and visibleByKey[childBucket.factionKey] then
				children[#children + 1] = childBucket
			end
		end
		table.sort(children, function(a, b)
			return ns.FactionFilters.CompareBucketsCore(ns.SORT_KEY.NAME, a, b)
		end)
		return children
	end

	local roots = {}
	for bucketIndex = 1, #index.all do
		local bucket = index.all[bucketIndex]
		if visibleByKey[bucket.factionKey] then
			local parentBucket = bucket.parentFactionKey and index.byKey[bucket.parentFactionKey] or nil
			if not parentBucket or not visibleByKey[parentBucket.factionKey] then
				roots[#roots + 1] = bucket
			end
		end
	end
	table.sort(roots, function(a, b)
		return ns.FactionFilters.CompareBucketsCore(filters.sortKey or ns.SORT_KEY.BEST_PROGRESS, a, b)
	end)

	local rows = {}
	local function appendBranch(bucket)
		local children = collectVisibleChildren(bucket)
		local hasChildren = #children > 0
		local isCollapsed = hasChildren and ns.IsFactionCollapsed(bucket.factionKey) and not revealSearchMatches
		rows[#rows + 1] = buildVisibleRow(bucket, hasChildren, isCollapsed)
		if hasChildren and not isCollapsed then
			for childIndex = 1, #children do
				appendBranch(children[childIndex])
			end
		end
	end

	for rootIndex = 1, #roots do
		appendBranch(roots[rootIndex])
	end

	runtime.visibleRows = rows
	runtime.visibleRowsDirty = false
	return rows
end
