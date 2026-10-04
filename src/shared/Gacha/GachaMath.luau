--!strict
-- Математика Gacha (чистая, без Roblox API — проверяется вне Studio).
--
-- Модель как в RNG-играх: кольца идут от самого редкого к самому частому; для каждого (кроме самого частого)
-- шанс срабатывания p = min(1, luck / OneIn); первое сработавшее побеждает, иначе выпадает самое частое кольцо.
-- probabilities() возвращает ТОЧНЫЕ вероятности исходов, по ним же строится показываемая игроку таблица —
-- показанные шансы всегда равны реальным.

local GachaMath = {}

export type Entry = { id: string, oneIn: number }
export type Rng = { NextNumber: (any) -> number } -- подходит и Roblox Random, и тестовый мок

-- От самого редкого к самому частому (при равенстве — по id, чтобы порядок был стабильным)
function GachaMath.sorted(pool: { Entry }): { Entry }
	local list = table.clone(pool)
	table.sort(list, function(a, b)
		if a.oneIn ~= b.oneIn then
			return a.oneIn > b.oneIn
		end
		return a.id < b.id
	end)
	return list
end

function GachaMath.chance(oneIn: number, luck: number): number
	return math.min(1, luck / oneIn)
end

-- Точные вероятности исходов при данной удаче: { [id] = вероятность }, сумма = 1
function GachaMath.probabilities(pool: { Entry }, luck: number): { [string]: number }
	local order = GachaMath.sorted(pool)
	local result: { [string]: number } = {}
	local remaining = 1.0
	for index, entry in order do
		if index == #order then
			result[entry.id] = remaining -- самое частое кольцо забирает остаток
		else
			local p = GachaMath.chance(entry.oneIn, luck)
			result[entry.id] = remaining * p
			remaining *= 1 - p
		end
	end
	return result
end

-- Один бросок: id выпавшего кольца
function GachaMath.roll(pool: { Entry }, luck: number, rng: Rng): string
	local order = GachaMath.sorted(pool)
	for index, entry in order do
		if index == #order then
			return entry.id
		end
		if rng:NextNumber() < GachaMath.chance(entry.oneIn, luck) then
			return entry.id
		end
	end
	error("Gacha pool is empty")
end

---------------------------------------------------------------------------
-- Показ шансов: проценты строками, сумма исходов ровно 100 %
---------------------------------------------------------------------------
-- Работаем целыми «единицами» по 1e-10 процента (100 % = 1e12 единиц) — точное целочисленное сложение,
-- так что сумма показанных чисел ровно 100. Самое частое кольцо получает остаток.
local UNITS_PER_PERCENT = 1e10
local TOTAL_UNITS = 100 * UNITS_PER_PERCENT

-- Целое число единиц -> строка процентов (минимум 2 знака после запятой, без лишних нулей)
function GachaMath.formatUnits(units: number): string
	local whole = math.floor(units / UNITS_PER_PERCENT)
	local fraction = units - whole * UNITS_PER_PERCENT
	local digits = string.format("%010d", fraction)
	local trimmed = string.gsub(digits, "0+$", "")
	if #trimmed < 2 then
		trimmed = string.sub(digits, 1, 2)
	end
	return string.format("%d.%s", whole, trimmed)
end

-- { [id] = единицы } — целые единицы процента; сумма ровно TOTAL_UNITS
function GachaMath.units(pool: { Entry }, luck: number): { [string]: number }
	local order = GachaMath.sorted(pool)
	local probs = GachaMath.probabilities(pool, luck)
	local result: { [string]: number } = {}
	local used = 0
	for index, entry in order do
		if index == #order then
			result[entry.id] = TOTAL_UNITS - used
		else
			local units = math.floor(probs[entry.id] * TOTAL_UNITS + 0.5)
			result[entry.id] = units
			used += units
		end
	end
	return result
end

-- Фактический шанс кольца с учётом удачи и каскада: «1 in 3.3» / «1 in 50,000,000» (по вероятности p)
function GachaMath.formatEffective(p: number): string
	if p <= 0 then
		return "—"
	end
	local n = 1 / p
	if n < 10 then
		return string.format("1 in %.1f", n)
	end
	return GachaMath.formatOneIn(math.floor(n + 0.5))
end

-- «1 in 50,000,000» (базовая редкость кольца)
function GachaMath.formatOneIn(oneIn: number): string
	local text = string.format("%d", oneIn)
	local out = text
	repeat
		local replaced
		out, replaced = string.gsub(out, "^(-?%d+)(%d%d%d)", "%1,%2")
	until replaced == 0
	return "1 in " .. out
end

GachaMath.TOTAL_UNITS = TOTAL_UNITS

return GachaMath
