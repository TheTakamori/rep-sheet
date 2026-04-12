local support = require("support")
local A = support.assert

return function(runner, root)
	runner:test("NormalizeFactionIDList and MergeFactionIDLists dedupe and sort IDs", function()
		local ctx = support.new_context(root)
		local ns = ctx.ns

		A.same(ns.NormalizeFactionIDList({ 42, "5", -1, 42, 0, "abc", 12 }), { 5, 12, 42 })
		A.same(ns.MergeFactionIDLists({ 9, 2, 2 }, { 3, -1, 9 }, nil, { 1 }), { 1, 2, 3, 9 })
	end)

	runner:test("DeriveProgressValues and NormalizeParagonValue handle edge cases", function()
		local ctx = support.new_context(root)
		local ns = ctx.ns

		A.same({ ns.DeriveProgressValues(4500, 3000, 9000) }, { 1500, 6000 })
		A.same({ ns.DeriveProgressValues(12000, 3000, 9000) }, { 6000, 6000 })
		A.equal(ns.NormalizeParagonValue(4500, 2000, false), 500)
		A.equal(ns.NormalizeParagonValue(4500, 2000, true), 2500)
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
