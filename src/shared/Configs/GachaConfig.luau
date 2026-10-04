--!strict
-- Настройки Gacha (призыв колец) и экономики. Всё, что влияет на шансы и награды, правится здесь.

local GachaConfig = {
	RollCost = 10, -- Summon Crystals за один призыв
	MultiCount = 10, -- размер «мульти»-призыва (стоит MultiCount * RollCost)
	RollCooldown = 0.6, -- мин. пауза между запросами призыва, сек (анти-спам)
	FastRollCooldown = 0.3, -- то же для владельцев пасса FastRoll

	FreeRollCooldown = 20 * 3600, -- бесплатный ролл раз в 20 часов

	-- Удача: итоговый множитель = 1 + (бонусы колец + платные бонусы) / 100, но не выше Max
	Luck = {
		Max = 25,
	},

	-- AFK Playtime Luck: за каждые StepSeconds непрерывной игры на сервере +StepPercent % удачи (+0.1x), максимум
	-- MaxPercent (+1.0x => общий множитель x2.0 при прочих равных). Хранится только в памяти сервера: выход сбрасывает.
	Playtime = {
		StepSeconds = 600,
		StepPercent = 10,
		MaxPercent = 100,
	},

	-- Lucky Hour: окно удачи по расписанию (по unix-времени, поэтому одинаково на всех серверах без MessagingService).
	-- Каждые Period секунд на Duration секунд все получают +Percent % удачи; показывается в разбивке удачи и в шансах.
	LuckEvent = {
		Name = "Lucky Hour",
		Period = 1800,
		Duration = 300,
		Percent = 100,
	},

	-- Титул над головой: градиент-волна для колец не реже 1 из MinGradientOneIn, радужная — от RainbowOneIn
	Overhead = {
		MinGradientOneIn = 500,
		RainbowOneIn = 1000000,
	},

	-- Находки не реже 1 из MinOneIn объявляются всем игрокам
	Announce = {
		MinOneIn = 100000,
	},

	-- Кинематографичная катсцена (камера, затемнение, гром) для находок не реже 1 из MinOneIn
	Cinematic = {
		MinOneIn = 1000,
	},

	-- Ring Essence за дубликат (по качеству)
	Essence = {
		Common = 1,
		Uncommon = 3,
		Rare = 10,
		Epic = 40,
		Legendary = 200,
		Mythic = 1000,
		Divine = 5000,
	} :: { [string]: number },

	-- Стартовые запасы и награды (экономика пока тестовая)
	Starting = {
		Crystals = 1600,
		Gold = 0,
	},
	Rewards = {
		KillGold = 10,
		KillCrystals = 1,
		LevelUpCrystals = 25,
	},
}

return GachaConfig
