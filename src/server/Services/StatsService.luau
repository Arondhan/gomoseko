--!strict
-- Пассивные бонусы надетых колец: суммируются по слотам профиля, публикуются атрибутами Player (Bonus_*) для UI
-- и читаются боевыми сервисами. Пересчёт — при загрузке профиля и после каждого изменения экипировки.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Configs = Shared:WaitForChild("Configs")
local RingsConfig = require(Configs:WaitForChild("Rings"):WaitForChild("RingsConfig"))
local PowerConfig = require(Configs:WaitForChild("PowerConfig"))
local PowerMath = require(Shared:WaitForChild("Combat"):WaitForChild("PowerMath"))

local DataService = require(script.Parent:WaitForChild("DataService"))

local StatsService = {}

export type Bonuses = {
	DamagePct: number,
	MaxMana: number,
	ManaRegen: number,
	CooldownReductionPct: number,
	CastRange: number,
	LuckPct: number,
	SkillDamagePct: { [string]: number }, -- бонус урона конкретного скилла от уровня его кольца, %
	LevelDamagePct: number, -- часть DamagePct, данная уровнем игрока (для разбивки в UI)
}

-- Срабатывает после пересчёта: Fire(player)
StatsService.changed = Instance.new("BindableEvent")

local MAX_COOLDOWN_REDUCTION = 60 -- потолок суммарного сокращения перезарядки, %

local ZERO: Bonuses = {
	DamagePct = 0,
	MaxMana = 0,
	ManaRegen = 0,
	CooldownReductionPct = 0,
	CastRange = 0,
	LuckPct = 0,
	SkillDamagePct = {},
	LevelDamagePct = 0,
}
local bonuses: { [Player]: Bonuses } = {}

local function zero(): Bonuses
	local fresh = table.clone(ZERO)
	fresh.SkillDamagePct = {}
	return fresh
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
			-- уровень кольца усиливает его пассивные бонусы; кольцо со скиллом добавляет урон именно этому скиллу
			local level = PowerMath.ringLevel(profile.RingLevels[ringId], PowerConfig.Rings)
			local multiplier = PowerMath.ringStatMultiplier(level, PowerConfig.Rings)
			local stats = ring.Stats
			total.DamagePct += (stats.DamagePct or 0) * multiplier
			total.MaxMana += (stats.MaxMana or 0) * multiplier
			total.ManaRegen += (stats.ManaRegen or 0) * multiplier
			total.CooldownReductionPct += (stats.CooldownReductionPct or 0) * multiplier
			total.CastRange += (stats.CastRange or 0) * multiplier
			total.LuckPct += (stats.LuckPct or 0) * multiplier
			if ring.SkillId then
				total.SkillDamagePct[ring.SkillId] = (total.SkillDamagePct[ring.SkillId] or 0)
					+ PowerMath.skillDamagePct(level, PowerConfig.Rings)
			end
		end
	end
	-- бонусы уровня игрока
	local levelDamage = PowerMath.levelDamagePct(profile.Level, PowerConfig.Level)
	total.LevelDamagePct = levelDamage
	total.DamagePct += levelDamage
	total.MaxMana = math.floor(total.MaxMana + PowerMath.levelMaxMana(profile.Level, PowerConfig.Level) + 0.5)
	total.CooldownReductionPct = math.min(total.CooldownReductionPct, MAX_COOLDOWN_REDUCTION)
	bonuses[player] = total

	-- атрибуты для UI (окно Character)
	player:SetAttribute("Bonus_DamagePct", total.DamagePct)
	player:SetAttribute("Bonus_LevelDamagePct", total.LevelDamagePct)
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
