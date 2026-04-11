AltRepTracker = AltRepTracker or {}
local ns = AltRepTracker
local tree = ns.FactionTree or {}
ns.FactionTree = tree

local function appendUnique(list, value)
	if value == nil or value == "" then
		return
	end
	for index = 1, #list do
		if list[index] == value then
			return
		end
	end
	list[#list + 1] = value
end

function tree.RebuildBucketSearchText(bucket)
	local relatedNames = {}
	if bucket.parentFactionName and bucket.parentFactionName ~= "" then
		appendUnique(relatedNames, bucket.parentFactionName)
	end
	if bucket.childFactionNames then
		for index = 1, #bucket.childFactionNames do
			appendUnique(relatedNames, bucket.childFactionNames[index])
		end
	end

	bucket.searchText = ns.NormalizeSearchText(string.format(
		"%s %s %s %s %s",
		bucket.name or "",
		bucket.expansionName or "",
		bucket.repTypeLabel or "",
		bucket.headerLabel or "",
		table.concat(relatedNames, " ")
	))
end

local function isForcedRoot(bucket)
	local factionID = ns.SafeNumber(bucket and bucket.factionID, 0)
	return ns.FACTION_FORCE_ROOT_IDS and ns.FACTION_FORCE_ROOT_IDS[factionID] == true or false
end

local function findBestNamedBucket(name, expansionKey, bucketsByName, currentFactionKey)
	local normalizedName = ns.NormalizeSearchText(name)
	if normalizedName == "" then
		return nil
	end

	local candidates = bucketsByName[normalizedName]
	local fallback = nil
	for candidateIndex = 1, #(candidates or {}) do
		local candidate = candidates[candidateIndex]
		if candidate and candidate.factionKey ~= currentFactionKey then
			if candidate.expansionKey == expansionKey then
				return candidate
			end
			fallback = fallback or candidate
		end
	end

	return fallback
end

local function chooseParentBucketFromHints(bucket, byFactionKey)
	local factionID = ns.SafeNumber(bucket.factionID, 0)
	local hintedParentID = ns.FACTION_PARENT_HINTS_BY_ID and ns.FACTION_PARENT_HINTS_BY_ID[factionID] or nil
	if hintedParentID then
		local parentBucket = byFactionKey[tostring(hintedParentID)]
		if parentBucket and parentBucket.factionKey ~= bucket.factionKey then
			return parentBucket
		end
	end
	return nil
end

local function chooseParentBucketFromHeaders(bucket, bucketsByName)
	local headerPath = bucket.headerPath
	if type(headerPath) ~= "table" or #headerPath == 0 then
		return nil
	end

	local directParentName = ns.NormalizeText(headerPath[#headerPath])
	if directParentName == "" then
		return nil
	end

	return findBestNamedBucket(directParentName, bucket.expansionKey, bucketsByName, bucket.factionKey)
end

local function countParentDepth(bucket, byFactionKey)
	local depth = 0
	local cursor = bucket
	local seen = {}
	while cursor and cursor.parentFactionKey do
		local parentKey = tostring(cursor.parentFactionKey)
		if seen[parentKey] then
			break
		end
		seen[parentKey] = true
		cursor = byFactionKey[parentKey]
		if cursor then
			depth = depth + 1
		end
	end
	return depth
end

local function rebuildChildFactionNames(bucket, byFactionKey)
	if not bucket.childFactionKeys or #bucket.childFactionKeys == 0 then
		bucket.childFactionKeys = nil
		bucket.childFactionNames = nil
		return
	end

	table.sort(bucket.childFactionKeys, function(a, b)
		local childA = byFactionKey[a]
		local childB = byFactionKey[b]
		local nameA = ns.NormalizeSearchText(childA and childA.name or "")
		local nameB = ns.NormalizeSearchText(childB and childB.name or "")
		if nameA ~= nameB then
			return nameA < nameB
		end
		return tostring(a) < tostring(b)
	end)

	bucket.childFactionNames = {}
	for childIndex = 1, #bucket.childFactionKeys do
		local childBucket = byFactionKey[bucket.childFactionKeys[childIndex]]
		if childBucket and childBucket.name and childBucket.name ~= "" then
			bucket.childFactionNames[#bucket.childFactionNames + 1] = childBucket.name
		end
	end
end

function tree.LinkBucketRelationships(all, byFactionKey)
	local bucketsByName = {}

	for index = 1, #all do
		local bucket = all[index]
		local normalizedName = ns.NormalizeSearchText(bucket.name)
		if normalizedName ~= "" then
			bucketsByName[normalizedName] = bucketsByName[normalizedName] or {}
			bucketsByName[normalizedName][#bucketsByName[normalizedName] + 1] = bucket
		end
	end

	for index = 1, #all do
		local bucket = all[index]
		bucket.parentFactionKey = nil
		bucket.parentFactionName = nil
		bucket.childFactionKeys = nil
		bucket.childFactionNames = nil
		bucket.treeDepth = 0
	end

	for index = 1, #all do
		local bucket = all[index]
		if not isForcedRoot(bucket) then
			local parentBucket = chooseParentBucketFromHints(bucket, byFactionKey)
				or chooseParentBucketFromHeaders(bucket, bucketsByName)
			if parentBucket and parentBucket ~= bucket then
				bucket.parentFactionKey = parentBucket.factionKey
				bucket.parentFactionName = parentBucket.name
				parentBucket.childFactionKeys = parentBucket.childFactionKeys or {}
				appendUnique(parentBucket.childFactionKeys, bucket.factionKey)
			end
		end
	end

	for index = 1, #all do
		local bucket = all[index]
		rebuildChildFactionNames(bucket, byFactionKey)
		bucket.treeDepth = countParentDepth(bucket, byFactionKey)
		tree.RebuildBucketSearchText(bucket)
	end
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
		bucket.treeHasChildren = hasChildren
		bucket.treeCollapsed = hasChildren and ns.IsFactionCollapsed(bucket.factionKey) and not revealSearchMatches
		rows[#rows + 1] = bucket
		if hasChildren and not bucket.treeCollapsed then
			for childIndex = 1, #children do
				appendBranch(children[childIndex])
			end
		end
	end

	for rootIndex = 1, #roots do
		appendBranch(roots[rootIndex])
	end

	return rows
end
