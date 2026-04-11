RepSheet = RepSheet or {}
local ns = RepSheet

function ns.SaveMainFramePosition(frame)
	if not frame or not frame.GetPoint then
		return
	end
	local point, _, relativePoint, xOfs, yOfs = frame:GetPoint(1)
	local pos = RepSheetDB.ui.mainFrame
	pos.point = point or ns.DEFAULT_MAIN_FRAME_POSITION.point
	pos.relativePoint = relativePoint or pos.point
	pos.x = ns.Round(xOfs or 0)
	pos.y = ns.Round(yOfs or 0)
end

function ns.RestoreMainFramePosition(frame)
	if not frame then
		return
	end
	local pos = RepSheetDB.ui.mainFrame or {}
	local fallback = ns.DEFAULT_MAIN_FRAME_POSITION
	frame:ClearAllPoints()
	frame:SetPoint(
		pos.point or fallback.point,
		UIParent,
		pos.relativePoint or pos.point or fallback.relativePoint,
		pos.x or fallback.x,
		pos.y or fallback.y
	)
end
