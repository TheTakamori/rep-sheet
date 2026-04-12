RepSheet = RepSheet or {}
local ns = RepSheet
local helpers = ns.UIHelpers or {}
ns.UIHelpers = helpers

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

function helpers.RegisterSpecialFrame(frame)
	if not frame or not frame.GetName then
		return
	end

	local frameName = frame:GetName()
	if not frameName or frameName == "" then
		return
	end

	UISpecialFrames = type(UISpecialFrames) == "table" and UISpecialFrames or {}
	for index = 1, #UISpecialFrames do
		if UISpecialFrames[index] == frameName then
			return
		end
	end

	UISpecialFrames[#UISpecialFrames + 1] = frameName
end

function helpers.SetDropdownEnabled(dropdown, enabled)
	if not dropdown then
		return
	end

	enabled = enabled == true
	if enabled then
		if UIDropDownMenu_EnableDropDown then
			UIDropDownMenu_EnableDropDown(dropdown)
		end
	else
		if UIDropDownMenu_DisableDropDown then
			UIDropDownMenu_DisableDropDown(dropdown)
		end
	end

	if dropdown.Button and dropdown.Button.SetEnabled then
		dropdown.Button:SetEnabled(enabled)
	end
	dropdown:SetAlpha(enabled and 1 or ns.UI_DROPDOWN_DISABLED_ALPHA)
end
