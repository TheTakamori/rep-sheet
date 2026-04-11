AltRepTracker = AltRepTracker or {}
local ns = AltRepTracker
local helpers = ns.UIHelpers or {}
ns.UIHelpers = helpers

local colors = ns.UI_COLORS

function helpers.ApplyTextColor(fontString, color)
	if fontString and color then
		fontString:SetTextColor(color[1], color[2], color[3])
	end
end

function helpers.ApplyBackdropColors(frame, backgroundColor, borderColor)
	if not frame then
		return
	end
	if backgroundColor then
		frame:SetBackdropColor(backgroundColor[1], backgroundColor[2], backgroundColor[3], backgroundColor[4])
	end
	if borderColor then
		frame:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
	end
end

function helpers.ApplyStatusBarColor(statusBar, color)
	if statusBar and color then
		statusBar:SetStatusBarColor(color[1], color[2], color[3])
	end
end

function helpers.SetSingleLine(fontString)
	if not fontString then
		return
	end
	if fontString.SetWordWrap then
		fontString:SetWordWrap(false)
	end
	if fontString.SetNonSpaceWrap then
		fontString:SetNonSpaceWrap(false)
	end
	if fontString.SetMaxLines then
		fontString:SetMaxLines(1)
	end
end

function helpers.CreateParagonOverlay(statusBar)
	if not statusBar then
		return nil
	end

	local overlay = CreateFrame("StatusBar", nil, statusBar)
	overlay:SetPoint("TOPLEFT", statusBar, "TOPLEFT", 1, -1)
	overlay:SetPoint("BOTTOMRIGHT", statusBar, "BOTTOMRIGHT", -1, 1)
	overlay:SetStatusBarTexture(ns.UI_TEXTURES.STATUS_BAR)
	overlay:SetMinMaxValues(0, 1)
	overlay:SetFrameLevel(statusBar:GetFrameLevel() + 1)
	overlay:Hide()
	statusBar.paragonOverlay = overlay
	return overlay
end

function helpers.UpdateParagonOverlay(statusBar, source)
	local overlay = statusBar and statusBar.paragonOverlay
	if not overlay then
		return
	end

	local fraction = ns.GetParagonOverlayFraction(source)
	if fraction > 0 then
		overlay:SetValue(fraction)
		helpers.ApplyStatusBarColor(overlay, colors.STATUS_BAR_PARAGON or colors.STATUS_BAR_DEFAULT)
		overlay:Show()
	else
		overlay:Hide()
	end
end
