--!strict
-- Серверный инвентарь колец: список колец + надетые кольца по слотам 1..N — всё хранится в профиле (DataService).
-- Клиент только просит (equip/unequip), сервер проверяет и рассылает актуальное состояние.
-- Каждое изменение экипировки пересчитывает бонусы колец (StatsService).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local CombatConfig = require(Shared:WaitForChild("Configs"):WaitForChild("CombatConfig"))
local PowerConfig = require(Shared:WaitForChild("Configs"):WaitForChild("PowerConfig"))
local PowerMath = require(Shared:WaitForChild("Combat"):WaitForChild("PowerMath"))
local RingsConfig = require(Shared:WaitForChild("Configs"):WaitForChild("Rings"):WaitForChild("RingsConfig"))

local Services = script.Parent
local CurrencyService = require(Services:WaitForChild("CurrencyService"))
local DataService = require(Services:WaitForChild("DataService"))
local OnboardingService = require(Services:WaitForChild("OnboardingService"))
local StatsService = require(Services:WaitForChild("StatsService"))

local InventoryService = {}

local EMPTY = "" -- маркер пустого слота
local changedRemote: RemoteEvent

-- копия состояния для отправки клиенту (клиент не получает ссылку на серверную таблицу)
local function snapshot(profile: DataService.Profile): Types.InventoryState
	return {
		items = table.clone(profile.Rings),
		equipped = table.clone(profile.Equipped),
		levels = table.clone(profile.RingLevels),
	}
end

local function emptyState(): Types.InventoryState
	local equipped = {}
	for i = 1, CombatConfig.RingSlotCount do
		equipped[i] = EMPTY
	end
	return { items = {}, equipped = equipped, levels = {} }
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
	OnboardingService.notify(player, "EquipRing")
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

-- Админ/тест: вернуть стартовый набор колец и снять всё (для проверки Gacha, дубликатов и Index)
function InventoryService.resetRings(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	profile.Rings = table.clone(RingsConfig.StartingItems)
	profile.RingLevels = {}
	for slot = 1, CombatConfig.RingSlotCount do
		profile.Equipped[slot] = EMPTY
	end
	StatsService.recalculate(player)
	notify(player)
end

-- Улучшение кольца на 1 уровень за Essence и Gold. Всё проверяет сервер: кольцо есть, уровень ниже максимума,
-- хватает обеих валют (проверяем оба баланса до списания, чтобы не остаться с половиной оплаты).
local function upgradeRing(player: Player, ringId: any): (boolean, string)
	local profile = DataService.get(player)
	local ring = if type(ringId) == "string" then RingsConfig.Rings[ringId :: string] else nil
	if not profile or not ring then
		return false, "Unknown ring"
	end
	if not table.find(profile.Rings, ring.Id) then
		return false, "You do not have this ring"
	end
	local level = PowerMath.ringLevel(profile.RingLevels[ring.Id], PowerConfig.Rings)
	local essence, gold =
		PowerMath.upgradeCost(PowerConfig.QualityMultiplier[ring.Quality] or 1, level, PowerConfig.Rings)
	if not essence or not gold then
		return false, "This ring is already at the maximum level"
	end
	if CurrencyService.get(player, "Essence") < essence or CurrencyService.get(player, "Gold") < gold then
		return false, string.format("Not enough: need %d Essence and %d Gold", essence, gold)
	end
	if not CurrencyService.trySpend(player, "Essence", essence, "Gameplay", "ring_upgrade") then
		return false, "Not enough Essence"
	end
	if not CurrencyService.trySpend(player, "Gold", gold, "Gameplay", "ring_upgrade") then
		CurrencyService.add(player, "Essence", essence, "Gameplay", "ring_upgrade_refund")
		return false, "Not enough Gold"
	end
	profile.RingLevels[ring.Id] = level + 1
	StatsService.recalculate(player)
	notify(player)
	return true, string.format("%s is now level %d", ring.Name, level + 1)
end

-- Админ/тест: задать уровень всем кольцам игрока (0 — сбросить к 1)
function InventoryService.setAllRingLevels(player: Player, level: number)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	profile.RingLevels = {}
	if level > 1 then
		for _, ringId in profile.Rings do
			profile.RingLevels[ringId] = PowerMath.ringLevel(level, PowerConfig.Rings)
		end
	end
	StatsService.recalculate(player)
	notify(player)
end

function InventoryService.start()
	changedRemote = Remotes.get("InventoryChanged") :: RemoteEvent
	local getRemote = Remotes.get("InventoryGet") :: RemoteFunction
	local equipRemote = Remotes.get("InventoryEquip") :: RemoteFunction
	local unequipRemote = Remotes.get("InventoryUnequip") :: RemoteFunction
	local upgradeRemote = Remotes.get("RingUpgrade") :: RemoteFunction

	DataService.onLoaded(function(player)
		notify(player) -- первое состояние сразу после загрузки профиля
	end)

	getRemote.OnServerInvoke = function(player: Player)
		local profile = DataService.waitForProfile(player, 30)
		return if profile then snapshot(profile) else emptyState()
	end
	equipRemote.OnServerInvoke = equip
	unequipRemote.OnServerInvoke = unequip
	upgradeRemote.OnServerInvoke = upgradeRing
end

return InventoryService
