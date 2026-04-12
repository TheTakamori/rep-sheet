RepSheet = RepSheet or {}
local ns = RepSheet
local widgets = ns.UIWidgets or {}
ns.UIWidgets = widgets

local colors = ns.UI_COLORS
local ui = ns.UIHelpers

local function resolveDropdownValue(option)
	if type(option) == "table" then
		if option.key ~= nil then
			return option.key
		end
		if option.value ~= nil then
			return option.value
		end
		if option.id ~= nil then
			return option.id
		end
	end
	return option
end

local function resolveDropdownText(option, fallbackValue)
	if type(option) == "table" then
		return option.label or option.name or option.text or tostring(fallbackValue)
	end
	return tostring(fallbackValue)
end

function widgets.ApplyHitRectInsets(button, insets)
	if not button or not button.SetHitRectInsets or type(insets) ~= "table" then
		return
	end
	button:SetHitRectInsets(
		ns.SafeNumber(insets[1], 0),
		ns.SafeNumber(insets[2], 0),
		ns.SafeNumber(insets[3], 0),
		ns.SafeNumber(insets[4], 0)
	)
end

function widgets.ConfigureDropdown(dropdown, width)
	if not dropdown then
		return
	end
	if UIDropDownMenu_SetWidth then
		UIDropDownMenu_SetWidth(dropdown, width)
		UIDropDownMenu_JustifyText(dropdown, "LEFT")
	end
end

function widgets.InitializeChoiceDropdown(dropdown, options, getSelectedValue, onSelect, getText, getValue)
	if not dropdown or not UIDropDownMenu_Initialize or not UIDropDownMenu_CreateInfo then
		return
	end
	UIDropDownMenu_Initialize(dropdown, function()
		local resolvedOptions = type(options) == "function" and options() or options
		local selectedValue = type(getSelectedValue) == "function" and getSelectedValue() or getSelectedValue
		for index = 1, #(resolvedOptions or {}) do
			local option = resolvedOptions[index]
			local value = type(getValue) == "function" and getValue(option, index) or resolveDropdownValue(option)
			local text = type(getText) == "function" and getText(option, index) or resolveDropdownText(option, value)
			local info = UIDropDownMenu_CreateInfo()
			info.text = text
			info.checked = selectedValue == value
			info.func = function()
				if onSelect then
					onSelect(option, value, index)
				end
			end
			UIDropDownMenu_AddButton(info)
		end
	end)
end

function widgets.CreateScrollChild(scrollFrame, width, minHeight, onMouseWheel)
	local child = CreateFrame("Frame", nil, scrollFrame)
	child:SetSize(width, minHeight)
	if onMouseWheel then
		child:EnableMouseWheel(true)
		child:SetScript("OnMouseWheel", onMouseWheel)
	end
	scrollFrame:SetScrollChild(child)
	return child
end

function widgets.CreateProgressBar(parent, config)
	config = type(config) == "table" and config or {}

	local statusBar = CreateFrame("StatusBar", nil, parent)
	statusBar:SetPoint(
		config.leftPoint or "BOTTOMLEFT",
		config.leftRelativeTo or parent,
		config.leftRelativePoint or config.leftPoint or "BOTTOMLEFT",
		ns.SafeNumber(config.leftX, 0),
		ns.SafeNumber(config.leftY, 0)
	)
	statusBar:SetPoint(
		config.rightPoint or "BOTTOMRIGHT",
		config.rightRelativeTo or parent,
		config.rightRelativePoint or config.rightPoint or "BOTTOMRIGHT",
		ns.SafeNumber(config.rightX, 0),
		ns.SafeNumber(config.rightY, 0)
	)
	statusBar:SetHeight(ns.SafeNumber(config.height, 0))
	statusBar:SetStatusBarTexture(ns.UI_TEXTURES.STATUS_BAR)
	statusBar:SetMinMaxValues(0, 1)

	local texture = statusBar:GetStatusBarTexture()
	if texture and texture.SetHorizTile then
		texture:SetHorizTile(config.horizTile == true)
	end

	local backgroundColor = config.backgroundColor or colors.STATUS_BAR_BG
	statusBar.bg = statusBar:CreateTexture(nil, "BACKGROUND")
	statusBar.bg:SetAllPoints()
	statusBar.bg:SetColorTexture(
		backgroundColor[1],
		backgroundColor[2],
		backgroundColor[3],
		backgroundColor[4]
	)

	ui.CreateBandOverlay(statusBar)
	ui.CreateParagonOverlay(statusBar)
	ui.CreateOverallOverlay(statusBar)
	ui.AttachProgressBarTooltip(statusBar)
	return statusBar
end

function widgets.RequestManualReputationScan()
	if ns.RequestReputationScan then
		ns.RequestReputationScan(ns.SCAN_REASON.MANUAL_REFRESH, true)
		return true
	end
	if ns.DebugLog then
		ns.DebugLog("Manual scan request ignored before bootstrap was ready.")
	end
	return false
end
