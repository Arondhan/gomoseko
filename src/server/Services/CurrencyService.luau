--!strict
-- Валюты игрока: Gold (за убийства), Crystals (Summon Crystals — для призыва колец), Essence (Ring Essence за дубликаты).
-- Значения лежат в профиле (DataService); клиенту реплицируются атрибутами Player.Gold/Crystals/Essence.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent:WaitForChild("DataService"))
local GachaConfig =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Configs"):WaitForChild("GachaConfig"))

local CurrencyService = {}

export type Kind = "Gold" | "Crystals" | "Essence"

local KINDS: { Kind } = { "Gold", "Crystals", "Essence" }

local function publish(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	for _, kind in KINDS do
		player:SetAttribute(kind, profile.Currencies[kind])
	end
end

function CurrencyService.get(player: Player, kind: Kind): number
	local profile = DataService.get(player)
	return if profile then profile.Currencies[kind] else 0
end

function CurrencyService.add(player: Player, kind: Kind, amount: number)
	local profile = DataService.get(player)
	if not profile or amount == 0 then
		return
	end
	profile.Currencies[kind] = math.max(0, profile.Currencies[kind] + amount)
	player:SetAttribute(kind, profile.Currencies[kind])
end

-- Списывает amount; false, если не хватает
function CurrencyService.trySpend(player: Player, kind: Kind, amount: number): boolean
	local profile = DataService.get(player)
	if not profile or amount < 0 or profile.Currencies[kind] < amount then
		return false
	end
	profile.Currencies[kind] -= amount
	player:SetAttribute(kind, profile.Currencies[kind])
	return true
end

-- Награда за убийство врага: золото и кристаллы (числа — Configs/GachaConfig.Rewards)
function CurrencyService.rewardKill(player: Player)
	CurrencyService.add(player, "Gold", GachaConfig.Rewards.KillGold)
	CurrencyService.add(player, "Crystals", GachaConfig.Rewards.KillCrystals)
end

function CurrencyService.rewardLevelUp(player: Player, levels: number)
	CurrencyService.add(player, "Crystals", GachaConfig.Rewards.LevelUpCrystals * levels)
end

function CurrencyService.start()
	DataService.onLoaded(function(player)
		publish(player)
	end)
end

return CurrencyService
