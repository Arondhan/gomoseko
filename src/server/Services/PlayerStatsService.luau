--!strict
-- Мана игрока. Значение живёт на сервере (таблица), клиентам реплицируется через атрибуты Player:
-- "Mana" и "MaxMana" (клиентский UI просто читает их). Списание маны — только через trySpend.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("Configs"):WaitForChild("CombatConfig"))

local PlayerStatsService = {}

local PUBLISH_INTERVAL = 0.1 -- как часто обновлять атрибут (сек), чтобы не спамить репликацией

local mana: { [Player]: number } = {}
local sinceLastPublish = 0

local function publish(player: Player)
	player:SetAttribute("Mana", math.floor(mana[player]))
end

local function onPlayerAdded(player: Player)
	mana[player] = CombatConfig.Mana.Max
	player:SetAttribute("MaxMana", CombatConfig.Mana.Max)
	publish(player)
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
	publish(player)
	return true
end

function PlayerStatsService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		mana[player] = nil
	end)

	-- один общий цикл регенерации на всех игроков
	RunService.Heartbeat:Connect(function(dt)
		local max = CombatConfig.Mana.Max
		local regen = CombatConfig.Mana.RegenPerSecond * dt
		for player, value in mana do
			if value < max then
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
