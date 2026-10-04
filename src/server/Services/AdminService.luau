--!strict
-- Админ-меню (сервер): выдача колец, валюты и уровень, тестовый режим боя, спавн врагов, события удачи.
-- Доступ проверяется на СЕРВЕРЕ при каждом действии (AdminAccess + Configs/AdminConfig): клиент присылает только
-- название действия и параметры, все параметры валидируются и ограничиваются. Попытки не-админов пишутся в warn.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local AdminAccess = require(Shared:WaitForChild("AdminAccess"))
local Configs = Shared:WaitForChild("Configs")
local AdminConfig = require(Configs:WaitForChild("AdminConfig"))
local RingsConfig = require(Configs:WaitForChild("Rings"):WaitForChild("RingsConfig"))

local Services = script.Parent
local CombatService = require(Services:WaitForChild("CombatService"))
local CurrencyService = require(Services:WaitForChild("CurrencyService"))
local InventoryService = require(Services:WaitForChild("InventoryService"))
local LuckEventService = require(Services:WaitForChild("LuckEventService"))
local PlayerStatsService = require(Services:WaitForChild("PlayerStatsService"))
local PlaytimeLuckService = require(Services:WaitForChild("PlaytimeLuckService"))
local RiftService = require(Services:WaitForChild("RiftService"))
local TestEnemy = require(script.Parent.Parent:WaitForChild("Hub"):WaitForChild("TestEnemy"))

local AdminService = {}

local MAX_CURRENCY_STEP = 1e9
local MAX_LEVEL = 100
local MAX_SPAWN_AT_ONCE = 10
local MAX_ENEMIES = 40
local FLAGS: { [string]: string } = { InfiniteMana = "Admin_InfiniteMana", NoCooldown = "Admin_NoCooldown" }
local CURRENCIES: { [string]: boolean } = { Gold = true, Crystals = true, Essence = true }

local function isAdmin(player: Player): boolean
	return AdminAccess.isAllowed(
		player.UserId,
		AdminConfig,
		RunService:IsStudio(),
		game.CreatorId,
		game.CreatorType == Enum.CreatorType.User
	)
end

local function flagsOf(player: Player): { [string]: boolean }
	local flags: { [string]: boolean } = {}
	for name, attribute in FLAGS do
		flags[name] = player:GetAttribute(attribute) == true
	end
	return flags
end

-- Земля перед игроком на расстоянии distance (с лучом вниз, чтобы враги не висели в воздухе)
local function groundAhead(player: Player, distance: number, sideways: number): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return nil
	end
	local point = root.Position + root.CFrame.LookVector * distance + root.CFrame.RightVector * sideways
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character :: any }
	local result = Workspace:Raycast(point + Vector3.new(0, 20, 0), Vector3.new(0, -80, 0), params)
	return if result then result.Position else Vector3.new(point.X, root.Position.Y - 3, point.Z)
end

type Handler = (player: Player, a: any, b: any) -> (boolean, string)

local ACTIONS: { [string]: Handler } = {}

ACTIONS.GiveRing = function(player: Player, ringId: any)
	local ring = if type(ringId) == "string" then RingsConfig.Rings[ringId :: string] else nil
	if not ring then
		return false, "Unknown ring"
	end
	return true,
		if InventoryService.grantRing(player, ring.Id) then "Added " .. ring.Name else "Already have " .. ring.Name
end

ACTIONS.GiveAllRings = function(player)
	local added = 0
	for _, ring in RingsConfig.List do
		if InventoryService.grantRing(player, ring.Id) then
			added += 1
		end
	end
	return true, string.format("Added %d new rings", added)
end

ACTIONS.ResetRings = function(player)
	InventoryService.resetRings(player)
	return true, "Rings reset to the starting set"
end

ACTIONS.AddCurrency = function(player, kind, amount)
	if type(kind) ~= "string" or not CURRENCIES[kind] then
		return false, "Unknown currency"
	end
	if type(amount) ~= "number" or amount ~= amount or amount < 1 or amount > MAX_CURRENCY_STEP then
		return false, "Invalid amount"
	end
	CurrencyService.add(player, kind :: any, math.floor(amount), "Gameplay", "admin")
	return true, string.format("+%d %s", math.floor(amount), kind)
end

ACTIONS.SetLevel = function(player, level)
	if type(level) ~= "number" or level ~= level or level < 1 or level > MAX_LEVEL then
		return false, "Invalid level"
	end
	PlayerStatsService.setLevel(player, level)
	return true, string.format("Level set to %d", math.floor(level))
