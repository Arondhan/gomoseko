--!strict
-- Серверный инвентарь колец: список колец + надетые кольца по слотам 1..N — всё хранится в профиле (DataService).
-- Клиент только просит (equip/unequip), сервер проверяет и рассылает актуальное состояние.
-- Каждое изменение экипировки пересчитывает бонусы колец (StatsService).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local CombatConfig = require(Shared:WaitForChild("Configs"):WaitForChild("CombatConfig"))
local RingsConfig = require(Shared:WaitForChild("Configs"):WaitForChild("Rings"):WaitForChild("RingsConfig"))

local Services = script.Parent
local DataService = require(Services:WaitForChild("DataService"))
local StatsService = require(Services:WaitForChild("StatsService"))

local InventoryService = {}

local EMPTY = "" -- маркер пустого слота
local changedRemote: RemoteEvent

-- копия состояния для отправки клиенту (клиент не получает ссылку на серверную таблицу)
local function snapshot(profile: DataService.Profile): Types.InventoryState
	return { items = table.clone(profile.Rings), equipped = table.clone(profile.Equipped) }
end

local function emptyState(): Types.InventoryState
	local equipped = {}
	for i = 1, CombatConfig.RingSlotCount do
		equipped[i] = EMPTY
	end
	return { items = {}, equipped = equipped }
end

local function notify(player: Player)
	local profile = DataService.get(player)
	if profile then
		changedRemote:FireClient(player, snapshot(profile))
	end
end

local function slotIndexOf(profile: DataService.Profile, itemId: string): number?
	for slot = 1, CombatConfig.RingSlotCount do
		if profile.Equipped[slot] == itemId then
			return slot
		end
	end
	return nil
end

local function isValidSlot(slot: any): boolean
	return type(slot) == "number" and slot % 1 == 0 and slot >= 1 and slot <= CombatConfig.RingSlotCount
end

-- Есть ли у игрока надетое кольцо, дающее этот скилл
function InventoryService.isSkillEquipped(player: Player, skillId: string): boolean
	local profile = DataService.get(player)
	if not profile then
		return false
	end
	for slot = 1, CombatConfig.RingSlotCount do
		local ring = RingsConfig.Rings[profile.Equipped[slot]]
		if ring and ring.SkillId == skillId then
			return true
		end
	end
	return false
end

-- Есть ли кольцо в инвентаре
function InventoryService.has(player: Player, ringId: string): boolean
	local profile = DataService.get(player)
	return profile ~= nil and table.find(profile.Rings, ringId) ~= nil
end

-- Выдаёт кольцо. true — кольцо новое; false — уже было (дубликат: решает вызывающий, например, Essence)
function InventoryService.grantRing(player: Player, ringId: string): boolean
	local profile = DataService.get(player)
	if not profile or not RingsConfig.Rings[ringId] then
		return false
	end
	if table.find(profile.Rings, ringId) then
		return false
	end
	table.insert(profile.Rings, ringId)
	notify(player)
	return true
end

local function equip(player: Player, itemId: any, slot: any): boolean
	local profile = DataService.get(player)
	if not profile or type(itemId) ~= "string" or not isValidSlot(slot) then
		return false
	end
	if not table.find(profile.Rings, itemId) or not RingsConfig.Rings[itemId] then
		return false
	end
	-- кольцо не может быть надето в двух слотах сразу; если целевой слот занят, а кольцо уже надето
	-- в другом слоте — меняем их местами, иначе прежнее кольцо слота просто возвращается в инвентарь
	local target = slot :: number
	local old = slotIndexOf(profile, itemId)
	local displaced = profile.Equipped[target]
	if old then
		profile.Equipped[old] = if old ~= target and displaced ~= EMPTY then displaced else EMPTY
	end
	profile.Equipped[target] = itemId
	StatsService.recalculate(player)
	notify(player)
	return true
end

local function unequip(player: Player, slot: any): boolean
	local profile = DataService.get(player)
	if not profile or not isValidSlot(slot) or profile.Equipped[slot :: number] == EMPTY then
		return false
	end
	profile.Equipped[slot :: number] = EMPTY
	StatsService.recalculate(player)
	notify(player)
	return true
end

function InventoryService.start()
	changedRemote = Remotes.get("InventoryChanged") :: RemoteEvent
	local getRemote = Remotes.get("InventoryGet") :: RemoteFunction
	local equipRemote = Remotes.get("InventoryEquip") :: RemoteFunction
	local unequipRemote = Remotes.get("InventoryUnequip") :: RemoteFunction

	DataService.onLoaded(function(player)
		notify(player) -- первое состояние сразу после загрузки профиля
	end)

	getRemote.OnServerInvoke = function(player: Player)
		local profile = DataService.waitForProfile(player, 30)
		return if profile then snapshot(profile) else emptyState()
	end
	equipRemote.OnServerInvoke = equip
	unequipRemote.OnServerInvoke = unequip
end

return InventoryService
