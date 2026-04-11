AltRepTracker = AltRepTracker or {}
local ns = AltRepTracker
local tree = ns.FactionTree

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

local function findBestNamedBucket(name, expansionKey, bucketsByName, currentFactionKey)
	local normalizedName = ns.NormalizeSearchText(name)
	if normalizedName == "" then
		return nil
	end

	local candidates = bucketsByName[normalizedName]
	for candidateIndex = 1, #(candidates or {}) do
		local candidate = candidates[candidateIndex]
		if candidate
			and candidate.factionKey ~= currentFactionKey
			and candidate.expansionKey == expansionKey
		then
			return candidate
		end
	end

	return nil
end

local function chooseParentBucketFromHeaders(bucket, bucketsByName)
	if bucket.isChild == false then
		return nil
	end

	local headerPath = bucket.headerPath
	if type(headerPath) ~= "table" or #headerPath == 0 then
		return nil
	end

	local directParentName = ns.NormalizeText(headerPath[#headerPath])
	if directParentName == "" then
		return nil
	end

	-- Never fall back across expansions; classic section headers like
	-- "Steamwheedle Cartel" should not attach to unrelated modern factions.
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
		local parentBucket = chooseParentBucketFromHeaders(bucket, bucketsByName)
		if parentBucket and parentBucket ~= bucket then
			bucket.parentFactionKey = parentBucket.factionKey
			bucket.parentFactionName = parentBucket.name
			parentBucket.childFactionKeys = parentBucket.childFactionKeys or {}
			appendUnique(parentBucket.childFactionKeys, bucket.factionKey)
		end
	end

	for index = 1, #all do
		local bucket = all[index]
		rebuildChildFactionNames(bucket, byFactionKey)
		bucket.treeDepth = countParentDepth(bucket, byFactionKey)
		tree.RebuildBucketSearchText(bucket)
	end
end
