--!strict
-- Клиентское зеркало инвентаря колец. Источник правды — сервер (InventoryService):
-- здесь мы только запрашиваем надеть/снять и обновляем локальную копию, когда сервер присылает состояние.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local CombatConfig = require(Shared:WaitForChild("Configs"):WaitForChild("CombatConfig"))
local RingsConfig = require(Shared:WaitForChild("Configs"):WaitForChild("Rings"):WaitForChild("RingsConfig"))

local InventoryController = {}

-- срабатывает при любом изменении состояния (как Window.changed в ui/Window)
InventoryController.changed = Instance.new("BindableEvent")

local state: Types.InventoryState = { items = {}, equipped = {}, levels = {} }

function InventoryController.getItems(): { Types.RingDef }
	local list = {}
	for _, itemId in state.items do
		local def = RingsConfig.Rings[itemId]
		if def then
			table.insert(list, def)
		end
	end
	return list
end

-- Кольцо, надетое в слот (nil, если слот пуст)
function InventoryController.getRingInSlot(slot: number): Types.RingDef?
	local itemId = state.equipped[slot]
	return if itemId and itemId ~= "" then RingsConfig.Rings[itemId] else nil
end

-- Номер слота, в котором надето это кольцо (nil, если не надето)
function InventoryController.getSlotOf(itemId: string): number?
	for slot = 1, CombatConfig.RingSlotCount do
		if state.equipped[slot] == itemId then
			return slot
		end
	end
	return nil
end

-- Номер слота с кольцом, дающим скилл (nil, если такого нет)
function InventoryController.getSlotForSkill(skillId: string): number?
	for slot = 1, CombatConfig.RingSlotCount do
		local ring = InventoryController.getRingInSlot(slot)
		if ring and ring.SkillId == skillId then
			return slot
		end
	end
	return nil
end

function InventoryController.firstFreeSlot(): number?
	for slot = 1, CombatConfig.RingSlotCount do
		if InventoryController.getRingInSlot(slot) == nil then
			return slot
		end
	end
	return nil
end

-- Уровень кольца (1, если не улучшалось)
function InventoryController.getLevel(itemId: string): number
	local level = state.levels[itemId]
	return if type(level) == "number" then level else 1
end

-- Улучшить кольцо на уровень (yield): (успех, сообщение сервера). Новое состояние придёт через changed.
function InventoryController.upgrade(itemId: string): (boolean, string)
	local remote = Remotes.get("RingUpgrade") :: RemoteFunction
	local ok, success, message = pcall(function()
		return remote:InvokeServer(itemId)
	end)
	if not ok then
		return false, "Connection problem, try again"
	end
	return success == true, tostring(message)
end

-- Запросить у сервера надеть кольцо в слот (результат придёт через changed)
function InventoryController.equip(itemId: string, slot: number)
	local remote = Remotes.get("InventoryEquip") :: RemoteFunction
	task.spawn(function()
		pcall(function()
			remote:InvokeServer(itemId, slot)
		end)
	end)
end

function InventoryController.unequip(slot: number)
	local remote = Remotes.get("InventoryUnequip") :: RemoteFunction
	task.spawn(function()
		pcall(function()
			remote:InvokeServer(slot)
		end)
	end)
end

local function setState(newState: Types.InventoryState)
	if type(newState.levels) ~= "table" then
		newState.levels = {}
	end
	state = newState
	InventoryController.changed:Fire()
end

function InventoryController.start()
	local changedRemote = Remotes.get("InventoryChanged") :: RemoteEvent
	changedRemote.OnClientEvent:Connect(setState)

	local getRemote = Remotes.get("InventoryGet") :: RemoteFunction
	task.spawn(function()
		local ok, result = pcall(function()
			return getRemote:InvokeServer()
		end)
		if ok and type(result) == "table" then
			setState(result)
		end
	end)
end

return InventoryController
