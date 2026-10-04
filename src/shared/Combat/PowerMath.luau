--!strict
-- Чистая математика роста силы (без Roblox API — проверяется в CLI): бонусы уровня, уровни колец, цена апгрейда.
-- Используется server/Services/StatsService, InventoryService и клиентским UI (подсказки, кнопка апгрейда).

local PowerMath = {}

export type LevelConfig = {
	MaxLevel: number,
	DamagePctPerLevel: number,
	BaseHealth: number,
	HealthPerLevel: number,
	ManaPerLevel: number,
}

export type RingConfig = {
	MaxLevel: number,
	PassivePerLevel: number,
	SkillDamagePctPerLevel: number,
	EssenceBase: number,
	GoldBase: number,
	CostGrowth: number,
}

local function clampLevel(level: number, max: number): number
	return math.clamp(math.floor(level), 1, max)
end

-- Бонус к урону от уровня игрока, %
function PowerMath.levelDamagePct(level: number, config: LevelConfig): number
	return (clampLevel(level, config.MaxLevel) - 1) * config.DamagePctPerLevel
end

function PowerMath.levelMaxHealth(level: number, config: LevelConfig): number
	return config.BaseHealth + (clampLevel(level, config.MaxLevel) - 1) * config.HealthPerLevel
end

function PowerMath.levelMaxMana(level: number, config: LevelConfig): number
	return (clampLevel(level, config.MaxLevel) - 1) * config.ManaPerLevel
end

-- Корректный уровень кольца (нет записи в профиле = 1)
function PowerMath.ringLevel(value: number?, config: RingConfig): number
	if type(value) ~= "number" or value ~= value then
		return 1
	end
	return clampLevel(value, config.MaxLevel)
end

-- Множитель пассивных бонусов кольца
function PowerMath.ringStatMultiplier(level: number, config: RingConfig): number
	return 1 + config.PassivePerLevel * (PowerMath.ringLevel(level, config) - 1)
end

-- Бонус к урону скилла этого кольца, %
function PowerMath.skillDamagePct(level: number, config: RingConfig): number
	return (PowerMath.ringLevel(level, config) - 1) * config.SkillDamagePctPerLevel
end

-- Цена перехода с уровня fromLevel на следующий: (Essence, Gold). nil — кольцо уже на максимуме.
function PowerMath.upgradeCost(qualityMultiplier: number, fromLevel: number, config: RingConfig): (number?, number?)
	local level = PowerMath.ringLevel(fromLevel, config)
	if level >= config.MaxLevel then
		return nil, nil
	end
	local growth = config.CostGrowth ^ (level - 1)
	return math.ceil(config.EssenceBase * qualityMultiplier * growth),
		math.ceil(config.GoldBase * qualityMultiplier * growth)
end

return PowerMath
