local source = debug.getinfo(1, "S").source
local script_path = source:sub(1, 1) == "@" and source:sub(2) or source
local script_dir = script_path:match("^(.*)/[^/]+$") or "."
local root = script_dir:gsub("/tests$", "")

if root == "tests" or root == "" then
	root = "."
end

package.path = table.concat({
	root .. "/tests/?.lua",
	package.path,
}, ";")

local support = require("support")
local coverage = require("coverage").new(root, {
	"Core/Constants.lua",
	"Core/Namespaces.lua",
	"Core/Utils.lua",
	"Core/ReputationUtils.lua",
	"Data/Expansions.lua",
	"Data/FactionExpansionMap.lua",
	"Core/ExpansionUtils.lua",
	"Core/DebugLog.lua",
	"Core/State.lua",
	"Core/CharacterStore.lua",
	"Core/CharacterDelete.lua",
	"Core/NormalizerHelpers.lua",
	"Core/NormalizerEntryMath.lua",
	"Core/Normalizer.lua",
	"Core/ScannerStandardHelpers.lua",
	"Core/ScannerStandardMetadata.lua",
	"Core/ScannerStandard.lua",
	"Core/ScannerMajor.lua",
	"Core/ScannerSpecial.lua",
	"Core/ScanPipeline.lua",
	"Core/Index.lua",
	"Core/FactionFilters.lua",
	"Core/FactionTree.lua",
	"Core/FactionTreeView.lua",
	"Core/AltsIndex.lua",
	"Core/AltsFilters.lua",
	"Core/AltRepFilters.lua",
	"Core/ReputationEventHints.lua",
	"Core/OpenFactionUI.lua",
	"Core/ScanScheduler.lua",
	"Core/Bootstrap.lua",
})
local runner = support.new_runner({
	coverage = coverage,
})

require("unit_spec")(runner, root)
require("state_spec")(runner, root)
require("feature_spec")(runner, root)
require("filters_normalizer_spec")(runner, root)
require("bootstrap_spec")(runner, root)
require("scanner_spec")(runner, root)
require("alts_index_spec")(runner, root)
require("alts_refresh_spec")(runner, root)
require("alt_rep_filters_spec")(runner, root)

os.exit(runner:run())
