--!strict
-- Rift: бесконечные волны врагов в отдельной арене. Всё, что влияет на баланс, правится здесь.
-- Сервер читает числа (волны, враги, награды), клиент — только тексты и тайминги для показа.

local RiftConfig = {}

-- Арена: круглая площадка далеко от хаба (хаб занимает квадрат ±160 вокруг (0,0,0))
RiftConfig.Arena = {
	Center = Vector3.new(600, 0, 0),
	Radius = 70,
	WallHeight = 40,
	SpawnRadius = 56, -- враги появляются по кольцу этого радиуса
	EntryRadius = 12, -- игроки появляются случайно на кольце этого радиуса вокруг центра
	ExitPortalRadius = 62, -- где стоит портал «Leave the Rift»
	PillarCount = 8,
}

-- Тайминги забега (секунды)
RiftConfig.LobbySeconds = 10 -- ожидание старта после первого входа
RiftConfig.IntermissionSeconds = 6 -- перерыв между волнами (игроки лечатся)
RiftConfig.WaveTimeoutSeconds = 150 -- после этого оставшиеся враги звереют (ускоряются)
RiftConfig.EndSeconds = 6 -- пауза после поражения (показ итогов), потом арена свободна для нового забега
RiftConfig.HealOnIntermission = 0.3 -- доля максимального HP, которую игрок восстанавливает между волнами
RiftConfig.EnrageSpeedMultiplier = 1.5

-- Лимиты (производительность)
RiftConfig.MaxAliveEnemies = 30
RiftConfig.SpawnInterval = 0.4 -- пауза между появлением врагов одной волны

-- Масштабирование: волна растёт линейно, число игроков усиливает врагов (co-op честнее для одиночки)
RiftConfig.Scaling = {
	CountBase = 4, -- врагов в 1-й волне для одного игрока
	CountPerWave = 1.0, -- прибавка врагов за волну
	HealthPerWave = 0.12, -- +12 % HP за волну
	DamagePerWave = 0.08, -- +8 % урона за волну
	CountPerExtraPlayer = 0.5, -- +50 % врагов за каждого игрока сверх первого
	HealthPerExtraPlayer = 0.5, -- +50 % HP за каждого игрока сверх первого
	BossEvery = 10, -- каждая 10-я волна — босс (в этом PR босс = усиленный Brute-гигант)
	ChestEvery = 5, -- каждая 5-я волна — сундук
	RunnerFromWave = 3,
	RunnerShare = 0.25,
	BruteFromWave = 6,
	BruteShare = 0.15,
	BossMinionShare = 0.5, -- доля обычного состава, идущая вместе с боссом
}

-- Враги: Health/Damage — базовые значения (умножаются на масштаб волны), Speed — WalkSpeed, Size — масштаб модели
RiftConfig.Enemies = {
	Grunt = {
		Name = "Rift Grunt",
		Health = 60,
		Damage = 6,
		Speed = 12,
		Size = 1,
		AttackRange = 4.5,
		AttackCooldown = 1.2,
		Color = Color3.fromRGB(200, 90, 90),
		KillCrystals = 1,
	},
	Runner = {
		Name = "Rift Runner",
		Health = 35,
		Damage = 4,
		Speed = 17,
		Size = 0.8,
		AttackRange = 4,
		AttackCooldown = 0.9,
		Color = Color3.fromRGB(230, 170, 60),
		KillCrystals = 1,
	},
	Brute = {
		Name = "Rift Brute",
		Health = 220,
		Damage = 14,
		Speed = 8,
		Size = 1.5,
		AttackRange = 6,
		AttackCooldown = 1.6,
		Color = Color3.fromRGB(120, 80, 170),
		KillCrystals = 3,
	},
	Boss = {
		Name = "Rift Titan",
		Health = 2200,
		Damage = 30,
		Speed = 9,
		Size = 3,
		AttackRange = 9,
		AttackCooldown = 1.8,
		Color = Color3.fromRGB(90, 30, 120),
		KillCrystals = 40,
	},
} :: {
	[string]: {
		Name: string,
		Health: number,
		Damage: number,
		Speed: number,
		Size: number,
		AttackRange: number,
		AttackCooldown: number,
		Color: Color3,
		KillCrystals: number,
	},
}

-- Награда за зачищенную волну: базовая сумма растёт с номером волны; личный множитель — по вкладу в урон
RiftConfig.Rewards = {
	CrystalsBase = 5,
	CrystalsPerWave = 2,
	EssenceBase = 1,
	EssencePerWave = 1,
	FreeloaderMultiplier = 0.5, -- минимум за присутствие (множитель 0.5..1 по доле урона)
}

return RiftConfig
