--!strict
-- Общие константы хаба. Используются генератором карты (server/BuildHub).

local Config = {}

-- Геометрия: центр ямы = (0,0,0), уровень верхнего яруса Y = 0, дно ямы Y = -10
Config.HALF = 160 -- половина стороны квадратной площади
Config.PIT_FLOOR_Y = -10
Config.PIT_BOTTOM_Y = -12
Config.WALL_R = 35.5 -- радиус стены ямы
Config.RCUT = 37 -- радиус выреза в плите верхнего яруса
Config.CEIL_Y = 94 -- нижняя грань свода
Config.SPAWN_POSITION = Vector3.new(0, 0.2, 92)

Config.Colors = {
	Sand = Color3.fromRGB(176, 160, 138),
	SandDark = Color3.fromRGB(148, 132, 110),
	SandLight = Color3.fromRGB(196, 184, 160),
	Plaza = Color3.fromRGB(170, 160, 144),
	StoneBrown = Color3.fromRGB(128, 98, 72),
	StoneDark = Color3.fromRGB(84, 64, 50),
	StoneLight = Color3.fromRGB(188, 168, 140),
	Rock = Color3.fromRGB(52, 52, 58),
	RockDark = Color3.fromRGB(38, 38, 44),
	Wood = Color3.fromRGB(104, 72, 44),
	WoodLight = Color3.fromRGB(138, 100, 62),
	Gold = Color3.fromRGB(214, 164, 70),
	Fire = Color3.fromRGB(255, 140, 30),
	Warm = Color3.fromRGB(255, 190, 120),
	Cool = Color3.fromRGB(120, 150, 255),
}

-- Цвета тентов: жёлтый, синий, красный, зелёный
Config.TentColors = {
	Color3.fromRGB(232, 190, 60),
	Color3.fromRGB(60, 110, 200),
	Color3.fromRGB(200, 55, 45),
	Color3.fromRGB(70, 155, 80),
}

-- Модель палатки из Creator Store (автор Jaomankai). Скрипты после загрузки удаляются.
-- Если загрузка не удалась, строятся процедурные палатки.
Config.StallAssetId = 10970560969

-- Порталы слева направо: Cyan, Orange, White, Purple
Config.Portals = {
	{ name = "PortalCyan", x = -24, color = Color3.fromRGB(0, 170, 255) },
	{ name = "PortalOrange", x = -8, color = Color3.fromRGB(255, 95, 0) },
	{ name = "PortalWhite", x = 8, color = Color3.fromRGB(225, 232, 255) },
	{ name = "PortalPurple", x = 24, color = Color3.fromRGB(125, 45, 235) },
}

Config.Dummies = {
	RespawnTime = 4,
	ClickDamage = 15,
	TouchDamage = 10,
	MaxHealth = 100,
}

return Config
