-- Палитра и мелкие помощники для UI в стиле WoW (Dragonflight).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Fonts = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Fonts"))
local Rarity = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Gacha"):WaitForChild("Rarity"))

local Theme = {
	-- Мультяшная палитра: тёмно-синие окна, яркие жёлто-оранжевые акценты (имена Gold* сохранены — это «акцентный» цвет)
	Bg = Color3.fromRGB(20, 26, 60),
	Panel = Color3.fromRGB(30, 40, 96),
	Header = Color3.fromRGB(40, 54, 130),
	Inset = Color3.fromRGB(24, 32, 80),
	Gold = Color3.fromRGB(255, 190, 50),
	GoldBright = Color3.fromRGB(255, 225, 90),
	GoldDim = Color3.fromRGB(150, 110, 40),
	Text = Color3.fromRGB(255, 248, 225),
	Coin = Color3.fromRGB(255, 214, 64),
	Muted = Color3.fromRGB(190, 200, 235),

	-- Акцент для заливок: светлое -> среднее -> тёмное
	GoldLight = Color3.fromRGB(255, 236, 110),
	GoldMid = Color3.fromRGB(255, 170, 35),
	GoldDark = Color3.fromRGB(200, 95, 15),

	-- Кнопки (оранжевые) и обводка элементов
	ButtonTop = Color3.fromRGB(255, 176, 40),
	ButtonBottom = Color3.fromRGB(214, 110, 20),
	Outline = Color3.fromRGB(14, 18, 48),

	-- Цвета плиток меню
	Tiles = {
		Summon = Color3.fromRGB(150, 80, 240),
		Rings = Color3.fromRGB(40, 190, 230),
		Index = Color3.fromRGB(50, 110, 240),
		Shop = Color3.fromRGB(235, 60, 60),
		Boost = Color3.fromRGB(250, 200, 30),
		Ranks = Color3.fromRGB(60, 200, 90),
		Settings = Color3.fromRGB(140, 150, 175),
		Admin = Color3.fromRGB(90, 100, 130),
		Rift = Color3.fromRGB(215, 70, 120),
	} :: { [string]: Color3 },

	-- Фон панелей: вертикальный градиент сверху вниз
	PanelTop = Color3.fromRGB(62, 96, 210),
	PanelBottom = Color3.fromRGB(30, 44, 128),

	-- Полосы и сообщения
	Health = Color3.fromRGB(60, 190, 80),
	Mana = Color3.fromRGB(50, 120, 240),
	Xp = Color3.fromRGB(160, 80, 220),
	Enemy = Color3.fromRGB(200, 55, 45),
	EnemyName = Color3.fromRGB(255, 105, 90),
	Danger = Color3.fromRGB(255, 80, 60),
	Good = Color3.fromRGB(30, 255, 0),
	Warn = Color3.fromRGB(255, 209, 0),

	-- Размеры текста (до масштабирования UIScale). Не опускаемся ниже Small: на телефоне это ~9 px
	TextSize = { Small = 14, Body = 16, Header = 18, Title = 24, Banner = 40 },

	-- Шрифты (FontFace) — см. shared/Fonts.luau: Title, Banner, Serif, Body, Numbers, Impact
	Fonts = Fonts,

	-- Качество предметов (как в WoW): серый, зелёный, синий, фиолетовый, оранжевый
	Quality = Rarity.Colors,
	QualityNames = {
		Common = "Common",
		Uncommon = "Uncommon",
		Rare = "Rare",
		Epic = "Epic",
		Legendary = "Legendary",
		Mythic = "Mythic",
		Divine = "Divine",
	} :: { [string]: string },
}

-- Сокращение больших чисел для валют: 1234 -> 1.2K, 3 400 000 -> 3.4M
function Theme.abbreviate(value: number): string
	local units = { "", "K", "M", "B", "T", "Qa", "Qn" }
	local n = math.floor(value)
	if math.abs(n) < 1000 then
		return tostring(n)
	end
	local index = 1
	local scaled = n :: number
	while math.abs(scaled) >= 1000 and index < #units do
		scaled /= 1000
		index += 1
	end
	return string.format("%.1f%s", math.floor(scaled * 10) / 10, units[index])
end

function Theme.new(class: string, props: { [string]: any }, parent: Instance?): any
	local obj = Instance.new(class)
	for key, value in props do
		obj[key] = value
	end
	obj.Parent = parent
	return obj
end

function Theme.corner(parent: Instance, radius: number)
	return Theme.new("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

function Theme.stroke(parent: Instance, color: Color3, thickness: number)
	return Theme.new("UIStroke", {
		Name = "Stroke",
		Color = color,
		Thickness = thickness,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

-- Трёхцветная последовательность (верх / середина / низ) для объёмных заливок
function Theme.threeStop(top: Color3, mid: Color3, bottom: Color3): ColorSequence
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, top),
		ColorSequenceKeypoint.new(0.5, mid),
		ColorSequenceKeypoint.new(1, bottom),
	})
end

-- Объёмная заливка одним цветом: светлее сверху, темнее снизу
function Theme.shade(color: Color3): ColorSequence
	return Theme.threeStop(color:Lerp(Color3.new(1, 1, 1), 0.35), color, color:Lerp(Color3.new(0, 0, 0), 0.45))
end

-- Горизонтальный/вертикальный градиент по двум цветам (rotation 90 = сверху вниз)
function Theme.gradient(parent: Instance, rotation: number, from: Color3, to: Color3)
	return Theme.new("UIGradient", { Rotation = rotation, Color = ColorSequence.new(from, to) }, parent)
end

-- Масштаб интерфейса (UIScale на ScreenGui): координаты курсора/пальца в offset-позициях надо делить на него
function Theme.scaleOf(instance: Instance): number
	local gui = instance:FindFirstAncestorOfClass("ScreenGui")
	local scale = gui and gui:FindFirstChildOfClass("UIScale")
	return if scale then scale.Scale else 1
end

function Theme.tween(obj: Instance, time: number, props: { [string]: any })
	TweenService:Create(obj, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

return Theme
