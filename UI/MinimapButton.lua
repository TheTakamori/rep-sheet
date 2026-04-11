RepSheet = RepSheet or {}
local ns = RepSheet
local colors = ns.UI_COLORS

local function normalizeAngle(angle)
	angle = ns.SafeNumber(angle, ns.DEFAULT_MINIMAP_BUTTON_ANGLE)
	angle = math.fmod(angle, 360)
	if angle < 0 then
		angle = angle + 360
	end
	return angle
end

local function atan2(y, x)
	if math.atan2 then
		return math.atan2(y, x)
	end
	if x > 0 then
		return math.atan(y / x)
	end
	if x < 0 and y >= 0 then
		return math.atan(y / x) + math.pi
	end
	if x < 0 and y < 0 then
		return math.atan(y / x) - math.pi
	end
	if x == 0 and y > 0 then
		return math.pi / 2
	end
	if x == 0 and y < 0 then
		return -math.pi / 2
	end
	return 0
end

local minimapShapes = {
	["ROUND"] = { true, true, true, true },
	["SQUARE"] = { false, false, false, false },
	["CORNER-TOPLEFT"] = { false, false, false, true },
	["CORNER-TOPRIGHT"] = { false, false, true, false },
	["CORNER-BOTTOMLEFT"] = { false, true, false, false },
	["CORNER-BOTTOMRIGHT"] = { true, false, false, false },
	["SIDE-LEFT"] = { false, true, false, true },
	["SIDE-RIGHT"] = { true, false, true, false },
	["SIDE-TOP"] = { false, false, true, true },
	["SIDE-BOTTOM"] = { true, true, false, false },
	["TRICORNER-TOPLEFT"] = { false, true, true, true },
	["TRICORNER-TOPRIGHT"] = { true, false, true, true },
	["TRICORNER-BOTTOMLEFT"] = { true, true, false, true },
	["TRICORNER-BOTTOMRIGHT"] = { true, true, true, false },
}

local function setMinimapButtonAngle(button, angle)
	if not button or not Minimap then
		return
	end

	angle = normalizeAngle(angle)
	local radians = math.rad(angle)
	local x = math.cos(radians)
	local y = math.sin(radians)
	local quadrant = 1
	if x < 0 then
		quadrant = quadrant + 1
	end
	if y > 0 then
		quadrant = quadrant + 2
	end

	local radiusOffset = ns.UI_MINIMAP_RADIUS_OFFSET
	local widthRadius = (Minimap:GetWidth() / 2) + radiusOffset
	local heightRadius = (Minimap:GetHeight() / 2) + radiusOffset
	local minimapShape = GetMinimapShape and GetMinimapShape() or "ROUND"
	local quadrants = minimapShapes[minimapShape] or minimapShapes.ROUND
	if quadrants[quadrant] then
		x = x * widthRadius
		y = y * heightRadius
	else
		local diagonalWidth = math.sqrt(2 * (widthRadius ^ 2)) - 10
		local diagonalHeight = math.sqrt(2 * (heightRadius ^ 2)) - 10
		x = math.max(-widthRadius, math.min(x * diagonalWidth, widthRadius))
		y = math.max(-heightRadius, math.min(y * diagonalHeight, heightRadius))
	end

	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", x, y)
	button.currentAngle = angle
end

local function updateDragPosition(button)
	if not button or not Minimap then
		return
	end

	local scale = Minimap:GetEffectiveScale()
	local cursorX, cursorY = GetCursorPosition()
	local centerX, centerY = Minimap:GetCenter()
	centerX = (centerX or 0) * scale
	centerY = (centerY or 0) * scale
	local deltaX = cursorX - centerX
	local deltaY = cursorY - centerY
	local angle = math.deg(atan2(deltaY, deltaX))
	if angle < 0 then
		angle = angle + 360
	end

	setMinimapButtonAngle(button, angle)
end

local function toggleMainFrame()
	local ui = ns.CreateMainFrame()
	ui:SetShown(not ui:IsShown())
	if ui:IsShown() then
		ns.RefreshMainFrame()
	end
end

local function showTooltip(button)
	if not button or not GameTooltip then
		return
	end

	GameTooltip:SetOwner(button, "ANCHOR_LEFT")
	GameTooltip:ClearLines()
	GameTooltip:AddLine(ns.TEXT.MAIN_TITLE, colors.TEXT_TITLE[1], colors.TEXT_TITLE[2], colors.TEXT_TITLE[3])
	GameTooltip:AddLine(ns.TEXT.MINIMAP_TOOLTIP_OPEN, colors.TEXT_INFO[1], colors.TEXT_INFO[2], colors.TEXT_INFO[3], true)
	GameTooltip:AddLine(ns.TEXT.MINIMAP_TOOLTIP_DRAG, colors.TEXT_STATUS[1], colors.TEXT_STATUS[2], colors.TEXT_STATUS[3], true)
	GameTooltip:Show()
end

function ns.EnsureMinimapButton()
	if ns.MinimapButton then
		setMinimapButtonAngle(ns.MinimapButton, ns.GetMinimapButtonAngle())
		return ns.MinimapButton
	end
	if not Minimap then
		return nil
	end

	local button = CreateFrame("Button", "RepSheetMinimapButton", Minimap)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel((Minimap:GetFrameLevel() or 0) + 8)
	button:SetSize(ns.UI_MINIMAP_BUTTON_SIZE, ns.UI_MINIMAP_BUTTON_SIZE)
	button:RegisterForClicks("LeftButtonUp")
	button:RegisterForDrag("LeftButton")
	button:SetHighlightTexture(ns.UI_TEXTURES.MINIMAP_HIGHLIGHT, "ADD")

	local background = button:CreateTexture(nil, "BACKGROUND")
	background:SetTexture(ns.UI_TEXTURES.MINIMAP_BACKGROUND)
	background:SetSize(ns.UI_MINIMAP_BACKGROUND_SIZE, ns.UI_MINIMAP_BACKGROUND_SIZE)
	background:SetPoint("CENTER", button, "CENTER")
	button.background = background

	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetTexture(ns.UI_TEXTURES.MINIMAP_ICON)
	icon:SetSize(ns.UI_MINIMAP_ICON_SIZE, ns.UI_MINIMAP_ICON_SIZE)
	icon:SetPoint("CENTER", button, "CENTER")
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	button.icon = icon

	local border = button:CreateTexture(nil, "OVERLAY")
	border:SetTexture(ns.UI_TEXTURES.MINIMAP_BORDER)
	border:SetSize(ns.UI_MINIMAP_OVERLAY_SIZE, ns.UI_MINIMAP_OVERLAY_SIZE)
	border:SetPoint("TOPLEFT", button, "TOPLEFT")
	button.border = border

	button:SetScript("OnClick", function(self)
		if self.suppressNextClick then
			self.suppressNextClick = nil
			return
		end
		toggleMainFrame()
	end)

	button:SetScript("OnEnter", function(self)
		showTooltip(self)
	end)

	button:SetScript("OnLeave", function()
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)

	button:SetScript("OnDragStart", function(self)
		self.suppressNextClick = true
		self:SetScript("OnUpdate", updateDragPosition)
	end)

	button:SetScript("OnDragStop", function(self)
		self:SetScript("OnUpdate", nil)
		updateDragPosition(self)
		ns.SetMinimapButtonAngle(self.currentAngle)
	end)

	setMinimapButtonAngle(button, ns.GetMinimapButtonAngle())
	ns.MinimapButton = button
	return button
end
