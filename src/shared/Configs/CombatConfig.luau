--!strict
-- Общие настройки боя: тег врагов, мана, допуски валидации, таргет.

local CombatConfig = {
	EnemyTag = "Enemy", -- тег CollectionService: только такие модели можно бить
	RingSlotCount = 4, -- слотов колец (RingBar)
	RangeTolerance = 4, -- запас (studs) при серверной проверке дистанции — компенсирует лаг
	TabTargetRange = 100, -- радиус выбора цели по Tab (дальность каста проверяется отдельно при касте)

	Mana = {
		Max = 100,
		RegenPerSecond = 5,
	},

	-- Прогрессия: опыт до следующего уровня = BaseXp * Growth^(level-1)
	Progression = {
		BaseXp = 100,
		Growth = 1.35,
		XpPerKill = 25,
	},
}

return CombatConfig
