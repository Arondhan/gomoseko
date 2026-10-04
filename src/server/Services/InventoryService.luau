--!strict
-- Серверный инвентарь колец: список предметов + надетые кольца по слотам 1..N.
-- Клиент только просит (equip/unequip), сервер проверяет и рассылает актуальное состояние.
-- Сохранение пока не подключено: serialize()/load() — точка для будущего DataStore.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local CombatConfig = require(Shared:WaitForChild("Configs"):WaitForChild("CombatConfig"))
local RingsConfig = require(Shared:WaitForChild("Configs"):WaitForChild("Rings"):WaitForChild("RingsConfig"))

local InventoryService = {}

local states: { [Player]: Types.InventoryState } = {}
local changedRemote: RemoteEvent

local EMPTY = "" -- маркер пустого слота

local function emptySlots(): { string }
	local slots = {}
	for i = 1, CombatConfig.RingSlotCount do
		slots[i] = EMPTY
	end
	return slots
end

local function newState(): Types.InventoryState
	return { items = table.clone(RingsConfig.StartingItems), equipped = emptySlots() }
end

-- копия состояния для отправки клиенту (клиент не получает ссылку на серверную таблицу)
local function snapshot(state: Types.InventoryState): Types.InventoryState
	return { items = table.clone(state.items), equipped = table.clone(state.equipped) }
end

local function notify(player: Player)
	local state = states[player]
	if state then
		changedRemote:FireClient(player, snapshot(state))
	end
end

local function slotIndexOf(state: Types.InventoryState, itemId: string): number?
	for slot = 1, CombatConfig.RingSlotCount do
		if state.equipped[slot] == itemId then
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
	local state = states[player]
	if not state then
		return false
	end
	for slot = 1, CombatConfig.RingSlotCount do
		local ring = RingsConfig.Rings[state.equipped[slot]]
		if ring and ring.SkillId == skillId then
			return true
		end
	end
	return false
end

-- Точка расширения: сохранение/загрузка (DataStore)
function InventoryService.serialize(player: Player): Types.InventoryState?
	local state = states[player]
	return state and snapshot(state)
end

function InventoryService.load(player: Player, saved: Types.InventoryState)
	states[player] = snapshot(saved)
	notify(player)
end

local function equip(player: Player, itemId: any, slot: any): boolean
	local state = states[player]
	if not state or type(itemId) ~= "string" or not isValidSlot(slot) then
		return false
	end
	if not table.find(state.items, itemId) or not RingsConfig.Rings[itemId] then
		return false
	end
	-- кольцо не может быть надето в двух слотах сразу: переносим
	local old = slotIndexOf(state, itemId)
	if old then
		state.equipped[old] = EMPTY
	end
	state.equipped[slot :: number] = itemId
	notify(player)
	return true
end

local function unequip(player: Player, slot: any): boolean
	local state = states[player]
	if not state or not isValidSlot(slot) or state.equipped[slot :: number] == EMPTY then
		return false
	end
	state.equipped[slot :: number] = EMPTY
	notify(player)
	return true
end

function InventoryService.start()
	changedRemote = Remotes.get("InventoryChanged") :: RemoteEvent
	local getRemote = Remotes.get("InventoryGet") :: RemoteFunction
	local equipRemote = Remotes.get("InventoryEquip") :: RemoteFunction
	local unequipRemote = Remotes.get("InventoryUnequip") :: RemoteFunction

	local function onPlayerAdded(player: Player)
		if not states[player] then
			states[player] = newState()
		end
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)

	getRemote.OnServerInvoke = function(player: Player)
		local state = states[player]
		return state and snapshot(state) or { items = {}, equipped = emptySlots() }
	end
	equipRemote.OnServerInvoke = equip
	unequipRemote.OnServerInvoke = unequip
end

return InventoryService
