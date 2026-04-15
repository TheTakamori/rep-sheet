local support = require("support")
local A = support.assert

local BOOTSTRAP_UI_FILES = support.with_files({
	"UI/UIConstants.lua",
	"UI/UIHelpers.lua",
	"UI/OptionsPanel.lua",
})

return function(runner, root)
	runner:test("ADDON_LOADED only initializes the addon for the matching addon name", function()
		local ctx = support.new_context(root)
		local ns = ctx.ns
		local calls = {}

		ns.InitDB = function()
			calls[#calls + 1] = "init"
		end
		ns.EnsureMinimapButton = function()
			calls[#calls + 1] = "minimap"
		end
		ns.InitializeLiveUpdateController = function()
			calls[#calls + 1] = "live"
		end

		ctx.trigger_event(ns.EVENT.ADDON_LOADED, "OtherAddon")
		A.same(calls, {})

		ctx.trigger_event(ns.EVENT.ADDON_LOADED, ns.ADDON_NAME)
		A.same(calls, { "init", "live", "minimap" })
	end)

	runner:test("PLAYER_LOGIN resets initial scan bookkeeping and requests an immediate full scan", function()
		local ctx = support.new_context(root)
		local ns = ctx.ns
		local calls = {}
		local state = ns.PlayerStateEnsure()
		local frame = ctx.env.__frames[1]

		state.bestObservedReputationCount = 99
		state.lastObservedReputationCount = 88
		state.pendingRefresh = { mode = "known" }
		state.queuedRefresh = { mode = "factions" }

		ns.EnsureMinimapButton = function()
			calls[#calls + 1] = "minimap"
		end
		ns.RequestReputationScan = function(reason, immediate, mode, faction_ids)
			calls[#calls + 1] = {
				reason = reason,
				immediate = immediate,
				mode = mode,
				factionIDs = faction_ids and support.copy_array(faction_ids) or nil,
			}
		end

		ctx.trigger_event(ns.EVENT.PLAYER_LOGIN)
		A.equal(state.bestObservedReputationCount, 0)
		A.equal(state.lastObservedReputationCount, 0)
		A.equal(state.pendingRefresh, nil)
		A.equal(state.queuedRefresh, nil)
		A.equal(calls[1], "minimap")
		A.equal(calls[2].reason, ns.SCAN_REASON.PLAYER_LOGIN)
		A.truthy(calls[2].immediate)
		A.equal(calls[2].mode, "full")
		A.truthy(frame.__events[ns.EVENT.PLAYER_LOGIN])
		A.truthy(frame.__events[ns.EVENT.PLAYER_REGEN_ENABLED])
	end)

	runner:test("Automatic reputation refresh events stay disabled by default", function()
		local ctx = support.new_context(root)
		local ns = ctx.ns
		local frame = ctx.env.__frames[1]

		ctx.trigger_event(ns.EVENT.ADDON_LOADED, ns.ADDON_NAME)

		A.falsy(frame.__events[ns.EVENT.PLAYER_ENTERING_WORLD])
		A.falsy(frame.__events[ns.EVENT.UPDATE_FACTION])
		A.falsy(frame.__events[ns.EVENT.CHAT_MSG_COMBAT_FACTION_CHANGE])
		A.falsy(frame.__events[ns.EVENT.MAJOR_FACTION_RENOWN_LEVEL_CHANGED])
		A.falsy(frame.__events[ns.EVENT.QUEST_TURNED_IN])
	end)

	runner:test("Live update events register when enabled and settings can be opened", function()
		local ctx = support.new_context(root, { files = BOOTSTRAP_UI_FILES })
		local ns = ctx.ns
		local frame = ctx.env.__frames[1]

		ctx.trigger_event(ns.EVENT.ADDON_LOADED, ns.ADDON_NAME)
		A.equal(#ctx.env.__settings_categories, 1)
		A.equal(ctx.env.__registered_addon_category, ctx.env.__settings_categories[1])

		ns.SetLiveUpdateOptions({
			noLiveUpdates = false,
			updateAfterCombat = true,
			updateOutOfCombat = true,
		})

		A.falsy(frame.__events[ns.EVENT.UPDATE_FACTION])
		A.truthy(frame.__events[ns.EVENT.CHAT_MSG_COMBAT_FACTION_CHANGE])
		A.truthy(frame.__events[ns.EVENT.MAJOR_FACTION_RENOWN_LEVEL_CHANGED])

		A.truthy(ns.OpenOptionsPanel())
		A.equal(ctx.env.__opened_settings_category, 1)
	end)

	runner:test("Options panel keeps No Live Updates derived from the other selections", function()
		local ctx = support.new_context(root, { files = BOOTSTRAP_UI_FILES })
		local ns = ctx.ns

		ctx.trigger_event(ns.EVENT.ADDON_LOADED, ns.ADDON_NAME)
		local panel = ns.EnsureOptionsPanel()
		ns.SetLiveUpdateOptions({
			noLiveUpdates = true,
		})

		panel:RefreshFromDB()
		A.truthy(panel.noLiveUpdates:GetChecked())
		A.truthy(panel.afterCombat:IsEnabled())
		A.truthy(panel.outOfCombat:IsEnabled())
		A.truthy(panel.periodic:IsEnabled())

		panel.afterCombat:SetChecked(true)
		panel.afterCombat:GetScript("OnClick")(panel.afterCombat)
		A.falsy(ns.GetLiveUpdateOptions().noLiveUpdates)
		A.truthy(ns.GetLiveUpdateOptions().updateAfterCombat)
		A.falsy(panel.noLiveUpdates:GetChecked())

		panel.afterCombat:SetChecked(false)
		panel.afterCombat:GetScript("OnClick")(panel.afterCombat)
		A.truthy(ns.GetLiveUpdateOptions().noLiveUpdates)
		A.falsy(ns.GetLiveUpdateOptions().updateAfterCombat)
		A.truthy(panel.noLiveUpdates:GetChecked())

		panel.outOfCombat:SetChecked(true)
		panel.outOfCombat:GetScript("OnClick")(panel.outOfCombat)
		A.falsy(ns.GetLiveUpdateOptions().noLiveUpdates)
		A.truthy(ns.GetLiveUpdateOptions().updateOutOfCombat)

		panel.noLiveUpdates:SetChecked(true)
		panel.noLiveUpdates:GetScript("OnClick")(panel.noLiveUpdates)
		A.truthy(ns.GetLiveUpdateOptions().noLiveUpdates)
		A.falsy(ns.GetLiveUpdateOptions().updateAfterCombat)
		A.falsy(ns.GetLiveUpdateOptions().updateOutOfCombat)
		A.falsy(ns.GetLiveUpdateOptions().updatePeriodic)
	end)

	runner:test("Slash commands cover manual scan and debug view opening", function()
		local ctx = support.new_context(root)
		local ns = ctx.ns
		local calls = {}
		local frame = {
			shown = false,
			debugShown = false,
		}

		function frame:Show()
			self.shown = true
		end

		function frame:IsShown()
			return self.shown
		end

		function frame:SetShown(shown)
			self.shown = shown == true
		end

		function frame:SetDebugPageShown(shown)
			self.debugShown = shown == true
		end

		ns.RequestReputationScan = function(reason, immediate)
			calls[#calls + 1] = {
				reason = reason,
				immediate = immediate,
			}
		end
		ns.IsLocalDebugEnabled = function()
			return true
		end
		ns.CreateMainFrame = function()
			return frame
		end
		ns.RefreshMainFrame = function()
			calls[#calls + 1] = "refresh"
		end

		ctx.env.SlashCmdList.REPSHEET(" scan ")
		A.equal(calls[1].reason, ns.SCAN_REASON.SLASH_COMMAND)
		A.truthy(calls[1].immediate)

		ctx.env.SlashCmdList.REPSHEET("debug")
		A.truthy(frame.shown)
		A.truthy(frame.debugShown)
		A.equal(calls[2], "refresh")
	end)

	runner:test("Default slash command toggles the main frame and refreshes only when showing it", function()
		local ctx = support.new_context(root)
		local ns = ctx.ns
		local refreshes = 0
		local frame = {
			shown = false,
		}

		function frame:IsShown()
			return self.shown
		end

		function frame:SetShown(shown)
			self.shown = shown == true
		end

		ns.CreateMainFrame = function()
			return frame
		end
		ns.RefreshMainFrame = function()
			refreshes = refreshes + 1
		end

		ctx.env.SlashCmdList.REPSHEET("")
		A.truthy(frame.shown)
		A.equal(refreshes, 1)

		ctx.env.SlashCmdList.REPSHEET("")
		A.falsy(frame.shown)
		A.equal(refreshes, 1)
	end)
end
