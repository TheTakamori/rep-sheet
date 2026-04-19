RepSheet = RepSheet or {}
local ns = RepSheet
local helpers = ns.NormalizerHelpers

function ns.NormalizeCurrentCharacterSnapshot(reason, scanRows, specialMap, scanKind)
	local snapshot = ns.BuildCurrentCharacterSnapshotBase(reason, scanKind)
	specialMap = specialMap or {}

	for index = 1, #(scanRows or {}) do
		local rawRow = scanRows[index]
		local normalized = helpers.normalizeFactionRow(rawRow, specialMap[rawRow.factionKey])
		if normalized then
			normalized.characterKey = snapshot.characterKey
			normalized.characterName = snapshot.name
			local existing = snapshot.reputations[normalized.factionKey]
			if existing and (ns.ShouldTraceReputationRow(rawRow, specialMap[rawRow.factionKey]) or ns.ShouldTraceReputationRow(existing)) then
				ns.DebugLog(string.format(
					'SAVE collision key=%s keep? incoming=%s[%s | %s] existing=%s[%s | %s]',
					ns.DebugValueText(normalized.factionKey),
					ns.DebugValueText(normalized.name),
					ns.DebugValueText(normalized.rankText),
					ns.DebugValueText(normalized.progressText),
					ns.DebugValueText(existing.name),
					ns.DebugValueText(existing.rankText),
					ns.DebugValueText(existing.progressText)
				))
			end
			if not existing or helpers.scoreNormalizedRow(normalized) >= helpers.scoreNormalizedRow(existing) then
				snapshot.reputations[normalized.factionKey] = normalized
			end
		end
	end

	snapshot.reputationCount = ns.CountTable(snapshot.reputations)
	return snapshot
end
