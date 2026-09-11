-- Indexed, validated view of Config so code never scans lists or trusts typos.
local Config = script.Parent.Parent:WaitForChild("Config")

local Stats = require(Config:WaitForChild("Stats"))
local Items = require(Config:WaitForChild("Items"))
local Rarities = require(Config:WaitForChild("Rarities"))
local Ranks = require(Config:WaitForChild("Ranks"))

local Catalog = {
	statIds = {} :: { string },
	statsById = {} :: { [string]: any },
	itemsById = {} :: { [string]: any },
	itemsByStat = {} :: { [string]: { any } },
	ranks = Ranks,
	rarities = Rarities,
}

for _, stat in Stats do
	assert(type(stat.id) == "string", "Config.Stats entry is missing an id")
	assert(not Catalog.statsById[stat.id], "Duplicate stat id " .. stat.id)
	table.insert(Catalog.statIds, stat.id)
	Catalog.statsById[stat.id] = stat
	Catalog.itemsByStat[stat.id] = {}
end

for _, item in Items do
	assert(Catalog.statsById[item.stat], ("Item %s uses unknown stat %s"):format(item.id, tostring(item.stat)))
	assert(Rarities[item.rarity], ("Item %s uses unknown rarity %s"):format(item.id, tostring(item.rarity)))
	assert(not Catalog.itemsById[item.id], "Duplicate item id " .. item.id)
	Catalog.itemsById[item.id] = item
	table.insert(Catalog.itemsByStat[item.stat], item)
end

for i = 2, #Ranks do
	assert(Ranks[i].threshold > Ranks[i - 1].threshold, "Config.Ranks thresholds must increase")
end

function Catalog.isStat(id: any): boolean
	return type(id) == "string" and Catalog.statsById[id] ~= nil
end

function Catalog.pointsFor(itemId: string): number
	local item = Catalog.itemsById[itemId]
	return if item then Rarities[item.rarity].points else 0
end

-- Sum of a stats table across configured stats only.
function Catalog.total(stats: { [string]: number }): number
	local total = 0
	for _, id in Catalog.statIds do
		total += stats[id] or 0
	end
	return total
end

return Catalog

