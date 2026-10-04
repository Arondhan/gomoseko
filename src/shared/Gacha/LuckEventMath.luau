--!strict
-- Lucky Hour: расписание по unix-времени. Окно k начинается в k * Period и длится Duration секунд.
-- Все серверы считают одно и то же по os.time(), поэтому событие синхронно без межсерверных сообщений.

local LuckEventMath = {}

export type Config = { Period: number, Duration: number }

export type Status = {
	active: boolean,
	endsIn: number, -- секунд до конца окна (0, если не активно)
	startsIn: number, -- секунд до начала следующего окна (0, если активно)
	endsAt: number, -- unix-время конца активного окна (0, если не активно)
}

function LuckEventMath.status(now: number, config: Config): Status
	local into = now % config.Period
	if into < config.Duration then
		local endsIn = config.Duration - into
		return { active = true, endsIn = endsIn, startsIn = 0, endsAt = now + endsIn }
	end
	return { active = false, endsIn = 0, startsIn = config.Period - into, endsAt = 0 }
end

return LuckEventMath
