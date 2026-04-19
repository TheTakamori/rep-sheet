---@diagnostic disable: undefined-global
local support = require("support")
local A = support.assert
local UI_TEST_FILES = support.with_files({
	"UI/UIConstants.lua",
	"UI/UIHelpers.lua",
	"UI/UIProgressBar.lua",
})

local function install_status_bar_frame_factory(env)
	env.CreateFrame = function()
		local frame = {
			__points = {},
			__shown = false,
			__frameLevel = 0,
		}

		function frame:SetPoint(point, _, relativePoint, x, y)
			self.__points[#self.__points + 1] = {
				point = point,
				relativePoint = relativePoint,
				x = x,
				y = y,
			}
		end

		function frame:ClearAllPoints()
			self.__points = {}
		end

		function frame:SetStatusBarTexture(texture)
			self.__texture = texture
		end

		function frame:SetMinMaxValues(minValue, maxValue)
			self.__minValue = minValue
			self.__maxValue = maxValue
		end

		function frame:SetFrameLevel(level)
			self.__frameLevel = level
		end

		function frame:GetFrameLevel()
			return self.__frameLevel
		end

		function frame:GetStatusBarTexture()
			self.__statusBarTexture = self.__statusBarTexture or {
				SetHorizTile = function(_, enabled)
					frame.__horizTile = enabled
				end,
			}
			return self.__statusBarTexture
		end

		function frame:SetWidth(width)
			self.__width = width
		end

		function frame:SetValue(value)
			self.__value = value
		end

		function frame:SetStatusBarColor(r, g, b)
			self.__color = { r, g, b }
		end

		function frame:Hide()
			self.__shown = false
		end

		function frame:Show()
			self.__shown = true
		end

		return frame
	end
end

local function new_status_bar(width)
	local statusBar = {
		__width = width or 100,
		__frameLevel = 7,
	}

	function statusBar:GetWidth()
		return self.__width
	end

	function statusBar:GetFrameLevel()
		return self.__frameLevel
	end

	function statusBar:SetValue(value)
		self.__value = value
	end

	function statusBar:SetStatusBarColor(r, g, b)
		self.__color = { r, g, b }
	end

	return statusBar
end

