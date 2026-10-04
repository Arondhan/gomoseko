--!strict
-- Index (книга колец): прогресс коллекции и достигнутые вехи. Чистая математика, тестируется в CLI.

local IndexMath = {}

-- Процент коллекции (0..100, дробный); пустая коллекция — 0
function IndexMath.percent(discovered: number, total: number): number
	if total <= 0 then
		return 0
	end
	return math.clamp(discovered / total * 100, 0, 100)
end

-- Достигнута ли веха milestonePercent: сравнение целыми (discovered * 100 >= percent * total) без ошибок float
function IndexMath.reached(discovered: number, total: number, milestonePercent: number): boolean
	return total > 0 and discovered * 100 >= milestonePercent * total
end

-- Сколько колец нужно для вехи (округление вверх)
function IndexMath.ringsNeeded(total: number, milestonePercent: number): number
	return math.ceil(total * milestonePercent / 100 - 1e-9)
end

return IndexMath
