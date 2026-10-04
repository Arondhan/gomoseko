--!strict
-- AFK Playtime Luck: чистая математика бонуса за непрерывное время на сервере (без Roblox API — тестируется в CLI).

local PlaytimeMath = {}

export type Config = { StepSeconds: number, StepPercent: number, MaxPercent: number }

export type Info = {
	steps: number, -- сколько полных шагов набрано
	percent: number, -- бонус к удаче в процентах (с учётом лимита)
	bonus: number, -- то же в «иксах» (0.2 = +0.2x)
	nextIn: number?, -- секунд до следующего шага (nil, если достигнут максимум)
	capped: boolean,
}

-- elapsed — секунд с момента входа на сервер
function PlaytimeMath.info(elapsed: number, config: Config): Info
	local steps = math.floor(math.max(0, elapsed) / config.StepSeconds)
	local percent = math.min(config.MaxPercent, steps * config.StepPercent)
	local capped = percent >= config.MaxPercent
	local nextIn: number? = nil
	if not capped then
		nextIn = config.StepSeconds - (math.max(0, elapsed) % config.StepSeconds)
	end
	return { steps = steps, percent = percent, bonus = percent / 100, nextIn = nextIn, capped = capped }
end

return PlaytimeMath