return function(runner, root)
	runner:test("NormalizeFactionIDList and MergeFactionIDLists dedupe and sort IDs", function()
		local ctx = support.new_context(root)
		local ns = ctx.ns

		A.same(ns.NormalizeFactionIDList({ 42, "5", -1, 42, 0, "abc", 12 }), { 5, 12, 42 })
		A.same(ns.MergeFactionIDLists({ 9, 2, 2 }, { 3, -1, 9 }, nil, { 1 }), { 1, 2, 3, 9 })
	end)

	runner:test("SafeString and NormalizeText ignore secret strings", function()
		local ctx = support.new_context(root, {
			configure_env = function(env)
				env.issecretvalue = function(value)
					return value == "SECRET"
				end
			end,
		})
		local ns = ctx.ns

		A.equal(ns.SafeString("SECRET"), "")
		A.equal(ns.SafeString("SECRET", "fallback"), "fallback")
		A.equal(ns.SafeString("Visible"), "Visible")
		A.equal(ns.NormalizeText("SECRET"), "")
		A.equal(ns.NormalizeText("  Visible\ntext  "), "Visible text")
	end)

	runner:test("DeriveProgressValues and NormalizeParagonValue handle edge cases", function()
		local ctx = support.new_context(root)
		local ns = ctx.ns

		A.same({ ns.DeriveProgressValues(4500, 3000, 9000) }, { 1500, 6000 })
		A.same({ ns.DeriveProgressValues(12000, 3000, 9000) }, { 6000, 6000 })
		A.equal(ns.NormalizeParagonValue(4500, 2000, false), 500)
		A.equal(ns.NormalizeParagonValue(4500, 2000, true), 2500)
	end)

	runner:test("CreateOverallOverlay keeps default thickness when it is the only visible layer", function()
		local ctx = support.new_context(root, {
			files = UI_TEST_FILES,
		})
		local ns = ctx.ns
		install_status_bar_frame_factory(ctx.env)

		local statusBar = new_status_bar(100)
		local overlay = ns.UIHelpers.CreateOverallOverlay(statusBar)
		ns.UIHelpers.UpdateOverallOverlay(statusBar, {
			overallFraction = 0.5,
		}, 0.5)

		A.equal(overlay.verticalInset, ns.UI_PROGRESS_BAR_LAYOUT.VERTICAL_INSET)
		A.truthy(overlay.__shown)
		A.equal(overlay.__points[1].point, "TOPLEFT")
		A.equal(overlay.__points[1].y, -ns.UI_PROGRESS_BAR_LAYOUT.VERTICAL_INSET)
		A.equal(overlay.__points[2].point, "BOTTOMLEFT")
		A.equal(overlay.__points[2].y, ns.UI_PROGRESS_BAR_LAYOUT.VERTICAL_INSET)
		A.near(overlay.__width, 49, 1e-6)
	end)

	runner:test("CreateOverallOverlay keeps full thickness behind the current band layer", function()
		local ctx = support.new_context(root, {
			files = UI_TEST_FILES,
		})
		local ns = ctx.ns
		install_status_bar_frame_factory(ctx.env)

		local statusBar = new_status_bar(100)
		local source = {
			standingId = 5,
			currentValue = 5999,
			maxValue = 6000,
			overallFraction = ((5 - 1) + (5999 / 6000)) / ns.MAX_STANDARD_STANDING_ID,
		}
		local overlay = ns.UIHelpers.CreateOverallOverlay(statusBar)
		ns.UIHelpers.UpdateOverallOverlay(statusBar, source, source.overallFraction)

		A.equal(overlay.verticalInset, ns.UI_PROGRESS_BAR_LAYOUT.VERTICAL_INSET)
		A.truthy(overlay.__shown)
		A.equal(overlay.__points[1].point, "TOPLEFT")
		A.equal(overlay.__points[1].y, -ns.UI_PROGRESS_BAR_LAYOUT.VERTICAL_INSET)
		A.equal(overlay.__points[2].point, "BOTTOMLEFT")
		A.equal(overlay.__points[2].y, ns.UI_PROGRESS_BAR_LAYOUT.VERTICAL_INSET)
		A.near(overlay.__width, 98 * source.overallFraction, 1e-6)
	end)

	runner:test("CreateBandOverlay shortens the top layer while spanning current-band progress", function()
		local ctx = support.new_context(root, {
			files = UI_TEST_FILES,
		})
		local ns = ctx.ns
		local expectedTopInset = ns.UI_PROGRESS_BAR_LAYOUT.VERTICAL_INSET
			+ ((ns.UI_PROGRESS_BAR_LAYOUT.STACKED_VERTICAL_INSET - ns.UI_PROGRESS_BAR_LAYOUT.VERTICAL_INSET) * 2)
		install_status_bar_frame_factory(ctx.env)

		local statusBar = new_status_bar(100)
		local source = {
			standingId = 5,
			currentValue = 5999,
			maxValue = 6000,
			overallFraction = ((5 - 1) + (5999 / 6000)) / ns.MAX_STANDARD_STANDING_ID,
		}
		local overlay = ns.UIHelpers.CreateBandOverlay(statusBar)
		ns.UIHelpers.UpdateBandOverlay(statusBar, source, source.overallFraction)

		A.equal(overlay.verticalInset, ns.UI_PROGRESS_BAR_LAYOUT.STACKED_VERTICAL_INSET)
		A.truthy(overlay.__shown)
		A.equal(overlay.__points[1].point, "TOPLEFT")
		A.equal(overlay.__points[1].x, ns.UI_PROGRESS_BAR_LAYOUT.HORIZONTAL_INSET)
		A.equal(overlay.__points[1].y, -expectedTopInset)
		A.equal(overlay.__points[2].point, "BOTTOMLEFT")
		A.equal(overlay.__points[2].y, ns.UI_PROGRESS_BAR_LAYOUT.VERTICAL_INSET)
		A.truthy(overlay.__width > (98 * source.overallFraction))
		A.near(overlay.__width, 98 * ns.GetBandOverlayFraction(source), 1e-6)
	end)

	runner:test("CreateParagonOverlay adds extra inset so the band underneath stays visible", function()
		local ctx = support.new_context(root, {
			files = UI_TEST_FILES,
		})
		local ns = ctx.ns
		local expectedTopInset = ns.UI_PROGRESS_BAR_LAYOUT.VERTICAL_INSET
			+ ((ns.UI_PROGRESS_BAR_LAYOUT.STACKED_VERTICAL_INSET - ns.UI_PROGRESS_BAR_LAYOUT.VERTICAL_INSET) * 2)
		install_status_bar_frame_factory(ctx.env)

		local statusBar = new_status_bar(100)
		local overlay = ns.UIHelpers.CreateParagonOverlay(statusBar)
		ns.UIHelpers.UpdateParagonOverlay(statusBar, {
			hasParagon = true,
			isMaxed = true,
			paragonValue = 500,
			paragonThreshold = 1000,
		})

		A.equal(overlay.verticalInset, ns.UI_PROGRESS_BAR_LAYOUT.STACKED_VERTICAL_INSET)
		A.truthy(overlay.__shown)
		A.equal(overlay.__points[1].point, "TOPLEFT")
		A.equal(overlay.__points[1].y, -expectedTopInset)
		A.equal(overlay.__points[2].point, "BOTTOMLEFT")
		A.equal(overlay.__points[2].y, ns.UI_PROGRESS_BAR_LAYOUT.VERTICAL_INSET)
		A.near(overlay.__width, 49, 1e-6)
	end)

	runner:test("normalizeFactionRow populates standard reputation display fields", function()
		local ctx = support.new_context(root)
		local ns = ctx.ns

		local normalized = ns.NormalizerHelpers.normalizeFactionRow({
			factionID = 123,
			name = "  The Example  ",
			description = "  Some\ntext  ",
			standingId = 6,
			currentStanding = 4500,
			bottomValue = 3000,
			topValue = 9000,
			headerPath = { " Dragonflight ", "", "Valdrakken Accord " },
			expansionID = ctx.env.LE_EXPANSION_DRAGONFLIGHT,
		}, {})

		A.equal(normalized.factionKey, "123")
		A.equal(normalized.name, "The Example")
		A.equal(normalized.description, "Some text")
		A.equal(normalized.expansionKey, "df")
		A.equal(normalized.expansionName, "Dragonflight")
		A.equal(normalized.repType, ns.REP_TYPE.STANDARD)
		A.equal(normalized.repTypeLabel, ns.TEXT.REPUTATION)
		A.equal(normalized.rankText, "Honored")
		A.equal(normalized.progressText, "1500/6000")
		A.equal(normalized.headerLabel, "Dragonflight / Valdrakken Accord")
		A.equal(normalized.currentValue, 1500)
		A.equal(normalized.maxValue, 6000)
		A.equal(normalized.icon, ns.FACTION_ICON)
		A.near(normalized.overallFraction, 0.65625, 1e-6)
		A.near(normalized.remainingFraction, 0.75, 1e-6)
		A.contains(normalized.searchText, "dragonflight")
		A.contains(normalized.searchText, "honored")
	end)

	runner:test("normalizeFactionRow exposes capped renown paragon state", function()
		local ctx = support.new_context(root)
		local ns = ctx.ns

		local normalized = ns.NormalizerHelpers.normalizeFactionRow({
			factionID = 2590,
			name = "Council of Dornogal",
			standingId = 8,
			currentStanding = 2500,
			bottomValue = 0,
			topValue = 2500,
			headerPath = { "The War Within" },
		}, {
			repType = ns.REP_TYPE.MAJOR,
			majorFactionID = 2590,
			renownLevel = 10,
			renownMaxLevel = 10,
			currentValue = 2500,
			maxValue = 2500,
			hasParagon = true,
			paragonValue = 750,
			paragonThreshold = 1000,
			paragonRewardPending = true,
		})

		A.equal(normalized.expansionKey, "tww")
		A.equal(normalized.repType, ns.REP_TYPE.MAJOR)
		A.equal(normalized.repTypeLabel, ns.TEXT.RENOWN .. ns.TEXT.PARAGON_SUFFIX)
		A.equal(normalized.rankText, "Renown: 10/10")
		A.equal(normalized.progressText, "Paragon: 750/1000 ready")
		A.equal(normalized.icon, ns.FACTION_ICON_MAJOR)
		A.truthy(normalized.isMaxed)
		A.near(normalized.overallFraction, 1, 1e-6)
		A.near(normalized.remainingFraction, 0, 1e-6)
	end)

	runner:test("NormalizeCurrentCharacterSnapshot keeps the strongest duplicate row", function()
		local ctx = support.new_context(root)
		local ns = ctx.ns

		local snapshot = ns.NormalizeCurrentCharacterSnapshot("Manual", {
			{
				factionID = 42,
				name = "Booty Bay",
				standingId = 5,
				currentStanding = 3000,
				bottomValue = 3000,
				topValue = 9000,
				headerPath = { "Classic / Vanilla", "Steamwheedle Cartel" },
			},
			{
				factionID = 42,
				name = "Booty Bay",
				standingId = 6,
				currentStanding = 6000,
				bottomValue = 3000,
				topValue = 9000,
				headerPath = { "Classic / Vanilla", "Steamwheedle Cartel" },
			},
		}, {})

		local stored = snapshot.reputations["42"]
		A.equal(snapshot.reputationCount, 1)
		A.equal(stored.standingId, 6)
		A.equal(stored.rankText, "Honored")
		A.equal(stored.progressText, "3000/6000")
	end)
end
