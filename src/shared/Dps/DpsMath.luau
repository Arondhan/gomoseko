--!strict
-- Чистая математика DPS-арены (без Roblox API — проверяется вне Studio): счёт, идентификаторы периодов, награды.
-- Счёт хранится целым числом «DPS × 10» (OrderedDataStore принимает только целые).

local DpsMath = {}

local SECONDS_PER_DAY = 86400

-- «DPS × 10», округлённый: total урона за duration секунд
function DpsMath.score(totalDamage: number, duration: number): number
	if duration <= 0 then
		return 0
	end
	return math.floor(totalDamage / duration * 10 + 0.5)
end

-- Показываемый DPS из счёта: 1543 -> "154.3"
function DpsMath.format(score: number): string
	return string.format("%.1f", score / 10)
end

-- Номер дня (UTC) от начала эпохи
function DpsMath.dayId(timestamp: number): number
	return math.floor(timestamp / SECONDS_PER_DAY)
end

-- Номер недели (UTC), неделя начинается в понедельник (1 января 1970 — четверг)
function DpsMath.weekId(timestamp: number): number
	return math.floor((DpsMath.dayId(timestamp) + 3) / 7)
end

-- Секунд до конца текущего дня / недели (UTC) — для подписей «обновится через …»
function DpsMath.secondsToDayEnd(timestamp: number): number
	return (DpsMath.dayId(timestamp) + 1) * SECONDS_PER_DAY - timestamp
end

function DpsMath.secondsToWeekEnd(timestamp: number): number
	return (DpsMath.weekId(timestamp) * 7 - 3 + 7) * SECONDS_PER_DAY - timestamp
end

export type RewardTier = { MaxRank: number, Crystals: number }

-- Награда кристаллами за место (1 — лучшее); tiers отсортированы по возрастанию MaxRank. 0 — без награды.
function DpsMath.rewardForRank(rank: number, tiers: { RewardTier }): number
	if rank < 1 then
		return 0
	end
	for _, tier in tiers do
		if rank <= tier.MaxRank then
			return tier.Crystals
		end
	end
	return 0
end

return DpsMath
