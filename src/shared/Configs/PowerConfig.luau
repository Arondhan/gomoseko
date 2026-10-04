--!strict
-- Рост силы игрока: бонусы уровня и улучшение колец за Essence и Gold. Все числа баланса — здесь.

local PowerConfig = {}

-- Пассивные бонусы уровня (за каждый уровень выше 1). Опыт не копится выше MaxLevel.
PowerConfig.Level = {
	MaxLevel = 60,
	DamagePctPerLevel = 2, -- +% к урону скиллов
	BaseHealth = 100,
	HealthPerLevel = 6, -- +HP
	ManaPerLevel = 1, -- +максимум маны
}

-- Улучшение колец: уровни 1..MaxLevel, цена растёт в CostGrowth раз за уровень и зависит от качества кольца
PowerConfig.Rings = {
	MaxLevel = 10,
	PassivePerLevel = 0.12, -- пассивные бонусы кольца +12 % от базы за каждый уровень выше 1
	SkillDamagePctPerLevel = 8, -- +% урона скилла этого кольца за каждый уровень выше 1
	EssenceBase = 8,
	GoldBase = 50,
	CostGrowth = 1.5,
}

PowerConfig.QualityMultiplier = {
	Common = 1,
	Uncommon = 1.5,
	Rare = 2.5,
	Epic = 5,
	Legendary = 12,
	Mythic = 40,
	Divine = 150,
} :: { [string]: number }

return PowerConfig
