-- How pickups travel to clients (PickupService -> LarpClient.PickupWorld). The server keeps
-- pickups as data and sends each client a snapshot when it asks, then batched changes; each
-- client builds models only for the ones near it. Parallel arrays keep the packets small.
local PickupWire = {}

-- A pickup's resting turn, the same on every client, so it isn't sent.
function PickupWire.yaw(id: number): number
	return (id * 2.399963) % (2 * math.pi)
end

-- Parallel arrays (ids, item ids, positions) for a list of pickups.
function PickupWire.pack(list: { { id: number, item: string, position: Vector3 } }): ({ number }, { string }, { Vector3 })
	local ids, items, positions = table.create(#list), table.create(#list), table.create(#list)
	for i, p in list do
		ids[i], items[i], positions[i] = p.id, p.item, p.position
	end
	return ids, items, positions
end

-- The pickups in parallel arrays from the server, skipping anything malformed or an item
-- `known` (Catalog.itemsById) doesn't have: a client never trusts a packet's shape.
function PickupWire.unpack(ids: any, items: any, positions: any, known: { [string]: any }): { { id: number, item: string, position: Vector3 } }
	local out = {}
	if type(ids) ~= "table" or type(items) ~= "table" or type(positions) ~= "table" then
		return out
	end
	for i, id in ids do
		local item, position = items[i], positions[i]
		if type(id) == "number" and type(item) == "string" and known[item] ~= nil and typeof(position) == "Vector3" then
			table.insert(out, { id = id, item = item, position = position })
		end
	end
	return out
end

return PickupWire
