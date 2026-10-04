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
	Sand = Color3.fromRGB(190, 180, 164),
	SandDark = Color3.fromRGB(160, 150, 136),
	SandLight = Color3.fromRGB(206, 198, 182),
	Plaza = Color3.fromRGB(182, 176, 166),
	StoneBrown = Color3.fromRGB(128, 98, 72),
	StoneDark = Color3.fromRGB(84, 64, 50),
	StoneLight = Color3.fromRGB(188, 168, 140),
	Rock = Color3.fromRGB(46, 50, 64), -- холодный сине-серый камень пещеры
	RockDark = Color3.fromRGB(30, 34, 46),
	Wood = Color3.fromRGB(104, 72, 44),
	WoodLight = Color3.fromRGB(138, 100, 62),
	Gold = Color3.fromRGB(214, 164, 70),
	Fire = Color3.fromRGB(255, 140, 30),
	Warm = Color3.fromRGB(255, 190, 120),
	Cool = Color3.fromRGB(120, 150, 255),

	-- Декор
	WoodTrim = Color3.fromRGB(112, 76, 48),
	MossGreen = Color3.fromRGB(70, 112, 58),
	BannerRed = Color3.fromRGB(150, 34, 34),
	BannerBlue = Color3.fromRGB(40, 72, 150),
	LanternGlass = Color3.fromRGB(255, 196, 120),
	Crystal = Color3.fromRGB(90, 150, 255),
	CaveStone = Color3.fromRGB(58, 64, 82), -- сталактиты
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

-- Освещение и атмосфера главной локации. Всё, что нужно подкрутить «на глаз», — здесь.
Config.Lighting = {
	Ambient = Color3.fromRGB(68, 74, 96), -- общий холодный полумрак
	OutdoorAmbient = Color3.fromRGB(86, 92, 116),
	Brightness = 2,
	ExposureCompensation = 0, -- было 0.35: давало пересвет и оранжевый налёт
	ClockTime = 0, -- ночь: в проёме свода видны звёзды
	EnvironmentDiffuseScale = 0.4,
	EnvironmentSpecularScale = 0.3,
	FogColor = Color3.fromRGB(14, 18, 30),
	FogStart = 90,
	FogEnd = 380,
	StarCount = 3000,

	Atmosphere = {
		Density = 0.3,
		Offset = 0,
		Color = Color3.fromRGB(110, 128, 168),
		Decay = Color3.fromRGB(36, 42, 66),
		Glare = 0,
		Haze = 1.3,
	},
	Bloom = { Intensity = 0.55, Size = 26, Threshold = 0.95 },
	ColorCorrection = {
		TintColor = Color3.fromRGB(255, 246, 236),
		Saturation = 0.12,
		Contrast = 0.12,
		Brightness = 0,
	},

	-- Лунный столб света через проём в своде над ямой
	Moon = {
		HoleHalf = 34, -- половина стороны квадратного проёма в своде
		Color = Color3.fromRGB(150, 180, 255),
		SpotBrightness = 3,
		SpotAngle = 90,
		SpotRange = 60, -- у света в Roblox максимум 60
		SpotHeight = 48, -- высота источника над площадью
		ShaftTransparency = 0.93,
		ShaftDiameter = 44,
	},

	-- Факелы и фонари (мерцание — client/VFX/TorchFlicker)
	Torch = {
		Color = Color3.fromRGB(255, 160, 80),
		Brightness = 2.5,
		Range = 24,
	},
}

Config.Dummies = {
	RespawnTime = 4,
	ClickDamage = 15,
	TouchDamage = 10,
	MaxHealth = 100,
}

return Config
