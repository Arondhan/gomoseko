--!strict
-- Настройки игрока (громкость эффектов, режим «Low graphics»): хранятся в профиле, клиент читает и меняет их
-- через ремоуты SettingsGet / SettingsSet. Значения валидируются: клиенту доверять нельзя.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local DataService = require(script.Parent:WaitForChild("DataService"))

local SettingsService = {}

local function get(player: Player)
	local profile = DataService.waitForProfile(player, 30)
	if not profile then
		return { SfxVolume = 1 }
	end
	return { SfxVolume = profile.Settings.SfxVolume, LowQuality = profile.Settings.LowQuality }
end

local function set(player: Player, key: any, value: any): boolean
	local profile = DataService.get(player)
	if not profile then
		return false
	end
	if key == "SfxVolume" and type(value) == "number" and value == value then
		profile.Settings.SfxVolume = math.clamp(value, 0, 1)
		return true
	elseif key == "LowQuality" and type(value) == "boolean" then
		profile.Settings.LowQuality = value
		return true
	end
	return false
end

function SettingsService.start()
	(Remotes.get("SettingsGet") :: RemoteFunction).OnServerInvoke = get;
	(Remotes.get("SettingsSet") :: RemoteFunction).OnServerInvoke = set
end

return SettingsService
