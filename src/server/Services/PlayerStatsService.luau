--!strict
-- Мана и опыт игрока. Мана живёт в памяти сервера, уровень/опыт — в профиле (DataService).
-- Клиентам всё реплицируется атрибутами Player: "Mana"/"MaxMana" и "Level"/"XP"/"XPToNext".
-- Максимум маны и регенерация зависят от бонусов надетых колец (StatsService).
-- Мана списывается только через trySpend, опыт начисляется через addXp.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("Configs"):WaitForChild("CombatConfig"))
local Progression = require(Shared:WaitForChild("Combat"):WaitForChild("Progression"))

local Services = script.Parent
local CurrencyService = require(Services:WaitForChild("CurrencyService"))
local DataService = require(Services:WaitForChild("DataService"))
local StatsService = require(Services:WaitForChild("StatsService"))

local PlayerStatsService = {}

local PUBLISH_INTERVAL = 0.1 -- как часто обновлять атрибут (сек), чтобы не спамить репликацией

local mana: { [Player]: number } = {}
local maxMana: { [Player]: number } = {}
local sinceLastPublish = 0

local function publishXp(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	local config = CombatConfig.Progression
	player:SetAttribute("Level", profile.Level)
	player:SetAttribute("XP", profile.XP)
	player:SetAttribute("XPToNext", Progression.xpToNext(profile.Level, config.BaseXp, config.Growth))
end

local function publishMana(player: Player)
	player:SetAttribute("Mana", math.floor(mana[player]))
end

-- Максимум маны с учётом колец; ману не выше нового максимума
local function refreshMax(player: Player)
	local max = CombatConfig.Mana.Max + StatsService.get(player).MaxMana
	maxMana[player] = max
	player:SetAttribute("MaxMana", max)
	if mana[player] then
		mana[player] = math.min(mana[player], max)
		publishMana(player)
	end
end

-- Текущая мана (0, если игрока нет)
function PlayerStatsService.get(player: Player): number
	return mana[player] or 0
end

-- Пытается списать amount маны. true — списано, false — не хватает.
function PlayerStatsService.trySpend(player: Player, amount: number): boolean
	local current = mana[player]
	if current == nil or current < amount then
		return false
	end
	mana[player] = current - amount
	publishMana(player)
	return true
end

-- Возвращает ману (например, при сорванном касте), не выше максимума
function PlayerStatsService.refund(player: Player, amount: number)
	local current = mana[player]
	if current ~= nil then
		mana[player] = math.min(maxMana[player] or CombatConfig.Mana.Max, current + amount)
		publishMana(player)
	end
end

-- Начисляет опыт; при переходе порога повышает уровень и выдаёт кристаллы за уровень
function PlayerStatsService.addXp(player: Player, amount: number)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	local config = CombatConfig.Progression
	local gained
	profile.Level, profile.XP, gained = Progression.add(profile.Level, profile.XP, amount, config.BaseXp, config.Growth)
	if gained > 0 then
		CurrencyService.rewardLevelUp(player, gained)
	end
	publishXp(player)
end

-- Админ/тест: сразу задать уровень (опыт сбрасывается) и заполнить ману
function PlayerStatsService.setLevel(player: Player, level: number)
	local profile = DataService.get(player)
	if profile then
		profile.Level = math.max(1, math.floor(level))
		profile.XP = 0
		publishXp(player)
	end
end

function PlayerStatsService.refillMana(player: Player)
	if mana[player] ~= nil then
		mana[player] = maxMana[player] or CombatConfig.Mana.Max
		publishMana(player)
	end
end

function PlayerStatsService.start()
	DataService.onLoaded(function(player)
		mana[player] = CombatConfig.Mana.Max + StatsService.get(player).MaxMana
		refreshMax(player)
		mana[player] = maxMana[player]
		publishMana(player)
		publishXp(player)
	end)
	StatsService.changed.Event:Connect(function(player: Player)
		refreshMax(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		mana[player] = nil
		maxMana[player] = nil
	end)

	-- один общий цикл регенерации на всех игроков
	RunService.Heartbeat:Connect(function(dt)
		for player, value in mana do
			local max = maxMana[player] or CombatConfig.Mana.Max
			if value < max then
				local regen = (CombatConfig.Mana.RegenPerSecond + StatsService.get(player).ManaRegen) * dt
				mana[player] = math.min(max, value + regen)
			end
		end
		sinceLastPublish += dt
		if sinceLastPublish >= PUBLISH_INTERVAL then
			sinceLastPublish = 0
			for player in mana do
				local shown = math.floor(mana[player])
				if player:GetAttribute("Mana") ~= shown then
					player:SetAttribute("Mana", shown)
				end
			end
		end
	end)
end

return PlayerStatsService
