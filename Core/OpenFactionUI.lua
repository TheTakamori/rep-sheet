RepSheet = RepSheet or {}
local ns = RepSheet

local function pcallOpen(fn, ...)
	if type(fn) ~= "function" then
		return false
	end
	local ok = pcall(fn, ...)
	return ok
end

function ns.OpenFactionInGameUI(bucket)
	if not bucket then
		return
	end

	local repType = bucket.repType
	local majorFactionID = ns.SafeNumber(bucket.majorFactionID, 0)
	local factionID = ns.SafeNumber(bucket.factionID, 0)

	if repType == ns.REP_TYPE.MAJOR and majorFactionID > 0 then
		local api = C_MajorFactions
		if api then
			if pcallOpen(api.OpenRenown, majorFactionID) then
				return
			end
			if pcallOpen(api.OpenMajorFactionRenown, majorFactionID) then
				return
			end
		end
		if pcallOpen(OpenMajorFactionRenown, majorFactionID) then
			return
		end
	end

	if C_Reputation and pcallOpen(C_Reputation.ToggleReputationUI) then
		return
	end

	if pcallOpen(ToggleCharacter, "ReputationFrame") then
		return
	end

	pcallOpen(ToggleCharacter, 4)
end
