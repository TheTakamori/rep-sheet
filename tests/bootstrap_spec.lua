local support = require("support")
local A = support.assert

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

		ctx.trigger_event(ns.EVENT.ADDON_LOADED, "OtherAddon")
		A.same(calls, {})

		ctx.trigger_event(ns.EVENT.ADDON_LOADED, ns.ADDON_NAME)
		A.same(calls, { "init", "minimap" })
	end)

	runner:test("PLAYER_LOGIN resets initial scan bookkeeping and PLAYER_ENTERING_WORLD requests known refresh", function()
		local ctx = support.new_context(root)
		local ns = ctx.ns
		local calls = {}
		local state = ns.PlayerStateEnsure()

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

		ctx.trigger_event(ns.EVENT.PLAYER_ENTERING_WORLD)
		A.equal(calls[1], "minimap")
		A.equal(calls[2].reason, ns.SCAN_REASON.PLAYER_LOGIN)
		A.falsy(calls[2].immediate)
		A.equal(calls[2].mode, "full")
		A.equal(calls[3].reason, ns.SCAN_REASON.PLAYER_ENTERING_WORLD)
		A.equal(calls[3].mode, "known")
	end)

	runner:test("UPDATE_FACTION ignores temporary header-mutation events and decrements suppression", function()
		local ctx = support.new_context(root)
		local ns = ctx.ns
		local requested = 0
		local state = ns.PlayerStateEnsure()

		state.suppressedUpdateFactionEvents = 2
		state.suppressedUpdateFactionUntil = ctx.env.time() + 10
		ns.RequestReputationScan = function()
			requested = requested + 1
		end

		ctx.trigger_event(ns.EVENT.UPDATE_FACTION)
		A.equal(requested, 0)
		A.equal(state.suppressedUpdateFactionEvents, 1)
	end)

	runner:test("UPDATE_FACTION resumes after expired suppression and honors targeted-burst suppression", function()
		local ctx = support.new_context(root)
		local ns = ctx.ns
		local calls = {}
		local state = ns.PlayerStateEnsure()

		state.suppressedUpdateFactionEvents = 1
		state.suppressedUpdateFactionUntil = ctx.env.time() - 1
		ns.ShouldSuppressGenericFactionRefresh = function()
			return false
		end
		ns.RequestReputationScan = function(reason, immediate, mode)
			calls[#calls + 1] = {
				reason = reason,
				immediate = immediate,
				mode = mode,
			}
		end

		ctx.trigger_event(ns.EVENT.UPDATE_FACTION)
		A.equal(state.suppressedUpdateFactionEvents, 0)
		A.equal(state.suppressedUpdateFactionUntil, 0)
		A.equal(calls[1].reason, ns.SCAN_REASON.UPDATE_FACTION)
		A.equal(calls[1].mode, "known")

		ns.ShouldSuppressGenericFactionRefresh = function(reason)
			return reason == ns.SCAN_REASON.UPDATE_FACTION
		end
		ctx.trigger_event(ns.EVENT.UPDATE_FACTION)
		A.equal(#calls, 1)
	end)

	runner:test("Combat faction change events choose targeted faction refreshes when faction IDs resolve", function()
		local ctx = support.new_context(root)
		local ns = ctx.ns
		local calls = {}

		ns.ResolveFactionIDsFromCombatMessage = function(message)
			A.equal(message, "Reputation changed")
			return { 4, 4, 1 }, "Booty Bay"
		end
		ns.NoteTargetedFactionRefresh = function(faction_ids)
			A.same(faction_ids, { 4, 4, 1 })
			return { 1, 4 }
		end
		ns.RequestReputationScan = function(reason, immediate, mode, faction_ids)
			calls[#calls + 1] = {
				reason = reason,
				immediate = immediate,
				mode = mode,
				factionIDs = faction_ids and support.copy_array(faction_ids) or nil,
			}
		end

		ctx.trigger_event(ns.EVENT.CHAT_MSG_COMBAT_FACTION_CHANGE, "Reputation changed")
		A.equal(#calls, 1)
		A.equal(calls[1].reason, ns.SCAN_REASON.CHAT_MSG_COMBAT_FACTION_CHANGE)
		A.equal(calls[1].mode, "factions")
		A.same(calls[1].factionIDs, { 1, 4 })
	end)

	runner:test("Combat faction change falls back to a full scan when no faction IDs resolve", function()
		local ctx = support.new_context(root)
		local ns = ctx.ns
		local calls = {}

		ns.ResolveFactionIDsFromCombatMessage = function()
			return {}, "Unknown Faction"
		end
		ns.RequestReputationScan = function(reason, immediate, mode, faction_ids)
			calls[#calls + 1] = {
				reason = reason,
				immediate = immediate,
				mode = mode,
				factionIDs = faction_ids,
			}
		end

		ctx.trigger_event(ns.EVENT.CHAT_MSG_COMBAT_FACTION_CHANGE, "Reputation changed")
		A.equal(#calls, 1)
		A.equal(calls[1].mode, "full")
		A.equal(calls[1].factionIDs, nil)
	end)

	runner:test("Combat faction change falls back cleanly when WoW marks the message secret", function()
		local ctx = support.new_context(root, {
			configure_env = function(env)
				env.issecretvalue = function(value)
					return value == "SECRET_COMBAT_MESSAGE"
				end
			end,
		})
		local ns = ctx.ns
		local calls = {}

		ns.RequestReputationScan = function(reason, immediate, mode, faction_ids)
			calls[#calls + 1] = {
				reason = reason,
				immediate = immediate,
				mode = mode,
				factionIDs = faction_ids,
			}
		end

		ctx.trigger_event(ns.EVENT.CHAT_MSG_COMBAT_FACTION_CHANGE, "SECRET_COMBAT_MESSAGE")
		A.equal(#calls, 1)
		A.equal(calls[1].reason, ns.SCAN_REASON.CHAT_MSG_COMBAT_FACTION_CHANGE)
		A.equal(calls[1].mode, "full")
		A.equal(calls[1].factionIDs, nil)
	end)

	runner:test("Major renown and quest-turn-in events request the expected refresh shapes", function()
		local ctx = support.new_context(root)
		local ns = ctx.ns
		local calls = {}

		ns.NoteTargetedFactionRefresh = function(faction_ids)
			return { faction_ids[1], 9999 }
		end
		ns.ShouldSuppressGenericFactionRefresh = function(reason)
			return reason == ns.SCAN_REASON.QUEST_TURNED_IN
		end
		ns.RequestReputationScan = function(reason, immediate, mode, faction_ids)
			calls[#calls + 1] = {
				reason = reason,
				immediate = immediate,
				mode = mode,
				factionIDs = faction_ids and support.copy_array(faction_ids) or nil,
			}
		end

		ctx.trigger_event(ns.EVENT.MAJOR_FACTION_RENOWN_LEVEL_CHANGED, 2590)
		A.equal(calls[1].reason, ns.SCAN_REASON.MAJOR_FACTION_RENOWN_LEVEL_CHANGED)
		A.equal(calls[1].mode, "factions")
		A.same(calls[1].factionIDs, { 2590, 9999 })

		ctx.trigger_event(ns.EVENT.QUEST_TURNED_IN)
		A.equal(#calls, 1)

		ns.ShouldSuppressGenericFactionRefresh = function()
			return false
		end
		ctx.trigger_event(ns.EVENT.QUEST_TURNED_IN)
		A.equal(calls[2].reason, ns.SCAN_REASON.QUEST_TURNED_IN)
		A.equal(calls[2].mode, "known")
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
