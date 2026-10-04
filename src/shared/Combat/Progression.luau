--!strict
-- Чистая математика уровней и опыта (без Roblox API — проверяется вне Studio).

local Progression = {}

-- Опыт, нужный для перехода с уровня level на level+1
function Progression.xpToNext(level: number, baseXp: number, growth: number): number
	return math.floor(baseXp * growth ^ (level - 1) + 0.5)
end

-- Добавляет опыт; возвращает новые (level, xp, сколько уровней получено)
function Progression.add(
	level: number,
	xp: number,
	amount: number,
	baseXp: number,
	growth: number
): (number, number, number)
	local gained = 0
	xp += amount
	local needed = Progression.xpToNext(level, baseXp, growth)
	while xp >= needed do
		xp -= needed
		level += 1
		gained += 1
		needed = Progression.xpToNext(level, baseXp, growth)
	end
	return level, xp, gained
end

return Progression
