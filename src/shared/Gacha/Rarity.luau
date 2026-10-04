--!strict
-- Цвета качества колец (общие для сервера и клиента: титул над головой строится на сервере) и палитры градиентов.

local Rarity = {}

Rarity.Colors = {
	Common = Color3.fromRGB(157, 157, 157),
	Uncommon = Color3.fromRGB(30, 255, 0),
	Rare = Color3.fromRGB(0, 112, 221),
	Epic = Color3.fromRGB(163, 53, 238),
	Legendary = Color3.fromRGB(255, 128, 0),
	Mythic = Color3.fromRGB(255, 64, 128),
	Divine = Color3.fromRGB(255, 232, 150),
} :: { [string]: Color3 }

-- Периодическая палитра для «бегущей волны»: период 0.5 (база — блик — база — блик — база), поэтому сдвиг Offset
-- на 0.5 даёт бесшовный цикл. Волну двигает клиент (client/VFX/TitleGradient.luau).
function Rarity.waveSequence(color: Color3): ColorSequence
	local bright = color:Lerp(Color3.new(1, 1, 1), 0.75)
	local dark = color:Lerp(Color3.new(0, 0, 0), 0.25)
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, dark),
		ColorSequenceKeypoint.new(0.25, bright),
		ColorSequenceKeypoint.new(0.5, dark),
		ColorSequenceKeypoint.new(0.75, bright),
		ColorSequenceKeypoint.new(1, dark),
	})
end

-- Радуга, сдвинутая на phase (0..1); 6 ключей по кругу оттенков, концы совпадают
function Rarity.rainbowSequence(phase: number): ColorSequence
	local keys: { ColorSequenceKeypoint } = {}
	for i = 0, 5 do
		keys[#keys + 1] = ColorSequenceKeypoint.new(i / 5, Color3.fromHSV((phase + i / 5) % 1, 0.65, 1))
	end
	return ColorSequence.new(keys)
end

return Rarity
