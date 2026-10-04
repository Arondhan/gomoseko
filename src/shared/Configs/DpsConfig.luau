--!strict
-- DPS-арена: тренировочные манекены не умирают, игрок 30 секунд бьёт по ним — счёт идёт в лидерборды.
-- Все числа наград и лидербордов правятся здесь.

local DpsConfig = {
	TestDuration = 30, -- длительность замера, сек (старт — первый удар по манекену)
	StatusInterval = 0.25, -- как часто сервер шлёт клиенту прогресс замера
	LeaderboardSize = 50, -- сколько мест хранит и показывает лидерборд
	RefreshSeconds = 60, -- как часто сервер обновляет таблицы лидеров
	BoardCycleSeconds = 8, -- как часто доска в хабе переключается между Daily / Weekly / All-time

	-- Награда за каждый завершённый замер
	TestRewards = {
		Xp = 25,
		GoldPer100Damage = 1, -- золото за каждые 100 нанесённого урона
		Crystals = 1,
		FirstOfDayCrystals = 10, -- бонус за первый замер за (UTC) день
	},

	-- Недельная награда по месту в прошлой неделе (Summon Crystals); забирается автоматически при входе
	WeeklyRewards = {
		{ MaxRank = 1, Crystals = 500 },
		{ MaxRank = 3, Crystals = 300 },
		{ MaxRank = 10, Crystals = 150 },
		{ MaxRank = 50, Crystals = 50 },
	},
}

return DpsConfig
