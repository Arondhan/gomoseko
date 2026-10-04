--!strict
-- Пассивные бонусы надетых колец: суммируются по слотам профиля, публикуются атрибутами Player (Bonus_*) для UI
-- и читаются боевыми сервисами. Пересчёт — при загрузке профиля и после каждого изменения экипировки.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RingsConfig = require(Shared:WaitForChild("Configs"):WaitForChild("Rings"):WaitForChild("RingsConfig"))

local DataService = require(script.Parent:WaitForChild("DataService"))

local StatsService = {}

export type Bonuses = {
	DamagePct: number,
	MaxMana: number,
	ManaRegen: number,
	CooldownReductionPct: number,
	CastRange: number,
	LuckPct: number,
}

-- Срабатывает после пересчёта: Fire(player)
StatsService.changed = Instance.new("BindableEvent")

local MAX_COOLDOWN_REDUCTION = 60 -- потолок суммарного сокращения перезарядки, %

local ZERO: Bonuses =
	{ DamagePct = 0, MaxMana = 0, ManaRegen = 0, CooldownReductionPct = 0, CastRange = 0, LuckPct = 0 }
local bonuses: { [Player]: Bonuses } = {}

local function zero(): Bonuses
	return table.clone(ZERO)
end

function StatsService.get(player: Player): Bonuses
	return bonuses[player] or ZERO
end

function StatsService.recalculate(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	local total = zero()
	for _, ringId in profile.Equipped do
		local ring = RingsConfig.Rings[ringId]
		if ring then
			local stats = ring.Stats
			total.DamagePct += stats.DamagePct or 0
			total.MaxMana += stats.MaxMana or 0
			total.ManaRegen += stats.ManaRegen or 0
			total.CooldownReductionPct += stats.CooldownReductionPct or 0
			total.CastRange += stats.CastRange or 0
			total.LuckPct += stats.LuckPct or 0
		end
	end
	total.CooldownReductionPct = math.min(total.CooldownReductionPct, MAX_COOLDOWN_REDUCTION)
	bonuses[player] = total

	-- атрибуты для UI (окно Character)
	player:SetAttribute("Bonus_DamagePct", total.DamagePct)
	player:SetAttribute("Bonus_MaxMana", total.MaxMana)
	player:SetAttribute("Bonus_ManaRegen", total.ManaRegen)
	player:SetAttribute("Bonus_CooldownReductionPct", total.CooldownReductionPct)
	player:SetAttribute("Bonus_CastRange", total.CastRange)
	player:SetAttribute("Bonus_LuckPct", total.LuckPct)
	StatsService.changed:Fire(player)
end

function StatsService.start()
	DataService.onLoaded(function(player)
		StatsService.recalculate(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		bonuses[player] = nil
	end)
end

return StatsService