end

ACTIONS.ToggleFlag = function(player, name)
	local attribute = if type(name) == "string" then FLAGS[name] else nil
	if not attribute then
		return false, "Unknown flag"
	end
	local on = player:GetAttribute(attribute) ~= true
	player:SetAttribute(attribute, on)
	return true, string.format("%s: %s", name, if on then "ON" else "OFF")
end

ACTIONS.RefillMana = function(player)
	PlayerStatsService.refillMana(player)
	return true, "Mana refilled"
end

ACTIONS.ResetCooldowns = function(player)
	CombatService.resetCooldowns(player)
	return true, "Cooldowns reset"
end

ACTIONS.Spawn = function(player, kind, count)
	if kind ~= "Dummy" and kind ~= "Mover" then
		return false, "Unknown enemy"
	end
	if type(count) ~= "number" or count ~= count then
		return false, "Invalid count"
	end
	local amount = math.clamp(math.floor(count), 1, MAX_SPAWN_AT_ONCE)
	if TestEnemy.count() + amount > MAX_ENEMIES then
		return false, "Too many enemies (max " .. MAX_ENEMIES .. "), press Clear"
	end
	for i = 1, amount do
		-- веером перед игроком: ряды по 5
		local row = (i - 1) // 5
		local column = (i - 1) % 5
		local ground = groundAhead(player, 16 + row * 7, (column - 2) * 6)
		if not ground then
			return false, "You have no character"
		end
		TestEnemy.spawn(kind, ground + Vector3.new(0, 3, 0))
	end
	return true, string.format("Spawned %d %s", amount, kind)
end

ACTIONS.ClearEnemies = function()
	TestEnemy.clear()
	return true, "Test enemies removed"
end

ACTIONS.LuckyHour = function(_, seconds)
	if type(seconds) ~= "number" or seconds ~= seconds or seconds < 0 or seconds > 3600 then
		return false, "Invalid duration"
	end
	LuckEventService.setOverride(seconds)
	return true, if seconds > 0 then "Lucky Hour started" else "Lucky Hour override cleared"
end

ACTIONS.AfkLuck = function(player, seconds)
	if type(seconds) ~= "number" or seconds ~= seconds or seconds < 1 or seconds > 86400 then
		return false, "Invalid time"
	end
	PlaytimeLuckService.addOffset(player, seconds)
	return true, string.format("AFK time +%d min", math.floor(seconds / 60))
end

ACTIONS.RiftJump = function(player: Player, wave: any)
	if type(wave) ~= "number" or wave ~= wave or wave < 1 or wave > 200 then
		return false, "Invalid wave"
	end
	return RiftService.adminJump(player, math.floor(wave))
end

ACTIONS.RiftKillAll = function()
	RiftService.killAll()
	return true, "Rift enemies removed"
end

ACTIONS.RiftChest = function(player: Player, boss: any)
	RiftService.adminChest(player, boss == true)
	return true, if boss == true then "Titan chest opened" else "Rift chest opened"
end

ACTIONS.RiftLeave = function(player: Player)
	return RiftService.leave(player)
end

local function act(player: Player, action: any, a: any, b: any): (boolean, string)
	if not isAdmin(player) then
		warn(
			string.format("[AdminService] %s (%d) tried admin action %s", player.Name, player.UserId, tostring(action))
		)
		return false, "Not allowed"
	end
	local handler = if type(action) == "string" then ACTIONS[action] else nil
	if not handler then
		return false, "Unknown action"
	end
	local ok, success, message = pcall(handler, player, a, b)
	if not ok then
		warn("[AdminService] action failed: " .. tostring(success))
		return false, "Action failed"
	end
	return success :: boolean, message :: string
end

function AdminService.start()
	local getRemote = Remotes.get("AdminGet") :: RemoteFunction
	local actRemote = Remotes.get("AdminAction") :: RemoteFunction
	getRemote.OnServerInvoke = function(player: Player)
		if not isAdmin(player) then
			return { admin = false, flags = {} }
		end
		return { admin = true, flags = flagsOf(player) }
	end
	actRemote.OnServerInvoke = act

	-- тестовые флаги не переживают выход игрока (это атрибуты Player), но на всякий случай сбрасываем
	Players.PlayerRemoving:Connect(function(player)
		for _, attribute in FLAGS do
			player:SetAttribute(attribute, nil)
		end
	end)
end

return AdminService
