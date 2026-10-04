--!strict
-- Первые минуты игры: короткие цели-подсказки. Шаги проходятся по порядку; прогресс хранится в профиле игрока,
-- завершение шага определяет сервер (OnboardingService.notify из соответствующих сервисов).

local OnboardingConfig = {}

export type Step = { Key: string, Text: string }

OnboardingConfig.Steps = {
	{
		Key = "EquipRing",
		Text = "Open Rings and wear the Arc Lightning Ring: just tap it!",
	},
	{
		Key = "CastSpell",
		Text = "Go to a training dummy and press ATTACK (or Q)!",
	},
	{ Key = "DpsTest", Text = "Hit a training dummy for 30 seconds to join the leaderboard!" },
	{ Key = "Summon", Text = "Open Summon and get your first new ring!" },
} :: { Step }

-- Награда за прохождение всех шагов
OnboardingConfig.Reward = { Crystals = 50 }

return OnboardingConfig
