--!strict
-- Первые минуты игры: короткие цели-подсказки. Шаги проходятся по порядку; прогресс хранится в профиле игрока,
-- завершение шага определяет сервер (OnboardingService.notify из соответствующих сервисов).

local OnboardingConfig = {}

export type Step = { Key: string, Text: string }

OnboardingConfig.Steps = {
	{
		Key = "EquipRing",
		Text = "Open Inventory (I) and equip the Arc Lightning Ring: drag it onto a ring slot or right-click it.",
	},
	{
		Key = "CastSpell",
		Text = "Select a training dummy and press 1 (or Q / tap its ring slot) to cast Arc Lightning.",
	},
	{ Key = "DpsTest", Text = "Hit a training dummy for 30 seconds to set your DPS score and join the leaderboard." },
	{ Key = "Summon", Text = "Open Ring Summon (G) and summon your first new ring." },
} :: { Step }

-- Награда за прохождение всех шагов
OnboardingConfig.Reward = { Crystals = 50 }

return OnboardingConfig
