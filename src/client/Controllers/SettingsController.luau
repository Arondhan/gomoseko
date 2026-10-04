--!strict
-- Настройки игрока на клиенте: громкость эффектов и режим Low graphics. Значения хранит сервер (профиль);
-- здесь — локальная копия, применение (Sfx, Quality) и отправка изменений.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local VFX = script.Parent.Parent:WaitForChild("VFX")
local Quality = require(VFX:WaitForChild("Quality"))
local Sfx = require(VFX:WaitForChild("Sfx"))
local Haptics = require(VFX:WaitForChild("Haptics"))

local SettingsController = {}

-- Fire() при любом изменении настроек
SettingsController.changed = Instance.new("BindableEvent")

local state: {
	SfxVolume: number,
	LowQuality: boolean?,
	Cinematic: boolean?,
	Shake: boolean?,
	SkipAnim: boolean?,
	Haptics: boolean?,
} =
	{ SfxVolume = 1, LowQuality = nil }

-- Булевы настройки «juice»: nil означает значение по умолчанию (ниже)
local FLAG_DEFAULTS: { [string]: boolean } = { Cinematic = true, Shake = true, SkipAnim = false, Haptics = true }

-- На телефоне (есть тач, нет клавиатуры) по умолчанию включаем Low graphics, пока игрок не выбрал сам
local function defaultLow(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

function SettingsController.getVolume(): number
	return state.SfxVolume
end

function SettingsController.isLowQuality(): boolean
	if state.LowQuality ~= nil then
		return state.LowQuality
	end
	return defaultLow()
end

local function apply()
	Sfx.setVolume(state.SfxVolume)
	Haptics.setEnabled(SettingsController.getFlag("Haptics"))
	Quality.apply(SettingsController.isLowQuality())
	SettingsController.changed:Fire()
end

local function send(key: string, value: any)
	local remote = Remotes.get("SettingsSet") :: RemoteFunction
	task.spawn(function()
		pcall(function()
			remote:InvokeServer(key, value)
		end)
	end)
end

-- name: "Cinematic" | "Shake" | "SkipAnim" | "Haptics"
function SettingsController.getFlag(name: string): boolean
	local value = (state :: any)[name]
	if type(value) == "boolean" then
		return value
	end
	return FLAG_DEFAULTS[name] == true
end

function SettingsController.setFlag(name: string, value: boolean)
	if FLAG_DEFAULTS[name] == nil then
		return
	end
	(state :: any)[name] = value
	SettingsController.changed:Fire()
	send(name, value)
end

function SettingsController.setVolume(volume: number, save: boolean)
	state.SfxVolume = math.clamp(volume, 0, 1)
	apply()
	if save then
		send("SfxVolume", state.SfxVolume)
	end
end

function SettingsController.setLowQuality(low: boolean)
	state.LowQuality = low
	apply()
	send("LowQuality", low)
end

function SettingsController.start()
	apply() -- сразу разумные значения по умолчанию (на телефоне — Low)
	task.spawn(function()
		local remote = Remotes.get("SettingsGet") :: RemoteFunction
		local ok, result = pcall(function()
			return remote:InvokeServer()
		end)
		if ok and type(result) == "table" then
			if type(result.SfxVolume) == "number" then
				state.SfxVolume = result.SfxVolume
			end
			if type(result.LowQuality) == "boolean" then
				state.LowQuality = result.LowQuality
			end
			for name in FLAG_DEFAULTS do
				if type(result[name]) == "boolean" then
					(state :: any)[name] = result[name]
				end
			end
			apply()
		end
	end)
end

return SettingsController
