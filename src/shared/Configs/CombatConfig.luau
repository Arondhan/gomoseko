--!strict
-- Общие настройки боя: тег врагов, мана, допуски валидации, таргет.

local CombatConfig = {
	EnemyTag = "Enemy", -- тег CollectionService: только такие модели можно бить
	RingSlotCount = 4, -- слотов колец (RingBar)
	RangeTolerance = 4, -- запас (studs) при серверной проверке дистанции — компенсирует лаг
	TabTargetRange = 40, -- радиус выбора ближайшей цели по Tab

	Mana = {
		Max = 100,
		RegenPerSecond = 5,
	},
}

return CombatConfig
