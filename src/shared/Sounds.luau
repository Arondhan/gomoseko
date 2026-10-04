--!strict
-- Реестр звуков. ID берутся из src/shared/Assets.luau (его генерирует Asphalt) по имени файла;
-- если Asphalt не используется — впишите rbxassetid:// вручную в Sounds.Manual. Пустая строка = звука нет.

local Generated: { [string]: any } = require(script.Parent.Assets)

local Sounds = {}

-- Ручные ID (имеют приоритет, если заполнены)
Sounds.Manual = {
	ArcLightningCharge = "",
	ArcLightningZap = "",
	ThunderBoom = "",
	RevealTick = "",
}

-- Имя звука -> имя файла в assets/audio (без расширения)
local FILES = {
	ArcLightningCharge = "arc_lightning_charge",
	ArcLightningZap = "arc_lightning_zap",
	ThunderBoom = "thunder_boom",
	RevealTick = "reveal_tick",
}

export type SoundName = "ArcLightningCharge" | "ArcLightningZap" | "ThunderBoom" | "RevealTick"

-- Asphalt может назвать ключ по-разному (с расширением, с папкой) — ищем по вхождению имени файла
local function lookup(file: string): string
	for key, value in Generated do
		if type(key) == "string" and type(value) == "string" and string.find(key, file, 1, true) then
			return value
		end
	end
	return ""
end

function Sounds.id(name: SoundName): string
	local manual = Sounds.Manual[name]
	if manual ~= "" then
		return manual
	end
	return lookup(FILES[name])
end

return Sounds
